
CREATE PROCEDURE [dbo].[uspPULSEApiGetListOfDatesForStudentWithPulseScore]
	@pSourceSystemID				INT			= 2
	, @pStudentID					BIGINT				OUT	
	, @pStartDate					DATE		= NULL
	, @pEndDate						DATE		= NULL
	, @pStudentName					VARCHAR(50)			OUT
	, @pStudentUserName				VARCHAR(25)			OUT
	, @pFirstAssessmentDate			DATE		        OUT
	, @pStartDateMinValue			DATE			    OUT
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of dates for a student with pulse score information
Author          : Deepak Patro
Date Created    : 27-Jun-2018
Date Modified   : 26-Nov-2018
Description     : Gets list of dates for a student within a given cohort and institution with pulse score for each date within the given date range
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	DECLARE @pStudentID				BIGINT		= 176262 --NULL --76662 --78456 --139820 --176262 --76726
	DECLARE @pStudentName			VARCHAR(50)
	DECLARE @pStudentUserName		VARCHAR(25)
	DECLARE @pFirstAssessmentDate	VARCHAR(15)
	DECLARE @pStartDateMinValue		VARCHAR(15)
	EXEC dbo.uspPULSEApiGetListOfDatesForStudentWithPulseScore
		@pSourceSystemID			= 2
		, @pStartDate				= NULL --NULL --'2016-06-28'
		, @pEndDate					= NULL --NULL --'2018-06-28'
		, @pStudentID				= @pStudentID OUT
		, @pStudentName				= @pStudentName OUT
		, @pStudentUserName			= @pStudentUserName OUT
		, @pFirstAssessmentDate		= @pFirstAssessmentDate OUT
		, @pStartDateMinValue		= @pStartDateMinValue OUT
	SELECT 
		@pStudentID AS StudentID
		, @pStudentName AS StudentName
		, @pStudentUserName AS StudentUserName
		, @pFirstAssessmentDate AS FirstAssessmentDate
		, @pStartDateMinValue AS StartDateMinValue
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @StudentID			    BIGINT		= @pStudentID
	DECLARE @EndDate				DATE		= COALESCE(@pEndDate,CONVERT(DATE,GETDATE()))
	DECLARE @StartDate				DATE		= COALESCE(@pStartDate,DATEADD(YEAR,-2,CONVERT(DATE,GETDATE())))
	DECLARE @TwoYearsBackDate		DATE		= DATEADD(YEAR,-2,CONVERT(DATE,GETDATE()))

	DECLARE @FactSSMEntriesForStudentId TABLE (
		StudentID 						BIGINT
		, LatestAssessmentDate 			DATE
		, ProbNCLEX 					NUMERIC(3)
		, Type							VARCHAR(15)
		, SeqNum						INT
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
		ATICommon.dbo.DimInstitution AS I
	JOIN 
		(	
			SELECT 
				DCon.consortiumID
				, DI.ProgramTypeID 
			FROM 
				ATICommon.dbo.DimStudent AS DS 
				JOIN ATICommon.dbo.DimClass AS DC 
					ON DS.ActiveClassID = DC.ClassID
				JOIN ATICommon.dbo.DimInstitution AS DI
					ON DC.InstitutionID = DI.InstitutionID
				LEFT OUTER JOIN ATICommon.dbo.DimConsortium AS DCon
					ON DI.ConsortiumID = DCon.ConsortiumID
			WHERE
				DS.StudentID = @StudentID
		) as A
		ON ((I.ProgramTypeID = A.ProgramTypeID AND I.ConsortiumID = A.ConsortiumID)
			OR (I.ProgramTypeID = A.ProgramTypeID AND A.ConsortiumID IS NULL))

	--Fetching Student Id, UserName and name for the given Student
	SELECT
		@pStudentID = StudentID
		, @pStudentName = (LastName + ', ' + FirstName)
		, @pStudentUserName = UserName
	FROM
		ATICommon.dbo.DimStudent WITH (NOLOCK)
	WHERE
		StudentID = @StudentID
		AND SourceSystemID = @SourceSystemID

	--Fetching the required and filtered fields from FactSSM for subsequent use
	INSERT INTO @FactSSMEntriesForStudentId (StudentID, LatestAssessmentDate, ProbNCLEX, Type, SeqNum)
	SELECT
		FSSM.UserID AS StudentID
		, CONVERT(DATE,FSSM.AssessmentDateTime) AS LatestAssessmentDate
		, CAST(FSSM.SSMScore AS NUMERIC(3)) AS ProbNCLEX
		, CASE 
			WHEN FSSM.IsFinalScore = 1 THEN 'comp'
			ELSE 'assessment'
		  END AS Type
		, (ROW_NUMBER() OVER (PARTITION BY CONVERT(DATE,FSSM.AssessmentDateTime) ORDER BY FSSM.AssessmentDateTime DESC)) AS SeqNum
	FROM 
		dbo.FactSSM AS FSSM WITH (NOLOCK)
		JOIN @InstinCon AS InsCon
			ON FSSM.InstitutionID = InsCon.InstitutionID
	WHERE
		FSSM.UserID = @StudentID
		AND FSSM.IsActive = 1
		AND FSSM.SourceSystemID = @SourceSystemID
		AND FSSM.SSMScore <>-1
		AND  FSSM.SSMScore is not NULL
	ORDER BY
		LatestAssessmentDate DESC

	--Fetching first assessment date for the given Student
	SELECT TOP 1
		@pFirstAssessmentDate = LatestAssessmentDate
		, @pStartDateMinValue = CASE
									WHEN @TwoYearsBackDate > @pFirstAssessmentDate THEN @TwoYearsBackDate
									ELSE @pFirstAssessmentDate
								END
	FROM
		@FactSSMEntriesForStudentId
	WHERE
		SeqNum = 1
	ORDER BY
		LatestAssessmentDate

		SELECT @pStartDateMinValue =	CASE
										WHEN @pFirstAssessmentDate IS NULL THEN NULL
										WHEN @TwoYearsBackDate > @pFirstAssessmentDate THEN @TwoYearsBackDate
										ELSE @pFirstAssessmentDate
									END

	--Fetching Scores for the given Student for all dates within the given date range
	SELECT
		LatestAssessmentDate AS Date
		, ProbNCLEX
		, Type
	FROM
		@FactSSMEntriesForStudentId
	WHERE
		LatestAssessmentDate >= @StartDate
		AND LatestAssessmentDate <= @EndDate
		AND SeqNum = 1
	ORDER BY
		LatestAssessmentDate

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Deepak Patro     | 27-Jun-2018 | ATIPUL2-672 - Initial Version                                                               |
===================================================================================================================================
|   Deepak Patro     | 05-Jul-2018 | ATIPUL2-672 - Changes as per review                                                         |
===================================================================================================================================
|   Deepak Patro     | 19-Jul-2018 | ATIPUL2-677 - Added filter for considering assessment attempts of all institutions (not only|
|                    |             | the current institution) from the current programtype of the student                        |
===================================================================================================================================
|   Deepak Dubey     | 07-Nov-2018 | ATIPUL2-1355 - Added filter for  notconsidering assessment SSM Score NULL or -1             |
===================================================================================================================================
|   Deepak Patro     | 26-Nov-2018 | ATIPUL2-1355 - Added new attribute - 'type' to signify if the latest assessment on that     |
|                    |             | particular date is CP or CMS                                                                |
===================================================================================================================================
**********************************************************************************************************************************/

END
