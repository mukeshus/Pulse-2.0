CREATE TABLE [dbo].[passingexpectancy] (
    [PassingExpectancyID] INT        NOT NULL,
    [AssessmentID]        INT        NOT NULL,
    [PercentageLow]       FLOAT (53) NOT NULL,
    [PercentageHigh]      FLOAT (53) NOT NULL,
    [Percentage]          FLOAT (53) NOT NULL,
    [Description]         NCHAR (32) NOT NULL,
    [ScoreRange]          NCHAR (32) NOT NULL,
    [PercentageHighNew]   FLOAT (53) NOT NULL
);

