#v1.3
$cont_var = Get-Content C:\Users\Public\conf.txt

$db_usr = $cont_var[0];
$db_pssw = $cont_var[1];


Function Measure-NetworkSpeed{
    # The test file has to be a 10MB file for the math to work. If you want to change sizes, modify the math to match
    $TestFile  = 'http://speedtest.tele2.net/10MB.zip'
    $TempFile  = Join-Path -Path $env:TEMP -ChildPath 'testfile.tmp'
    $WebClient = New-Object Net.WebClient
    $TimeTaken = Measure-Command { $WebClient.DownloadFile($TestFile,$TempFile) } | Select-Object -ExpandProperty TotalSeconds
    $SpeedMbps = (10 / $TimeTaken) * 8
    $Message = "{0:N2}" -f ($SpeedMbps)
    return $Message
}

Function Mesure-Usage{
    $Processor = (Get-WmiObject -Class win32_processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average | Select-Object Average).Average
    $ComputerMemory = Get-WmiObject -Class win32_operatingsystem -ErrorAction Stop
    $Memory = ((($ComputerMemory.TotalVisibleMemorySize - $ComputerMemory.FreePhysicalMemory)*100)/ $ComputerMemory.TotalVisibleMemorySize) 
    $RoundMemory = [math]::Round($Memory, 2)
    return "{Memory:" + $RoundMemory.ToString() + ",Processor:" + $Processor.ToString() + "}"
}

Function Get-Updates-Status{
    $search = (New-Object -com "Microsoft.Update.AutoUpdate"). Results.LastSearchSuccessDate
    $install = (New-Object -com "Microsoft.Update.AutoUpdate"). Results.LastInstallationSuccessDate
    return "{LastSearchSuccessDate:" + $search + ",LastInstallationSuccessDate:" + $install + "}"
}

