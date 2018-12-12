




CREATE VIEW [dbo].[vwPULSEEtlAssessmentDailySnapshot_bkp]
AS

/*** Script Details *********************************************************************************************************
Title			: AssessmentDailySnapshot ETL INCREMENT Load for PULSE
Author          : Deepak Dubey
Date Created    : 26-Jul-2018
Date Modified   : 26-Jul-2018
Description     : This view will aggregate the assessmentlevel data for a Cohort and load into AssessmentDailySnapShot Table PULSE
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: SELECT * FROM [dbo].[vwPULSEEtlAssessmentDailySnapshot]
****************************************************************************************************************************/

WITH valid_user
 AS ( SELECT DISTINCT userid,assessmentID,tran_begin_time 
	  FROM 
			(SELECT MAX( cLTM.tran_begin_time) as tran_begin_time,userid,assessmentID
		       FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
			   INNER JOIN [cdc].dbo_FactSSM_CT FCT (NOLOCK) ON cLTM.start_lsn = FCT.__$start_lsn AND FCT.__$operation IN (2, 4)
			   GROUP BY userid,assessmentID) DS
	 ) 

SELECT  	  ChangeTime,
			  [Date],
              ProgramTypeID,
              ConsortiumID,
              ConsortiumName,
              InstitutionID,
              InstitutionName,
              AssessmentID,
              AssessmentName,
              ClassID,
              ClassName,  
          SUM(CASE WHEN ScoreCategoryName = 'At Risk' THEN StudentCount ELSE 0 END) [AtRiskStudentCount],
       	  SUM(CASE WHEN ScoreCategoryName = 'On Track' THEN StudentCount ELSE 0 END) [OnTrackStudentCount],
		  ROUND(SUM(SSMScore)/SUM(StudentCount),2) AS AvgPoP       
	          	FROM (            
	          			SELECT   
						    ConsortiumID,
						    ChangeTime,
	                        ConsortiumName,
	                        ProgramTypeID,
	                        InstitutionID,
	                        InstitutionName,
	                        ClassID,
	                        ClassName,
	                        CONVERT(Date,getdate(),101) [Date],
	                        AssessmentID,
	                        AssessmentName,
	                        ScoreCategoryName,
	                        COUNT(UserID) StudentCount,
	                        COUNT(UserID)*AVG(SSMScore) AS SSMScore
	                        FROM (
							      SELECT   
										MSC.ConsortiumID,
										COALESCE(tran_begin_time, GETDATE()) AS ChangeTime,
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
										ROW_NUMBER() OVER(PARTITION BY F.USERID, F.ASSESSMENTID,MSC.ClassID ORDER BY AssessmentDateTime DESC) Attempt
										FROM valid_user  FCT
											INNER JOIN ATICommon.[dbo].[MapStudentClass] MSC ON FCT.UserID = MSC.StudentID
											INNER JOIN ATICommon.[dbo].[MapStudentClass] MSC1 ON MSC1.ClassID = MSC.ClassID
											INNER JOIN ATICommon.[dbo].[DimClass] DC ON MSC1.ClassID = DC.ClassID
											INNER JOIN FactSSM F ON FCT.AssessmentID = F.AssessmentID and MSC1.StudentID = F.UserID
											INNER JOIN ATICommon.[dbo].[DimInstitution] DI ON DC.InstitutionID = DI.InstitutionID
											LEFT JOIN ATICommon.[dbo].[DimConsortium] DCo ON DCo.ConsortiumID = MSC.ConsortiumID
										WHERE MSC.IsActive=1 ) Interim_DS
							GROUP by    ConsortiumID,
										ConsortiumName,
										ProgramTypeID,
										InstitutionID,
										InstitutionName,
										ClassID,
										AssessmentID,
										ScoreCategoryName,
										ClassName,
										AssessmentName,
										ChangeTime ) AS sourcetable
    GROUP BY [Date],ConsortiumName,InstitutionID,InstitutionName,ProgramTypeID,ConsortiumID,AssessmentID,AssessmentName, ClassID,ClassName,ChangeTime



/*** Version History ********************************************************************************************************
=============================================================================================================================
|   Modified By            | Modified On | Change Details                                                                   |
=============================================================================================================================
| <<Deepak Dubey>>         | 26-Jul-2018 | <<ATIPUL2-796>>:<<Initial Version>>                                    			|
-----------------------------------------------------------------------------------------------------------------------------
| <<FName LName>>          | DD-Mmm-YYYY | <<JIRA Ticket #>>:<<Summary of changes made>>                                    |
=============================================================================================================================
****************************************************************************************************************************/

