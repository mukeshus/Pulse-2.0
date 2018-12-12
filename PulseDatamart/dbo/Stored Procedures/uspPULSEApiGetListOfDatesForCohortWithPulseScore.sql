
CREATE PROCEDURE [dbo].[uspPULSEApiGetListOfDatesForCohortWithPulseScore]
	@pSourceSystemID				INT			= 2
	, @pInstitutionID				BIGINT		= 0
	, @pClassID						BIGINT		= 0		OUT		
	, @pStartDate					DATE		= NULL
	, @pEndDate						DATE		= NULL
	, @pClassName					VARCHAR(100)		OUT
	, @pFirstAssessmentDate			DATE			OUT
	, @pStartDateMinValue			DATE			OUT
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of dates for a cohort with pulse score information
Author          : Deepak Patro
Date Created    : 05-Oct-2018
Date Modified   : 05-Oct-2018
Description     : Gets list of dates for a cohort and institution with pulse score for each date
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	DECLARE @pClassID				BIGINT		= 32513	--NULL	--32513	--41748	--48811
	DECLARE @pClassName				VARCHAR(100)
	DECLARE @pFirstAssessmentDate	VARCHAR(15)
	DECLARE @pStartDateMinValue		VARCHAR(15)
	EXEC dbo.uspPULSEApiGetListOfDatesForCohortWithPulseScore
		@pSourceSystemID			= 2
		, @pInstitutionID			= 9	--NULL	--9	--7717
		, @pStartDate				= NULL --NULL --'1993-06-27'
		, @pEndDate					= NULL --NULL --'2018-06-28'
		, @pClassID					= @pClassID OUT
		, @pClassName				= @pClassName OUT
		, @pFirstAssessmentDate		= @pFirstAssessmentDate OUT
		, @pStartDateMinValue		= @pStartDateMinValue OUT
	SELECT 
		@pClassID AS CohortID
		, @pClassName AS CohortName
		, @pFirstAssessmentDate AS FirstAssessmentDate
		, @pStartDateMinValue AS StartDateMinValue
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT		= @pInstitutionID
	DECLARE @ClassID			    BIGINT		= @pClassID
	DECLARE @EndDate				DATE		= COALESCE(@pEndDate,CONVERT(DATE,GETDATE()))
	DECLARE @StartDate				DATE		= COALESCE(@pStartDate,DATEADD(YEAR,-2,@EndDate))
	DECLARE @TwoYearsBackDate		DATE		= DATEADD(YEAR,-2,@EndDate)

	DECLARE @SnapshotEntriesForCohortId TABLE (
		CohortID 						BIGINT
		, SnapshotDate 					DATE
		, AvgPoP 						NUMERIC(3)
		, SeqNum						INT
	)

	--Fetching Cohort Id and Cohort name  for the given Cohort
	SELECT 
		@pClassID = DC.ClassID
		, @pClassName = DC.ClassName
	FROM
		ATICommon.dbo.DimClass AS DC WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID

	INSERT INTO @SnapshotEntriesForCohortId (CohortID, SnapshotDate, AvgPoP, SeqNum)
	SELECT
		ClassID AS CohortID
		, SnapshotDate
		, AvgPoP
		, (ROW_NUMBER() OVER (PARTITION BY SnapshotDate ORDER BY DateModified DESC)) AS SeqNum
	FROM 
		dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
	
	--Fetching first assessment date for the given Cohort
	SELECT TOP 1
		@pFirstAssessmentDate = SnapshotDate
	FROM
		@SnapshotEntriesForCohortId
	WHERE
		SeqNum = 1
	ORDER BY
		SnapshotDate

	
	SELECT @pStartDateMinValue =	CASE
										WHEN @pFirstAssessmentDate = NULL THEN NULL
										WHEN @TwoYearsBackDate > @pFirstAssessmentDate THEN @TwoYearsBackDate
										ELSE @pFirstAssessmentDate
									END

	--Fetching Scores for the given Cohort for all dates within the given date range
	SELECT
		SnapshotDate AS assessmentDate
		, AvgPoP AS AvgPoP
	FROM
		@SnapshotEntriesForCohortId
	WHERE
		SeqNum = 1
		AND SnapshotDate >= @StartDate
		AND SnapshotDate <= @EndDate
	ORDER BY
		SnapshotDate DESC

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Dubey     | 05-Oct-2018 | ATIPUL2-1162 - Initial version (For Date Filter limits)                                     |
===================================================================================================================================
**********************************************************************************************************************************/

END
