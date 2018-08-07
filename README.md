# API Conversion Automation Using WSDL

This powershell script will read in local soap endpoint files and import them into Azure's APIM using WSDL.

## Getting Started

Create an APIM in Azure if one does not already exist for this API to be located in.

Prepare a csv file that contains the following information in order for the script to run correctly. The required fields are ProfilePath, SubscriptionID, SubscriptionKey, ServiceName, ResourceGroupName, InitialFilePath, Policies

ProfilePath
	- Path to the file that contains the information needed to log into Azure
SubscriptionID
	- SubscriptionID of the subscription the API is under. This can be found under "Subscriptions" in "All Services"
SubscriptionKey
	- Subscription key that provides access to the API
ServiceName
	- The name of the APIM service
ResourceGroupName
	- The name of the resource group that the APIM service is under
InitialFilePath
	- The path where the SOAP endpoint files are located
Policies
	- A string representation of the policies that will be changed in the API
	
Change $configPath to the location the configuration file will be stored and change $fileName to the name of the configuration file.

## Authors

* **Jennifer Tsan** - *Initial work*



