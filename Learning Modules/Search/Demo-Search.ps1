# Helper script for deploying and using Azure Search in the context of WTP

$DemoScenario = 1
<# Select the demo scenario that will be run. It is recommended you run the scenarios below in order. 
     Demo   Scenario
      0       None
      1       Deploy the single database that will be crawled by Azure Search 
#>

## ------------------------------------------------------------------------------------------------

Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

# Get the resource group and user names used when the WTP application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

### Default state - enter a valid demo scenaro 
if ($DemoScenario -eq 0)
{
    Write-Output "Please modify the demo script to select a scenario to run."
    exit
}


### Deploy the search database that will be crawled by Azure Search
if ($DemoScenario -eq 1)
{
    & $PSScriptRoot\Deploy-SearchDB.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name
    exit
}


Write-Output "Invalid scenario selected"