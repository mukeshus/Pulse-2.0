

CREATE PROCEDURE [dbo].[uspPULSEApiGetDailyActivityDetailsForCohort_tmp]
	@pSourceSystemID				INT				= 2
	, @pInstitutionID				BIGINT			= NULL
	, @pClassID						BIGINT			= NULL
	, @pDate						DATE			= NULL
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve daily activity details for a student within a cohort
Author          : Hansraj Bendale
Date Created    : 1-Nov-2018
Date Modified   : 1-Nov-2018
Description     : Gets daily activity details for a student within a given cohort and for a given date range.
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	EXEC dbo.uspPULSEApiGetDailyActivityDetailsForCohort_tmp
		@pSourceSystemID			= 2
		, @pInstitutionID			= 9
		, @pClassID					= 43738 --NULL ---1 --43738 --44464 --49379
		, @pDate					= '2017-03-09' --NULL --'2017-03-09' --'2016-12-09' --'2017-07-19' --'2017-04-20' --'1996-03-17'
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @InstitutionID			BIGINT		= @pInstitutionID
	DECLARE @ClassID			    BIGINT		= @pClassID
	DECLARE @ActivityDate			DATE		= COALESCE(@pDate,CONVERT(date,getdate()))

	DECLARE @UniqueAssessments	BIGINT = 0
	DECLARE @StudentCount		BIGINT = 0
	
	SELECT 
		@UniqueAssessments = COUNT(DISTINCT AssessmentID)
	FROM
		dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND SnapshotDate = @ActivityDate
		
	SELECT
		TOP 1 @StudentCount = TotalStudents
	FROM
		dbo.AssessmentDailySnapshot WITH (NOLOCK)
	WHERE
		InstitutionID = @InstitutionID
		AND ClassID = @ClassID
		AND SourceSystemID = @SourceSystemID
		AND SnapshotDate <= @ActivityDate
		AND TotalStudents IS NOT NULL
	ORDER BY
		DateModified DESC

	SELECT @ActivityDate AS ActivityDate, @UniqueAssessments AS UniqueAssessments, @StudentCount AS StudentCount

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 1-Nov-2018  | ATIPUL2-1216 - Initial Version                                                              |
===================================================================================================================================
**********************************************************************************************************************************/

END
