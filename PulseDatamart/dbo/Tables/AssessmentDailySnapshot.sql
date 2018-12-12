CREATE TABLE [dbo].[AssessmentDailySnapshot] (
    [AssessmentDailySnapshotID] BIGINT         IDENTITY (1, 1) NOT NULL,
    [SnapshotDate]              DATE           NULL,
    [ConsortiumID]              BIGINT         NULL,
    [ConsortiumName]            NVARCHAR (128) NULL,
    [InstitutionID]             BIGINT         NULL,
    [InstitutionName]           NVARCHAR (128) NULL,
    [ClassID]                   INT            NULL,
    [ClassName]                 NVARCHAR (45)  NULL,
    [AssessmentID]              INT            NULL,
    [AssessmentName]            NVARCHAR (128) NULL,
    [AtRiskStudentCount]        INT            NOT NULL,
    [OnTrackStudentCount]       INT            NOT NULL,
    [AvgPoP]                    DECIMAL (6, 3) NULL,
    [TotalStudents]             INT            NULL,
    [Attempts]                  INT            NULL,
    [DateCreated]               DATETIME       CONSTRAINT [DF__Assessmen__DateC__6166761E] DEFAULT (getdate()) NULL,
    [UserCreated]               NVARCHAR (30)  CONSTRAINT [DF__Assessmen__UserC__634EBE90] DEFAULT (suser_sname()) NULL,
    [DateModified]              DATETIME       NULL,
    [UserModified]              NVARCHAR (30)  NULL,
    [SourceSystemID]            INT            NOT NULL,
    CONSTRAINT [AssessmentDailySnapshot_C] PRIMARY KEY CLUSTERED ([AssessmentDailySnapshotID] ASC)
);

