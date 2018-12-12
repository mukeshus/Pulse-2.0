CREATE TABLE [dbo].[PulseClass] (
    [InstitutionID] BIGINT NOT NULL,
    [ConsortiumID]  BIGINT NOT NULL,
    [ClassID]       BIGINT NOT NULL,
    [IsActive]      BIT    NULL,
    CONSTRAINT [ClassID] PRIMARY KEY CLUSTERED ([InstitutionID] ASC, [ConsortiumID] ASC, [ClassID] ASC)
);

