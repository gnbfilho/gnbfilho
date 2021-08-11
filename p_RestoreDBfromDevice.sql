USE [master]
GO

CREATE OR ALTER PROCEDURE p_RestoreDBfromDevice (
	  @deviceName NVARCHAR(128) = 'all'
	, @debug BIT = 0)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @stmt NVARCHAR(MAX) = '';
	DECLARE @devNameAux NVARCHAR(128);
	DECLARE @defaultDataPath NVARCHAR(255);

	IF EXISTS (
		SELECT TOP 1 1
		FROM sys.backup_devices
		WHERE @deviceName = 'all'
		OR [name] = @deviceName
	) 
	BEGIN
		SELECT TOP (1) @defaultDataPath = SUBSTRING(physical_name, 1, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
        FROM sys.master_files
		WHERE database_id > 4;

		DROP TABLE IF EXISTS #filelistonly;

		CREATE TABLE #filelistonly (
			LogicalName				nvarchar(128)
		  , PhysicalName			nvarchar(260)
		  , [Type]					char(1)
		  , FileGroupName			nvarchar(128)
		  , Size					numeric(20,0)
		  , MaxSize					numeric(20,0)
		  , FileID					bigint
		  , CreateLSN				numeric(25,0)
		  , DropLSN					numeric(25,0)
		  , UniqueID				uniqueidentifier
		  , ReadOnlyLSN				numeric(25,0)
		  , ReadWriteLSN			numeric(25,0)
		  , BackupSizeInBytes		bigint
		  , SourceBlockSize			int
		  , FileGroupID				int
		  , LogGroupGUID			uniqueidentifier
		  , DifferentialBaseLSN		numeric(25,0)
		  , DifferentialBaseGUID	uniqueidentifier
		  , IsReadOnly				bit
		  , IsPresent				bit
		  , TDEThumbprint			varbinary(32)
		  , SnapshotURL				nvarchar(360)
		);

		DROP TABLE IF EXISTS #DBfiles;

		CREATE TABLE #DBfiles (
			dbname			nvarchar(128)
		  , LogicalName		nvarchar(128)
		  , PhysicalName	nvarchar(260)
		);

		DECLARE curDevice CURSOR FOR
		SELECT [name]
		FROM sys.backup_devices
		WHERE @deviceName = 'all'
		OR [name] = @deviceName;

		OPEN curDevice;
		FETCH NEXT FROM curDevice INTO @devNameAux;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @stmt = N'RESTORE FILELISTONLY FROM ' + QUOTENAME(@devNameAux);
			TRUNCATE TABLE #filelistonly;

			INSERT INTO #filelistonly
			EXEC (@stmt);

			INSERT INTO #DBfiles
				SELECT @devNameAux, LogicalName, PhysicalName
				FROM #filelistonly

			FETCH NEXT FROM curDevice INTO @devNameAux;
		END

		CLOSE curDevice;
		DEALLOCATE curDevice;

		UPDATE #DBfiles
		SET	PhysicalName = REPLACE(PhysicalName, SUBSTRING(PhysicalName, 1, LEN(PhysicalName) - CHARINDEX('\', REVERSE(PhysicalName)) + 1), @defaultDataPath)

		--SELECT * FROM #DBfiles;

		SELECT @stmt = '';

		DROP TABLE IF EXISTS #SQLstmt;

		SELECT 
			'ALTER DATABASE ' + QUOTENAME(dbname) + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;' AS Line0
		,	'RESTORE DATABASE ' + QUOTENAME(dbname) AS Line1
		,	'FROM ' + QUOTENAME(dbname)  AS Line2
		,	'WITH STATS, REPLACE,' AS Line3
		,	STUFF((SELECT  ',' + 'MOVE ''' + LogicalName + ''' TO ''' + dbfInner.PhysicalName + ''''
					FROM #DBfiles AS dbfInner
					WHERE  dbfInner.dbname = dbfOuter.dbname
					--ORDER BY sortOrder
				FOR XML PATH('')), 1, 1, '') + ';' AS listStr
		INTO #SQLstmt
		FROM #DBfiles AS dbfOuter
		GROUP BY dbname

		SELECT @stmt += CONCAT(CHAR(13), Line0, CHAR(13), Line1, CHAR(13), Line2, CHAR(13), Line3, CHAR(13), listStr, CHAR(13))
		FROM #SQLstmt;

		IF @debug = 0
			EXEC (@stmt);
		ELSE
			PRINT @stmt;
	END
	ELSE
	BEGIN
		RAISERROR('Device not found.', 11, 1);
	END
END
GO
