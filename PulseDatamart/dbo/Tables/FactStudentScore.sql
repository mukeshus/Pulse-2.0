CREATE TABLE [dbo].[FactStudentScore] (
    [KeyStudentScoreID] BIGINT         IDENTITY (1, 1) NOT NULL,
    [UserID]            BIGINT         NULL,
    [ClassID]           BIGINT         NULL,
    [InstitutionID]     BIGINT         NULL,
    [StudentName]       NVARCHAR (100) NULL,
    [ProbofNCLEX]       NVARCHAR (45)  NULL,
    [Trending]          NVARCHAR (20)  NULL,
    [Status]            NVARCHAR (45)  NULL,
    [DateCreated]       DATETIME       DEFAULT (getdate()) NULL,
    [UserCreated]       NVARCHAR (30)  NULL,
    [DateModified]      DATETIME       NULL,
    [UserModified]      NVARCHAR (30)  NULL,
    CONSTRAINT [PK_FactStudentScore] PRIMARY KEY CLUSTERED ([KeyStudentScoreID] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_FactStudentStats]
    ON [dbo].[FactStudentScore]([UserID] ASC, [ClassID] ASC, [InstitutionID] ASC);

