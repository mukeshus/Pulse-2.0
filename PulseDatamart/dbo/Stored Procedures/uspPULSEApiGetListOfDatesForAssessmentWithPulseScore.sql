
CREATE PROCEDURE [dbo].[uspPULSEApiGetListOfDatesForAssessmentWithPulseScore]
	@pSourceSystemID				INT			= 2
	, @pInstitutionID				BIGINT
	, @pClassID						BIGINT
	, @pAssessmentID				BIGINT				OUT	
	, @pStartDate					DATE		= NULL
	, @pEndDate						DATE		= NULL
	, @pAssessmentName				VARCHAR(50)			OUT
	, @pFirstAssessmentDate			VARCHAR(15)			OUT
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of dates for a student with pulse score information
Author          : Deepak Patro
Date Created    : 05-Jul-2018
Date Modified   : 05-Jul-2018
Description     : Gets list of dates for a student within a given cohort and institution with pulse score for each date within the given date range
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	DECLARE @pAssessmentID			BIGINT		= 118577 --7 --17
	DECLARE @pAssessmentName		VARCHAR(50)
	DECLARE @pFirstAssessmentDate	VARCHAR(15)
	EXEC dbo.uspPULSEApiGetListOfDatesForAssessmentWithPulseScore
		@pSourceSystemID			= 2
		, @pInstitutionID			= 7717 --NULL --7717 --7718
		, @pClassID					= 43738 --NULL ---1 --43738 --44464 --49379
		, @pStartDate				= '2016-06-28' --NULL --'2016-06-28'
		, @pEndDate					= '2018-06-28' --NULL --'2018-06-28'
		, @pAssessmentID			= @pAssessmentID OUT
		, @pAssessmentName			= @pAssessmentName OUT
		, @pFirstAssessmentDate		= @pFirstAssessmentDate OUT
	SELECT @pAssessmentID AS AssessmentID, @pAssessmentName AS AssessmentName,	@pFirstAssessmentDate AS FirstAssessmentDate
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT		= @pInstitutionID
	DECLARE @ClassID			    BIGINT		= @pClassID
	DECLARE @AssessmentID			BIGINT		= @pAssessmentID
	DECLARE @AssessmentName			VARCHAR(50)	= @pAssessmentName
	DECLARE @EndDate				DATE		= COALESCE(@pEndDate,CONVERT(DATE,GETDATE()))
	DECLARE @StartDate				DATE		= COALESCE(@pStartDate,DATEADD(YEAR,-2,CONVERT(DATE,GETDATE())))

	DECLARE @AssessmentEntriesForAssessmentId TABLE (
		AssessmentID 					BIGINT
		, AssessmentDate 				DATE
		, ProbNCLEX 					NUMERIC(4)
		, SeqNum						INT
	)

	--Fetching the required and filtered fields from AssessmentDailySnapshot for subsequent use
	INSERT INTO @AssessmentEntriesForAssessmentId (AssessmentID, AssessmentDate, ProbNCLEX, SeqNum)
	SELECT
		AssessmentID AS AssessmentID
		, CONVERT(DATE, [Date]) AS AssessmentDate
		, AVG(AvgSSMScore) AS ProbNCLEX
		, (ROW_NUMBER() OVER (PARTITION BY CONVERT(DATE, [Date]) ORDER BY [Date] DESC)) AS SeqNum
	FROM 
		dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ActiveClassID = @ClassID
		AND AssessmentID = @AssessmentID
		AND SourceSystemID = @SourceSystemID
	GROUP BY
		AssessmentID, [Date]
	ORDER BY
		[Date] DESC

	--Fetching first assessment date for the given Student
	SELECT TOP 1
		@pFirstAssessmentDate = CONVERT(VARCHAR(15),AssessmentDate)
	FROM
		@AssessmentEntriesForAssessmentId
	WHERE
		SeqNum = 1
	ORDER BY
		AssessmentDate

	SELECT @pFirstAssessmentDate = COALESCE(@pFirstAssessmentDate,'n/a')

	--Fetching Scores for the given Assessment for all dates within the given date range
	SELECT
		CONVERT(VARCHAR(15),AssessmentDate) AS AssessmentDate
		, ProbNCLEX
	FROM
		@AssessmentEntriesForAssessmentId
	WHERE
		AssessmentDate >= @StartDate
		AND AssessmentDate <= @EndDate
		AND SeqNum = 1
	ORDER BY
		AssessmentDate

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Patro     | 5-Jul-2018 | ATIPUL2-672 - Initial Version                                                               |
===================================================================================================================================
**********************************************************************************************************************************/

END
