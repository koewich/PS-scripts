# This script works as a scheduled task.
# It checks the shovels of RabbitMQ service on all of machines
# and restarts RabbitMQ service if the shovel is not working

$startTime = (Get-Date)

$rabbitCreds = Import-Clixml "$PSScriptRoot\rabbitCreds.xml"

$dbCreds = Import-Clixml "$PSScriptRoot\dbCreds.xml"
$centralServerName = ''
$dbCentral = ''

$queryGlns = "SELECT GLN FROM [...].[dbo].[Site] WHERE GLN LIKE 'C%' AND RFIDLive = 1"
$storesList = (Invoke-Sqlcmd -ServerInstance $centralServerName -Database $dbCentral -Credential $dbCreds -Query $queryGlns).ItemArray

$checkedStores = 0

$storesWithFailedShovels = @()

foreach ($store in $storesList) {

    $shovelsUrl = 'https://...' + $store + '...'
    try {
        $result = Invoke-RestMethod -Uri $shovelsUrl -Cred $rabbitCreds -TimeoutSec 10
    } catch {
        Continue
    }

    foreach ($el in $result) {
        if ($el.state -ne 'running') {

            $storesWithFailedShovels += $store
            $computer = "..." + $store + "..."
            Get-Service -ComputerName $computer -Name RabbitMQ | Restart-Service
            break
        }
    }

    $checkedStores++
}


$endTime = (Get-Date)

$payload = @"
{
	"@type": "MessageCard",
	"@context": "https://schema.org/extensions",
	"summary": "Shovels check",
	"themeColor": "0078D7",
	"title": "Shovels Check",
	"sections": [
		{
			"facts": [
				{
					"name": "Start Time:",
					"value": "$startTime"
				},
				{
					"name": "End Time",
					"value": "$endTime"
				},
				{
					"name": "Checked stores:",
					"value": "$checkedStores"
				},
				{
					"name": "RabbitMQ restarted in:",
					"value": "$storesWithFailedShovels"
				}
			]
		
		}
	]
}
"@

$webhook = ''
Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $payload -Uri $webhook
