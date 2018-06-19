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
    $serviceName = $fileContent.ServiceName
    $resourceGroupName = $fileContent.ResourceGroupName
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

        $swaggerFile = $fileContent.ExportFilePath + $apiPath + ".swagger"

        # Get the swagger file for the API endpoint for testing later
        Export-AzureRmApiManagementApi -Context $context -ApiId $apiId -SpecificationFormat Swagger -SaveAs $swaggerFile

        # for each operation in the newly imported API, delete unnecessary operations, and test the operations
        foreach($operation in $operationsArray) {
            $operationId = $operation.OperationId
            $operationName = $operation.Name

            # Remove any operations that aren't needed (Ping, SessionStart, SessionEnd)
            If ($operationName -eq "Ping" -or $operationName -eq "SessionStart" -or $operationName -eq "SessionEnd") {
                Remove-AzureRmApiManagementOperation -Context $context -ApiId $apiId -OperationId $operationId
                Write-Host "Removed " $operationName " operation`n" -ForegroundColor Green
            } Else {
                # Check each operation to see if it gets a 200 ok
                $operationURL = $fileContent.APIPathBegining + $apiPath + $fileContent.APIPathMiddle + $operationName
                $method = "POST"
                $headers = @{"Ocp-Apim-Subscription-Key"= $subscriptionKey}
                $headers.Add("Content-Type", "application/json")
                $headers.Add("Ocp-Apim-Trace", "true")

                # This gets the policies in the inbound and outbound, could parse it and sub in variables in the request body
                $policy = Get-AzureRmApiManagementPolicy -Context $context -ApiId $apiId -OperationId $operationId -Format "json"

                #get the swagger for each endpoint (outside of the current loop), look at definitions and check each operation to see if it matches the current operation, if it matches, save it to the body (may have to format it first)
                #look at the yaml definitions
                $requestBody = extractRequestBodyExample -operation $operationName -file $swaggerFile

                $resp = Invoke-WebRequest -Uri $operationURL -Headers $headers -Body $requestBody -Credential $fileContent.Credential # This works, just need to find a way to customize the body for each

                "Status code: " + $resp.StatusCode # This works, just need to complete Invoke-Webrequest
                "Status description: " + $resp.StatusDescription # This works, just need to complete Invoke-Webrequest

                Write-Host "Operation " $operation.Name ": Complete`n" -ForegroundColor Green
            }
        }
        
        Write-Host "API ("$apiId "): Complete`n`n" -ForegroundColor Green
    }

    Write-Host "All processes Complete" -ForegroundColor Green
}

function extractRequestBodyExample {
    param([string]$operation, [string]$file)
    
    $foundOp = 0
    $foundExample = 0
    $trimmedExample = ""
    $final = ""
    $line = ""

    Get-Content $file | ForEach-Object {
        #run through, find matching operation, mark foundOp boolean to true, then start looking for the example right after that operation, mark foundEx to true, save the substring of the request body and exit loop
        $line = $_

        if($line -like ('*' + $operation + 'Request":*') -and -Not $foundOp) {
            $foundOp = 1
        }
        if($foundOp -and $line -like ('*"example":*') -and -Not $foundExample) {
            $foundExample = 1
            #after a the example is found, format it so it can be sent in a request
            $trimmedExample = $line.Trim()
            $length = $trimmedExample.Length
            $endOfSubstring = $length- 1 - 12
            $sub = $trimmedExample.Substring(12, $endOfSubstring)
            $noNewLines = $sub.Replace("\r\n", "")
            $noSlash = $noNewLines.Replace("\", "")
            $noColon = $noSlash.Replace(":", "=")
            $noComma = $noColon.Replace(",", "")
            $final = $noComma.Replace("sample", "00000000-0000-0000-0000-000000000000")
            return $final
            break
        }
    }
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
<<<<<<< HEAD

mainFunction
=======
>>>>>>> d4e204ede4da9ac4d24e8d535a71b7d354d36f5d
