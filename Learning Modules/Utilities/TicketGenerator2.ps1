﻿<#
.Synopsis
	Simulates customer ticket purchases for events in Wingtip SaaS tenant databases 
.DESCRIPTION
	Adds customers and creates tickets for events in tenant (venue) databases. Does not 
    create tickets for the last event in each database to allow this to be deleted to 
    demonstrate point-in-time restore.
#>

[CmdletBinding()]
Param
(
	# Resource Group Name entered during deployment 
	[Parameter(Mandatory=$true)]
	[String]
	$WtpResourceGroupName,

	# The user name used entered during deployment
	[Parameter(Mandatory=$true)]
	[String]
	$WtpUser,

	# The baseline sales % for an event - approx % of tickets to be sold
	[Parameter(Mandatory=$false)]
    [int]$salesPercent = 80,

    # The variation (+/-) % for ticket sales, gives impression that there is variation in interest in events
	[Parameter(Mandatory=$false)]
    [int]$salesPercentVariation = 20

)
Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement"
Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force

$ErrorActionPreference = "Stop"

$config = Get-Configuration

$catalog = Get-Catalog -ResourceGroupName $WtpResourceGroupName -WtpUser $WtpUser

## Functions

function Get-CurvedSalesForDay 
{
    param 
    (
    [object] $Curve,

    #[range 1..60]
    [int] $Day

    )
        
    if ($Day -eq 1)
    {
        return $Curve.$Day
    } 
    if ($Day -le 5)
    {
        return ($Curve.5 / 4) 
    }   
    elseif($Day -le 10)
    {
        return ($Curve.10 / 5)
    }     
    elseif($Day -le 15)
    {
        return ($Curve.10 / 5)
    }
    elseif($Day -le 20)
    {
        return ($Curve.20 / 5)
    }
    elseif($Day -le 25)
    {
        return ($Curve.25 / 5)
    }


}

## MAIN SCRIPT ## ----------------------------------------------------------------------------

# Ensure logged in to Azure
Initialize-Subscription

$AdminUserName = $config.TenantAdminUsername
$AdminPassword = $config.TenantAdminPassword

$ServerName = $config.TenantServerNameStem + $WtpUser.ToLower()
  
<# uncomment to generate tickets for the golden databases   
$WtpResourceGroupName = "wingtip-gold"
$ServerName = "wingtip-customers-gold"
#>

$FullyQualifiedServerName = $ServerName + ".database.windows.net" 

# load fictitious customer names, postal codes, event sales curves
$fictitiousNames = Import-Csv -Path ("$PSScriptRoot\FictitiousNames.csv") -Header ("Id","FirstName","LastName","Language","Gender")
$fictitiousNames = {$fictitiousNames}.Invoke()
$customerCount = $fictitiousNames.Count
$postalCodes = Import-Csv -Path ("$PSScriptRoot\SeattleZonedPostalCodes.csv") -Header ("Zone","PostalCode")
$curves = Import-Csv -Path ("$PSScriptRoot\WtpSalesCurves1.csv") #-Header ("Curve","1", "5","10","15","20","25","30","35","40","45","50","55","60") 

# set up SQl script for creating fictious customers, same people will be used for all venues and events
$customersSql  = "
    DELETE FROM [dbo].[Tickets]
    DELETE FROM [dbo].[TicketPurchases]
    DELETE FROM [dbo].[Customers]
    SET IDENTITY_INSERT [dbo].[Customers] ON 
    INSERT INTO [dbo].[Customers] 
    ([CustomerId],[FirstName],[LastName],[Email],[PostalCode],[CountryCode]) 
    VALUES `n"

# all customers are located in the US
$CountryCode = 'USA'
$CustomerId = 0
while ($fictitiousNames.Count -gt 0) 
{
    # get a name at random then remove from the list
    if ($fictitiousNames.Count -gt 1)
    {
        $index = Get-Random -Minimum 0  -Maximum ($fictitiousNames.Count - 1)
    }
    else
    {
        $index = 0
    }

    $name = $fictitiousNames[$index]
    $fictitiousNames.Remove($name) > $null

    $firstName = $name.FirstName.Replace("'","").Trim()
    $lastName = $name.LastName.Replace("'","").Trim()
    
    # form the customers email address
    $alias = ($firstName + "." + $lastName).ToLower()

    if($alias.Length -gt 38) { $alias = $alias.Substring(0,38) }

    # oh, look, they all use outlook as their email provider...
    $email = $alias + "@outlook.com"

    # randomly assign a postal code
    $postalCode = ($postalCodes[(Get-Random -Minimum 0 -Maximum ($postalCodes.Count - 1))]).PostalCode

    $customerId ++

    $customersSql += "      ($customerId,'$firstName','$lastName','$email','$postalCode','$CountryCode'),`n"

}

