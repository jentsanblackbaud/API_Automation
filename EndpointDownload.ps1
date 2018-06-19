#read in the config file to figure out which soap endpoints to download, there may be multiple will have to loop through

#read config file
$configPath = "C:\Users\jennifer.tsan\Documents"
$fileName ="\EndpointDownloadConfig.csv"
$fullPath = $configPath + $fileName
$fileContent = Import-Csv $fullPath

foreach ($endpoint in $fileContent) {
    #get endpoint name, get location (5 possible locations)
    $endpointName = $endpoint.EndpointName.ToLower() -replace '\s',''
    $endpointLocation = $endpoint.EndpointLocation.ToUpper() -replace '\s',''
    $credential = $endpoint.Credential
    $outputPath = $endpoint.SaveLocation

    If($endpointLocation -like "*creates*") {
        $endpointLocation = "recordadds"
    } ElseIf ($endpointLocation -like "*updates*") {
        $endpointLocation = "recordedits"
    } ElseIf ($endpointLocation -like "*operations*" -or $endpointLocation -like "*deletes*") {
        $endpointLocation = "recordoperations"
    } ElseIf ($endpointLocation -like "*searches*") {
        $endpointLocation = "searchlists"
    }

    #get location to save file
    $saveLocation = $endpoint.SaveLocation

    $url = "http://bbcrm.eastus.cloudapp.azure.com/bbappfx/vpp/bizops/db[BBINFINITY]/" + $endpointLocation + "/" + $endpointName + "/soap.asmx?WSDL"

    [string]$outputPath = $outputPath + "\" + $endpointName + ".swagger"

    Write-Host "Saved: " $outputPath "`n" -ForegroundColor Green

    Invoke-WebRequest -Uri $url -outFile $outputPath -Credential $credential
}


