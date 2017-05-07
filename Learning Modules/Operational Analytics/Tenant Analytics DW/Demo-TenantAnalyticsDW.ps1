# Helper script for demonstrating tenant analytics scripts -deploys the Tenant Analytics database to the catalog server

Import-Module "$PSScriptRoot\..\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\..\UserConfig" -Force
Import-Module "$PSScriptRoot\..\..\WtpConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

# Get the resource group and user names used when the WTP application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig
$config = Get-Configuration

# Enter the fully-qualified name of an existing analytics server and data warehouse if they are already created
$AnalyticsServerName = "<Existing Analytics Server>"
$AnalyticsDataWarehouseName = "<Existing Analytics DataWarehouse>"

$DemoScenario = 0
<# Select the demo scenario that will be run. It is recommended you run the scenarios below in order. 
     Demo   Scenario
      0       None
      1       Purchase tickets for events at all venues
      2       Deploy operational tenant analytics DW database 
      3       Deploy job account database
      4       Create job to copy tenant data to data warehouse for analysis
#>

## ------------------------------------------------------------------------------------------------

### Default state - enter a valid demo scenaro 
if ($DemoScenario -eq 0)
{
    Write-Output "Please modify the demo script to select a scenario to run."
    exit
}

### Purchase new tickets 
if ($DemoScenario -eq 1)
{
    Write-Output "Running ticket generator ..."

    & $PSScriptRoot\..\..\Utilities\TicketGenerator2.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name
    exit
}

### Provision a DW database for operational tenant analytics results
if ($DemoScenario -eq 2)
{
    & $PSScriptRoot\Deploy-TenantAnalyticsDW.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name
    exit
}

### Provision a database and a job account to manage ETL jobs
if ($DemoScenario -eq 3)
{
    & $PSSciptRoot\..\..\Schema Management\Deploy-JobAccount.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name
    exit
}

### Start elastic job to copy tenant data from tenant database into DataWarehouse for analysis
if ($DemoScenario -eq 4)
{
    # Retrieve Wingtip default analytics server and data warehouse if no existing analytics server/datawarehouse have been provided
    if ($AnalyticsServerName -eq "<Existing Analytics Server>" -or $AnalyticsDataWarehouseName -eq "<Existing Analytics DataWarehouse>")
    {
        $AnalyticsServerName = $config.catalogServerNameStem
        $AnalyticsDataWarehouseName = $config.TenantAnalyticsDWDatabaseName
    }

    & $PSScriptRoot\Copy-TenantDataToDataWarehouse.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name `
        -JobExecutionCredentialName $config.JobAccountCredentialName `
        -OutputServer $AnalyticsServerName `
        -OutputDataWarehouse $AnalyticsDataWarehouseName `
        -OutputServerCredentialName $config.JobAccountCredentialName
    exit
}
