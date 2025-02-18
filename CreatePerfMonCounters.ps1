Param(
    [string]$name = "SQL Server Resource Consumption"
)

$datacollectorset = New-Object -COM Pla.DataCollectorSet
$datacollectorset.DisplayName = $name
$datacollectorset.SubdirectoryFormat = 1
$datacollectorset.SubdirectoryFormatPattern = "yyyyMMdd\-NNNNNN"
$datacollectorset.RootPath = "$env:SystemDrive\PerfLogs\Admin\$name"

$DataCollector = $datacollectorset.DataCollectors.CreateDataCollector(0)
$DataCollector.FileName = $name + "_"
$DataCollector.FileNameFormat = 0x1
$DataCollector.FileNameFormatPattern = "yyyy\-MM\-dd"
$DataCollector.SampleInterval = 15
$DataCollector.LogAppend = $false

# Get all SQL Server instances
$sqlInstances = Get-WmiObject -Class Win32_Service | Where-Object {$_.Name -like "MSSQL*"}

$counters = @()
foreach ($instance in $sqlInstances) {
    $instanceName = $instance.Name.Replace("MSSQLSERVER", "SQLServer")

    $counters += @('\'+$instanceName+':Memory Manager\Target Server Memory (KB)')
    $counters += @('\'+$instanceName+':Memory Manager\Total Server Memory (KB)')
    $counters += @('\'+$instanceName+':Buffer Manager\Buffer cache hit ratio')
    $counters += @('\'+$instanceName+':Buffer Manager\Page life expectancy')
    $counters += @('\'+$instanceName+':Memory Manager\Free Memory (KB)')
    $counters += @('\'+$instanceName+':Memory Manager\Memory Grants Outstanding')
    $counters += @('\'+$instanceName+':Memory Manager\Memory Grants Pending')
}

$counters += @(
    '\Process(sqlservr)\% Processor Time',
    '\Process(sqlservr)\ID Process'
)

if ($sqlInstances.Count -gt 1) {
    for ($i = 1; $i -lt $sqlInstances.Count; $i++) {
        $countAux = '\Process(sqlservr#'+$i+')\% Processor Time'
        $counters += @($countAux.ToString())
        $countAux = '\Process(sqlservr#'+$i+')\ID Process'
        $counters += @($countAux.ToString())
    }
}

# Add non-SQL Server specific counters
$counters += @(
    '\Processor(_Total)\% Processor Time',
    '\LogicalDisk(E:)\Avg. Disk sec/Read',
    '\LogicalDisk(E:)\Avg. Disk sec/Write'
)

$DataCollector.PerformanceCounters = $counters

try {
        $datacollectorset.DataCollectors.Add($DataCollector)
        $datacollectorset.Commit($name, $null, 0x0003) | Out-Null
        $datacollectorset.Start($false)
} catch [Exception] {
        Write-Host "Exception Caught: " $_.Exception -ForegroundColor Red
        return
}
