﻿<#
.SYNOPSIS
    Returns the User name and resource group name used during the WTP application deployment.  
    The values defined here are referenced by the learning module scripts.
#>

function Get-UserConfig {

    $userConfig = @{`
        ResourceGroupName = "<resourcegroup>"     # the resource group used when the WTP application was deployed. CASE SENSITIVE
        Name =              $("<user>".ToLower()) # the User name entered when the WTP application was deployed  
    }



    ##  DO NOT CHANGE VALUES BELOW HERE -------------------------------------------------------------

   
    if ($userConfig.ResourceGroupName -eq "<resourcegroup>" -or $userConfig.Name -eq "<user>")
    {
        throw '$userConfig.ResourceGroupName and $userConfig.Name are not set.  Modify both values in UserConfig.psm1 and try again.'
    }

    return $userConfig

}
