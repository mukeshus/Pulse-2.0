










CREATE VIEW [dbo].[vwPULSEEtlAssessmentDailySnapshot]
AS

/*** Script Details *********************************************************************************************************
Title			: AssessmentDailySnapshot ETL INCREMENT Load for PULSE
Author          : Mukesh
Date Created    : 26-Jul-2018
Date Modified   : 26-Jul-2018
Description     : This view will aggregate the assessmentlevel data for a Cohort and load into AssessmentDailySnapShot Table PULSE
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: SELECT * FROM [dbo].[vwPULSEEtlAssessmentDailySnapshot] where classID =36167
****************************************************************************************************************************/
WITH valid_user
 AS (  SELECT * FROM (
		SELECT IsNull(FCT.Datemodified,FCT.DateCreated) as Datemodified ,userid,AssessmentID,AssessmentName,MSC.ClassID,
		ROW_NUMBER() OVER (PARTITION BY userid,AssessmentID,AssessmentName,MSC.ClassID ORDER BY IsNull(FCT.Datemodified,FCT.DateCreated) DESC) Latest
		       FROM cdc.lsn_time_mapping AS CLTM WITH (NOLOCK)
			   INNER JOIN [cdc].dbo_FactSSM_CT FCT (NOLOCK) ON cLTM.start_lsn = FCT.__$start_lsn AND FCT.__$operation IN (2, 4) and IsActive=1
			   INNER JOIN ATICommon.[dbo].[MapStudentClass] MSC ON FCT.UserID = MSC.StudentID and MSC.IsActive =1 
			   WHERE FCT.IsLatestSSMScore = 1
			   GROUP BY userid,AssessmentID,AssessmentName,MSC.ClassID,IsNull(FCT.Datemodified,FCT.DateCreated) ) A WHERE Latest =1

	  UNION 
	  SELECT * FROM (
	  SELECT COALESCE(MSC.DateModified,MSC.DateCreated) as tran_begin_time,StudentID as userid,IsNULL(AssessmentID,-1) AssessmentID,ISNULL(AssessmentName,'StudentMovement') AssessmentName,MSC.ClassID
			,ROW_NUMBER() OVER (PARTITION BY StudentID,AssessmentID,AssessmentName,MSC.ClassID ORDER BY COALESCE(MSC.DateModified,MSC.DateCreated) DESC) Latest
		        FROM ATICommon.cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
			    INNER JOIN ATICommon.cdc.[dbo_MapStudentClass_CT] MSC ON cLTM.start_lsn = MSC.__$start_lsn AND MSC.__$operation IN (2, 4)
			    LEFT JOIN dbo.FactSSM FCT (NOLOCK) ON MSC.StudentID = FCT.UserID and FCT.IsLatestSSMScore = 1 and ActiveClassID = MSC.ClassID
				GROUP BY StudentID,AssessmentID,AssessmentName,MSC.ClassID,COALESCE(MSC.DateModified,MSC.DateCreated) ) A WHERE Latest =1


	 ),
	 
