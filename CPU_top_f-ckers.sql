-- Script by Valmir da Spring
--PRINT @@SERVERNAME


DECLARE @DB_ID INT --= DB_ID(); -- BANCO ATUAL. PARA EXIBIR TODOS OS BANCOS, MUDE PARA NULL
DECLARE @SESSION_ID INT = NULL

SELECT TOP 20
    REPLICATE('▒', [DER].[cpu_time] /10000)
    ,[DES].[Session_Id]
    ,[DES].[Status]
    ,[DES].[Login_Name]
    ,[DES].[Host_Name]
    ,[DER].[Blocking_Session_Id]
    ,DB_NAME([DES].[Database_Id]) As [database_Name]
    ,SUBSTRING([DEST].[Text], [DER].[Statement_Start_Offset]/2, (CASE WHEN [DER].[Statement_End_Offset] = -1 THEN DATALENGTH([Dest].[Text]) ELSE [Der].[Statement_End_Offset] END-[Der].[Statement_Start_Offset])/2) AS [Executing Statement]
    ---- Descomentar para exigir o execution plan
    , [DEQP].[Query_Plan]
    ,[DER].[Command]
    ,COALESCE([DER].[Reads],0) + [DES].[Reads] [Reads]  
    ,COALESCE([DER].[Logical_Reads],0) + [DES].[Logical_Reads] [Logical_Reads]
    ,COALESCE([DER].[Writes],0) + [DES].[Writes] [Writes]
    ,[DEC].[Last_Write]
    ,[DEC].[Connections_count]
    ,[TASK].[thread_count]
    ,CASE 
        WHEN [program_name] LIKE 'SQLAgent - TSQL JobStep%'
            THEN COALESCE((
                    SELECT 'JOB: ' + name
                    FROM [MSDB].[dbo].[sysjobs]
                    WHERE [job_id] = CAST(SUBSTRING([program_name], 32 + 06, 2) + SUBSTRING([program_name], 32 + 04, 2) + SUBSTRING([program_name], 32 + 02, 2) + SUBSTRING([program_name], 32 + 00, 2) + '-' + SUBSTRING([program_name], 32 + 10, 2) + SUBSTRING([program_name], 32 + 08, 2) + '-' + SUBSTRING([program_name], 32 + 14, 2) + SUBSTRING([program_name], 32 + 12, 2) + '-' + SUBSTRING([program_name], 32 + 16, 4) + '-' + SUBSTRING([program_name], 32 + 20, 12) AS UNIQUEIDENTIFIER)
                    ),[program_name])
        WHEN [program_name] IS NULL 
            THEN 'Unknown'
        ELSE [program_name]
     END [program_name]
    ,[DER].[Wait_Type]
    ,FORMAT(DATEADD(MILLISECOND, [wait_time], '1900-01-01'), N'HH:mm:ss.fff') [wait_time]
    ,[DES].[cpu_time]
    ,[DER].[cpu_time] [Request_cpu_time]
    ,[DER].[Last_Wait_Type]
    ,[DER].[Wait_Resource]
    ,CASE [Des].[Transaction_Isolation_Level] WHEN 0 THEN 'Unspecified' WHEN 1 THEN 'ReadUncommitted' WHEN 2 THEN 'ReadCommitted' WHEN 3 THEN 'Repeatable' WHEN 4 THEN 'Serializable' WHEN 5 THEN 'Snapshot' END AS [Transaction_Isolation_Level]
    ,OBJECT_NAME([DEST].[Objectid], [DER].[Database_Id]) AS OBJECT_NAME
    ,[DEST].[Objectid], [DER].[Database_Id]
    ,[T].[transaction_id]
    ,[T].[transaction_begin_time] 
    ,[DES].[open_transaction_count]
    ,[DES].[last_request_end_time]
    ,[DES].[last_request_start_time]
    ,[DES].[login_time]
    --, CAST(COALESCE([TS].[user_objects_alloc_page_count],0) + [SS].[user_objects_alloc_page_count] / 128 AS DECIMAL(15, 2)) [Total Allocation User Objects MB] 
    --, CAST(COALESCE([TS].[user_objects_alloc_page_count],0) + [SS].[user_objects_dealloc_page_count] / 128 AS DECIMAL(15, 2)) [Deallocation User Objects MB] 
    --, CAST(COALESCE([TS].[user_objects_alloc_page_count],0) + [SS].[internal_objects_alloc_page_count] / 128 AS DECIMAL(15, 2)) [Total Allocation Internal Objects MB] 
    --, CAST(COALESCE([TS].[user_objects_alloc_page_count],0) + [SS].[internal_objects_dealloc_page_count] / 128 AS DECIMAL(15,2)) [Deallocation Internal Objects MB] 
    , CAST((COALESCE([TS].[user_objects_alloc_page_count] + [TS].[internal_objects_alloc_page_count] ,0)  +  ([SS].[user_objects_alloc_page_count] + [SS].[internal_objects_alloc_page_count] )) / 128 AS DECIMAL(15, 2)) [Total Allocation MB] 
    , CAST((COALESCE([TS].[user_objects_dealloc_page_count] + [TS].[internal_objects_dealloc_page_count] ,0)  +  ([SS].[user_objects_dealloc_page_count] + [SS].[internal_objects_dealloc_page_count] )) / 128 AS DECIMAL(15, 2)) [Total Deallocation MB] 
