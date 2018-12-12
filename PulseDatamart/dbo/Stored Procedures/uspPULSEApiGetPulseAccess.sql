
CREATE PROCEDURE [dbo].[uspPULSEApiGetPulseAccess] 
	@pInstitutionID					BIGINT
	, @pRole						VARCHAR(25)
	, @pUserID						BIGINT
AS
BEGIN
/*** Script Details ***************************************************************************************************************
Title			: Stored Procedure to validate a user to determine access to Pulse application
Author          : Hansraj Bendale
Date Created    : 13-Aug-2018
Description     : Validate a user to determine access to Pulse application
Scenarios		: Refer to the Scenarios at the bottom of this script for detailed list of scenarios
Version History : Refer to Version History at the bottom of this script for detailed list of changes
Execute Sample	: 
	-- Test for Student
	EXEC uspPULSEApiGetPulseAccess
	@pUserID	= 3994800		-- 3994833302 for unauthorized user -- 3994800 for authorized user
	, @pInstitutionID	= 13		-- 13 for unauthorized institution -- 14 for authorized institution
	, @pRole = 'Student';

	-- Test for Instructor
	EXEC uspPULSEApiGetPulseAccess 
	@pInstitutionID	= 13			-- 13 for unauthorized institution -- 14 for authorized institution
	, @pRole = 'Instructor';

	EXEC uspPULSEApiGetPulseAccess 
	@pInstitutionID	= 14			-- 13 for unauthorized institution -- 14 for authorized institution
	, @pRole = '4';
	
	-- Test for Director
	EXEC uspPULSEApiGetPulseAccess
	@pUserID		= 3994800	-- 3101167 for authorized user -- 3994800 for unauthorized user
	, @pInstitutionID	= 6897		-- 13 for unauthorized institution -- 14 for authorized institution -- 8917 for authorized institution
	, @pRole		= 'Director';

	EXEC uspPULSEApiGetPulseAccess
	@pUserID		= 3994800	-- 3101167 for authorized user -- 3994800 for unauthorized user
	, @pInstitutionID	= 13		-- 13 for unauthorized institution -- 14 for authorized institution -- 8917 for authorized institution
	, @pRole		= '5';
	
	-- Test for ATI
	EXEC uspPULSEApiGetPulseAccess
	@pUserID		= 3994800 
	, @pInstitutionID	= 9393		-- 13 for unauthorized institution -- 14 for authorized institution -- 9393 for authorized institution
	, @pRole		= 'Personnel';

	EXEC uspPULSEApiGetPulseAccess 
	@pUserID		= 3248726
	, @pInstitutionID	= 9393		-- 13 for unauthorized institution -- 14 for authorized institution -- 9393 for authorized institution
	, @pRole		= '1';
	
	EXEC uspPULSEApiGetPulseAccess 
	@pUserID		= 3248726
	, @pInstitutionID	= 14	
	, @pRole		= 'Instructor';
**********************************************************************************************************************************/
	SET NOCOUNT ON ;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@IsValid			BIT			= 0
		, @ConID			BIGINT		= -1

	SELECT TOP 1 
		@ConID = COALESCE(ConsortiumID,-1) 
	FROM 
		ATICommon.dbo.DimInstitution WITH (NOLOCK)
	WHERE 
		InstitutionID = @pInstitutionID 
		AND SourceSystemID = 2
	ORDER BY
		ISNULL(DateModified,DateCreated) DESC

	--SELECT @ConID AS ConsortiumID

    IF @pRole IS NOT NULL
	BEGIN
		
		IF ISNUMERIC(@pRole) = 1
			SELECT 
				@pRole = LOWER(Name)
			FROM 
				ATICommon.dbo.DimRole WITH (NOLOCK)
			WHERE 
				RoleID = @pRole

		-- Is role Instructor?
		IF @pRole = 'instructor'		
		BEGIN
			-- Does selected InstitutionID exist in PulseClass?
			IF EXISTS (
				SELECT 1 
				FROM 
					dbo.PulseClass WITH (NOLOCK)
				WHERE 
					InstitutionID = @pInstitutionID 
					AND IsActive = 1
			)
			BEGIN			  
				SET @IsValid = 1;
			END	
		END
        -- Is role a Student?        
		ELSE IF @pRole = 'student'
		BEGIN
			-- Does UserID exist in PulseStudent?
			IF EXISTS (
				SELECT 1 
				FROM 
					dbo.PulseClass WITH (NOLOCK)
				WHERE 
					InstitutionID = @pInstitutionID 
					AND IsActive = 1
			)
			BEGIN
				IF EXISTS (
					SELECT 1 
					FROM 
						dbo.PulseStudent WITH (NOLOCK)
					WHERE 
						UserID = @pUserID
						AND InstitutionID = @pInstitutionID
						AND IsActive = 1
				)
				BEGIN
					SET @IsValid = 1;
				END				 
			END
		END		
        -- Is role a Director?
		ELSE IF @pRole = 'director'	
		BEGIN 
			-- Has Institution purchased Pulse?
            IF (@ConID <> 0)
			BEGIN
				IF EXISTS (
					SELECT 1 
					FROM 
						dbo.PulseClass WITH (NOLOCK)
					WHERE 
						ConsortiumID = @ConID 
						AND IsActive = 1
					)
				BEGIN
					-- Does ConsortiumContact record exist for the UserID where IsDirector = 1 ?
					IF EXISTS (
						--	SELECT 1 FROM [ATI-PRD-SQL11].asm.[Config].[ConsortiumContact]		-- From Original SP. Retained for Reference
						SELECT 1 
						FROM 
							ATICommon.dbo.DimConsortiumContact WITH (NOLOCK)
						WHERE
							UserID = @pUserID
							AND ConsortiumID = @ConID
							AND IsDirector = 1
					)
					BEGIN
						SET @IsValid = 1;
					END
					ELSE
					BEGIN
						IF EXISTS (
							SELECT 1 
							FROM 
								dbo.PulseClass WITH (NOLOCK)
							WHERE InstitutionID = @pInstitutionID 
							AND IsActive = 1
						)
						BEGIN
							SET @IsValid = 1;
						END
					END
				END
			END
			ELSE
			BEGIN
				-- Does selected InstitutionID exist in PulseClass
				IF EXISTS (
					SELECT 1 
					FROM 
						dbo.PulseClass WITH (NOLOCK)
					WHERE 
						InstitutionID = @pInstitutionID 
						AND IsActive = 1
				)
				BEGIN
					SET @IsValid = 1;
				END
			END
		END
        -- Is role a Personnel?        
		ELSE IF @pRole = 'personnel' OR  @pRole = 'ati'
		BEGIN
			-- Does selected InstitutionID belong to a Consortium?
			-- AND Does selected ConsortiumID exist in PulseClass?
			IF EXISTS (
				SELECT 1 
				FROM 
					dbo.PulseClass WITH (NOLOCK)
				WHERE
					--InstitutionID = @pInstitutionID
					--AND 
					ConsortiumID = @ConID 
					AND IsActive = 1
			)
			BEGIN
				SET @IsValid = 1;
			END

			-- Is institution in PulseClass?
			IF EXISTS (
				SELECT 1
				FROM 
					dbo.PulseClass WITH (NOLOCK)
				WHERE 
					InstitutionID = @pInstitutionID 
					AND IsActive = 1
			)
			BEGIN
				SET @IsValid = 1;
			END
		END
		
		IF @IsValid = 0x0
		BEGIN
			SELECT 0 AS isValid;
		END
		ELSE IF @IsValid = 0x1
		BEGIN
			SELECT 1 AS isValid;
		END
		
	END
	ELSE
		SELECT 0 AS isValid;

/* Scenarios **********************************************************************************************************************
Refer to JIRA Stories
**********************************************************************************************************************************/

/*** Version History **************************************************************************************************************
===================================================================================================================================
|    Modified By     | Modified On | Change Details                                                                              |
===================================================================================================================================
|   Hansraj Bendale  | 13-Aug-2018 | ATIPUL2-612 - Initial Version                                                               |
===================================================================================================================================
|   Hansraj Bendale  | 12-Sep-2018 | ATIPUL2-1073 - Update to the existing API - Deriving  Consortium ID from Institution ID and | 
|                    |             | taking SourceSystem ID into consideration. Also changed input names as per standard         |
===================================================================================================================================
**********************************************************************************************************************************/

END