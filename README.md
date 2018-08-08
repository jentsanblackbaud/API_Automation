# API Conversion Automation Using WSDL

This powershell script will read in local soap endpoint files and import them into Azure's APIM using WSDL.

## Getting Started

Create an APIM in Azure if one does not already exist for this API to be located in.

Install the Azure Powershell Modules. Instructions can be found [here](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-6.6.0).

Download your Azure profile so Powershell can log you into Azure. Instructions can be found [here](https://blogs.technet.microsoft.com/dataplatform/2016/11/16/set-your-powershell-session-to-automatically-log-into-azure/).

Download all desired SOAP endpoints in WSDL format into a local folder.

Prepare a csv file that contains the following information in order for the script to run correctly. The required fields are ProfilePath, SubscriptionID, SubscriptionKey, ServiceName, ResourceGroupName, InitialFilePath, Policies

*ProfilePath: Path to the file that contains the information needed to log into Azure
	
*SubscriptionID: SubscriptionID of the subscription the API is under. This can be found under "Subscriptions" in "All Services"
	
*SubscriptionKey: Subscription key that provides access to the API
	
*ServiceName: The name of the APIM service
	
*ResourceGroupName: The name of the resource group that the APIM service is under
	
*InitialFilePath: The path where the SOAP endpoint WSDL files are located
	
*Policies: A string representation of the policies that will be changed in the API
	
Change $configPath to the location the configuration file will be stored and change $fileName to the name of the configuration file.

Note: the script currently does not allow the customization of endpoint names and Azure's APIM automatically uses the name of the service. Therefore, the script will  only import the endpoints correctly if there are not any endpoints in the APIM with the same name as the service it is using.

## Authors

* **Jennifer Tsan** - *Initial work*