[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
$Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
$ConnectionString = "server=172.18.2.45;port=3306;uid=" + $db_usr + ";pwd=" + $db_pssw +";database=it;SslMode=none"
$Connection.ConnectionString = $ConnectionString
$Connection.Open()

Function Get-Actions{
    for ($i = 0; $i -lt 9; $i++) {
        $id_device = 0;
        $Query = "SELECT * FROM devices WHERE serial = '" + $serialnumber + "';"
        $oMYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
        $oMYSQLDataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter
        $oMYSQLDataSet = New-Object System.Data.DataSet 
        $oMYSQLCommand.Connection=$Connection
        $oMYSQLCommand.CommandText= $Query
        $oMYSQLDataAdapter.SelectCommand=$oMYSQLCommand
        $iNumberOfDataSets=$oMYSQLDataAdapter.Fill($oMYSQLDataSet, "data")
        if($iNumberOfDataSets -le 0){
            $env:computername | Select-Object
            $Query = "INSERT INTO devices VALUES (null, '" +  $env:computername + "', '" + $serialnumber + "', '1');";
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
            $DataSet.Tables[0]
            $Query = "SELECT last_insert_id();";
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
            $DataSet.Tables[0]
            foreach($oDataSet in $oMYSQLDataSet.tables[0])
            {
                $id_device = $oDataSet.last_insert_id();
            }
        }else{
            foreach($oDataSet in $oMYSQLDataSet.tables[0])
            {
                $id_device = $oDataSet.iddevices;
            }
        }
        $Query_dv = "SELECT * FROM actions WHERE idDevice = " + $id_device + " AND status = 0;"
        $oMYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
        $oMYSQLDataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter
        $oMYSQLDataSet = New-Object System.Data.DataSet 
        $oMYSQLCommand.Connection=$Connection
        $oMYSQLCommand.CommandText= $Query_dv
        $oMYSQLDataAdapter.SelectCommand=$oMYSQLCommand
        $iNumberOfDataSets=$oMYSQLDataAdapter.Fill($oMYSQLDataSet, "data")

        if($iNumberOfDataSets -gt 0){
            foreach($oDataSet in $oMYSQLDataSet.tables[0])
            {
                $res = &$oDataSet.action;
                $output = "";
                $id_action = $oDataSet.idactions;
                foreach ($line in $res) {
                    $output = $output + $line + ";";
                }
                $Query_rt = "UPDATE actions SET ``return`` = '" + $output + "', executed = '" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") +"', ``status`` = 1 WHERE ``idactions`` = " + $id_action + ";"
                $oMYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
                $oMYSQLDataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter
                $oMYSQLDataSet = New-Object System.Data.DataSet 
                $oMYSQLCommand.Connection=$Connection
                $oMYSQLCommand.CommandText= $Query_rt
                $oMYSQLDataAdapter.SelectCommand=$oMYSQLCommand
                $iNumberOfDataSets=$oMYSQLDataAdapter.Fill($oMYSQLDataSet, "data")
            }
        }

        Start-Sleep -Milliseconds 60000;
    }
}

try{
    $registryPath = "HKLM:\SOFTWARE\WOW6432Node\ThinKiosk\ConnectionInfo"
    $thinscale = Get-ItemProperty -Path $registryPath -Name DeviceName
}catch{
    $registryPath = "HKLM:\SOFTWARE\WOW6432Node\SRW\ConnectionInfo"
    $thinscale = (Get-ItemProperty -Path $registryPath -Name DeviceName)
}
$thinscale = $thinscale.DeviceName

$start_date = Get-Date -Format("yyyy-MM-dd");
$cnt = 0;

while(1){
$res = Measure-NetworkSpeed
$usage = Mesure-Usage
$update = Get-Updates-Status
$env:computername | Select-Object
$ipv4 = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00"}).IPAddress
$date = Get-Date -Format("yyyy-MM-dd HH:mm:ss")
$serialnumber = Get-WmiObject win32_bios | Select-Object SerialNumber
$serialnumber = $serialnumber.SerialNumber

$Query = 'INSERT INTO events VALUES (NULL,"' + $serialnumber + '","' + $ipv4 + '", "' + $env:computername + '", "' + $res + '", "' + $date + '","' + $thinscale + '")'
$Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
$DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
$DataSet = New-Object System.Data.DataSet
$RecordCount = $dataAdapter.Fill($dataSet, "data")
$DataSet.Tables[0]

$Query = 'INSERT INTO events VALUES (NULL,"' + $serialnumber + '","' + $ipv4 + '", "' + $env:computername + '", "' + $usage + '", "' + $date + '","' + $thinscale + '")'
$Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
$DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
$DataSet = New-Object System.Data.DataSet
$RecordCount = $dataAdapter.Fill($dataSet, "data")
$DataSet.Tables[0]

if($cnt -eq 0 -or -not $start_date -eq (Get-Date -Format("yyyy-MM-dd"))){
    $Query = 'INSERT INTO events VALUES (NULL,"' + $serialnumber + '","' + $ipv4 + '", "' + $env:computername + '", "' + $update + '", "' + $date + '","' + $thinscale + '")'
    $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
    $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
    $DataSet = New-Object System.Data.DataSet
    $RecordCount = $dataAdapter.Fill($dataSet, "data")
    $DataSet.Tables[0]
}

$cnt ++

try{
    Remove-Item C:\Users\Public\cnf.cfg
}catch{}
try{
    Remove-Item C:\Users\Public\browsing.txt
}catch{}
New-Item C:\Users\Public\cnf.cfg
$start_date = Get-Date -Format("dd-MM-yyyy HH:mm:ss")
$end_date_st = (Get-Date).AddMinutes(-10)
$end_date = $end_date_st.ToString("dd-MM-yyyy HH:mm:ss")

Add-Content C:\Users\Public\cnf.cfg "[General]"
Add-Content C:\Users\Public\cnf.cfg "ShowGridLines=0"
Add-Content C:\Users\Public\cnf.cfg "SaveFilterIndex=0"
Add-Content C:\Users\Public\cnf.cfg "ShowInfoTip=1"
Add-Content C:\Users\Public\cnf.cfg "ShowTimeInGMT=0"
Add-Content C:\Users\Public\cnf.cfg "VisitTimeFilterType=5"
Add-Content C:\Users\Public\cnf.cfg "VisitTimeFilterValue=10"
Add-Content C:\Users\Public\cnf.cfg "VisitTimeFrom=$end_date"
Add-Content C:\Users\Public\cnf.cfg "VisitTimeTo=$start_date"
Add-Content C:\Users\Public\cnf.cfg "LoadChromeCanary=1"
Add-Content C:\Users\Public\cnf.cfg "LoadSeaMonkey=1"
Add-Content C:\Users\Public\cnf.cfg "LoadOpera=1"
Add-Content C:\Users\Public\cnf.cfg "LoadBrave=1"
Add-Content C:\Users\Public\cnf.cfg "LoadFirefox=1"
Add-Content C:\Users\Public\cnf.cfg "LoadChrome=1"
Add-Content C:\Users\Public\cnf.cfg "LoadIE10=1"
Add-Content C:\Users\Public\cnf.cfg "LoadIE=1"
Add-Content C:\Users\Public\cnf.cfg "LoadSafari=1"
Add-Content C:\Users\Public\cnf.cfg "LoadEdge=1"
Add-Content C:\Users\Public\cnf.cfg "LoadPaleMoon=1"
Add-Content C:\Users\Public\cnf.cfg "LoadYandex=1"
Add-Content C:\Users\Public\cnf.cfg "LoadVivaldi=1"
Add-Content C:\Users\Public\cnf.cfg "LoadWaterfox=1"
Add-Content C:\Users\Public\cnf.cfg "HistorySource=1"
Add-Content C:\Users\Public\cnf.cfg "HistorySourceFolder="
Add-Content C:\Users\Public\cnf.cfg "IEUseAPI=0"
Add-Content C:\Users\Public\cnf.cfg "IncludeURLStr="
Add-Content C:\Users\Public\cnf.cfg "ExcludeURLStr="
Add-Content C:\Users\Public\cnf.cfg "IncludeURL=0"
Add-Content C:\Users\Public\cnf.cfg "ExcludeURL=0"
Add-Content C:\Users\Public\cnf.cfg "MarkOddEvenRows=0"
Add-Content C:\Users\Public\cnf.cfg "ShowAdvancedOptionsOnStart=1"
Add-Content C:\Users\Public\cnf.cfg "SkipDuplicates=0"
Add-Content C:\Users\Public\cnf.cfg "SkipDuplicateSeconds=5"
Add-Content C:\Users\Public\cnf.cfg "CustomFolderAppData="
Add-Content C:\Users\Public\cnf.cfg "CustomFolderIEHistory="
Add-Content C:\Users\Public\cnf.cfg "CustomFolderLocalAppData="
Add-Content C:\Users\Public\cnf.cfg "StopIECacheTask=0"
Add-Content C:\Users\Public\cnf.cfg "SaveFileEncoding=0"
Add-Content C:\Users\Public\cnf.cfg "UseQuickFilter=0"
Add-Content C:\Users\Public\cnf.cfg "QuickFilterString="
Add-Content C:\Users\Public\cnf.cfg "QuickFilterColumnsMode=1"
Add-Content C:\Users\Public\cnf.cfg "QuickFilterFindMode=1"
Add-Content C:\Users\Public\cnf.cfg "QuickFilterShowHide=1"
Add-Content C:\Users\Public\cnf.cfg "CustomFiles.ChromeFiles="
Add-Content C:\Users\Public\cnf.cfg "CustomFiles.IEFolders="
Add-Content C:\Users\Public\cnf.cfg "CustomFiles.IE10Files="
Add-Content C:\Users\Public\cnf.cfg "CustomFiles.FirefoxFiles="
Add-Content C:\Users\Public\cnf.cfg "CustomFiles.SafariFiles="
Add-Content C:\Users\Public\cnf.cfg "ComputerName="
Add-Content C:\Users\Public\cnf.cfg "DoubleClickAction=1"
Add-Content C:\Users\Public\cnf.cfg "VerSplitLoc=16383"
Add-Content C:\Users\Public\cnf.cfg "DisplayQRCode=0"
Add-Content C:\Users\Public\cnf.cfg "WinPos=2C 00 00 00 00 00 00 00 01 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF 3C 02 00 00 F6 00 00 00 DC 07 00 00 ED 03 00 00"
Add-Content C:\Users\Public\cnf.cfg "Columns=96 00 00 00 96 00 01 00 96 00 02 00 96 00 03 00 96 00 04 00 96 00 05 00 6E 00 06 00 96 00 07 00 96 00 08 00 96 00 09 00 50 00 0A 00 50 00 0B 00 18 01 0C 00 64 00 0D 00"
Add-Content C:\Users\Public\cnf.cfg "Sort=0"


& "C:\Users\Public\BrowsingHistoryView.exe" /cfg  C:\Users\Public\cnf.cfg /scomma C:\Users\Public\browsing.txt

Start-Sleep -milliseconds 60000

$sql = "";
$ccn = 0;

$Query = "SELECT * FROM events where thinScale = '" + $thinscale +"' AND date = '" + $date + "';"
$oMYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
$oMYSQLDataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter
$oMYSQLDataSet = New-Object System.Data.DataSet 
$oMYSQLCommand.Connection=$Connection
$oMYSQLCommand.CommandText= $Query
$oMYSQLDataAdapter.SelectCommand=$oMYSQLCommand
$iNumberOfDataSets=$oMYSQLDataAdapter.Fill($oMYSQLDataSet, "data")

$id = "1"

foreach($oDataSet in $oMYSQLDataSet.tables[0])
{
     $id = $oDataSet.idevents;
}

foreach($line in [System.IO.File]::ReadLines("C:\\Users\\Public\\browsing.txt"))
{
    try{
        if($ccn -gt 0){
            $ln = $line.Split(",")
            $sql = "INSERT INTO history VALUES (NULL, " + $id + ", '" + $ln[0] + "','" + $ln[1] + "','" + $ln[2] + "','" + $ln[3] + "','" + $ln[4] + "','" + $ln[5] + "','" + $ln[6] + "','" + $ln[7] + "','" + $ln[8] + "','" + $ln[9] + "','" + $ln[10] + "','" + $ln[11] + "','" + $ln[12] + "','" + $ln[13] + "');"
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
            $DataSet.Tables[0]
        }
        
    }catch{
    }
    $ccn++
}

Get-Actions;
}