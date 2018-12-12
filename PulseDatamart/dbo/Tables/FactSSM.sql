CREATE TABLE [dbo].[FactSSM] (
    [SSMID]                  BIGINT          IDENTITY (1, 1) NOT NULL,
    [TestAttemptID]          BIGINT          NOT NULL,
    [AssessmentDateTime]     DATETIME        NOT NULL,
    [UserID]                 BIGINT          NOT NULL,
    [UserName]               NVARCHAR (100)  NULL,
    [FirstName]              NVARCHAR (32)   NULL,
    [LastName]               NVARCHAR (32)   NULL,
    [ConsortiumID]           BIGINT          NULL,
    [ConsortiumName]         NVARCHAR (128)  NULL,
    [InstitutionID]          BIGINT          NULL,
    [InstitutionName]        NVARCHAR (128)  NULL,
    [ActiveClassID]          BIGINT          NOT NULL,
    [ActiveClassName]        NVARCHAR (45)   NULL,
    [TestingClassID]         BIGINT          NULL,
    [TestingClassName]       NVARCHAR (45)   NULL,
    [ProgramTypeID]          INT             NOT NULL,
    [ProgramTypeName]        NVARCHAR (64)   NULL,
    [ContentAreaID]          INT             NOT NULL,
    [ContentAreaName]        NVARCHAR (100)  NULL,
    [AssessmentID]           INT             NULL,
    [AssessmentName]         NVARCHAR (128)  NULL,
    [SSMScore]               DECIMAL (6, 3)  NULL,
    [ScoreCategoryID]        INT             NULL,
    [ScoreCategoryName]      NVARCHAR (40)   NULL,
    [ScoreCategoryMessage]   NVARCHAR (512)  NULL,
    [AdjPercentage]          DECIMAL (12, 2) NULL,
    [ProgramMean]            DECIMAL (12, 2) NULL,
    [TestAttempt]            INT             NOT NULL,
    [PendingAssessmentCount] INT             CONSTRAINT [DF_FactSSM_PendingAssessmentCount] DEFAULT ((0)) NULL,
    [IsFinalScore]           BIT             NULL,
    [IsLatestSSMScore]       BIT             CONSTRAINT [DF__FactSSM__IsLates__66603565] DEFAULT ((0)) NULL,
    [IsActive]               BIT             NULL,
    [BatchID]                INT             NULL,
    [DateCreated]            DATETIME        CONSTRAINT [DF__FactSSM__DateCre__6754599E] DEFAULT (getdate()) NULL,
    [UserCreated]            NVARCHAR (30)   NULL,
    [DateModified]           DATETIME        NULL,
    [UserModified]           NVARCHAR (30)   NULL,
    [SourceSystemID]         INT             NOT NULL,
    [SourceDateCreated]      DATETIME        CONSTRAINT [DF__FactSSM__SourceD__68487DD7] DEFAULT (getdate()) NULL,
    [SourceDateModified]     DATETIME        NULL,
    CONSTRAINT [PK_FactSSM] PRIMARY KEY CLUSTERED ([SSMID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [idx_userid]
    ON [dbo].[FactSSM]([UserID] ASC);


GO
CREATE NONCLUSTERED INDEX [idx_TestAttemptid]
    ON [dbo].[FactSSM]([TestAttemptID] ASC);

