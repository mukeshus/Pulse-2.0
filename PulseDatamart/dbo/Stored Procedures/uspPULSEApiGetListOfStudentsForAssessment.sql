
CREATE    PROCEDURE [dbo].[uspPULSEApiGetListOfStudentsForAssessment]
	@pSourceSystemID				INT				= 2
	, @pAssessmentID				BIGINT			= NULL			
	, @pStartDate					DATE			= NULL
	, @pEndDate						DATE			= NULL
	, @pAssessmentName				VARCHAR(50)		= NULL		OUT
	--, @pSortByColumn				VARCHAR(255)	= NULL
	--, @pSortOrder					VARCHAR(5)		= NULL
	--, @pPaginationPageSize			INT				= 10
	--, @pPaginationPageNumber		INT				= 1
	, @pTotalRecords				BIGINT			= NULL		OUT
AS
BEGIN

/*** Script Details *******************************************************a********************************************************
Title			: Stored Procedure to retrieve list of assessment attempts for a student within current program type
Author          : Hansraj Bendale
Date Created    : 06-Dec-2018
Date Modified   : 06-Dec-2018
Description     : Gets list of assessment attempts for a student within current program type and for a given date range.
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 

	SET STATISTICS IO, TIME ON
	DECLARE @pStudentID				BIGINT		= 176262 --NULL --76662 --78456 --139820 --176262 --76726
	DECLARE @pStudentName			VARCHAR(50)
	DECLARE @pStudentUserName		VARCHAR(25)
	DECLARE @pTotalRecords			BIGINT
	EXEC dbo.uspPULSEApiGetListOfAssessmentAttemptsForStudent
		@pSourceSystemID			= 2
		, @pStartDate				= '2000-02-28' --NULL --'2016-06-28'
		, @pEndDate					= NULL --NULL --'2018-06-28'
		, @pStudentID				= @pStudentID OUT
		, @pStudentName				= @pStudentName OUT
		, @pStudentUserName			= @pStudentUserName OUT
		, @pSortByColumn			= 'ATTEMPT'	--NULL	--'DATE'	--'ASSESSMENT'	-- 'SCORE'	--'RISK'	--'POP'	--'ATTEMPT'	--''
		, @pSortOrder				= 'ASC'	--'ASC'	--'DESC'
		, @pPaginationPageSize		= 20
		, @pPaginationPageNumber	= 1
		, @pTotalRecords			= @pTotalRecords OUT
	SELECT 
		@pStudentID AS StudentID
		, @pStudentName AS StudentName
		, @pStudentUserName AS StudentUserName
		, @pTotalRecords AS TotalRecords
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT			= COALESCE(@pSourceSystemID,2)
	DECLARE @AssessmentID			BIGINT			= @pAssessmentID
	DECLARE @EndDate				DATE			= @pEndDate
	DECLARE @StartDate				DATE			= @pStartDate
	
	--SELECT @SourceSystemID, @AssessmentID, @StartDate, @EndDate
	--DECLARE @pAssessmentID  BIGINT = 132116
	--DECLARE @pAssessmentName VARCHAR(50)
	--DECLARE @pTotalRecords			BIGINT

	DECLARE @FactSSMEntriesForAssessmentId TABLE (
		StudentId						BIGINT
		, StudentName					VARCHAR(255)
		, ProbNCLEX 					VARCHAR(5)
		, TotalScore					VARCHAR(5)
		, RiskCategory					VARCHAR(10)
		, Attempt						VARCHAR(5)
		, AttemptNum					INT
		, Validity						VARCHAR(8)
	)

	--Fetching Assessment Id, Assessment Name for the given Assessment
	SELECT
		@pAssessmentID = AssessmentID
		, @pAssessmentName = Name
	FROM
		ATICommon.dbo.DimAssessmentDetail WITH (NOLOCK)
	WHERE
		AssessmentID = @AssessmentID
		AND SourceSystemID = @SourceSystemID

	--Fetching the required and filtered fields from FactSSM for subsequent use
	INSERT INTO @FactSSMEntriesForAssessmentId (StudentId, StudentName, ProbNCLEX, TotalScore, RiskCategory, Attempt, AttemptNum, Validity)
	SELECT
		FSSM.UserID AS StudentId
		, DS.LastName + ', ' + DS.FirstName AS StudentName
		, CASE 
			WHEN (FSSM.SSMScore = -1) THEN CONVERT(VARCHAR(5),CAST(0 AS NUMERIC(3))) 
			ELSE CONVERT(VARCHAR(5),CAST(FSSM.SSMScore AS NUMERIC(3))) 
		  END AS ProbNCLEX
		, CASE
			WHEN (FSSM.SSMScore = -1) THEN CONVERT(VARCHAR(5),CAST(0.0 AS NUMERIC(4,1)))
			ELSE CONVERT(VARCHAR(5),CAST(FSSM.AdjPercentage AS NUMERIC(4,1)))
		  END AS TotalScore 
		, CASE 
			WHEN (FSSM.SSMScore = -1) THEN ''
			ELSE FSSM.ScoreCategoryName 
		  END AS RiskCategory
		, CASE
			WHEN FSSM.TestAttempt >= 4 AND FSSM.IsFinalScore = 0 THEN '4+'
			WHEN (FSSM.SSMScore = -1) THEN CONVERT(VARCHAR(5),0)
			ELSE CONVERT(VARCHAR(5),FSSM.TestAttempt)
		  END AS Attempt
		, CASE
			WHEN (FSSM.SSMScore = -1) THEN 0
			ELSE FSSM.TestAttempt
		  END AS AttemptNum
		, CASE
			WHEN (FSSM.SSMScore = -1) THEN 'Invalid'
			ELSE 'Valid'
		  END AS Validity
	FROM 
		dbo.FactSSM AS FSSM WITH (NOLOCK)
		JOIN ATICommon.dbo.DimInstitution AS InsCon
			ON FSSM.InstitutionID = InsCon.InstitutionID
		JOIN ATICommon.dbo.DimStudent AS DS
			ON DS.StudentID = FSSM.UserID
	WHERE
		FSSM.AssessmentID = @AssessmentID
		AND FSSM.SourceSystemID = @SourceSystemID
		AND FSSM.IsActive = 1
		AND CONVERT(DATE,FSSM.AssessmentDateTime) >= @StartDate
		AND CONVERT(DATE,FSSM.AssessmentDateTime) <= @EndDate
	ORDER BY
		FSSM.AssessmentDateTime DESC


	--SELECT * FROM @FactSSMEntriesForAssessmentId	

	--Fetching Total Number of Assessment Attempts before pagination
	SELECT
		@pTotalRecords = COUNT(1)
	FROM
		@FactSSMEntriesForAssessmentId

		SELECT @pAssessmentName
		
	--Fetching Students for the given Assessment for all dates within the given date range		
		SELECT
			StudentId
			, StudentName
			, TotalScore
			, RiskCategory
			, ProbNCLEX
			, Attempt
			, Validity
			, ROW_NUMBER ( ) OVER (ORDER BY StudentId) AS RowId
		FROM
			@FactSSMEntriesForAssessmentId

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 06-Dec-2018 | ATIPUL2-1223 - Initial Version                                                              |
===================================================================================================================================
**********************************************************************************************************************************/

END
