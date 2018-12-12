CREATE TABLE [dbo].[PulseStudent] (
    [UserID]        BIGINT NOT NULL,
    [InstitutionID] BIGINT NOT NULL,
    [IsActive]      BIT    NOT NULL,
    CONSTRAINT [Userid] PRIMARY KEY CLUSTERED ([UserID] ASC, [InstitutionID] ASC)
);

