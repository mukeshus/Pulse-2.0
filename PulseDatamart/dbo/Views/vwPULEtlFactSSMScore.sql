







CREATE VIEW [dbo].[vwPULEtlFactSSMScore]
AS
	WITH UserID_valid
	AS (
		SELECT distinct CS.USERID,CS.TestAttemptID,max(COALESCE(cLTM.tran_begin_time, GETDATE())) as ChangeTime,max(CS1.[AssessmentTakenDate]) as  AssessmentDateTime
		FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
      	  INNER JOIN cdc.dbo_ComponentScore_CT CS (NOLOCK) ON cLTM.start_lsn = CS.__$start_lsn and CS.__$operation IN (2, 4) 
		   INNER JOIN dbo.ComponentScore CS1 (NOLOCK) ON CS1.TestAttemptID = CS.TestAttemptID
		  WHERE CS1.BatchID !=-1   group by CS.USERID,CS.TestAttemptID
	   ),

	User_maxCT
	AS (SELECT distinct USERID,max(COALESCE(cLTM.tran_begin_time, GETDATE())) as ChangeTime
		FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
      	  INNER JOIN cdc.dbo_ComponentScore_CT CS (NOLOCK) ON  cLTM.start_lsn = CS.__$start_lsn and CS.__$operation IN (2, 4) group by USERID
		),

	CMS_test_data
	AS (
		SELECT distinct CS.USERID,CS.TestAttemptID,max(COALESCE(cLTM.tran_begin_time, GETDATE())) as ChangeTime,max(CS1.[AssessmentTakenDate]) as  AssessmentDateTime
		FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
      	  INNER JOIN cdc.dbo_ComponentScore_CT CS (NOLOCK) ON  cLTM.start_lsn = CS.__$start_lsn and CS.__$operation IN (2, 4)
		   INNER JOIN dbo.ComponentScore CS1 (NOLOCK) ON CS1.TestAttemptID = CS.TestAttemptID
		  WHERE CS.IsFinalScore != 1
		  group by CS.USERID,CS.TestAttemptID
		),

	Prev_Category
	AS ( Select TestAttemptID,UserID,(SELECT TOP 1 ScoreCategoryID FROM FactSSM WHERE UserID = CT_data.UserID AND AssessmentDateTime < CT_data.AssessmentDateTime ORDER BY AssessmentDateTime desc) AS PrevCategoryID from CMS_test_data CT_data
		),

	Abandoned_tests
	AS ( SELECT distinct CS.USERID,CS.TestAttemptID,max(COALESCE(cLTM.tran_begin_time, GETDATE())) as ChangeTime,max(CS1.[AssessmentTakenDate]) as  AssessmentDateTime
		FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
      	  INNER JOIN cdc.dbo_ComponentScore_CT CS (NOLOCK) ON cLTM.start_lsn = CS.__$start_lsn and CS.__$operation IN (2, 4)
		  INNER JOIN dbo.ComponentScore CS1 (NOLOCK) ON CS1.TestAttemptID = CS.TestAttemptID
		  WHERE CS1.BatchID =-1 group by CS.USERID,CS.TestAttemptID
		)
	