valid_class_assessment
AS ( SELECT AssessmentID,AssessmentName,ClassID,max(Datemodified) as Datemodified
		FROM 
		valid_user ---where classID in (48944,48954)
		GROUP BY AssessmentID,AssessmentName,ClassID
	 
	) 

	--select * from valid_class_assessment


	SELECT    ChangeTime,
			  SnapshotDate,
              ProgramTypeID,
              ConsortiumID,
              ConsortiumName,
              InstitutionID,
              InstitutionName,
              max(AssessmentID) AssessmentID ,
              AssessmentName,
              ClassID,
              max(ClassName) ClassName,
              GETDATE() AS DateCreated,
			  SYSTEM_USER AS UserCreated,
			  GETDATE() AS DateModified,
			  SYSTEM_USER AS UserModified,
			  2 AS SourceSystemID,   
          SUM(CASE WHEN ScoreCategoryName = 'At Risk' THEN StudentCount ELSE 0 END) [AtRiskStudentCount],
       	  SUM(CASE WHEN ScoreCategoryName = 'On Track' THEN StudentCount ELSE 0 END) [OnTrackStudentCount],
		  CASE WHEN SUM(StudentCount)=0 then 0 ELSE ROUND(SUM(SSMScore)/SUM(StudentCount),0) END AS AvgPoP,
		  MAX(TotalStudents) As TotalStudents,
		  MAX(Attempt) As Attempts    
	          	FROM (            
	          			SELECT   
						    ConsortiumID,
						    ChangeTime,
	                        ConsortiumName,
	                        ProgramTypeID,
	                        InstitutionID,
	                        InstitutionName,
	                        ClassID,
	                        max(ClassName) ClassName,
	                        CONVERT(Date,getdate(),101) SnapshotDate,
	                        max(AssessmentID) AssessmentID ,
	                        AssessmentName,
	                        ScoreCategoryName,
							COUNT(USERID) AS StudentCount,
	                        (select COUNT(*) from dbo.FactSSM A WHERE A.AssessmentID = MAX(Interim_DS.AssessmentID) and CONVERT(Date,IsNULL(DateModified,DateCreated),101) = CONVERT(Date,getdate(),101) and ActiveClassID = Interim_DS.ClassID  ) AS  Attempt,
	                        COUNT(UserID)*AVG(SSMScore) AS SSMScore,
							(SELECT COUNT(*) FROM ATICommon.[dbo].[MapStudentClass] MSCC WHERE ClassID = Interim_DS.ClassID AND IsActive =1)  AS TotalStudents
	                        FROM (
							      SELECT   
										CAST(DI.ConsortiumID AS bigint) ConsortiumID ,
										COALESCE(FCT.Datemodified, GetDate()) AS ChangeTime,
										DCo.ConsortiumName,
										DI.ProgramTypeID,
										DC.InstitutionID,
										DI.InstitutionName,
										DC.ClassID,
										DC.ClassName,
										IsNULL(FCT.AssessmentID,0) AssessmentID,
										FCT.AssessmentName,
										ISNULL(F.ScoreCategoryName,'') ScoreCategoryName,
										F.UserID,
										IsNULL(F.SSMScore,0) SSMScore
										FROM valid_class_assessment  FCT
											INNER JOIN ATICommon.[dbo].[DimClass] DC ON FCT.ClassID = DC.ClassID
											LEFT JOIN ATICommon.[dbo].[MapStudentClass] MSC ON MSC.ClassID = FCT.ClassID and MSC.IsActive=1
											LEFT JOIN FactSSM F ON MSC.StudentID = F.UserID and F.SSMScore IS NOT NULL and f.Islatestssmscore =1 and F.IsActive =1
											INNER JOIN ATICommon.[dbo].[DimInstitution] DI ON DC.InstitutionID = DI.InstitutionID
											LEFT JOIN ATICommon.[dbo].[DimConsortium] DCo ON DCo.ConsortiumID = DI.ConsortiumID
										 --and msc.ClassID = 48717  -- and f.userid =4018001
										) Interim_DS 
							GROUP by    ConsortiumID,
										ConsortiumName,
										ProgramTypeID,
										InstitutionID,
										InstitutionName,
										ClassID,
									--	AssessmentID,
										ScoreCategoryName,
									--	ClassName,
										AssessmentName,
										ChangeTime ) AS sourcetable
    GROUP BY SnapshotDate,ConsortiumName,InstitutionID,InstitutionName,ProgramTypeID,ConsortiumID,AssessmentName, ClassID,ChangeTime

	


/*** Version History ********************************************************************************************************
=============================================================================================================================
|   Modified By            | Modified On | Change Details                                                                   |
=============================================================================================================================
| <<Mukesh>>         | 26-Jul-2018 | <<ATIPUL2-796>>:<<Initial Version>>                                    			|
-----------------------------------------------------------------------------------------------------------------------------
| <<FName LName>>          | DD-Mmm-YYYY | <<JIRA Ticket #>>:<<Summary of changes made>>                                    |
=============================================================================================================================
****************************************************************************************************************************/

