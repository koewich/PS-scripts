# This script works as a CMD tool for a Support Engineers
# to find a certain document in the database and then find the mentioning
# of that document in the log files

$creds = Get-Credential
$serverName = ''
$dbCentral = ''

$outPath = ''


function Search-GrDc2s {
    param (
        $Asn
    )
    $queryGln = "SELECT [ReceipientGLN] FROM [...].[dbo].[EdiMessage] where afsasnnumber =  '" + $Asn + "'"
    $gln = Invoke-Sqlcmd -ServerInstance $serverName -Database $dbCentral -Credential $creds -Query $queryGln
    if ($gln -eq $null) {
        Write-Warning "ASN $Asn was not found in the central database! Please check if ASN is correct"
        $ProblemAsns.Add($Asn)
        continue
    }
    Write-Host "Store GLN is" $gln.ReceipientGLN
    $storeFull = "..." + $gln.ReceipientGLN + "..."
    $storeShort = "..." + $gln.ReceipientGLN + "..."

    $queryGrNumber = "SELECT TOP 1 Name, CONVERT(varchar, TimeStampCreated, 23) Date FROM [...].[dbo].[Group] where DeliveryNumber = '" + $Asn + "' and GroupType = '1011'"
    try {
        return Invoke-Sqlcmd -hostname $storeFull -ServerInstance $storeShort -Query $queryGrNumber -ErrorAction Stop
    }
    catch {
        Write-Warning "Something happened while trying to reach receipient store! Please check if store database is accessible"
        $ProblemAsns.Add($Asn)
        return
    }
}

function Search-GrS2s {
    param (
        $Asn
    )
    $SenderGln = $Asn.Substring(0,4)
    $SenderStoreFull = "..." + $SenderGln + "..."
    $SenderStoreShort = "..." + $SenderGln + "..."
    $QueryReceipientGln = "SELECT [DestinationNumber] FROM [...].[dbo].[rtOutboundByAsn] where groupname = '$Asn' and Culture = 'en-Us'"
    try {
        $ReceipientGln = Invoke-SqlCmd -HostName $SenderStoreFull -ServerInstance $SenderStoreShort -Query $QueryReceipientGln -ErrorAction Stop
    }
    catch {
        Write-Warning "Something happened while trying to reach sender store! Please check if ASN number is correct."
        $ProblemAsns.Add($Asn)
        return
    }
    
    $ReceipientStoreFull = "..." + $ReceipientGln.DestinationNumber + "..."
    $ReceipientStoreShort = "..." + $ReceipientGln.DestinationNumber + "..."
    $QueryGrNumber = "SELECT TOP 1 Name, CONVERT(varchar, TimeStampCreated, 23) Date FROM [...].[dbo].[Group] where DeliveryNumber = '" + $Asn + "' and GroupType = '1011'"
    try {
        return Invoke-Sqlcmd -HostName $ReceipientStoreFull -ServerInstance $ReceipientStoreShort -Query $QueryGrNumber -ErrorAction Stop
    }
    catch {
        Write-Warning "Something happened while trying to reach receipient store! Please check if store database is accessible"
        $ProblemAsns.Add($Asn)
        return
    }
}

function Search-Log {
    param (
        $Path
    )
    Write-Host "Searching in $Path"
    $scriptBlock = {
        param ($Path, $Pattern)
        $result = Select-String -Path $Path -Pattern $Pattern -Context 0, 1
        $idx = $result.line.indexOf("Items`":[")
        $line = $result.line.substring(0, $idx + 8) + "...TRUNCATED..." + "`n"
        return $line + $result.Context.PostContext + "`n"
    }
    $output = Invoke-Command -ComputerName "..." -ScriptBlock $scriptBlock -ArgumentList $Path, $grNumber.Name
    $label = "ASN $asn - GR " + $grNumber.Name
    Out-File -FilePath $outPath -InputObject $label -Append
    Out-File -FilePath $outPath -InputObject $output -Append
}

$Input = Read-Host "Enter ASN or multiple ASNs separated by space"
$Asns = $Input -Split ' '

$ProblemAsns = New-Object System.Collections.Generic.List[System.Object]

$Counter = 0

foreach ($Asn in $Asns) {
    
    $Counter++
    Write-Progress -Activity "Searching GR" -CurrentOperation "Looking for $Asn" -PercentComplete (($Counter / $Asns.Count) * 100)

    Write-Host "Searching for $Asn"
    if ($Asn -match "^\d+$") {
        $grNumber = Search-GrDc2s -Asn $Asn
    }
    elseif ($Asn -match "^C+...") {
        $grNumber = Search-GrS2s -Asn $Asn
    }
    else {
        Write-Warning "Incorrect input!"
        return
    }

    if ($grNumber -eq $null) {
        Write-Warning "GR for ASN $Asn was not found! Please check the logs in the store"
        if (-not ($ProblemAsns -contains $Asn)) {
            $ProblemAsns.Add($Asn)
        }
        continue
    }

    if ($grNumber.Date -eq (Get-Date -Format "yyyy-MM-dd")) {
        $Path = "..."
        Search-Log -Path $Path
    }
    else {
        $Path = "..."
        Search-Log -Path $Path
    }
}

if ($ProblemAsns.Count -ne 0) {
    Write-Warning "There were some some issues with the following ASNs: $ProblemAsns"  
}
