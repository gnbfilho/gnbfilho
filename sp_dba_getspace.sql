USE [master]
GO

CREATE PROCEDURE sp_dba_getspace (
	@DBname nvarchar(128) = NULL,
	@threshold decimal(5,2) = NULL,
	@showfileinfo bit = 0,
	@debug bit = 0,
	@tmpTabName varchar(128) = NULL
) AS
BEGIN
	SET NOCOUNT ON

	DECLARE @stmt nvarchar(4000),
			@lensrv int,
			@lendb INT;

	CREATE TABLE #showfilestats_final (
		DBname	nvarchar(128),
		FileGroupName nvarchar(128),
		FileId int,
		[FileName]	nvarchar(128),
		[PhysicalName] nvarchar(255),
		Total	DECIMAL(15,2),
		[Used] DECIMAL(15,2),
		[Free]	DECIMAL(15,2),
		[Maximum] DECIMAL(15,2)
	)
	CREATE TABLE #showlogstats (
		DBname	nvarchar(128),
		TotalLog DECIMAL(15,2),
		[Used] DECIMAL(15,2),
		[Status] INT
	)

	EXEC sp_MSforeachdb @command1 = '
	USE [?]
	SET NOCOUNT ON
	CREATE TABLE #showfilestats (
		Fileid	INT,
		FileGroup INT,
		TotalExtents DECIMAL(15),
		UsedExtents DECIMAL(15),
		Max8kbPages bigint,
		Name VARCHAR(255),
		[FileName] VARCHAR(255)
	)
	INSERT INTO #showfilestats (
		Fileid,
		FileGroup,
		TotalExtents,
		UsedExtents,
		Name,
		[FileName]
	) EXEC (''DBCC SHOWFILESTATS WITH NO_INFOMSGS'')
	update #showfilestats
		set Max8kbPages = saf.maxsize
	from #showfilestats sfs
		join master..sysaltfiles saf on sfs.[FileName] = saf.[FileName]
	INSERT INTO #showfilestats_final
	SELECT	''?'',
		fg.groupname,
		Fileid,
		Name,
		[PhysicalName] = [FileName],
		Total = TotalExtents*65536/1024/1024.,
		[Used] = UsedExtents*65536/1024/1024.,
		[Free] = TotalExtents*65536/1024/1024. - UsedExtents*65536/1024/1024.,
		[Maximum] =	case Max8kbPages
						when 0 then TotalExtents*65536/1024/1024.
						when -1 then Max8kbPages
						else Max8kbPages * 8 / 1024.
					end
	FROM	#showfilestats fs
		join [?].dbo.sysfilegroups fg on fs.FileGroup = fg.groupid
	DROP TABLE #showfilestats';

	INSERT INTO #showlogstats
	EXEC ('DBCC SQLPERF(LOGSPACE)');

	SELECT @lensrv = LEN(@@SERVERNAME) + 2;
	SELECT @lendb = MAX(LEN([name])) + 2 FROM [master].sys.databases;

	IF @showfileinfo = 1
		SELECT @stmt = 'SELECT	
				DBname = CONVERT(VARCHAR(' + CONVERT(VARCHAR, @lendb) + '), A.DBname),
				FILEGROUP = FileGroupName,
				FileId,
				[FileName],
				A.Total,
				A.[Free],
				PERC_OCUP = 100 - CONVERT(DECIMAL(5,2),A.[Free] * 100.0 / Total),
				[Maximum],
				[PhysicalName],
				B.TotalLog,
				B.[Used],
				[VERIFYDATE] = GETDATE()
			FROM	#showfilestats_final A
				inner join #showlogstats B on A.DBname = B.DBname
			WHERE	A.DBname != ''model'' ';
	ELSE
		SELECT @stmt = 'SELECT DISTINCT
				DBname = CONVERT(VARCHAR(' + CONVERT(VARCHAR, @lendb) + '), A.DBname),
				(SELECT SUM(Total) from #showfilestats_final where DBname = A.DBname),
				(SELECT SUM([Free]) from #showfilestats_final where DBname = A.DBname),
				100 - CONVERT(DECIMAL(5,2),(SELECT SUM([Free]) from #showfilestats_final where DBname = A.DBname) * 100. / (SELECT SUM(Total) from #showfilestats_final where DBname = A.DBname)),
				B.TotalLog,
				B.[Used],
				[VERIFYDATE] = GETDATE()
			FROM	#showfilestats_final A
				inner join #showlogstats B on A.DBname = B.DBname
			WHERE	A.DBname != ''model'' ';
		
	IF @DBname IS NOT NULL
	BEGIN
		SELECT @stmt = @stmt + '
		AND A.DBname like ''' + @DBname + ''' ';
	END

	IF @threshold IS NOT NULL
	BEGIN
		if @showfileinfo = 1
			SELECT @stmt = @stmt + '
				AND 100 - CONVERT(DECIMAL(5,2),A.[Free] * 100.0 / Total) >= ' + CONVERT(VARCHAR, @threshold);
		ELSE
			SELECT @stmt = @stmt + '
				AND 100 - CONVERT(DECIMAL(5,2),(SELECT SUM([Free]) from #showfilestats_final where DBname = A.DBname) * 100.0 / (SELECT SUM(Total) from #showfilestats_final where DBname = A.DBname)) >= ' + CONVERT(VARCHAR, @threshold);
	END
	
	SELECT @stmt = @stmt + '
			ORDER BY 1,2,3';
			
	SET NOCOUNT OFF

	if @tmpTabName is not null
		select @stmt = 'INSERT INTO ' + @tmpTabName + ' ' + @stmt;

	IF @debug = 1
	BEGIN
		SELECT @stmt = '
	**** Procedure: sp_dba_getspace *************************************************************
		
	**** Parameters, types and values: ************************************************************
			@DBname nvarchar(128) = ' + ISNULL(@DBname, 'NULL') + '
			@threshold decimal(5,2) = ' + ISNULL(convert(varchar(9), @threshold), 'NULL') + '
			@showfileinfo bit = ' + ISNULL(convert(char(1), @showfileinfo), 'NULL') + '
			@debug bit = ' + ISNULL(convert(char(1), @showfileinfo), 'NULL') + '
			@tmpTabName varchar(128) = ' + ISNULL(@tmpTabName, 'NULL') + '
			
	**** Query: ***********************************************************************************
		' + @stmt;
		PRINT @stmt;
	END
		ELSE EXEC(@stmt);
		
	DROP TABLE #showfilestats_final;
	DROP TABLE #showlogstats;
END
GO

EXEC sys.sp_MS_marksystemobject @objname = N'sp_dba_getspace';
GO
