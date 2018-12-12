
CREATE PROCEDURE [dbo].[uspPULSEApiGetStudentRosterForCohort_temp]
	@pSourceSystemID				INT				= 2
	, @pInstitutionID				BIGINT
	, @pClassID						BIGINT					OUT
	, @pEndDate						DATE			= NULL
	, @pSortByColumn				VARCHAR(255)	= NULL
	, @pSortOrder					VARCHAR(5)		= NULL
	, @pPaginationPageSize			INT				= 10
	, @pPaginationPageNumber		INT				= 1
	, @pClassName					NVARCHAR(128)			OUT
AS
BEGIN


/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve student roster for a cohort.
Author          : Deepak Patro
Date Created    : 03-Dec-2018
Date Modified   : 03-Dec-2018
Description     : Gets list of all students who are at risk within a cohort
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	DECLARE @pClassID				BIGINT	= 32513	--NULL	--32513	--12815
	DECLARE @pClassName				NVARCHAR(128)
	EXEC dbo.uspPULSEApiGetStudentRosterForCohort_temp
		@pSourceSystemID			= 2
		, @pInstitutionID			= 9	--NULL	--9		--393
		, @pClassID					= @pClassID OUT
		, @pEndDate					= '2018-08-05'	--'2018-08-05' --NULL --'1993-06-28'
		, @pSortByColumn			= NULL	--NULL	--'STUDENT'	--'POP'	--'RISK'
		, @pSortOrder				= NULL	--NULL	--'ASC'	--'DESC'
		, @pPaginationPageSize		= 50
		, @pPaginationPageNumber	= 1
		, @pClassName				= @pClassName OUT
	SELECT 
		@pClassID AS CohortID
		, @pClassName AS CohortName
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT			= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT			= @pInstitutionID
	DECLARE @ClassID			    BIGINT			= @pClassID
	DECLARE @EndDate				DATETIME		= CASE
														WHEN @pEndDate IS NULL THEN GETDATE()
														ELSE 
															CASE
																WHEN @pEndDate = CONVERT(date,GETDATE()) THEN GETDATE()
																ELSE DATEADD(ms, -3, DATEADD(DAY, 1, CONVERT(DATETIME,@pEndDate)))
															END
													  END
	DECLARE @PrimarySortByColumn	VARCHAR(255)	= CASE UPPER(@pSortByColumn)
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

	DECLARE @StudentClassMappings TABLE (
		StudentID						BIGINT
		, ClassID						BIGINT
		, ClassName						NVARCHAR(128)
	)
	
	DECLARE @FactSSMEntriesWithPoP TABLE (
		StudentID						BIGINT
		, PoP							VARCHAR(5)
		, RiskCategory					NVARCHAR(40)
		, SeqNum						INT
	)

	DECLARE @FinalListOfStudents TABLE (
		StudentID						BIGINT
		, StudentName					NVARCHAR(128)
		, StudentUserName				NVARCHAR(50)
		, PoP							VARCHAR(5)
		, RiskCategory					VARCHAR(10)
	)

	INSERT INTO @StudentClassMappings (StudentID, ClassID, ClassName)
	SELECT 
		StudentID
		, ClassID
		, ClassName
	FROM 
		ATICommon.dbo.MapStudentClass WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND ISNULL(FromDate,'1999-01-01T00:00:00') <= @EndDate
		AND (ToDate IS NULL OR ToDate >= @EndDate)

	--SELECT * FROM @StudentClassMappings

	SELECT TOP 1
		@pClassID = ClassID
		, @pClassName = ClassName
	FROM
		ATICommon.dbo.DimClass WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND GraduationDate IS NOT NULL
		AND SourceSystemID = @SourceSystemID

	INSERT INTO @FactSSMEntriesWithPoP (StudentID, PoP, RiskCategory, SeqNum)
	SELECT
		FSSM.UserID AS StudentID
		, CASE 
			WHEN (FSSM.SSMScore = -1) THEN 'n/a' 
			ELSE CONVERT(VARCHAR(5),CAST(FSSM.SSMScore AS NUMERIC(3))) 
		  END AS PoP
		, CASE 
			WHEN (FSSM.SSMScore = -1) THEN 'n/a'
			ELSE FSSM.ScoreCategoryName 
		  END AS RiskCategory
		, ROW_NUMBER ( ) OVER (PARTITION BY FSSM.UserID ORDER BY FSSM.AssessmentDateTime DESC) AS SeqNum
	FROM
		@StudentClassMappings AS SCM
		INNER JOIN dbo.FactSSM AS FSSM WITH (NOLOCK)
			ON SCM.StudentID = FSSM.UserID
	WHERE
		FSSM.InstitutionID = @InstitutionID
		AND FSSM.ActiveClassID = @ClassID
		AND FSSM.IsActive = 1
		AND FSSM.SourceSystemID = @SourceSystemID
		AND CONVERT(DATE,FSSM.AssessmentDateTime) <= @EndDate
	
	--SELECT * FROM @FactSSMEntriesWithPoP WHERE SeqNum = 1
	
	INSERT INTO @FinalListOfStudents (StudentID, StudentName, StudentUserName, PoP, RiskCategory)
	SELECT
		DS.StudentID
		, (DS.LastName + ', ' + DS.FirstName) AS StudentName
		, DS.UserName AS StudentUserName		
		, COALESCE(FSSM.PoP, 'n/a') AS PoP
		, COALESCE(FSSM.RiskCategory, 'n/a') AS RiskCategory
	FROM
		@StudentClassMappings AS SCM
		INNER JOIN ATICommon.dbo.DimStudent AS DS WITH (NOLOCK)
			ON SCM.StudentID = DS.StudentID
		LEFT JOIN @FactSSMEntriesWithPoP AS FSSM
			ON SCM.StudentID = FSSM.StudentID
	WHERE
		DS.SourceSystemID = @SourceSystemID
		AND (FSSM.SeqNum IS NULL OR FSSM.SeqNum = 1)

	IF	@PrimarySortOrder = ''
	BEGIN
		SET @PrimarySortOrder = 'ASC'
	END
	
	IF @PrimarySortByColumn = ''
	BEGIN
		SET @PrimarySortByColumn = 'STUDENT'
	END

	IF @PrimarySortOrder = 'ASC'
		SELECT
			StudentID
			, StudentName
			, StudentUserName		
			, PoP
			, RiskCategory
		FROM
			@FinalListOfStudents
		ORDER BY 
			CASE WHEN @PrimarySortByColumn = 'STUDENT' THEN StudentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'STUDENT' THEN REPLICATE(' ',5-LEN(PoP))+PoP END ASC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN REPLICATE(' ',5-LEN(PoP))+PoP END ASC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN StudentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN 
				CASE 
					WHEN RiskCategory = 'n/a' THEN '9999999'
					ELSE REPLICATE(' ',10-LEN(RiskCategory))+RiskCategory
				END 
			END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN StudentName END ASC
		OFFSET @PaginationPageSize * (@PaginationPageNumber - 1) ROWS
		FETCH NEXT @PaginationPageSize ROWS ONLY
	ELSE
		SELECT
			StudentID
			, StudentName
			, StudentUserName		
			, PoP
			, RiskCategory
		FROM
			@FinalListOfStudents
		ORDER BY 
			CASE WHEN @PrimarySortByColumn = 'STUDENT' THEN StudentName END DESC,
			CASE WHEN @PrimarySortByColumn = 'STUDENT' THEN REPLICATE(' ',5-LEN(PoP))+PoP END ASC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN REPLICATE(' ',5-LEN(PoP))+PoP END DESC,
			CASE WHEN @PrimarySortByColumn = 'POP' THEN StudentName END ASC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN 
				CASE 
					WHEN RiskCategory = 'n/a' THEN ' '
					ELSE REPLICATE(' ',10-LEN(RiskCategory))+RiskCategory
				END 
			END DESC,
			CASE WHEN @PrimarySortByColumn = 'RISK' THEN StudentName END ASC
		OFFSET @PaginationPageSize * (@PaginationPageNumber - 1) ROWS
		FETCH NEXT @PaginationPageSize ROWS ONLY

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Patro     | 03-Dec-2018 | Initial version - ATIPUL2-1443                                                              |
===================================================================================================================================
|   Deepak Patro     | 06-Dec-2018 | Initial version - ATIPUL2-1444 with sorting and pagination                                                             |
===================================================================================================================================
**********************************************************************************************************************************/

END
