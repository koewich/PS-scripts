# This script allows you to query all of the databases from Azure Elastic pool
# and get the output on the screen

# Specify Azure Elastic pool url
$pool = ''

$creds = Get-Credential

# Get the list of all databases in the pool
$queryDatabases = "SELECT Name FROM sys.databases WHERE Name LIKE '' ORDER BY Name"
$databaseList = (Invoke-Sqlcmd -Query $queryDatabases -ServerInstance $Pool -Database 'master' -Credential $creds).Name

# Edit the query you need to execute for each database
$query = "SELECT [StringValue] FROM [dbo].[ServiceSettings] where PropertyName = 'Service.ActualStoreNumber'"

foreach ($db in $databaseList) {
    Write-Host "Executing in $db"
    $result = (Invoke-Sqlcmd -Query $query -ServerInstance $pool -Database $db -Credential $creds).ItemArray
    Write-Host $result
}
