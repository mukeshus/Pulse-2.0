
CREATE   PROCEDURE [dbo].[uspPULSEApiGetListOfStudents]
	@pSourceSystemID				INT			= 2
AS
BEGIN

/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to retrieve list of students for a assessment within current program type
Author          : Hansraj Bendale
Date Created    : 28-Aug-2018
Date Modified   : 28-Aug-2018
Description     : Gets list of students for a assessment within current program type and for a given date range.
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 

	SET STATISTICS IO, TIME ON
	EXEC dbo.uspPULSEApiGetListOfStudentsForAssessment
		@pSourceSystemID = 2
	SET STATISTICS IO, TIME OFF
**********************************************************************************************************************************/

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SourceSystemID			BIGINT = COALESCE(@pSourceSystemID,2)

	DECLARE @FactSSMEntries TABLE (
		UserID						BIGINT
		, AssessmentDateTime		DATETIME
	)

	INSERT INTO @FactSSMEntries (UserID, AssessmentDateTime)
	SELECT DISTINCT TOP 1000 
		UserID
		, MAX(AssessmentDateTime) AS AssessmentDateTime
	FROM 
		dbo.FactSSM WITH (NOLOCK)
	WHERE
		IsActive = 1
		AND SSMScore IS NOT NULL
		AND SourceSystemID = @SourceSystemID
		AND InstitutionID IN 
		(
			SELECT
				I.InstitutionID
			FROM
				ATICommon.dbo.DimInstitution AS I WITH (NOLOCK)
			JOIN 
				(	
					SELECT 
						DCon.consortiumID
						, DI.ProgramTypeID 
					FROM 
						ATICommon.dbo.DimStudent AS IDS WITH (NOLOCK)
						JOIN ATICommon.dbo.DimClass AS DC WITH (NOLOCK)
							ON IDS.ActiveClassID = DC.ClassID
						JOIN ATICommon.dbo.DimInstitution AS DI WITH (NOLOCK)
							ON DC.InstitutionID = DI.InstitutionID
						LEFT OUTER JOIN ATICommon.dbo.DimConsortium AS DCon WITH (NOLOCK)
							ON DI.ConsortiumID = DCon.ConsortiumID
					WHERE
						IDS.StudentID = UserID
				) AS A
				ON ((I.ProgramTypeID = A.ProgramTypeID AND I.ConsortiumID = A.ConsortiumID)
					OR (I.ProgramTypeID = A.ProgramTypeID AND A.ConsortiumID IS NULL))
		) 	 
	GROUP BY 
		UserID 
	ORDER BY 
		AssessmentDateTime DESC
		, UserID
	
	--Fetching Student Id, UserName and name for the given Student
	SELECT 
		DS.StudentID
		, (DS.LastName + ', ' + DS.FirstName) AS StudentName
		, DS.UserName
	FROM
		ATICommon.dbo.DimStudent AS DS WITH (NOLOCK)
		JOIN @FactSSMEntries AS FSSM
			ON DS.StudentID = FSSM.UserID
		ORDER BY 
			FSSM.AssessmentDateTime DESC

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 28-Aug-2018 | ATIPUL2-1003 - Initial Version which will be currently used for temporary drop down of Pulse|
|                    |             | 2.0 Home page to show list of students to enable change of student id input for Student     |
|                    |             | Individual Dashboard. This SP will be revisited and reused once the other screens are added |
===================================================================================================================================
**********************************************************************************************************************************/

END
