[cmdletbinding()]

<#
 .SYNOPSIS
    Deploys an database for Ad-hoc query analytics

 .DESCRIPTION
    Deploys an an Operational Analytics database into which results from ad-hoc and scheduled queries for the 
    WTP applications will be collected .

 .PARAMETER WtpResourceGroupName
    The name of the resource group in which the WTP application is deployed.

 .PARAMETER WtpUser
    # The 'User' value entered during the deployment of the WTP application.
#>
param(
    [Parameter(Mandatory=$True)]
    [string] $WtpResourceGroupName,

    [Parameter(Mandatory=$True)]
    [string] $WtpUser
 )

Import-Module $PSScriptRoot\..\Common\SubscriptionManagement -Force
Import-Module $PSScriptRoot\..\Common\CatalogAndDatabaseManagement -Force
Import-Module $PSScriptRoot\..\WtpConfig -Force

$ErrorActionPreference = "Stop" 

$config = Get-Configuration

# Get Azure credentials if not already logged on. 
Initialize-Subscription

# Check resource group exists
$resourceGroup = Get-AzureRmResourceGroup -Name $WtpResourceGroupName -ErrorAction SilentlyContinue

if(!$resourceGroup)
{
    throw "Resource group '$WtpResourceGroupName' does not exist.  Exiting..."
}

$catalogServerName = $config.CatalogServerNameStem + $WtpUser
$fullyQualfiedCatalogServerName = $catalogServerName + ".database.windows.net"
$searchDatabaseName = $config.SearchDatabaseName

# Check if Search database has already been created 
$searchDB = Get-AzureRmSqlDatabase `
                -ResourceGroupName $WtpResourceGroupName `
                -ServerName $catalogServerName `
                -DatabaseName $searchDatabaseName `
                -ErrorAction SilentlyContinue

if($searchDB)
{
    Write-Output "Search database '$searchDatabaseName' already exists."
    exit
}

Write-output "Deploying database '$searchDatabaseName' on server '$catalogServerName'..."

# Deploy head database for search to index 
New-AzureRmSqlDatabase `
        -ResourceGroupName $WtpResourceGroupName `
        -ServerName $catalogServerName `
        -DatabaseName $searchDatabaseName `
        -RequestedServiceObjectiveName $config.SearchDatabaseServiceObjective `
        > $null
#>

$commandText = "
    CREATE MASTER KEY;
    GO

    CREATE DATABASE SCOPED CREDENTIAL [SearchDBCred]
        WITH IDENTITY = N'$($config.CatalogAdminUserName)', SECRET = N'$($config.CatalogAdminPassword)';
    GO

    CREATE EXTERNAL DATA SOURCE [WtpTenantDBs]
        WITH (
        TYPE = SHARD_MAP_MANAGER,
        LOCATION = N'$fullyQualfiedCatalogServerName',
        DATABASE_NAME = N'$($config.CatalogDatabaseName)',
        SHARD_MAP_NAME = N'$($config.CatalogShardMapName)',
        CREDENTIAL = [SearchDBCred]
        );
    GO

    SET ANSI_NULLS ON;

    SET QUOTED_IDENTIFIER OFF;
    GO

    CREATE EXTERNAL TABLE [dbo].[VenueEvents] (
        [VenueId] INT NOT NULL,
        [EventId] INT NOT NULL,
        [EventName] NVARCHAR (50) NOT NULL,
        [Subtitle] NVARCHAR (50) NULL,
        [Date] DATETIME NOT NULL
    )
        WITH (
        DATA_SOURCE = [WtpTenantDBs],
        DISTRIBUTION = ROUND_ROBIN
        );
    GO

    SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
    GO

    SET ANSI_NULLS ON;

    SET QUOTED_IDENTIFIER OFF;
    GO

    GO
    CREATE EXTERNAL TABLE [dbo].[Venues] (
        [Server] NVARCHAR(128),
        [VenueId] INT NOT NULL,
        [VenueName] NVARCHAR (50) NOT NULL,
        [VenueType] CHAR (30) NOT NULL,
        [AdminEmail] VARCHAR (50) NOT NULL,
        [PostalCode] CHAR (10) NULL,
        [CountryCode] CHAR (3) NOT NULL
    )
        WITH (
        DATA_SOURCE = [WtpTenantDBs],
        DISTRIBUTION = ROUND_ROBIN
        );
    GO

    CREATE TABLE [dbo].[VenueTypes]
    (
        [VenueType]                 CHAR(30) NOT NULL,
	    [VenueTypeName]             NCHAR(30) NOT NULL,  
        [EventTypeName]             NVARCHAR(30) NOT NULL, 
	    [EventTypeShortName]        NVARCHAR(20) NOT NULL,
	    [EventTypeShortNamePlural]  NVARCHAR(20) NOT NULL,
        [Language]                  CHAR(8) NOT NULL,
        PRIMARY KEY CLUSTERED ([VenueType] ASC)
    )
    GO

    CREATE UNIQUE INDEX IX_VENUETYPES_VENUETYPE ON [dbo].[VenueTypes] ([VenueType])
    GO

    CREATE UNIQUE INDEX IX_VENUETYPES_VENUETYPENAME_LANGUAGE ON [dbo].[VenueTypes] ([VenueTypeName], [Language])
    GO

    INSERT INTO [dbo].[VenueTypes]
        ([VenueType],[VenueTypeName],[EventTypeName],[EventTypeShortName],[EventTypeShortNamePlural],[Language])
    VALUES
        ('multipurpose','Multi-Purpose','Event', 'Event','Events','en-us'),
        ('classicalmusic','Classical Music ','Classical Concert','Concert','Concerts','en-us'),
        ('jazz','Jazz','Jazz Session','Session','Sessions','en-us'),
        ('judo','Judo','Judo Tournament','Tournament','Tournaments','en-us'),
        ('soccer','Soccer','Soccer Match', 'Match','Matches','en-us'),
        ('motorracing','Motor Racing','Car Race', 'Race','Races','en-us'),
        ('dance', 'Dance', 'Performance', 'Performance', 'Performances','en-us'),
        ('blues', 'Blues', 'Blues Session', 'Session','Sessions','en-us' ),
        ('rockmusic','Rock Music','Rock Concert','Concert', 'Concerts','en-us'),
        ('opera','Opera','Opera','Opera','Operas','en-us');      
    GO

    PRINT N'Update complete.';
    GO
    "
    Write-output "Initializing schema in '$searchDatabaseName'..."

    Invoke-Sqlcmd `
    -ServerInstance $fullyQualfiedCatalogServerName `
    -Username $config.CatalogAdminUserName `
    -Password $config.CatalogAdminPassword `
    -Database $searchDatabaseName `
    -Query $commandText `
    -ConnectionTimeout 30 `
    -QueryTimeout 30 `
    -EncryptConnection

Write-Output "`nDeployment of database '$searchDatabaseName' complete."
