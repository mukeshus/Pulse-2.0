
CREATE   PROCEDURE [dbo].[uspCommonApiGetListOfCohortsWithPulseScore]
	@pSourceSystemID				INT				= 2
	, @pInstitutionID				BIGINT          = NULL
	, @pClassID						BIGINT          = NULL
	, @pCohortType					VARCHAR(25)		= NULL
	, @pEndDate						DATE			= NULL
	, @pReleaseDate                 DATE
	, @pSearchQuery					VARCHAR(100)	= NULL
	, @pShowGraduated				BIT
AS
BEGIN


/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of cohorts with pulse score and risk distribution information
Author          : Hansraj Bendale
Date Created    : 27-Jun-2018
Date Modified   : 17-Oct-2018
Description     : Gets list of cohorts along with other information like cohort name, cohort type, 
                  pulse score, total no of students in cohort and risk distribution info
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	EXEC dbo.uspCommonApiGetListOfCohortsWithPulseScore_temp
		@pSourceSystemID			= 2
		, @pInstitutionID			= 9 --NULL --7717 --9198 --9
		--, @pClassID					= 32513 --NULL ---1 --43738 --44464	--32513
		--, @pCohortType			= NULL --NULL --'' --'Graduation Cohort' --'Course Cohort'
		--, @pEndDate				= '2018-08-05' --NULL --'1993-06-28'
		, @pSearchQuery				= NULL	--NULL	--'06'	--'061'	--'0614'	--'class'
		, @pReleaseDate				= '2018-09-07'
		, @pShowGraduated			= 0
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT			= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT			= @pInstitutionID
	DECLARE @ClassID			    BIGINT			= @pClassID
	DECLARE @CohortType			    VARCHAR(25)		= @pCohortType
	DECLARE @EndDate				DATE			= COALESCE(@pEndDate,CONVERT(date,getdate()))
	DECLARE @ReleaseDate			DATE			= @pReleaseDate
	DECLARE @SearchQuery		    VARCHAR(100)	= @pSearchQuery
	DECLARE @ShowGraduated			BIT				= COALESCE(@pShowGraduated,0)

	DECLARE @SnapShotEntriesForAllDates TABLE (
		CohortID						BIGINT
		, AvgPoP						NUMERIC(3)
		, SnapshotDate					DATE
		, DateModified					DATETIME
	)

	DECLARE @SnapShotEntriesForCurrentDate TABLE (
		CohortID						BIGINT
		, AvgPoP						NUMERIC(3)
		, SeqNum						BIGINT
	)
	
	DECLARE @SnapShotEntriesForOldDate TABLE (
		CohortID						BIGINT
		, AvgPoP						NUMERIC(3)
		, SeqNum						BIGINT
	)

	DECLARE @SnapShotEntriesCombined TABLE (
		CohortID						BIGINT
		, AvgPoP						NUMERIC(3)
		, Rate							VARCHAR(5)
		, RateSign						VARCHAR(15)
	)

	INSERT INTO @SnapShotEntriesForAllDates (CohortID, AvgPoP, SnapshotDate, DateModified)
	SELECT 
		ClassID AS CohortID
		, CAST(AvgPoP AS NUMERIC(3)) AS AvgPoP
		, SnapshotDate
		, DateModified
	FROM 
		PulseDatamart.dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND (@ClassID IS NULL OR @ClassID = -1 OR ClassID = @ClassID)
		AND (@SearchQuery IS NULL OR @SearchQuery = '' OR ClassName LIKE '%' + @SearchQuery + '%')
		AND SourceSystemID = @SourceSystemID
	
	INSERT INTO @SnapShotEntriesForCurrentDate (CohortID, AvgPoP,SeqNum)
	SELECT 
		CohortID
		, AvgPoP
		, (ROW_NUMBER() OVER (PARTITION BY CohortID ORDER BY DateModified DESC)) AS SeqNum
	FROM 
		@SnapShotEntriesForAllDates
	WHERE
		SnapshotDate <= @EndDate
		
	INSERT INTO @SnapShotEntriesForOldDate (CohortID, AvgPoP,SeqNum)
	SELECT 
		CohortID
		, AvgPoP
		, (ROW_NUMBER() OVER (PARTITION BY CohortID ORDER BY DateModified DESC)) AS SeqNum
	FROM 
		@SnapShotEntriesForAllDates
	WHERE
		SnapshotDate <= DATEADD(DAY, -90, @EndDate)
	
	--SELECT * FROM @SnapShotEntriesForCurrentDate
	--SELECT * FROM @SnapShotEntriesForOldDate
		
	INSERT INTO @SnapShotEntriesCombined (CohortID, AvgPoP, Rate, RateSign)
	SELECT
		SEFC.CohortID
		, SEFC.AvgPoP
		, CONVERT(VARCHAR(5),ABS(CAST((SEFC.AvgPoP - SEFO.AvgPoP) AS NUMERIC(3)))) AS Rate
		, CASE
			WHEN (SEFC.AvgPoP - SEFO.AvgPoP) > 0 THEN 'Positive'
			WHEN (SEFC.AvgPoP - SEFO.AvgPoP) < 0 THEN 'Negative'
			WHEN (SEFC.AvgPoP - SEFO.AvgPoP) = 0 THEN 'Neutral'
			ELSE 'n/a'
		  END AS RateSign
	FROM
		@SnapShotEntriesForCurrentDate AS SEFC
		LEFT JOIN @SnapShotEntriesForOldDate AS SEFO
	ON
		SEFC.CohortID = SEFO.CohortID
	WHERE
		SEFC.SeqNum = 1
		AND (SEFO.SeqNum = 1 OR SEFO.SeqNum IS NULL)
		
	--SELECT * FROM @SnapShotEntriesCombined
	
	IF (@ShowGraduated = 0)
	    BEGIN
			SELECT
				DC.ClassID AS CohortID
				, DC.ClassName AS CohortName
				, DC.CohortTypeName AS CohortType
				, (COUNT(MSC.ClassID)) AS StudentCount
				, COALESCE(CONVERT(VARCHAR(5),SEC.AvgPoP),'n/a') AS ProbNCLEX
				, COALESCE(SEC.Rate,'n/a') AS Rate
				, COALESCE(SEC.RateSign,'n/a') AS RateSign
				, CASE
					WHEN(ISNULL(DC.GraduationDate,'2099-01-01') <= @ReleaseDate) THEN 'PULSE 1.0'
					ELSE 'PULSE 2.0'
				  END AS pulseAlgo
			FROM
				dbo.DimClass AS DC WITH (NOLOCK)
				LEFT JOIN @SnapShotEntriesCombined AS SEC
					ON DC.ClassID = SEC.CohortID
				LEFT JOIN dbo.MapStudentClass AS MSC WITH (NOLOCK)
					ON DC.ClassID = MSC.ClassID
			WHERE
				DC.InstitutionID = @InstitutionID
				AND (@ClassID IS NULL OR @ClassID = -1  OR DC.ClassID = @ClassID)
				AND (@CohortType IS NULL OR @CohortType = '' OR DC.CohortTypeName = @CohortType)
				AND DC.GraduationDate IS NOT NULL
				AND DC.GraduationDate >= CAST(GETDATE() AS DATE)
				AND (@SearchQuery IS NULL OR @SearchQuery = '' OR DC.ClassName LIKE '%' + @SearchQuery + '%')
				AND DC.SourceSystemID = @SourceSystemID
				AND (MSC.IsActive IS NULL OR MSC.IsActive = 1)
			GROUP BY
				DC.ClassID
				, DC.ClassName
				, DC.CohortTypeName
				, SEC.AvgPoP
				, SEC.Rate
				, SEC.RateSign
				, DC.GraduationDate
			ORDER BY 
				DC.GraduationDate DESC
				, DC.ClassName ASC
    	END
    ELSE
        BEGIN
	        SELECT
				DC.ClassID AS CohortID
				, DC.ClassName AS CohortName
				, DC.CohortTypeName AS CohortType
				, (COUNT(MSC.ClassID)) AS StudentCount
				, COALESCE(CONVERT(VARCHAR(5),SEC.AvgPoP),'n/a') AS ProbNCLEX
				, COALESCE(SEC.Rate,'n/a') AS Rate
				, COALESCE(SEC.RateSign,'n/a') AS RateSign
				, CASE
					WHEN(ISNULL(DC.GraduationDate,'2099-01-01') <= @ReleaseDate) THEN 'PULSE 1.0'
					ELSE 'PULSE 2.0'
				  END AS pulseAlgo
			FROM
				dbo.DimClass AS DC WITH (NOLOCK)
				LEFT JOIN @SnapShotEntriesCombined AS SEC
					ON DC.ClassID = SEC.CohortID
				LEFT JOIN dbo.MapStudentClass AS MSC WITH (NOLOCK)
					ON DC.ClassID = MSC.ClassID
			WHERE
				DC.InstitutionID = @InstitutionID
				AND (@ClassID IS NULL OR @ClassID = -1  OR DC.ClassID = @ClassID)
				AND (@CohortType IS NULL OR @CohortType = '' OR DC.CohortTypeName = @CohortType)
				AND DC.GraduationDate IS NOT NULL
				AND (@SearchQuery IS NULL OR @SearchQuery = '' OR DC.ClassName LIKE '%' + @SearchQuery + '%')
				AND DC.SourceSystemID = @SourceSystemID
				AND (MSC.IsActive IS NULL OR MSC.IsActive = 1)
			GROUP BY
				DC.ClassID
				, DC.ClassName
				, DC.CohortTypeName
				, SEC.AvgPoP
				, SEC.Rate
				, SEC.RateSign
				, DC.GraduationDate
			ORDER BY 
				DC.GraduationDate DESC
				, DC.ClassName ASC
        END

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 27-Jun-2018 | Story number TBD                                                                            |
===================================================================================================================================
|   Deepak Dubey	 | 22-Sep-2018 | ATIPUL2-633 - Updated the queries as per new requirement and design                         |
===================================================================================================================================
|   Deepak Patro	 | 17-Oct-2018 | ATIPUL2-1212 - Added filter for search text against Cohort Names                            |
===================================================================================================================================
|   Hansraj Bendale	 | 6-Nov-2018  | ATIPUL2-1381 - Movement of Cohort list API to Common Services		                         |
===================================================================================================================================
|   Hansraj Bendale	 | 27-Nov-2018 | ATIPUL2-1530 - Pulse Landing Page - Toggle option for 'Show Graduated' Label - Update       |
===================================================================================================================================
**********************************************************************************************************************************/

END
