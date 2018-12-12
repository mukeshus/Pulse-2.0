

CREATE PROCEDURE [dbo].[uspPULSEApiGetTimelineDetailsForCohort]
	@pSourceSystemID				INT				= 2
	, @pInstitutionID				BIGINT          = NULL
	, @pClassID						BIGINT          = NULL
	, @pEndDate						DATE			= NULL
	, @pPaginationPageSize			INT				= 10
	, @pPaginationPageNumber		INT				= 1
	, @pTotalRecords				BIGINT					OUT
AS
BEGIN


/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve timeline details for a cohort.
Author          : Deepak Patro
Date Created    : 05-Nov-2018
Date Modified   : 29-Nov-2018
Description     : Gets avgPoP and assessment details for a cohort categorized by dates
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	DECLARE @pTotalRecords			BIGINT
	EXEC dbo.uspPULSEApiGetTimelineDetailsForCohort
		@pSourceSystemID			= 2
		, @pInstitutionID			= 9393	--NULL	--9		--393
		, @pClassID					= 48961	--NULL	--32513	--12815
		, @pEndDate					= NULL	--'2018-08-05' --NULL --'1993-06-28'
		, @pPaginationPageSize		= 25
		, @pPaginationPageNumber	= 1
		, @pTotalRecords			= @pTotalRecords OUT
	SELECT 
		@pTotalRecords AS TotalRecords
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT			= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT			= @pInstitutionID
	DECLARE @ClassID			    BIGINT			= @pClassID
	DECLARE @EndDate				DATE			= COALESCE(@pEndDate,CONVERT(date,getdate()))
	DECLARE @PaginationPageSize		INT				= COALESCE(@pPaginationPageSize,5)
	DECLARE @PaginationPageNumber	INT				= COALESCE(@pPaginationPageNumber,1)

	--SELECT @EndDate

	DECLARE @SnapshotEntriesWithDates TABLE (
		AssessmentDate					DATE
		, AssessmentID					INT
		, AssessmentName				NVARCHAR(128)
		, AvgPoP						VARCHAR(5)
		, AttemptsTaken					INT
		, SeqNumPerDate					INT
		, SeqNumPerDateAssmnt			INT
	)
	
	DECLARE @SnapshotEntriesWithAvgPoP TABLE (
		AssessmentDate					DATE
		, AvgPoP						VARCHAR(5)
	)

	DECLARE @SnapshotEntriesWithAssessments TABLE (
		AssessmentDate					DATE
		, AssessmentID					INT
		, AssessmentName				NVARCHAR(128)
		, AttemptsTaken					INT
		, SeqNumPerDate					INT
		, SeqNumPerDateAssmnt			INT
	)

	INSERT INTO @SnapshotEntriesWithDates (AssessmentDate, AssessmentID, AssessmentName, AvgPoP, AttemptsTaken, SeqNumPerDate, SeqNumPerDateAssmnt)
	SELECT 
		SnapshotDate AS AssessmentDate
		, AssessmentID
		, AssessmentName
		, CONVERT(VARCHAR(5),CAST(AvgPoP AS NUMERIC(3))) AS AvgPoP
		, Attempts AS AttemptsTaken
		, ROW_NUMBER () OVER (PARTITION BY SnapshotDate ORDER BY DateModified DESC) AS SeqNumPerDate
		, ROW_NUMBER () OVER (PARTITION BY SnapshotDate, AssessmentName ORDER BY DateModified DESC) AS SeqNumPerDateAssmnt
	FROM 
		dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND SnapshotDate <= @EndDate
		AND (Attempts IS NOT NULL AND Attempts <> 0)

	--SELECT * FROM @SnapshotEntriesWithDates

	INSERT INTO @SnapshotEntriesWithAvgPoP (AssessmentDate, AvgPoP)
	SELECT 
		AssessmentDate
		, AvgPoP
	FROM 
		@SnapshotEntriesWithDates
	WHERE
		SeqNumPerDate = 1

	INSERT INTO @SnapshotEntriesWithAssessments (AssessmentDate, AssessmentID, AssessmentName, AttemptsTaken, SeqNumPerDate, SeqNumPerDateAssmnt)
	SELECT 
		AssessmentDate
		, AssessmentID
		, AssessmentName
		, AttemptsTaken
		, SeqNumPerDate
		, SeqNumPerDateAssmnt
	FROM 
		@SnapshotEntriesWithDates
	WHERE
		SeqNumPerDateAssmnt = 1
	
	--SELECT * FROM @SnapshotEntriesWithAvgPoP
	--SELECT * FROM @SnapshotEntriesWithAssessments

	SELECT
		@pTotalRecords = COUNT(1)
	FROM
		@SnapshotEntriesWithAssessments
		
	SELECT
		YEAR(SEWA.AssessmentDate) AS Year
		, UPPER(FORMAT(SEWA.AssessmentDate, 'MMM')) AS Month
		, SEWA.AssessmentDate AS Date
		, COALESCE(SEWP.AvgPoP, 'n/a') AS AvgPoP
		, SEWA.AssessmentID
		, SEWA.AssessmentName
		, SEWA.AttemptsTaken
		, ROW_NUMBER () OVER (ORDER BY SEWA.AssessmentDate DESC) AS RowNum
	FROM
		@SnapshotEntriesWithAssessments AS SEWA
		LEFT JOIN @SnapshotEntriesWithAvgPoP AS SEWP
			ON SEWA.AssessmentDate = SEWP.AssessmentDate
	ORDER BY
		SEWA.AssessmentDate DESC, SEWA.SeqNumPerDate
	OFFSET @PaginationPageSize * (@PaginationPageNumber - 1) ROWS
	FETCH NEXT @PaginationPageSize ROWS ONLY

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Patro     | 05-Nov-2018 | Initial version - ATIPUL2-1217                                                              |
===================================================================================================================================
|   Deepak Patro     | 19-Nov-2018 | Updated format of output parameter - 'date' to UTC standard format                          |
===================================================================================================================================
|   Deepak Patro     | 22-Nov-2018 | Updated source from dbo.FactSSM to dbo.AssessmentDailySnapshot under issue ATIPUL2-1558.    |
===================================================================================================================================
|   Deepak Patro     | 23-Nov-2018 | Changed attribute from 'NumOfStudentsTaken' to 'AttemptsTaken'                              |
===================================================================================================================================
|   Deepak Patro     | 29-Nov-2018 | Changed source of attribute 'AttemptsTaken' from count of assessment ids to new field added |
|                    |             | in dbo.AssessmentDailySnapshot table                                                        |
===================================================================================================================================
**********************************************************************************************************************************/

END
