
CREATE PROCEDURE [dbo].[uspPULSEApiGetDailyActivityDetailsForStudent]
	@pSourceSystemID				INT				= 2
	, @pStudentID					BIGINT
	, @pEndDate						DATE			= NULL
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve daily activity details for a student within a cohort
Author          : Hansraj Bendale
Date Created    : 27-Jun-2018
Date Modified   : 19-Jul-2018
Description     : Gets daily activity details for a student within a given cohort and for a given date range.
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	EXEC dbo.uspPULSEApiGetDailyActivityDetailsForStudent
		@pSourceSystemID			= 2
		, @pStudentID				= 76726 --NULL --76662 --78456 --139820 --176262 --76726
		, @pEndDate					= '2011-01-07' --NULL --'2017-03-09' --'2016-12-09' --'2017-07-19' --'2017-04-20' --'1996-03-17' --'2018-07-17' --'2018-07-18'
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @StudentID			    BIGINT		= @pStudentID
	DECLARE @EndDate				DATE		= COALESCE(@pEndDate,CONVERT(date,getdate()))

	--SELECT @EndDate

	DECLARE @FactSSMEntriesForStudentId TABLE (
		StudentID 						BIGINT
		, AssessmentDate 				DATE
		, ProbNCLEX 					NUMERIC(3)
		, TotalScore					NUMERIC(3)
		, SeqNum						INT
	)

	DECLARE @StudentEntryWithScoreForOldDate TABLE (
		StudentID 						BIGINT
		, ProbNCLEX 					NUMERIC(3)
	)

	DECLARE @StudentEntryWithScoreForGivenDate TABLE (
		StudentID 						BIGINT
		, ProbNCLEX 					NUMERIC(3)
		, TotalScore					NUMERIC(3)
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

	--Fetching the required and filtered fields from FactSSM for subsequent use
	INSERT INTO @FactSSMEntriesForStudentId (StudentID, AssessmentDate, ProbNCLEX, TotalScore, SeqNum)
	SELECT
		FSSM.UserID AS StudentID
		, CONVERT(DATE,FSSM.AssessmentDateTime) AS AssessmentDate
		, CAST(FSSM.SSMScore AS NUMERIC(3)) AS ProbNCLEX
		, CAST(FSSM.AdjPercentage AS NUMERIC(3)) AS TotalScore
		, (ROW_NUMBER() OVER (PARTITION BY CONVERT(DATE,FSSM.AssessmentDateTime) ORDER BY FSSM.AssessmentDateTime DESC)) AS SeqNum
	FROM 
		dbo.FactSSM AS FSSM WITH (NOLOCK)
		JOIN @InstinCon AS InsCon
			ON FSSM.InstitutionID = InsCon.InstitutionID
	WHERE
		FSSM.UserID = @StudentID
		AND FSSM.SourceSystemID = @SourceSystemID
	ORDER BY
		FSSM.AssessmentDateTime DESC

	--Fetching the Student's Score for the date 90 days back to the given end date
	INSERT INTO @StudentEntryWithScoreForOldDate (StudentID, ProbNCLEX)
	SELECT
		StudentID
		, ProbNCLEX
	FROM 
		@FactSSMEntriesForStudentId
	WHERE
		AssessmentDate = DATEADD(DAY, -90, @EndDate)
		AND SeqNum = 1

	--Fetching the Student's Score and totalscore as on the given end date
	INSERT INTO @StudentEntryWithScoreForGivenDate (StudentID, ProbNCLEX, TotalScore)
	SELECT
		StudentID
		, ProbNCLEX
		, TotalScore
	FROM 
		@FactSSMEntriesForStudentId
	WHERE
		AssessmentDate = @EndDate
		AND SeqNum = 1

	--SELECT * FROM @FactSSMEntriesForStudentId
	--SELECT * FROM @StudentEntryWithScoreForOldDate
	--SELECT * FROM @StudentEntryWithScoreForGivenDate

	--Combining the above two results to get the count of assessments, rate 
	--and rate sign along with the other details already fetched
	SELECT
		DS.StudentID AS StudentID
		, (DS.LastName + ', ' + DS.FirstName) AS StudentName
		, DS.UserName AS StudentUserName
		, COALESCE(CONVERT(VARCHAR(3),SEWSGD.ProbNCLEX),'n/a') AS ProbNCLEX
		, COALESCE(CONVERT(VARCHAR(3),SEWSGD.TotalScore),'n/a') AS TotalScore
		, (SELECT COUNT(1) 
			FROM @FactSSMEntriesForStudentId
			WHERE
				AssessmentDate <= @EndDate) AS AssessmentCount
		, COALESCE(CONVERT(VARCHAR(3),ABS((SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX))),'n/a') AS Rate
		, CASE
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) > 0 THEN 'Positive'
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) < 0 THEN 'Negative'
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) = 0 THEN 'Neutral'
			ELSE 'n/a'
		  END AS RateSign
	FROM
		ATICommon.dbo.DimStudent AS DS WITH (NOLOCK)
		LEFT JOIN @StudentEntryWithScoreForOldDate AS SEWSOD
			ON DS.StudentID = SEWSOD.StudentID
		LEFT JOIN @StudentEntryWithScoreForGivenDate AS SEWSGD
			ON DS.StudentID = SEWSGD.StudentID
	WHERE
		DS.StudentID = @StudentID
		AND DS.SourceSystemID = @SourceSystemID

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 27-Jun-2018 | ATIPUL2-674 - Initial Version                                                               |
===================================================================================================================================
|   Hansraj Bendale  | 05-Jul-2018 | ATIPUL2-674 - Changes as per review                                                         |
===================================================================================================================================
|   Deepak Patro     | 19-Jul-2018 | ATIPUL2-677 - Added filter for considering assessment attempts of all institutions (not only|
|                    |             | the current institution) from the current programtype of the student                        |
===================================================================================================================================
**********************************************************************************************************************************/

END
