
CREATE PROCEDURE [dbo].[uspPULSEApiFacultyClassGetClassRiskDistribution]
	@pSourceSystemID				INT			= 2
	, @pInstitutionID				BIGINT
	, @pClassID						BIGINT
AS
BEGIN

/* Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve risk distribution details for given class
Author          : Hansraj Bendale
Date Created    : 05-Sep-2018
Date Modified   : 19-Sep-2018
Description     : Gets risk distribution details for a given cohort
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	EXEC dbo.uspPULSEApiFacultyClassGetClassRiskDistribution
		@pSourceSystemID			= 2 --NULL --2
		, @pInstitutionID			= 9198	--11	--11	--717 --11
		, @pClassID					= 48700	--32470	--32452	--32470
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @InstitutionID			BIGINT		= @pInstitutionID
	DECLARE @ClassID				BIGINT		= @pClassID
	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID, 2)

	DECLARE @RiskDistribution TABLE (
		CohortID						BIGINT
		, CohortName 					NVARCHAR(128)
		, CohortType					NVARCHAR(100)
		, AvgPoP 						NUMERIC(3)
		, TotalStudentCount				INT
		, AtRiskStudentCount			INT
		, OnTrackStudentCount			INT
	)

	INSERT INTO @RiskDistribution(
		CohortID
		, CohortName
		, CohortType
		, AvgPoP
		, TotalStudentCount
		, AtRiskStudentCount
		, OnTrackStudentCount
	)
	SELECT TOP 1
		MSC.ClassID AS CohortID
		, MSC.ClassName AS CohortName
		, MSC.CohortTypeName AS CohortType
		, CAST(AvgPop AS NUMERIC(3)) AS AvgPoP 
		, COUNT(DISTINCT MSC.StudentID) AS TotalStudentCount
		, ADS.AtRiskStudentCount AS AtRiskStudentCount
		, ADS.OnTrackStudentCount AS OnTrackStudentCount
	FROM 
		ATICommon.dbo.MapStudentClass AS MSC WITH (NOLOCK)
		LEFT JOIN dbo.AssessmentDailySnapshot AS ADS WITH (NOLOCK)
	ON
		ADS.InstitutionID = MSC.InstitutionID
		AND ADS.ClassID = MSC.ClassID
	WHERE 
		MSC.ClassID = @ClassID
		AND MSC.InstitutionID = @InstitutionID
		AND MSC.SourceSystemID = @SourceSystemID
		AND MSC.IsActive = 1
		AND (ADS.SourceSystemID IS NULL OR ADS.SourceSystemID = @SourceSystemID)
	GROUP BY
		MSC.ClassID
		, MSC.ClassName
		, MSC.CohortTypeName
		, ADS.AvgPoP
		, ADS.AtRiskStudentCount
		, ADS.OnTrackStudentCount
		, ADS.DateModified
	ORDER BY
		ADS.DateModified DESC
	
	SELECT
		CohortID
		, CohortName
		, CohortType
		, COALESCE(CONVERT(VARCHAR(5),AvgPoP),'n/a') AS AvgPoP
		, COALESCE(CONVERT(VARCHAR(5),TotalStudentCount),'n/a') AS TotalStudentCount
		, COALESCE(CONVERT(VARCHAR(5),AtRiskStudentCount),'n/a') AS AtRiskStudentCount
		, COALESCE(CONVERT(VARCHAR(5),OnTrackStudentCount),'n/a') AS OnTrackStudentCount
		, COALESCE(CONVERT(VARCHAR(5),TotalStudentCount - (AtRiskStudentCount + OnTrackStudentCount)),'n/a') AS UnavailableStudentCount 
	FROM 
		@RiskDistribution

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/* Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 05-Sep-2018 | ATIPUL2-925 - Initial Version                                                               |
===================================================================================================================================
|   Hansraj Bendale  | 19-Sep-2018 | ATIPUL2-925 - Updated format and added corrections                                          |
===================================================================================================================================
**********************************************************************************************************************************/

END
