<#
Collection of useful functions

https://github.com/chrisrowe851/justposhthings

#>

#common root directory for all functions
$rootdir="C:\PoshArmyKnife"
$filesdir
$logsdir


Function Initialize-PoshArmyKnife{
    #creates common local resources needed for functions

    [cmdletbinding(SupportsShouldProcess=$True)]

#
param()

$script:logsdir = New-Item -ItemType Directory -Path "$rootdir\logs" -Force
$script:filesdir = New-Item -ItemType Directory -Path "$rootdir\files" -Force
}

Function Remove-OldSnapshots
{

<#
  .SYNOPSIS
    Delete snapshots older than "x" days from VMs provided in CSV file. Works across multiple vCenters

.DESCRIPTION
    As per synopsis

.PARAMETER Grace
    The number of days grace to give snapshots (eg do not delete snapshots if created within <grace> days)

.PARAMETER CredLabel
    This script uses windows credential manager credentials. You must provide the name/label of the credential you have created and wish to use to connect to all vCenters. There is no support for vCenters with different credentials at this time

.PARAMETER CSVFile
    The location of the csv file containing VM list. Must be formatted with 2 headers [VCENTER] and [VM]

.PARAMETER LogFile
    Location for logfile. It will be cleared on each run

.PARAMETER SnapSuffix
    The suffix used to target snaps on all VMs. Mandatory for safety, avoids deletion of WIP. At snap creation, add the Suffix to the snap name. For example "ExampleSnap-AutoClean".

    If not a requirement, change Mandatory to $false on this param. All snaps will be deleted if no suffix is provided.

.EXAMPLE
    VMWare-DeleteOldSnapshots.ps1 -Grace 2 -CredLabel vCenterAdmin -SnapSuffix AUTOCLEAN
        This will delete all snapshots older than 2 days with the suffix AUTOCLEAN attached to the snapshot name. It will use credentials in windows credential store with Label "vCenterAdmin" to connect to vCenter and complete the task.

.NOTES
    Author: Chris Rowe
    Last Edit: 02/01/2020
    
#>

#add support for -WhatIf (Remove-Snapshot supports WhatIf, so no changes to function needed)
[cmdletbinding(SupportsShouldProcess=$True)]

#
param
(
    [Parameter(Mandatory=$true)] [int32] $Grace, #number of grace days for snapshots
    [Parameter(Mandatory=$true)] [string] $CredLabel, #stored credentials from windows cred store to use
    [string] $csvfile ="$filesdir\Remove-OldSnapshots-VMList.csv", # CSV file where VM list is found, must exist
    [string] $logfile ="$logsdir\Remove-OldSnapshots-Log.txt", # logfile location, will be created if not exist
    [Parameter(Mandatory=$true)] [string] $SnapSuffix
)

#Ensure PAK has been initialized
Initialize-PoshArmyKnife

#Read the CSV File into a variable
$vmlist = Import-Csv $csvfile 

#Get the user's credentials for vCenter from computer credential store
$creds = Get-StoredCredential -Target $CredLabel 

#Get the current date/time and place entry into log that a new session has started
$timestamp = Get-Date 

New-Item $logfile -Force

Add-Content $logfile "#####################################################"

Add-Content $logfile "$timestamp New Session Started"

 
#Read the vCenters contained in the CSV and dedupe them
$vcenters = $vmlist | Select-Object -ExpandProperty vCenter -Unique 

 
#Log into each vCenter included in the CSV file
foreach ($vcenter in $vcenters) 

    {

    $timestamp = Get-Date #Get the current date/time and place entry into log that the script is connecting to each vCenter

    $message = "$timestamp Connecting to $vcenter"

    Write-Host $message

    Add-Content $logfile  $message

    

    Connect-VIServer $vcenter -Credential $creds #Connect to the vCenter using the credentials provided at first run

    

    Write-Host `n

    }

 
#Remove snapshots for each VM in the CSV
foreach ($vm in $vmlist)

    {

    #Load the virtual machine object
    $vm = get-VM -Name $vm.VM 

    #Get the number of snapshots for the VM
    $snapshotcount = $vm | Get-Snapshot | Where-Object {($_.Created -lt (Get-Date).AddDays($grace)) -And ($_.Name -like "*$SnapSuffix")} | Measure-Object 

    #This line makes it easier to insert the number of snapshots into the log file
    $snapshotcount = $snapshotcount.Count 

    
    #Get the current date/time and place entry into log that the script is going to remove x number of shapshots for the VM
    $timestamp = Get-Date 

    $message = "$timestamp Removing $snapshotcount Snapshot(s) for VM $vm"

    Write-Host $message

    Add-Content $logfile  $message

    
    #Snapshot removal happens here
    $vm | Get-Snapshot | Where-Object {($_.Created -lt (Get-Date).AddDays($grace)) -And ($_.Name -like "*$SnapSuffix*")} | Remove-Snapshot -confirm:$false | Out-File $logfile -Append 

    #Get the current date/time and place entry into log that the script has finished removing the VM's snapshot(s)
    $timestamp = Get-Date 

    Add-Content $logfile "$timestamp Snapshots removed for $vm"

    }
}