$customersSql = $customersSql.TrimEnd(("`n",","," ")) + ";`nSET IDENTITY_INSERT [dbo].[Customers] OFF"

# Get all the venue databases in the catalog
$venues = Get-Shards -ShardMap $catalog.ShardMap

$totalTicketPurchases = 0
$totalTickets = 0

# load characteristics of known venues from config

foreach ($venue in $venues)
{
    # add customers to the venue
    $results = Invoke-SqlAzureWithRetry `
                -Username "$AdminUserName" -Password "$AdminPassword" `
                -ServerInstance $venue.Location.Server `
                -Database $venue.Location.Database `
                -Query $customersSql 

    # reset ticket purchase identity
    $ticketPurchaseId = 1

    # reset SQL insert batch counters for tickets and ticket purchases
    $tBatch = 1
    $tpBatch = 1
    
    # iitialize SQL batches for tickets and ticket purchases
    $ticketSql += "INSERT INTO [dbo].[Tickets] ([RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n"
    $ticketPurchaseSql = `
       "SET IDENTITY_INSERT [dbo].[TicketPurchases] ON
        INSERT INTO [dbo].[TicketPurchases] ([TicketPurchaseId],[CustomerId],[PurchaseDate],[PurchaseTotal]) VALUES`n" 

    # get venue characteristics (popularity) or assign

    # set probability for sales curves for this venue

    # set relative popularity of sections from config or assign  

    # get total number of seats
    $command = "SELECT SUM(SeatRows * SeatsPerRow) AS TotalSeats FROM Sections"        
    $totalSeats = Invoke-SqlAzureWithRetry `
                -Username "$AdminUserName" -Password "$AdminPassword" `
                -ServerInstance $venue.Location.Server `
                -Database $venue.Location.Database `
                -Query $command

    # get events for this venue
    $command = "SELECT EventId, EventName, Date FROM [dbo].[Events]"        
    $events = Invoke-SqlAzureWithRetry `
                -Username "$AdminUserName" -Password "$AdminPassword" `
                -ServerInstance $venue.Location.Server `
                -Database $venue.Location.Database `
                -Query $command 

    foreach ($event in $events) 
    {
        # get seating sections and prices for this event
        $command = "
            SELECT s.SectionId, s.SectionName, SeatRows, SeatsPerRow, es.Price
            FROM [dbo].[EventSections] AS es
            INNER JOIN [dbo].[Sections] AS s ON s.SectionId = es.SectionId
            WHERE es.EventId = $($event.EventId)"
        $sections = @()
        $sections += Invoke-SqlAzureWithRetry `
                    -Username "$AdminUserName" -Password "$AdminPassword" `
                    -ServerInstance $venue.Location.Server `
                    -Database $venue.Location.Database `
                    -Query $command

        # process sections to create array of seats
        $seating = @{}
        $sectionNumber = 1
        foreach ($section in $sections)
        {
            $sectionSeating = @()
            $sectionSeating = {$sectionSeating}.Invoke()

            for ($row = 1;$row -le $section.SeatRows;$row++)
            {
                for ($seatNumber = 1;$seatNumber -le $section.SeatsPerRow;$seatNumber++)
                {
                    # create the seat and assign its price
                    $seat = New-Object psobject -Property @{
                                SectionId = $section.SectionId
                                Row = $row
                                SeatNumber = $seatNumber
                                Price = $section.Price
                                }
 
                    $sectionSeating += $seat 
                   
                }
            }           

            $seating += @{$sectionNumber = $sectionSeating} 
            $sectionNumber ++
        }            

        ## set event characteristics

        # set event popularity (likelihood of sellout) 

        # assign a sales curve for this event from the set associated with this venue
        $curve = $curves[0]

        # set the tickets to be sold based on event popularity and relative popularity of sections

        # ticket sales start date as (event date - 60)
        $ticketStart = $event.Date

        # loop over 60 day sales period          
        for($day = 1; $day -le 60 ; $day++)  
        {
            $purchaseDate = $ticketStart.AddDays($day-1)

            # find the number of tickets to purchase today based on the curved percent for the day
            [int]$percentSalesThisDay = Get-CurvedSalesForDay -Curve $curve -Day $day
            [int]$ticketsToPurchase = $percentSalesThisDay * $totalSeats.TotalSeats / 100
            
            # buy tickets
            $ticketsPurchased = 0            
            while ($ticketsPurchased -le $ticketsToPurchase)
            {
                # pick customer at random
                $customerId = Get-Random -Minimum 1 -Maximum $customerCount  
                
                # determine number of tickets customer wants to purchase (1-6 per person)
                $ticketOrder = Get-Random -Minimum 1 -Maximum 6
                
                $PurchaseTotal = 0
                    
                # pick seats based on remaining available seats, relative popularity of sections 
                
                $seatingAssigned = $false
                
                while ($seatingAssigned -eq $false)
                {
                    # select seating section (could extend here to bias by section popularity)
                    if ($sections.Count -eq 1)
                    {
                        $preferredSectionSeating = $seating.1
                    }
                    else
                    {
                        $preferredSectionSeating = $seating.(Get-Random -Minimum 1 -Maximum ($sections.Count))
                    }

                    #determine if seats available or try another section
                    if ($preferredSectionSeating.Count -ge $ticketOrder)
                    {
                        #assign seats
                        for ($s = 1;$s -le $ticketOrder; $s++)
                        {
                            # add ticket to tickets batch
                            $purchasedSeat = $preferredSectionSeating[$s]

                            $mins = Get-Random -Maximum 1440 -Minimum 0
                            $purchaseDate = $purchaseDate.AddMinutes(-$mins)

                            $PurchaseTotal += $purchasedSeat.Price

                            if($tBatch -ge 1000)
                            {
                                # finalize current INSERT and start new INSERT statements
                                
                                
                                $ticketSql = $ticketSql.TrimEnd((" ",",","`n")) + ";`n`n"
                     
                                $ticketSql += "INSERT INTO [dbo].[Tickets] ([RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n"
                            
                                $tBatch = 0
                            }

                            $ticketSql += "($($purchasedSeat.Row),$($purchasedSeat.SeatNumber),$($event.EventId),$($section.SectionId),$ticketPurchaseId)"

                            # remove seat from set of available seats
                            $preferredSectionSeating.Remove($purchasedSeat) 
                        }
                        
                        $seatingAssigned = $true

                        $ticketPurchaseSql += "($ticketPurchaseId,$CustomerId,$purchaseDate,$PurchaseTotal)"

                        $ticketPurchaseId ++

                    }
                    
                }

                # add ticket sales details to batch of tickets to be generated

                $totalTicketPurchases ++
                $totalTickets += $ticketsPurchased


            }                                   

        }

    }

}

