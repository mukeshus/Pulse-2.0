
CREATE PROCEDURE [dbo].[uspPULSEApiGetCountOfStudentsAtRiskForCohort]
	@pSourceSystemID				INT				= 2
	, @pInstitutionID				BIGINT
	, @pClassID						BIGINT
	, @pEndDate						DATE			= NULL
	, @pStudentsAtRiskCount			VARCHAR(5)					OUT
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve count of students at risk within a cohort
Author          : Deepak Patro
Date Created    : 3-Dec-2018
Date Modified   : 10-Dec-2018
Description     : Gets count of students at risk within a given cohort as of a given date
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	DECLARE @pStudentsAtRiskCount			VARCHAR(5)
	EXEC dbo.uspPULSEApiGetCountOfStudentsAtRiskForCohort
		@pSourceSystemID				= 2
		, @pInstitutionID				= 9198	--NULL	--9		--393
		, @pClassID						= 48700	--NULL	--32513	--12815
		, @pEndDate						= NULL --NULL --'2017-03-09' --'2016-12-09' --'2017-07-19' --'2017-04-20' --'1996-03-17' --'2018-07-17' --'2018-07-18'
		, @pStudentsAtRiskCount			= @pStudentsAtRiskCount OUT
	SELECT 
		@pStudentsAtRiskCount AS StudentsAtRiskCount
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT		= @pInstitutionID
	DECLARE @ClassID			    BIGINT		= @pClassID
	DECLARE @ActivityDate			DATE		= COALESCE(@pEndDate,CONVERT(date,getdate()))

	DECLARE @CountOfAssessments		INT

	--SELECT 
		--@SourceSystemID AS SourceSystemId
		--, @InstitutionID AS InstitutionId
		--, @ClassID AS ClassId
		--, @ActivityDate AS ActivityDate
	
	--Fetching the StudentAtRiskCount from AssessmentDailySnapshot for given date
	
	SELECT 
		@CountOfAssessments = COUNT(AssessmentID) 
	FROM 
		dbo.AssessmentDailySnapshot
	WHERE 
		InstitutionId = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND SnapshotDate <= CONVERT(date, @ActivityDate)
		AND AssessmentID <> -1
		
	SELECT 
		TOP 1 @pStudentsAtRiskCount = CASE
										WHEN @CountOfAssessments > 0 THEN CONVERT(VARCHAR(5),AtRiskStudentCount)
										ELSE 'n/a'
									  END
	FROM 
		dbo.AssessmentDailySnapshot
	WHERE 
		InstitutionId = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND SnapshotDate <= CONVERT(date, @ActivityDate)
		AND AtRiskStudentCount IS NOT NULL
	ORDER BY 
		DateModified DESC

	SELECT @pStudentsAtRiskCount = COALESCE(@pStudentsAtRiskCount, 'n/a')

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Patro     | 3-Dec-2018  | ATIPUL2-1215 - Initial Version                                                              |
===================================================================================================================================
|   Deepak Patro     | 10-Dec-2018 | ATIPUL2-1682 - Fix for issue where count was supposed to be 'n/a' if cohort id is invalid or|
|                    |             | there is no assessment taken yet from the cohort.                                           |
===================================================================================================================================
**********************************************************************************************************************************/

END
