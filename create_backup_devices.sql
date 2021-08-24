USE [master]
GO

/*
DECLARE @stmt NVARCHAR(MAX) = N'';

SELECT @stmt += CONCAT(
	'EXEC [master].dbo.sp_addumpdevice @devtype = N''', [type_desc], '''',
	', @logicalname = N''', [name], '''',
	', @physicalname = N''', physical_name, '''', ';', CHAR(13), CHAR(10)
)
FROM sys.backup_devices;

PRINT @stmt;
*/

EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'TSQL', @physicalname = N'C:\MSSQL\Samples\Databases\TSQL.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2008R2', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2008R2-Full Database Backup.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2012', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2012.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2014', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2014.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2016', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2016.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2016_EXT', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2016_EXT.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2017', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2017.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorksDW2017', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorksDW2017.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorks2019', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorks2019.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'StackOverflow2010', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\StackOverflow2010.bak';
EXEC [master].dbo.sp_addumpdevice @devtype = N'DISK', @logicalname = N'AdventureWorksLT2017', @physicalname = N'C:\MSSQL\Samples\Databases\AdventureWorks\AdventureWorksLT2017.bak';
GO
