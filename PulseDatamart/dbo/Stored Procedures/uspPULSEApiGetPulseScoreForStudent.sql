
CREATE   PROCEDURE [dbo].[uspPULSEApiGetPulseScoreForStudent]
	@pSourceSystemID				INT				= 2
	, @pStudentID					BIGINT
	, @pEndDate						DATE			= NULL
	,@pReleaseDate                  DATE
AS
BEGIN

/* Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve pulse score for a student within a cohort
Author          : Hansraj Bendale
Date Created    : 26-Jul-2018
Date Modified   : 26-Jul-2018
Description     : Gets Pulse Score for a student within a given cohort and for a given date range.
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	SET STATISTICS IO, TIME ON
	EXEC dbo.uspPULSEApiGetPulseScoreForStudent
		@pSourceSystemID			= 2
		, @pStudentID				= 76726 --NULL --76662 --78456 --139820 --176262 --76726
		, @pEndDate					= '2011-05-18' --NULL --'2017-03-09' --'2016-12-09' --'2017-07-19' --'2017-04-20' --'1996-03-17' --'2018-07-17' --'2018-07-18'
		, @pReleaseDate				= '2011-05-18' --NULL --'2017-03-09' --'2016-12-09'
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT		= COALESCE(@pSourceSystemID,2)
	DECLARE @StudentID			    BIGINT		= @pStudentID
	DECLARE @EndDate				DATE		= COALESCE(@pEndDate,CONVERT(date,getdate()))
	DECLARE @ReleaseDate			DATE		= COALESCE(@pReleaseDate,CONVERT(date,getdate()))
	
	--SELECT @EndDate

	DECLARE @FactSSMEntriesForStudentId TABLE (
		StudentID 						BIGINT
		, AssessmentDateTime 			DATETIME
		, AssessmentDate 				DATE
		, ProbNCLEX 					NUMERIC(3)
		--, SeqNum						INT
	)

	DECLARE @StudentEntryWithScoreForOldDate TABLE (
		StudentID 						BIGINT
		, ProbNCLEX 					NUMERIC(3)
	)

	DECLARE @StudentEntryWithScoreForGivenDate TABLE (
		StudentID 						BIGINT
		, ProbNCLEX 					NUMERIC(3)
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
	JOIN 
		(	
			SELECT 
				DCon.consortiumID
				, DI.ProgramTypeID 
			FROM 
				ATICommon.dbo.DimStudent AS DS WITH (NOLOCK)
				JOIN ATICommon.dbo.DimClass AS DC WITH (NOLOCK)
					ON DS.ActiveClassID = DC.ClassID
				JOIN ATICommon.dbo.DimInstitution AS DI WITH (NOLOCK)
					ON DC.InstitutionID = DI.InstitutionID
				LEFT OUTER JOIN ATICommon.dbo.DimConsortium AS DCon WITH (NOLOCK)
					ON DI.ConsortiumID = DCon.ConsortiumID
			WHERE
				DS.StudentID = @StudentID
		) AS A
		ON ((I.ProgramTypeID = A.ProgramTypeID AND I.ConsortiumID = A.ConsortiumID)
			OR (I.ProgramTypeID = A.ProgramTypeID AND A.ConsortiumID IS NULL))

	--Fetching the required and filtered fields from FactSSM for subsequent use
	INSERT INTO @FactSSMEntriesForStudentId (StudentID, AssessmentDateTime, AssessmentDate, ProbNCLEX)
	SELECT
		FSSM.UserID AS StudentID
		, FSSM.AssessmentDateTime
		, CONVERT(DATE,FSSM.AssessmentDateTime) AS AssessmentDate
		, CAST(FSSM.SSMScore AS NUMERIC(3)) AS ProbNCLEX
	FROM 
		dbo.FactSSM AS FSSM WITH (NOLOCK)
		JOIN @InstinCon AS InsCon
			ON FSSM.InstitutionID = InsCon.InstitutionID
	WHERE
		FSSM.UserID = @StudentID
		AND FSSM.IsActive = 1
		AND FSSM.SSMScore IS NOT NULL
		AND FSSM.SourceSystemID = @SourceSystemID
	ORDER BY
		FSSM.AssessmentDateTime DESC

	--Fetching the Student's Score for the date 90 days back to the given end date
	INSERT INTO @StudentEntryWithScoreForOldDate (StudentID, ProbNCLEX)
	SELECT TOP 1
		StudentID
		, ProbNCLEX
	FROM 
		@FactSSMEntriesForStudentId
	WHERE
		AssessmentDate <= DATEADD(DAY, -90, @EndDate)
	ORDER BY
		AssessmentDateTime DESC

	--Fetching the Student's Pulse Score on the given end date
	INSERT INTO @StudentEntryWithScoreForGivenDate (StudentID, ProbNCLEX)
	SELECT TOP 1
		StudentID
		, ProbNCLEX
	FROM 
		@FactSSMEntriesForStudentId
	WHERE
		AssessmentDate <= @EndDate
	ORDER BY
		AssessmentDateTime DESC

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
		, COALESCE(CONVERT(VARCHAR(3),ABS((SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX))),'n/a') AS Rate
		, CASE
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) > 0 THEN 'Positive'
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) < 0 THEN 'Negative'
			WHEN (SEWSGD.ProbNCLEX - SEWSOD.ProbNCLEX) = 0 THEN 'Neutral'
			ELSE 'n/a'
		  END AS RateSign
		 , CASE
			WHEN(ISNULL(DC.GraduationDate,'2099-01-01') <= @ReleaseDate ) THEN 'PULSE 1.0'
			ELSE 'PULSE 2.0'
		  END AS pulseAlgo
	
	FROM
		ATICommon.dbo.DimStudent AS DS WITH (NOLOCK)
		LEFT JOIN @StudentEntryWithScoreForOldDate AS SEWSOD
			ON DS.StudentID = SEWSOD.StudentID
		LEFT JOIN @StudentEntryWithScoreForGivenDate AS SEWSGD
			ON DS.StudentID = SEWSGD.StudentID
		JOIN ATICommon.dbo.DimClass AS DC 
					ON DS.ActiveClassID = DC.ClassID
	WHERE
		DS.StudentID = @StudentID
		AND DS.SourceSystemID = @SourceSystemID

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/* Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 26-Jul-2018 | ATIPUL2-858 - Initial Version - story is for updating the PoP trend for story ATIPUL2-674   |
===================================================================================================================================
===================================================================================================================================
|   Deepak Dubey     | 11-SEP-2018 | ATIPUL2-934 - Initial Version - story is for showing Algorithm version CUrrently Pulse 1 or 2|
===================================================================================================================================
**********************************************************************************************************************************/

END
