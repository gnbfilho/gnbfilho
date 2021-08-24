USE [master]
GO

CREATE OR ALTER PROCEDURE sp_dba_getspace (
	@dbname nvarchar(128) = NULL,
	@threshold decimal(5,2) = NULL,
	@showfileinfo bit = 0,
	@testonly bit = 0,
	@tmpTabName varchar(128) = NULL
) as
begin

	set nocount on

	DECLARE @stmt nvarchar(4000),
			@lensrv int,
			@lendb int

	CREATE TABLE #showfilestats_final (
		Banco	nvarchar(128),
		FileGroupName nvarchar(128),
		IdArquivo int,
		Arquivo	nvarchar(128),
		CaminhoArquivo nvarchar(255),
		Total	DECIMAL(15,2),
		Utilizado DECIMAL(15,2),
		Livre	DECIMAL(15,2),
		Maximo DECIMAL(15,2)
	)
	CREATE TABLE #showlogstats (
		Banco	nvarchar(128),
		TotalLog DECIMAL(15,2),
		Utilizado DECIMAL(15,2),
		Status INT
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
		FileName VARCHAR(255)
	)
	INSERT INTO #showfilestats (
		Fileid,
		FileGroup,
		TotalExtents,
		UsedExtents,
		Name,
		FileName
	) EXEC (''DBCC SHOWFILESTATS WITH NO_INFOMSGS'')
	update #showfilestats
		set Max8kbPages = saf.maxsize
	from #showfilestats sfs
		join master..sysaltfiles saf on sfs.FileName = saf.filename
	INSERT INTO #showfilestats_final
	SELECT	''?'',
		fg.groupname,
		Fileid,
		Name,
		CaminhoArquivo = FileName,
		Total = TotalExtents*65536/1024/1024.,
		Utilizado = UsedExtents*65536/1024/1024.,
		Livre = TotalExtents*65536/1024/1024. - UsedExtents*65536/1024/1024.,
		Maximo =	case Max8kbPages
						when 0 then TotalExtents*65536/1024/1024.
						when -1 then Max8kbPages
						else Max8kbPages * 8 / 1024.
					end
	FROM	#showfilestats fs
		join [?].dbo.sysfilegroups fg on fs.FileGroup = fg.groupid
	DROP TABLE #showfilestats'

	INSERT INTO #showlogstats
	EXEC ('DBCC SQLPERF(LOGSPACE)')

	select @lensrv = LEN(@@SERVERNAME) + 2;
	select @lendb = MAX(LEN(name)) + 2 from master.sys.databases;

	if @showfileinfo = 1
		SELECT @stmt = 'SELECT	
				BANCO = CONVERT(VARCHAR(' + convert(varchar, @lendb) + '),A.Banco),
				FILEGROUP = FileGroupName,
				ID_ARQUIVO = IdArquivo,
				NOME_ARQUIVO = Arquivo,
				TAMANHO_ARQUIVO_MB = A.Total,
				LIVRE_ARQUIVO_MB = A.Livre,
				PERC_OCUP = 100 - CONVERT(DECIMAL(5,2),A.Livre * 100.0 / Total),
				TAMANHO_MAXIMO_MB = Maximo,
				CAMINHO_ARQUIVO = CaminhoArquivo,
				TAMANHO_LOG_MB = B.TotalLog,
				LOG_SPACE_USED = B.Utilizado,
				DATA = GETDATE()
			FROM	#showfilestats_final A
				inner join #showlogstats B on A.Banco = B.Banco
			WHERE	A.Banco != ''model'' '
	else
		SELECT @stmt = 'SELECT DISTINCT
				BANCO = CONVERT(VARCHAR(' + convert(varchar, @lendb) + '),A.Banco),
				TAMANHO_MB = (SELECT SUM(Total) from #showfilestats_final where Banco = A.Banco),
				LIVRE_MB = (SELECT SUM(Livre) from #showfilestats_final where Banco = A.Banco),
				PERC_OCUP = 100 - CONVERT(DECIMAL(5,2),(SELECT SUM(Livre) from #showfilestats_final where Banco = A.Banco) * 100. / (SELECT SUM(Total) from #showfilestats_final where Banco = A.Banco)),
				TAMANHO_LOG_MB = B.TotalLog,
				LOG_SPACE_USED = B.Utilizado,
				DATA = GETDATE()
			FROM	#showfilestats_final A
				inner join #showlogstats B on A.Banco = B.Banco
			WHERE	A.Banco != ''model'' '
		
	IF @dbname IS NOT NULL
	BEGIN
		SELECT @stmt = @stmt + '
		AND A.Banco like ''' + @dbname + ''' '
	END

	IF NOT @threshold IS NULL
	BEGIN
		if @showfileinfo = 1
			SELECT @stmt = @stmt + '
				AND 100 - CONVERT(DECIMAL(5,2),A.Livre * 100.0 / Total) >= ' + CONVERT(VARCHAR, @threshold)
		else
			SELECT @stmt = @stmt + '
				AND 100 - CONVERT(DECIMAL(5,2),(SELECT SUM(Livre) from #showfilestats_final where Banco = A.Banco) * 100.0 / (SELECT SUM(Total) from #showfilestats_final where Banco = A.Banco)) >= ' + CONVERT(VARCHAR, @threshold)
	END
	
	SELECT @stmt = @stmt + '
			ORDER BY 1,2,3'
			
	set nocount off

	if @tmpTabName is not null
		select @stmt = 'INSERT INTO ' + @tmpTabName + ' ' + @stmt

	if @testonly = 1
	begin
		SELECT @stmt = '
	**** Procedure: sp_dba_getspace *************************************************************
		
	**** Parametros, tipos e valores passados: ****************************************************
			@dbname nvarchar(128) = ' + ISNULL(@dbname, 'NULL') + '
			@threshold decimal(5,2) = ' + ISNULL(convert(varchar(9), @threshold), 'NULL') + '
			@showfileinfo bit = ' + ISNULL(convert(char(1), @showfileinfo), 'NULL') + '
			@testonly bit = ' + ISNULL(convert(char(1), @showfileinfo), 'NULL') + '
			@tmpTabName varchar(128) = ' + ISNULL(@tmpTabName, 'NULL') + '
			
	**** Query realizada: *************************************************************************
		' + @stmt
		print @stmt
	end
		else EXEC(@stmt)
		
	DROP TABLE #showfilestats_final
	DROP TABLE #showlogstats
END
GO

EXEC sys.sp_MS_marksystemobject @objname = N'sp_dba_getspace';
GO