Write-Output "$totalTicketPurchases TicketPurchases total"
Write-Output "$totalTickets Tickets total"



    # Initialize SQL command variables for ticket generation
                                                
    $command = "SELECT SectionName FROM [dbo].[Sections]"        
    $Sections = Invoke-Sqlcmd `
                    -Username "$AdminUserName" -Password "$AdminPassword" `
                    -ServerInstance $db.Location.Server `
                    -Database $db.Location.Database `
                    -Query $command `
                    -ConnectionTimeout 30 -QueryTimeout 30 -EncryptConnection `
                    -ErrorAction Stop

    $command = "SELECT EventName FROM [dbo].[Events]"        
    $Events = Invoke-Sqlcmd `
                -Username "$AdminUserName" -Password "$AdminPassword" `
                -ServerInstance $db.Location.Server `
                -Database $db.Location.Database `
                -Query $command `
                -ConnectionTimeout 30 -QueryTimeout 30 -EncryptConnection       

    # for ticket purchases (TODO VERIFY AND THEN REMOVE COMMENTED)
    $tpCommand = `
        "SET IDENTITY_INSERT [dbo].[TicketPurchases] ON
        INSERT INTO [dbo].[TicketPurchases] ([TicketPurchaseId],[CustomerId],[PurchaseDate],[PurchaseTotal]) VALUES`n" 
        
    # TicketPurchaseId 
    $tpId = 1

    # for tickets
    $tCommand = "INSERT INTO [dbo].[Tickets] ([RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n" 

    # counter for batches of values included in an INSERT statement
    $iValues = 1 
         
    # set the tickets sales % for this db, based on the sales % and sales % variation
    $venueSalesPercentVariation = (Get-Random -Maximum $salesPercentVariation -Minimum 0)
    if ((Get-Random -Maximum 10 -Minimum 0) -gt 5) 
    {
            $venueSalesPercent = $SalesPercent + $venueSalesPercentVariation
             
            if ($venueSalesPercent -gt 100) 
            {
                $venueSalesPercent = 100
            }
    }
    else
    {
        $venueSalesPercent = $SalesPercent - $venueSalesPercentVariation
    }
         
    # initialize Tickets, TicketPurchases and Customers tables and then insert customers

    $command = "`
        DELETE FROM [dbo].[Tickets]
        DELETE FROM [dbo].[TicketPurchases]
        DELETE FROM [dbo].[Customers]
        SET IDENTITY_INSERT [dbo].[Customers] ON 
        INSERT INTO [dbo].[Customers] 
            ([CustomerId],[FirstName],[LastName],[Email],[PostalCode],[CountryCode]) 
            VALUES `n     "

    $i = 1

    # Extend here to provide varied postal codes, countries for customers 
    $PostalCode = "98052"
    $CountryCode = "USA"

    foreach($fName in $fictiousNames)
    {        
        $email = ($fName.FirstName + "." + $fName.LastName + "@outlook.com").ToLower()

        $command += "($i,'$($fName.FirstName)','$($fName.LastName)','$email','$PostalCode','$CountryCode'),`n     "

        $i++       
    }

    $command = $command.TrimEnd(("`n",","," ")) + ";`nSET IDENTITY_INSERT [dbo].[Customers] OFF"

    $customersExec = Invoke-Sqlcmd -Username "$AdminUserName" -Password "$AdminPassword" -ServerInstance $fullyQualifiedServerName -Database $db.DatabaseName -Query $command -ConnectionTimeout 30 -QueryTimeout 30 -EncryptConnection
        
    # get the event sections and seating capacity for all events in this venue except the last one 
    $command = "`
        DECLARE @eventCount int
        SET @eventCount = (SELECT count(*) FROM events) - 1
        SELECT e.EventId,e.Date as EventDate, es.SectionId,s.SeatRows,s.SeatsPerRow,es.Price 
            FROM dbo.eventsections AS es 
            INNER JOIN dbo.sections AS s ON es.SectionId = s.SectionId 
            INNER JOIN dbo.Events as e ON e.EventId = es.EventId
            WHERE e.EventId in
                (SELECT top (@EventCount) EventId FROM dbo.Events ORDER BY Date)"
        
    $eventSections = Invoke-Sqlcmd -Username "$AdminUserName" -Password "$AdminPassword" -ServerInstance $fullyQualifiedServerName -Database $db.DatabaseName -Query $command -ConnectionTimeout 30 -QueryTimeout 30 -EncryptConnection

    if ($eventSections)
    {
        foreach($eventSection in $eventSections)
        {
            # for all rows and then for some (randomly selected) seats per row, create ticket purchases for randomly selected customers            

            for ($iRow=1; $iRow -le $eventSection.SeatRows; $iRow++)
            {
                for($iSeat=1; $iSeat -le $eventSection.SeatsPerRow; $iSeat++)
                {
                    $seatRandomizer = Get-Random -Maximum 100 -Minimum 0

                    if($seatRandomizer -le $venueSalesPercent)
                    {
                        # buy a ticket for this seat, otherwise, try next seat...  
                        # each ticket is bought 1 per ticket purchase
                        # pick a purchase date
                        
                        # determine if event is in the future
                        if ($eventSection.EventDate.ToUniversalTime() -gt (Get-Date).ToUniversalTime())
                        {
                            # if so calculate offset in days plus margin
                            $offset = ($eventSection.EventDate.ToUniversalTime() - (Get-Date).ToUniversalTime()).Days + 1
                        }
                        
                        If ($offset -le 1) {$offset = 1}

                        # set ticket purchase date to a point between today and 90 days prior to the event 
                        $days = Get-Random -Maximum 90 -Minimum $offset
                        $purchaseDate = $eventSection.EventDate.AddDays(-$days)

                        # randomize the purchase time                        
                        $mins = Get-Random -Maximum 1440 -Minimum 0
                        $purchaseDate = $purchaseDate.AddMinutes(-$mins)

                        # pick the customer at random
                        $randomCustomer = Get-Random -Maximum $fictiousNames.Count -Minimum 1

                        if($iValues -ge 1000)
                        {
                            # finalize current INSERT and start new INSERT statements
                                
                            $tpCommand = $tpCommand.TrimEnd((" ",",","`n")) + ";`n`n"                               

                            #$tpCommand += "SET IDENTITY_INSERT [dbo].[TicketPurchases] OFF `n`nSET IDENTITY_INSERT [dbo].[TicketPurchases] ON `n"

                            $tpCommand += "INSERT INTO [dbo].[TicketPurchases] ([TicketPurchaseId],[CustomerId],[PurchaseDate],[PurchaseTotal]) VALUES`n" 
                                
                            $tCommand = $tCommand.TrimEnd((" ",",","`n")) + ";`n`n"
                     
                            $tCommand += "INSERT INTO [dbo].[Tickets] ([RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n"  

                            
                            $iValues = 0
                        }

                        # add the ticket purchase to the values being inserted
                        $tpCommand += "    ($tpId,$randomCustomer,'$purchaseDate',$($eventSection.Price)),`n"
                        
                        # add the ticket to the values being inserted
                        $tCommand += "    ($iRow,$iSeat,$($eventSection.EventId),$($eventSection.SectionId),$tpId),`n"

                        $iValues ++

                        $tpId ++

                    }                                       
                }                
            }
        }
       
        # Finalize the commands and execute

        Write-Output "Adding $tpId TicketPurchases for $($db.DatabaseName)" 
        
        $tpCommand = $tpCommand.TrimEnd((" ",",","`n")) + ";"

        #$tpCommand += "SET IDENTITY_INSERT [dbo].[TicketPurchases] OFF"

        $ticketPurchasesExec = Invoke-Sqlcmd `
            -Username "$AdminUserName" `
            -Password "$AdminPassword" `
            -ServerInstance $fullyQualifiedServerName `
            -Database $db.DatabaseName `
            -Query $tpCommand `
            -ConnectionTimeout 30 `
            -QueryTimeout 120 `
            -EncryptConnection

        Write-Output "Adding $tpId Tickets for $($db.DatabaseName)" 
               
        $tCommand = $tCommand.TrimEnd((" ",",","`n")) + ";"

        $ticketsExec = Invoke-Sqlcmd `
            -Username "$AdminUserName" `
            -Password "$AdminPassword" `
            -ServerInstance $fullyQualifiedServerName `
            -Database $db.DatabaseName `
            -Query $tCommand `
            -ConnectionTimeout 30 `
            -QueryTimeout 120 `
            -EncryptConnection

        $totalTicketPurchases += $tpId
        $totalTickets += $tpId 
    }       
    else
    {
        Write-Output "No events exist in $($db.DatabaseName)"
    }