FROM [Sys].[Dm_Exec_Sessions] [DES]
LEFT JOIN [Sys].[Dm_Exec_Requests] [DER] ON [DES].[Session_Id] = [DER].[Session_Id]
OUTER APPLY 
(
    SELECT MAX([DEC].[last_write]) [last_write], COUNT(*) AS [Connections_count]
    FROM [Sys].[Dm_Exec_Connections] [DEC] 
    WHERE [DES].[Session_Id] = [DEC].[Session_Id]
) [DEC]
OUTER APPLY
(
    SELECT  COUNT([osThreads].[os_thread_id]) [thread_count]
    FROM [sys].[dm_os_tasks] AS [osTask]
    LEFT JOIN [sys].[dm_os_threads] AS [osThreads]
    ON [osTask].[worker_address] = [osThreads].[worker_address]
    WHERE [osTask].[session_id] = [DES].[session_id]
) [TASK]
LEFT JOIN [sys].[dm_tran_active_transactions] [T] 
    ON [T].[transaction_id] = [DER].[transaction_id]
LEFT JOIN [sys].[dm_db_session_space_usage] [SS]
    ON [DES].[session_id] = [SS].[session_id]
LEFT JOIN [sys].[dm_db_task_space_usage] [TS]
    ON [DER].[request_id] = [TS].[request_id]
            AND DER.[session_id] = [TS].[session_id]
OUTER APPLY [Sys].[Dm_Exec_Sql_Text]([DER].[Sql_Handle]) [DEST]
-- Descomentar para exiBir o execution plan
OUTER APPLY [Sys].[Dm_Exec_Query_Plan]([DER].[Plan_Handle]) [DEQP]
WHERE [DES].[session_id] <> @@SPID 
      AND ([DES].[session_id] = @SESSION_ID OR @SESSION_ID IS NULL)
      -- SÓ O BANCO ATUAL 
      AND ([DES].[Database_Id] = @DB_ID OR @DB_ID IS NULL) 
      -- APENAS SESSÕES QUE NÃO SÃO DO SGDB
      AND [DES].[Session_Id] > 50  
      -- FILTRAR PELO PROGRAMA
      --AND PROGRAM_NAME LIKE '%MiddlewareIntegration%'
      -- APENAS SESSÕES ATIVAS 
      AND ([DES].[Status] != 'sleeping' or [DES].[open_transaction_count] > 0)
ORDER BY --[DES].[session_id]
     [DER].[cpu_time] 
    --[PROGRAM_NAME]
    --transaction_begin_time
    --login_time
DESC;


