#Import Wingtip App Tenant Registration dll [required for vOLD only] 
Add-Type -Path $PSScriptRoot\WingtipApp_TenantRegistration.dll

<#
.SYNOPSIS
    Returns an integer tenant key from a normalized tenant name for use in the catalog.
#>
function Get-TenantKey
{
    param
    (
        # Tenant name 
        [parameter(Mandatory=$true)]
        [String]$TenantName
    )

    $TenantName = $TenantName.Replace(' ', '').ToLower()

    # Return Knuth hash of tenant name 
    [Type]$TenantInitialization = [WingtipApp_TenantRegistration.TenantRegistration]

    return $TenantInitialization::GetTenantId($TenantName)
}

<#
.SYNOPSIS
    Returns default configuration values that will be used by the Wingtip tickets application
#>
function Get-Configuration
{
    $configuration = @{`
        DeployByCopy = $true
        TemplatesLocationUrl = "https://wtpdeploystorageaccount.blob.core.windows.net/templates"
        TenantDatabaseTemplate = "tenantdatabasetemplate.json"
        TenantDatabaseCopyTemplate = "tenantdatabasecopytemplate.json"
        TenantDatabaseBatchTemplate = "tenantdatabasebatchtemplate.json"
        TenantDatabaseCopyBatchTemplate = "tenantdatabasecopybatchtemplate.json"
        WebApplicationTemplate = "webapplicationtemplate.json"
        LogAnalyticsWorkspaceTemplate = "loganalyticsworkspacetemplate.json"
        LogAnalyticsWorkspaceNameStem = "wtploganalytics-"
        LogAnalyticsDeploymentLocation = "westcentralus"
        DatabaseAndBacpacTemplate = "databaseandbacpactemplate.json"
        TenantBacpacUrl = "https://wtpdeploystorageaccount.blob.core.windows.net/wingtip-bacpacsvold/wingtiptenantdb.bacpac"
        GoldenTenantDatabaseName = "baseTenantDB"
        CatalogDatabaseName = "customercatalog"
        CatalogServerNameStem = "catalog-"
        TenantServerNameStem = "customers1-"
        TenantPoolNameStem = "Pool"
        CatalogShardMapName = "customercatalog"
        CatalogAdminUserName = "developer"
        CatalogAdminPassword = "P@ssword1"
        TenantAdminUsername = "developer"
        TenantAdminPassword = "P@ssword1"
        CatalogManagementAppNameStem = "catalogmanagement-"
        CatalogManagementAppSku = "standard"
        CatalogManagementAppSkuCode = "S1"
        CatalogManagementAppWorkerSize = 0
        CatalogSyncWebJobNameStem = "catalogsync-"
        AutoProvisionWebJobNameStem = "autoprovision-"
        ServicePrincipalPassword = "P@ssword1"
        JobAccount = "jobaccount"
        JobAccountDatabaseName = "jobaccount"
        TenantAnalyticsDatabaseName = "tenantanalytics"
        AdhocAnalyticsDatabaseName = "adhocanalytics"
        AdhocAnalyticsDatabaseServiceObjective = "S0"
        AdhocAnalyticsBacpacUrl = "https://wtpdeploystorageaccount.blob.core.windows.net/wingtip-bacpacsvold/adhoctenantanalytics.bacpac"
        StorageKeyType = "SharedAccessKey"
        StorageAccessKey = (ConvertTo-SecureString -String "?" -AsPlainText -Force)
        DefaultVenueType = "MultiPurposeVenue"
        TenantNameBatch = @(
            ("Poplar Dance Academy","DanceStudio"),
            ("Blue Oak Jazz Club","BluesClub"),
            ("Juniper Jammers Jazz","JazzClub"),
            ("Sycamore Symphony","ClassicalConcertHall"),
            ("Hornbeam HipHop","DanceStudio"),
            ("Mahogany Soccer","SoccerClub"),
            ("Lime Tree Track","MotorRacing"),
            ("Balsam Blues Club","BluesClub"),
            ("Tamarind Studio","DanceStudio"),
            ("Star Anise Judo", "JudoClub"),
            ("Cottonwood Concert Hall","ClassicalConcertHall"),
            ("Mangrove Soccer Club","SoccerClub"),
            ("Foxtail Rock","RockMusicVenue"),
            ("Osage Opera","Opera"),
            ("Papaya Players","SoccerClub"),
            ("Magnolia Motor Racing","MotorRacing"),
            ("Sorrel Soccer","SoccerClub")       
            )
        }
    return $configuration
}
