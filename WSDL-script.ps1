mainFunction

function mainFunction {
    #read config file
    $configPath = "C:\Users\jennifer.tsan\Documents"
    $fileName ="\WSDLConfig.csv"
    $fullPath = $configPath + $fileName
    $fileContent = Import-Csv $fullPath
    
    #login to azure first if necessary
    $profilePath = $fileContent.ProfilePath
    $subscriptionName = "REx"
    login -profilepath $profilePath -subscriptionname $subscriptionName #try to prompt user for file
    
    # Set $DebugPreference to "Continue" for more information when getting errors. Set it to "SilentlyContinue" to hide those details
    $DebugPreference="SilentlyContinue"

    #Azure specific details
    $subscriptionId = $fileContent.SubscriptionID
    $subscriptionKey = $fileContent.SubscriptionKey

    # Api Management service specific details
    $serviceName = $fileContent.ServiceName #"jentsan"
    $resourceGroupName = $fileContent.ResourceGroupName #"interns"
    $productId = "unlimited"

    # Set the context to the subscription Id where the cluster will be created
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
    Write-Host "Set the context to the subscription Id`n" -ForegroundColor Green

    # Create the API Management context
    $context = New-AzureRmApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $serviceName
    Write-Host "Created the API Management Context`n" -ForegroundColor Green

    # The path where the files will be found
    $Path = $fileContent.InitialFilePath

    $wsdlFiles = Get-ChildItem -Path $Path

    # Iterate through all SOAP endpoints and import them
    foreach($wsdlFile in $wsdlFiles) {
        $completePath = $Path + $wsdlFile
        Write-Host "Current file: " $completePath "`n" -ForegroundColor Green

        #get the wsdlServiceName and wsdlEndpointName from the file
        $xml = [xml](Get-Content $completePath)
        $xml.Load($completePath)

        $xmlString = [string]$xml.InnerXml

        #get the wsdlEndpointName
        $portBeginningString = "wsdl:port name=`""
        $portEndingString ="`" binding=`"tns:"
        $wsdlEndpointName = extractSubstring -beginningstring $portBeginningString -endingstring $portEndingString -last 0
        Write-Host "Extracted wsdl Endpoint name`n" -ForegroundColor Green
         
        #get the wsdlServiceName
        $serviceBeginningString = "wsdl:service name=`""
        $serviceEndingString = "`"><wsdl:documentation xmlns"
        $wsdlServiceName = extractSubstring -beginningstring $serviceBeginningString -endingstring $serviceEndingString -last 1
        Write-Host "Extracted wsdl Service name`n" -ForegroundColor Green

        # Api Specific Details
        $apiPath = $wsdlServiceName

        # import API from Path
        $api = Import-AzureRmApiManagementApi -Context $context -SpecificationFormat Wsdl -SpecificationPath $completePath -Path $apiPath -WsdlServiceName $wsdlServiceName -WsdlEndpointName $wsdlEndpointName -ApiType Http
        Write-Host "Imported API from File`n" -ForegroundColor Green
        $apiId = $api.ApiId

        # Add the API to the published Product, so that it can be called in developer portal console
        Add-AzureRmApiManagementApiToProduct -Context $context -ProductId $productId -ApiId $apiId
        Write-Host "Added API to published Product`n" -ForegroundColor Green

        # Get necessary info for the policy string
        # Info for rewriteUri Template
        $rewriteBeginning = $fileContent.RewriteBeginning
        $rewriteEnding = "soap.asmx"
        $rewriteUriTemplate = extractSubstring -beginningstring $rewriteBeginning -endingstring $rewriteEnding -last 0
        $rewriteUriTemplate = $rewriteUriTemplate + $rewriteEnding

        # Get all APIM operations
        $operationsArray = Get-AzureRmApiManagementOperation -Context $context -ApiId $apiId

        # for each operation in the newly imported API, delete unnecessary operations, and test the operations
        foreach($operation in $operationsArray) {
            $operationId = $operation.OperationId

            # Remove any operations that aren't needed (Ping, SessionStart, SessionEnd)
            If ($operation.Name -eq "Ping" -or $operation.Name -eq "SessionStart" -or $operation.Name -eq "SessionEnd") {
                Remove-AzureRmApiManagementOperation -Context $context -ApiId $apiId -OperationId $operationId
                Write-Host "Removed " $operation.Name " operation`n" -ForegroundColor Green
            } Else {
                # Check each operation to see if it gets a 200 ok
                $operationURL = $fileContent.APIPathBegining + $apiPath + $fileContent.APIPathMiddle + $operation.Name
                $method = "POST"
                $headers = @{"Ocp-Apim-Subscription-Key"= $subscriptionKey}
                $headers.Add("Content-Type", "application/json")
                $headers.Add("Ocp-Apim-Trace", "true")

                # This gets the policies in the inbound and outbound, could parse it and sub in variables in the request body
                $policy = Get-AzureRmApiManagementPolicy -Context $context -ApiId $apiId -OperationId $operationId -Format "json"

                Write-Host "Operation " $operation.Name ": Complete`n" -ForegroundColor Green
            }
        }
        
        Write-Host "API ("$apiId "): Complete`n`n" -ForegroundColor Green
    }

    Write-Host "All processes Complete" -ForegroundColor Green
}

function extractSubstring {
    param([string]$beginningString, [string]$endingString, [boolean]$last)

    $startIndex = $xmlString.IndexOf($beginningString)
    If ($last) {
        $endIndex = $xmlString.LastIndexOf($endingString) #this is just a hack, hopefully it will work for all files
    }
    Else {
        $endIndex = $xmlString.IndexOf($endingString)
    }

    $startIndex = $startIndex + $beginningString.Length
    $lengthOfSubstring = $endIndex-$startIndex

    If ($xmlString.Contains($beginningString) -and $xmlString.Contains($endingString)) {
        return $xmlString.Substring($startIndex, $lengthOfSubstring)
    }
}

function login {
    param([string]$profilePath, [string]$subscriptionName)
    #most of this is from https://stackoverflow.com/questions/28105095/how-to-detect-if-azure-powershell-session-has-expired
    $needLogin = $true
    
    Import-AzureRmContext -Path $profilePath | Out-Null
    Write-Host "Successfully logged in using saved profile file" -ForegroundColor Green
         
    Get-AzureRmSubscription –SubscriptionName $subscriptionName | Select-AzureRmSubscription  | Out-Null
    Write-Host "Set Azure Subscription for session complete`n"  -ForegroundColor Green
    
}