--Added to get only the most recent records after all business rules - Normal, CP, Abandoned rules
SELECT * FROM (
SELECT *, ROW_NUMBER() OVER (PARTITION BY TestAttemptID ORDER BY AssessmentDateTime desc, IsLatestSSMScore desc ) Final_seq from 
 (

	SELECT * FROM
	(   ----  Added to create the logic to deactive previous CP attempts if there is any  new CMS attempt
		SELECT *, 
		ROW_NUMBER() OVER (PARTITION BY TestAttemptID ORDER BY AssessmentDateTime desc, DateModified DESC ) AS Seq1 
		FROM

	          (	-- Added to update the IsLatestSSMScore Logic , To mark the IslatestSSMScore to 0 for prev records
					SELECT * FROM  
							(	SELECT *, ROW_NUMBER() over (partition by TestAttemptID Order by AssessmentDateTime desc,ChangeTime desc,IsLatestSSMScore asc ) as Seq2
							    FROM (

									  SELECT  CONVERT(DATETIME2(0),ChangeTime) AS ChangeTime
									  ,[UserID]
									  ,AssessmentDateTime
									  ,UserName
									  ,FirstName
									  ,LastName
									  ,ConsortiumID
									  ,ConsortiumName
									  ,[InstitutionID]
									  ,[InstitutionName]
									  ,[ActiveClassID]
									  ,[ActiveClassName]
									  ,TestingClassID
									  ,TestingClassName
									  ,ProgramTypeID
									  ,ProgramTypeName
									  ,[ContentAreaID]
									  ,CASE WHEN IsFinalScore =1 then 'Comprehensive Predictor' Else [ContentAreaName] END AS [ContentAreaName]
									  ,[AssessmentID]
									  ,[AssessmentName]
									  ,[TestAttempt]
									  ,[AdjPercentage]
									  ,SSMScore
									  ,[ScoreCategoryID]
									  ,[ScoreCategoryName]
									  ,ScoreCategoryMessage
									  ,CASE WHEN IsLatestSSMScore_Seq = 1  THEN 1 ELSE 0 END AS IsLatestSSMScore
									  ,1 AS IsActive
									  ,[ProgramMean]
									  ,[TestAttemptID]
									  ,[PendingAssessmentCount]
									  ,[IsFinalScore]
									  ,BatchID
									  ,[DateCreated]
									  ,[UserCreated]
									  ,[DateModified]
									  ,[UserModified]
									  ,[SourceSystemID]
									  ,[SourceDateCreated]
									  ,[SourceDateModified]
									   FROM (
								   SELECT 
									--  COALESCE(cLTM.tran_begin_time, GETDATE()) AS ChangeTime
									  COALESCE(UV.ChangeTime, GETDATE()) AS ChangeTime
									  ,CS.[UserID]
									  ,[AssessmentTakenDate] as AssessmentDateTime
									  ,UserName
									  ,FirstName
									  ,LastName
									  ,ConsortiumID
									  ,ConsortiumName
									  ,[InstitutionID]
									  ,[InstitutionName]
									  ,[ActiveClassID]
									  ,[ActiveClassName]
									  ,TestingClassID
									  ,TestingClassName
									  ,CS.ProgramTypeID
									  ,ProgramName AS ProgramTypeName
									  ,[ContentAreaID]
									  ,[ContentAreaName]
									  ,CS.[AssessmentID]
									  ,[AssessmentName]
									  ,[TestAttempt]
									  ,[AdjPercentage]
									  ,[Percentage] AS SSMScore
									  , DSC.CategoryID AS [ScoreCategoryID]
									  , DSC.CategoryName AS  [ScoreCategoryName]
									  , DSCM.MessageName AS ScoreCategoryMessage
									  ,ROW_NUMBER() OVER (PARTITION BY  CS.UserID order by AssessmentTakenDate DESC,cLTM.tran_begin_time desc ) AS IsLatestSSMScore_Seq
									  ,1 as IsActive
									  ,[ProgramMean]
									  ,CS.[TestAttemptID]
									  ,[PendingAssessmentCount]
									  ,[IsFinalScore]
									  ,CS.BatchID
									  ,CS.[DateCreated]
									  ,CS.[UserCreated]
									  ,CASE WHEN CS.__$operation = 4 then GETDATE() ELSE  CS.[DateModified] END  as [DateModified]
									  ,CS.[UserModified]
									  ,CS.[SourceSystemID]
									  ,CS.[SourceDateCreated]
									  ,CS.[SourceDateModified]
									  --Sequence to get the latest changes for a user,testattempt
    								   , Row_number( )
												OVER(
													partition BY CS.UserID,CS.TestAttemptID 
													ORDER BY AssessmentTakenDate DESC,cLTM.tran_begin_time desc) as GetLatest  
								  FROM cdc.lsn_time_mapping AS cLTM WITH (NOLOCK)
								  INNER JOIN cdc.dbo_ComponentScore_CT CS (NOLOCK) ON cLTM.start_lsn = CS.__$start_lsn AND CS.__$operation IN (2, 4)
								  INNER JOIN dbo.passingexpectancy PE with(nolock) on PE.PercentageLow <= CS.RawScore and PercentageHighNew >= CS.RawScore
								  INNER JOIN UserID_valid UV1 on CS.UserID = UV1.UserID and CS.TestAttemptID = UV1.TestAttemptID
								  INNER JOIN User_maxCT UV on CS.UserID = UV.UserID
								  INNER JOIN ATICommon.dbo.DimScoreCategory DSC ON PE.[Percentage] <= DSC.ScoreHigh and [Percentage] > DSC.ScoreLow and DSC.ProgramTypeID = CS.ProgramTypeID
								  LEFT JOIN Prev_Category PC ON PC.UserID = CS.UserID and PC.TestAttemptID = CS.TestAttemptID
								  LEFT JOIN ATICOMMON.dbo.DimScoreCategoryMessage DSCM ON DSC.CategoryID = DSCM.NewScoreCategoryID and PC.PrevCategoryID = DSCM.PreviousScoreCategoryID
								  where PE.AssessmentID = 79104 
									) CS_Data  where GetLatest =1
  
								  UNION
									-- Added to create the logic to update the IsLatestSSMScore Column to 0 for previous assessment
								  SELECT 
									  CONVERT(DATETIME2(0),UV1.ChangeTime) AS ChangeTime
									  ,FS.[UserID]
									  ,FS.AssessmentDateTime
									  ,FS.UserName
									  ,FS.FirstName
									  ,FS.LastName
									  ,FS.ConsortiumID
									  ,FS.ConsortiumName
									  ,FS.[InstitutionID]
									  ,FS.[InstitutionName]
									  ,FS.[ActiveClassID]
									  ,FS.[ActiveClassName]
									  ,FS.TestingClassID
									  ,FS.TestingClassName
									  ,FS.ProgramTypeID
									  ,FS.ProgramTypeName
									  ,FS.[ContentAreaID]
									  ,CASE WHEN FS.IsFinalScore =1 then 'Comprehensive Predictor' Else FS.[ContentAreaName] END AS [ContentAreaName] 
									  ,FS.[AssessmentID]
									  ,FS.[AssessmentName]
									  ,FS.[TestAttempt]
									  ,FS.[AdjPercentage]
									  ,SSMScore
									  ,[ScoreCategoryID]
									  ,[ScoreCategoryName]
									  ,ScoreCategoryMessage
									  ,0 as IsLatestSSMScore
									  ,IsActive
									  ,FS.[ProgramMean]
									  ,FS.[TestAttemptID]
									  ,FS.[PendingAssessmentCount]
									  ,FS.[IsFinalScore]
									  ,FS.BatchID
									  ,FS.[DateCreated]
									  ,FS.[UserCreated]
									  , GETDATE() as [DateModified]
									  ,FS.[UserModified]
									  ,FS.[SourceSystemID]
									  ,FS.[SourceDateCreated]
									  ,FS.[SourceDateModified]
								  FROM dbo.FactSSM FS with(nolock) 
								  INNER JOIN UserID_valid UV on FS.UserID = UV.UserID 
								  INNER JOIN User_maxCT UV1 on FS.UserID = UV1.UserID
								  INNER JOIN cdc.dbo_ComponentScore_CT CCT ON CCT.UserID = FS.UserID and CCT.__$operation = 4
								  WHERE IsLatestSSMScore = 1 and FS.AssessmentDateTime < UV.AssessmentDateTime AND CCT.BatchID !=-1
								  ) Interim 
						) a WHERE seq2 =1
  UNION
    -- Added to create the logic to extract and deactive previous CP attempts by marking the ssmscore as -1 if there is any  new CMS attempt 
  SELECT 
	  CONVERT(DATETIME2(0),UV1.ChangeTime) AS ChangeTime
      ,FS.[UserID]
      ,FS.AssessmentDateTime
	  ,FS.UserName
	  ,FS.FirstName
	  ,FS.LastName
	  ,FS.ConsortiumID
      ,FS.ConsortiumName
      ,FS.[InstitutionID]
      ,FS.[InstitutionName]
      ,FS.[ActiveClassID]
      ,FS.[ActiveClassName]
	  ,FS.TestingClassID
	  ,FS.TestingClassName
	  ,FS.ProgramTypeID
	  ,ProgramTypeName
      ,FS.[ContentAreaID]
      ,CASE WHEN FS.IsFinalScore =1 then 'Comprehensive Predictor' Else FS.[ContentAreaName] END AS [ContentAreaName]
      ,FS.[AssessmentID]
      ,FS.[AssessmentName]
      ,FS.[TestAttempt]
      ,FS.[AdjPercentage]
      ,-1 SSMScore
	  ,NULL AS [ScoreCategoryID]
	  ,NULL AS [ScoreCategoryName]
	  ,ScoreCategoryMessage
	  ,0 as IsLatestSSMScore
	  ,1 as IsActive
      ,FS.[ProgramMean]
      ,FS.[TestAttemptID]
      ,FS.[PendingAssessmentCount]
      ,FS.[IsFinalScore]
	  ,FS.BatchID
      ,FS.[DateCreated]
      ,FS.[UserCreated]
      ,GETDATE() AS [DateModified]
      ,FS.[UserModified]
      ,FS.[SourceSystemID]
      ,FS.[SourceDateCreated]
      ,FS.[SourceDateModified]
	  ,1 as Seq2
  FROM dbo.FactSSM FS WITH(NOLOCK) 
  INNER JOIN CMS_test_data UV ON FS.UserID = UV.UserID 
  INNER JOIN User_maxCT UV1 on FS.UserID = UV1.UserID
  INNER JOIN cdc.dbo_ComponentScore_CT CCT ON CCT.UserID = FS.UserID and CCT.__$operation in (2,4)
  WHERE FS.IsFinalScore =1 and  FS.AssessmentDateTime < UV.AssessmentDateTime  and FS.IsActive =1 AND CCT.BatchID !=-1 
   	) Final_DS ) a WHERE seq1 = 1
UNION
-- Handle Abandoned Tests
SELECT
CONVERT(DATETIME2(0),UV1.ChangeTime) AS ChangeTime
      ,FS.[UserID]
      ,FS.AssessmentDateTime
	  ,FS.UserName
	  ,FS.FirstName
	  ,FS.LastName
	  ,FS.ConsortiumID
      ,FS.ConsortiumName
      ,FS.[InstitutionID]
      ,FS.[InstitutionName]
      ,FS.[ActiveClassID]
      ,FS.[ActiveClassName]
	  ,FS.TestingClassID
	  ,FS.TestingClassName
	  ,FS.ProgramTypeID
	  ,FS.ProgramTypeName
      ,FS.[ContentAreaID]
      ,CASE WHEN FS.IsFinalScore =1 then 'Comprehensive Predictor' Else FS.[ContentAreaName] END AS [ContentAreaName] 
	  ,FS.[AssessmentID]
      ,FS.[AssessmentName]
      ,FS.[TestAttempt]
      ,FS.[AdjPercentage]
      ,0 AS SSMScore
	  ,0 AS [ScoreCategoryID]
	  ,NULL AS [ScoreCategoryName]
	  ,NULL AS ScoreCategoryMessage
	  ,0 as IsLatestSSMScore
	  ,0 as IsActive
      ,FS.[ProgramMean]
      ,FS.[TestAttemptID]
      ,FS.[PendingAssessmentCount]
      ,FS.[IsFinalScore]
	  ,FS.BatchID
      ,FS.[DateCreated]
      ,FS.[UserCreated]
      ,GETDATE() AS [DateModified]
      ,FS.[UserModified]
      ,FS.[SourceSystemID]
      ,FS.[SourceDateCreated]
      ,FS.[SourceDateModified]
	  ,1 as Seq2
	  ,1 as Seq1
  FROM dbo.FactSSM FS WITH(NOLOCK) 
  INNER JOIN Abandoned_tests CCT ON CCT.TestAttemptID = FS.TestAttemptID  
 -- INNER JOIN UserID_valid UVF ON UVF.TestAttemptID != FS.TestAttemptID
  INNER JOIN User_maxCT UV1 on FS.UserID = UV1.UserID 
  WHERE  FS.TestAttemptID NOT IN (SELECT TestAttemptID FROM UserID_valid )
  UNION
  SELECT 
	   ChangeTime,
		UserID,
	   AssessmentDateTime
	  ,UserName
	  ,FirstName
	  ,LastName
	  ,ConsortiumID
      ,ConsortiumName
      ,[InstitutionID]
      ,[InstitutionName]
      ,[ActiveClassID]
      ,[ActiveClassName]
	  ,TestingClassID
	  ,TestingClassName
	  ,ProgramTypeID
	  ,ProgramTypeName
      ,[ContentAreaID]
      ,[ContentAreaName] 
	  ,[AssessmentID]
      ,[AssessmentName]
      ,[TestAttempt]
      ,[AdjPercentage]
      ,SSMScore
	  ,[ScoreCategoryID]
	  ,[ScoreCategoryName]
	  ,ScoreCategoryMessage
	  ,IsLatestSSMScore
	  ,IsActive
      ,[ProgramMean]
      ,[TestAttemptID]
      ,[PendingAssessmentCount]
      ,[IsFinalScore]
	  ,BatchID
      ,[DateCreated]
      ,[UserCreated]
      ,[DateModified]
      ,[UserModified]
      ,[SourceSystemID]
      ,[SourceDateCreated]
      ,[SourceDateModified]
	  ,Seq2
	  ,Seq1
	  FROM (
					SELECT 
				   CONVERT(DATETIME2(0),CCT.ChangeTime) AS ChangeTime
				  ,FS.[UserID]
				  ,FS.AssessmentDateTime
				  ,FS.UserName
				  ,FS.FirstName
				  ,FS.LastName
				  ,FS.ConsortiumID
				  ,FS.ConsortiumName
				  ,FS.[InstitutionID]
				  ,FS.[InstitutionName]
				  ,FS.[ActiveClassID]
				  ,FS.[ActiveClassName]
				  ,FS.TestingClassID
				  ,FS.TestingClassName
				  ,FS.ProgramTypeID
				  ,FS.ProgramTypeName
				  ,FS.[ContentAreaID]
				  ,CASE WHEN FS.IsFinalScore =1 then 'Comprehensive Predictor' Else FS.[ContentAreaName] END AS [ContentAreaName] 
				  ,FS.[AssessmentID]
				  ,FS.[AssessmentName]
				  ,FS.[TestAttempt]
				  ,FS.[AdjPercentage]
				  ,SSMScore
				  ,[ScoreCategoryID]
				  ,[ScoreCategoryName]
				  ,ScoreCategoryMessage
				  ,1 as IsLatestSSMScore
				  ,1 as IsActive
				  ,FS.[ProgramMean]
				  ,FS.[TestAttemptID]
				  ,FS.[PendingAssessmentCount]
				  ,FS.[IsFinalScore]
				  ,FS.BatchID
				  ,FS.[DateCreated]
				  ,FS.[UserCreated]
				  ,GETDATE() AS [DateModified]
				  ,FS.[UserModified]
				  ,FS.[SourceSystemID]
				  ,FS.[SourceDateCreated]
				  ,FS.[SourceDateModified]
				  ,1 as Seq2
				  ,1 as Seq1
				  ,ROW_NUMBER() OVER (Partition BY FS.UserID ORDER BY FS.AssessmentDateTime DESC) SecLatest
			  FROM dbo.FactSSM FS WITH(NOLOCK) 
			  INNER JOIN Abandoned_tests CCT ON CCT.UserID = FS.UserID 
			  LEFT JOIN UserID_valid UVF ON UVF.UserID = FS.UserID
			  WHERE  FS.TestAttemptID NOT IN (SELECT TestAttemptID FROM Abandoned_tests ) ) a WHERE SecLatest =1

  ) Final ) Final_DS  WHERE Final_Seq =1


	

  
  /*** Version History ********************************************************************************************************
=============================================================================================================================
|     Modified By          | Modified On | Change Details                                                                   |
=============================================================================================================================
| <<Modified By>>          | DD-Mmm-YYYY | <<JIRA Ticket #>>:<<Summary of changes made>>                                    |
-----------------------------------------------------------------------------------------------------------------------------
=============================================================================================================================
****************************************************************************************************************************/




;
