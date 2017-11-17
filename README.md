
# DEPRECATED, SEE BELOW FOR REPLACEMENT
An expanded set of sample SaaS applications is now available, replacing the sample in this repo.  

## The Wingtip Tickets SaaS application
The same *Wingtip Tickets* application is implemented in each sample. The app is a simple event listing and ticketing SaaS app targeting small venues - theaters, clubs, etc. Each venue is a tenant of the app, and has their own data: venue details, lists of events, customers, ticket orders, etc.  The app, together with the management scripts and tutorials, showcases an end-to-end SaaS scenario. This includes provisioning tenants, monitoring and managing performance, schema management, and cross-tenant reporting and analytics.

## Three SaaS application patterns
Three vesions of the app are available; each explores a different database tenancy pattern on SQL Database.  The first uses a single-tenant application with an isolated single-tenant database. The second uses a multi-tenant app, with a database per tenant. The third sample uses a multi-tenant app with sharded multi-tenant databases.

![Three patterns](./threepatterns.png)

 Each sample includes management scripts and tutorials that explore a range of design and management patterns you can use in your own application.  Each sample deploys in less that five minutes.  All three can be deployed side-by-side so you can compare the differences in design and management. 

## Standalone application pattern
Uses a single tenant application with a single tenant database for each tenant. Each tenant’s app is deployed into a separate Azure resource group. This could be in the service provider’s subscription or the tenant’s subscription and managed by the provider on the tenant’s behalf. This pattern provides the greatest tenant isolation, but it is typically the most expensive as there is no opportunity to share resources across multiple tenants.

Check out the [tutorials](https://aka.ms/wingtipticketssaas-sa) and code  on GitHub  [.../Microsoft/WingtipTicketsSaaS-StandaloneApp](http://github.com/Microsoft/WingtipTicketsSaaS-StandaloneApp).

## Database-per-tenant pattern
This pattern is effective for service providers that are concerned with tenant isolation and want to run a centralized service that allows cost-efficient use of shared resources. A database is created for each venue, or tenant, and all the databases are centrally managed. Databases can be hosted in elastic pools to provide cost-efficient and easy performance management, which leverages the unpredictable workload patterns of the tenants. A catalog database holds the mapping between tenants and their databases. This mapping is managed using the shard map management features of the Elastic Database Client Library, which  provides efficient connection management to the application.

Check out the [tutorials](https://aka.ms/wingtipticketssaas-dpt) and code  on GitHub  [.../Microsoft/WingtipTicketsSaaS-DbPerTenant](http://github.com/Microsoft/WingtipTicketsSaaS-DbPerTenant).

## Sharded multi-tenant database pattern
Multi-tenant databases are effective for service providers looking for lower cost per tenant and okay with reduced tenant isolation. This model allows packing large numbers of tenants into a single database, driving the cost-per-tenant down. Near infinite scale is possible by sharding the tenants across multiple database.  A catalog database again maps tenants to databases.  

This pattern also allows a hybrid model in which you can optimize for cost with multiple tenants in a database, or optimize for isolation with a single tenant in their own database. The choice can be made on a tenant-by-tenant basis, either when the tenant is provisioned or later, with no impact on the application.

Check out the [tutorials](https://aka.ms/wingtipticketssaas-mt) and code  on GitHub  [.../Microsoft/WingtipTicketsSaaS-MultiTenantDb](http://github.com/Microsoft/WingtipTicketsSaaS-MultiTenantDb).

</br>

# Wingtip SaaS - DEPRECATED

NOW REPLACED BY   [.../Microsoft/WingtipTicketsSaaS-DbPerTenant](http://github.com/Microsoft/WingtipTicketsSaaS-DbPerTenant)

</br>
Sample multi-tenant SaaS application and management scripts built on SQL Database using a database-per-tenant model.

This project provides a sample SaaS application that embodies many common SaaS patterns that can be used with Azure SQL Database.  The sample is based on an event-management and ticket-selling scenario for small venues.  Each venue is a 'tenant' of the SaaS application.  The sample uses a database-per-tenant model, with a database created for each venue.  These databases are hosted in elastic database pools to provide easy performance management, and to cost-effectively accommodate the unpredictable usage patterns of these small venues and their customers.  An additional catalog database holds the mapping between tenants and their databases.  This mapping is managed using the Shard Map Management features of the Elastic Database Client Library.  

The basic application, which includes three pre-defined databases for three venues, can be installed in your Azure subscription under a single ARM resource group.  To uninstall the application, delete the resource group from the Azure Portal. 

NOTE: if you install the application you will be charged for the Azure resources created.  Actual costs incurred are based on your subscription offer type but are nominal if the application is not scaled up unreasonably and is deleted promptly after you have finished exploring the tutorials.

More information about the sample app and the associated tutorials is here: [https://aka.ms/sqldbsaastutorial](https://aka.ms/sqldbsaastutorial)

Also available in the Documentation folder in this repo is an **overview presentation** that provides background, explores alternative database models for multi-tenant apps, and walks through several of the SaaS patterns at a high level. There is also a demo script you can use with the presentation to give others a guided tour of the app and several of the patterns.

To deploy the app to Azure, click the link below.  Deploy the app in a new resource group, and provide a short *user* value that will be appended to several resource names to make them globally unique.  Your initials and a number is a good pattern to use.


<a href="http://aka.ms/deploywtpapp" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


After deployment completes, launch the app by browsing to ```http://events.wtp.USER.trafficmanager.net```, substituting *USER* with the value you set during deployment. 

**IMPORTANT:** If you download and extract the repo or [Learning Modules](https://github.com/Microsoft/WingtipSaaS/tree/master/Learning%20Modules) from a zip file, make sure you unblock the .zip file before extracting. Executable contents (scripts, dlls) may be blocked by Windows when zip files are downloaded from an external source and extracted.

To avoid scripts from being blocked by Windows:

1. Right click the zip file and select **Properties**.
1. On the **General** tab, select **Unblock** and select **OK**.


## License
Microsoft Wingtip SaaS sample application and tutorials are licensed under the MIT license. See the [LICENSE](https://github.com/Microsoft/WingtipSaaS/blob/master/license) file for more details.

# Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
