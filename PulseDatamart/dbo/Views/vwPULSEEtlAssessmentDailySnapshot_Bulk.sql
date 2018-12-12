

CREATE VIEW [dbo].vwPULSEEtlAssessmentDailySnapshot_Bulk
AS

/*** Script Details *********************************************************************************************************
Title			: AssessmentDailySnapshot ETL bulk Load for PULSE
Author          : Mukesh
Date Created    : 26-Jul-2018
Date Modified   : 26-Jul-2018
Description     : This view will aggregate the assessmentlevel data for a Cohort and load into AssessmentDailySnapShot Table PULSE
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: SELECT * FROM [dbo].[vwPULSEEtlAssessmentDailySnapshot_Bulk] where classID =36167
****************************************************************************************************************************/

WITH valid_user
 AS ( SELECT MSC.ClassID
		       FROM  FactSSM FCT (NOLOCK) 
			   INNER JOIN ATICommon.[dbo].[MapStudentClass] MSC ON FCT.UserID = MSC.StudentID and MSC.IsActive =1
			   GROUP BY MSC.ClassID
	 ),
	 
Interim_DS
AS ( SELECT   
			MSC.ConsortiumID,
			DCo.ConsortiumName,
			MSC.ProgramTypeID,
			DC.InstitutionID,
			DI.InstitutionName,
			MSC.ClassID,
			MSC.ClassName,
			F.AssessmentID,
			F.AssessmentName,
			F.ScoreCategoryName,
			F.UserID,
			F.SSMScore,
			ROW_NUMBER() OVER(partition by MSC.ClassID ORDER BY AssessmentDateTime DESC) Attempt
			FROM valid_user  FCT
				INNER JOIN ATICommon.[dbo].[DimClass] DC ON FCT.ClassID = DC.ClassID
				INNER JOIN ATICommon.[dbo].[MapStudentClass] MSC ON MSC.ClassID = FCT.ClassID
				INNER JOIN FactSSM F ON MSC.StudentID = F.UserID
				INNER JOIN ATICommon.[dbo].[DimInstitution] DI ON DC.InstitutionID = DI.InstitutionID
				LEFT JOIN ATICommon.[dbo].[DimConsortium] DCo ON DCo.ConsortiumID = MSC.ConsortiumID
			WHERE MSC.IsActive=1 and F.SSMScore IS NOT NULL and F.IsLatestSSMScore =1  --and msc.ClassID =34998
		),
ClassID_Assesment
AS (
     SELECT
			ClassID, 
			AssessmentName
	 FROM
			Interim_DS
	 WHERE 
			Attempt =1
	)

	--	select * from Interim_DS

SELECT  	  SnapshotDate,
              ProgramTypeID,
              ConsortiumID,
              ConsortiumName,
              InstitutionID,
              InstitutionName,
              max(AssessmentID) AssessmentID ,
              max(AssessmentName) AssessmentName,
              ClassID,
              ClassName,
              GETDATE() AS DateCreated,
			  SYSTEM_USER AS UserCreated,
			  GETDATE() AS DateModified,
			  SYSTEM_USER AS UserModified,
			  2 AS SourceSystemID,   
          SUM(CASE WHEN ScoreCategoryName = 'At Risk' THEN StudentCount ELSE 0 END) [AtRiskStudentCount],
       	  SUM(CASE WHEN ScoreCategoryName = 'On Track' THEN StudentCount ELSE 0 END) [OnTrackStudentCount],
		  ROUND(SUM(SSMScore)/SUM(StudentCount),0) AS AvgPoP       
	          	FROM (            
	          			SELECT   
						    ConsortiumID,
						    --ChangeTime,
	                        ConsortiumName,
	                        ProgramTypeID,
	                        InstitutionID,
	                        InstitutionName,
	                        IDS.ClassID,
	                        ClassName,
	                        CONVERT(Date,getdate(),101) SnapshotDate,
	                        max(AssessmentID) AssessmentID ,
	                      	MAX(CA.AssessmentName) As AssessmentName,
	                        ScoreCategoryName,
	                        COUNT(UserID) StudentCount,
	                        COUNT(UserID)*AVG(SSMScore) AS SSMScore
	                        FROM  Interim_DS IDS
							INNER JOIN ClassID_Assesment CA ON CA.ClassID = IDS.ClassID
							GROUP by    ConsortiumID,
										ConsortiumName,
										ProgramTypeID,
										InstitutionID,
										InstitutionName,
										IDS.ClassID,
									--	AssessmentID,
										ScoreCategoryName,
										ClassName
									--	AssessmentName,
										 ) AS sourcetable
    GROUP BY SnapshotDate,ConsortiumName,InstitutionID,InstitutionName,ProgramTypeID,ConsortiumID, ClassID,ClassName



/*** Version History ********************************************************************************************************
=============================================================================================================================
|   Modified By            | Modified On | Change Details                                                                   |
=============================================================================================================================
| <<Deepak Dubey>>         | 26-Jul-2018 | <<ATIPUL2-796>>:<<Initial Version>>                                    			|
-----------------------------------------------------------------------------------------------------------------------------
| <<FName LName>>          | DD-Mmm-YYYY | <<JIRA Ticket #>>:<<Summary of changes made>>                                    |
=============================================================================================================================
****************************************************************************************************************************/

