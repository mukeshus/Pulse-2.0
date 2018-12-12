
CREATE   PROCEDURE [dbo].[uspPULSEApiGetListOfStudentsForAssessment_tmp]
	@pSourceSystemID				INT				= 2
	, @pAssessmentID				BIGINT					OUT	
	, @pStartDate					DATE			= NULL
	, @pEndDate						DATE			= NULL
	, @pAssessmentName				VARCHAR(50)				OUT
	, @pSortByColumn				VARCHAR(255)	= NULL
	, @pSortOrder					VARCHAR(5)		= NULL
	, @pPaginationPageSize			INT				= 10
	, @pPaginationPageNumber		INT				= 1
	, @pTotalRecords				BIGINT					OUT
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of assessment attempts for a student within current program type
Author          : Hansraj Bendale
Date Created    : 10-Jul-2018
Date Modified   : 30-Jul-2018
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
	DECLARE @EndDate				DATE			= COALESCE(@pEndDate,CONVERT(DATE,GETDATE()))
	DECLARE @StartDate				DATE			= COALESCE(@pStartDate,DATEADD(YEAR,-6,CONVERT(DATE,GETDATE())))
	DECLARE @PrimarySortByColumn	VARCHAR(255)	= CASE UPPER(@pSortByColumn)
														WHEN 'STUDENT' THEN 'STUDENT'
														WHEN 'SCORE' THEN 'SCORE'
														WHEN 'ATTEMPT' THEN 'ATTEMPT'
														WHEN 'POP' THEN 'POP'
														WHEN 'RISK' THEN 'RISK'
														ELSE ''
													  END
	DECLARE @PrimarySortOrder		VARCHAR(5)		= CASE UPPER(@pSortOrder) 
														WHEN 'ASC' THEN 'ASC' 
														WHEN 'DESC' THEN 'DESC' 
														ELSE ''
													  END
	DECLARE @PaginationPageSize		INT			= @pPaginationPageSize
	DECLARE @PaginationPageNumber	INT			= @pPaginationPageNumber
	--SELECT @EndDate
	--SELECT @PrimarySortOrder AS OrderBefore,@PrimarySortByColumn AS HeaderBefore

	DECLARE @FactSSMEntriesForStudentId TABLE (
		AssessmentID					BIGINT
		, AssessmentName				VARCHAR(128)
		, LatestAssessmentDateTime		DATETIME
		, ProbNCLEX 					VARCHAR(5)
		, TotalScore					VARCHAR(5)
		, RiskCategory					VARCHAR(10)
		, Attempt						VARCHAR(5)
		, AttemptNum					INT
		, Validity						VARCHAR(8)
	)

	DECLARE @InstinCon TABLE(
		ConsortiumID					INT
		, InstitutionID					INT
		, ProgramTypeID					INT
	)

	INSERT INTO @InstinCon (ConsortiumID,InstitutionID,ProgramTypeID)
	SELECT
		I.ConsortiumID
		, I.InstitutionID
		, I.ProgramTypeID
	FROM
		ATICommon.dbo.DimInstitution AS I WITH (NOLOCK)
	
	
	--Fetching Student Id, UserName and name for the given Student
	SELECT
		@pAssessmentID = AssessmentID
		, @pAssessmentName = Name
	FROM
		ATICommon.dbo.DimAssessmentDetail WITH (NOLOCK)
	WHERE
		AssessmentID = @AssessmentID
		AND SourceSystemID = @SourceSystemID

	--Fetching the required and filtered fields from FactSSM for subsequent use
	INSERT INTO @FactSSMEntriesForStudentId (AssessmentID, AssessmentName, LatestAssessmentDateTime, ProbNCLEX, TotalScore, RiskCategory, Attempt, AttemptNum, Validity)
	SELECT
		FSSM.AssessmentID
		, FSSM.AssessmentName
		, FSSM.AssessmentDateTime AS LatestAssessmentDateTime
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
		JOIN @InstinCon AS InsCon
			ON FSSM.InstitutionID = InsCon.InstitutionID
	WHERE
		FSSM.AssessmentID = @AssessmentID
		AND FSSM.SourceSystemID = @SourceSystemID
		AND FSSM.IsActive = 1
		AND CONVERT(DATE,FSSM.AssessmentDateTime) >= @StartDate
		AND CONVERT(DATE,FSSM.AssessmentDateTime) <= @EndDate
	ORDER BY
		FSSM.AssessmentDateTime DESC

	--SELECT * FROM @FactSSMEntriesForStudentId	

	--Fetching Total Number of Assessment Attempts before pagination
	SELECT
		@pTotalRecords = COUNT(1)
	FROM
		@FactSSMEntriesForStudentId
	
	IF	@PrimarySortOrder = ''
	BEGIN
		SET @PrimarySortOrder = 'ASC'
		IF @PrimarySortByColumn = ''
		BEGIN
			SET @PrimarySortByColumn = 'Date'
			SET @PrimarySortOrder = 'DESC'
		END
	END
	ELSE
	BEGIN
		IF @PrimarySortByColumn = ''
		BEGIN
			SET @PrimarySortByColumn = 'Date'
		END
	END

	--SELECT @PrimarySortOrder AS OrderAfter,@PrimarySortByColumn AS HeaderAfter
		
	--Fetching Scores for the given Student for all dates within the given date range		
	IF @PrimarySortOrder = 'DESC'
		SELECT
			CONVERT(VARCHAR,CONVERT(DATE,LatestAssessmentDateTime),107) AS AssessmentDate
			, AssessmentID
			, AssessmentName
			, TotalScore
			, RiskCategory
			, ProbNCLEX
			, Attempt
			, Validity
			, ROW_NUMBER ( ) OVER (ORDER BY AssessmentID) AS RowId
		FROM
			@FactSSMEntriesForStudentId
		ORDER BY 
			CASE WHEN @PrimarySortByColumn = 'DATE' THEN LatestAssessmentDateTime END DESC,
			CASE WHEN @PrimarySortByColumn = 'DATE' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'ASSESSMENT' THEN AssessmentName END DESC,
			CASE WHEN @PrimarySortByColumn = 'ASSESSMENT' THEN AttemptNum END ASC,
			CASE WHEN @PrimarySortByColumn = 'SCORE' THEN REPLICATE(' ',5-LEN(TotalScore))+TotalScore END DESC,
			CASE WHEN @PrimarySortByColumn = 'SCORE' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN REPLICATE(' ',10-LEN(RiskCategory))+RiskCategory END DESC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN REPLICATE(' ',5-LEN(ProbNCLEX))+ProbNCLEX END DESC,	
			CASE WHEN @PrimarySortByColumn = 'POP' THEN REPLICATE(' ',5-LEN(ProbNCLEX))+ProbNCLEX END DESC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'ATTEMPT' THEN AttemptNum END DESC,
			CASE WHEN @PrimarySortByColumn = 'ATTEMPT' THEN AssessmentName END ASC
		OFFSET @PaginationPageSize * (@PaginationPageNumber - 1) ROWS
		FETCH NEXT @PaginationPageSize ROWS ONLY
	ELSE
		SELECT
			CONVERT(VARCHAR,CONVERT(DATE,LatestAssessmentDateTime),107) AS AssessmentDate
			, AssessmentID
			, AssessmentName
			, TotalScore
			, RiskCategory
			, ProbNCLEX
			, Attempt
			, Validity
			, ROW_NUMBER ( ) OVER (ORDER BY AssessmentID) AS RowId
		FROM
			@FactSSMEntriesForStudentId
		ORDER BY 
			CASE WHEN @PrimarySortByColumn = 'DATE' THEN LatestAssessmentDateTime END ASC,
			CASE WHEN @PrimarySortByColumn = 'DATE' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'ASSESSMENT' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'ASSESSMENT' THEN AttemptNum END ASC,
			CASE WHEN @PrimarySortByColumn = 'SCORE' THEN REPLICATE(' ',5-LEN(TotalScore))+TotalScore END ASC,
			CASE WHEN @PrimarySortByColumn = 'SCORE' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN REPLICATE(' ',10-LEN(RiskCategory))+RiskCategory END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN REPLICATE(' ',5-LEN(ProbNCLEX))+ProbNCLEX END ASC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN REPLICATE(' ',5-LEN(ProbNCLEX))+ProbNCLEX END ASC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN AssessmentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'ATTEMPT' THEN AttemptNum END ASC,
			CASE WHEN @PrimarySortByColumn = 'ATTEMPT' THEN AssessmentName END ASC
		OFFSET @PaginationPageSize * (@PaginationPageNumber - 1) ROWS
		FETCH NEXT @PaginationPageSize ROWS ONLY

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 10-Jul-2018 | ATIPUL2-677 - Initial Version                                                               |
===================================================================================================================================
|   Deepak Patro     | 19-Jul-2018 | ATIPUL2-677 - Added filter for considering assessment attempts of all institutions (not only|
|                    |             | the current institution) from the current programtype of the student                        |
===================================================================================================================================
|   Hansraj Bendale  | 30-Jul-2018 | ATIPUL2-760 - Added changes to support sorting                                              |
===================================================================================================================================
|   Deepak Patro     | 07-Sep-2018 | ATIPUL2-761 - Added changes to support pagination                                           |
===================================================================================================================================
**********************************************************************************************************************************/

END
