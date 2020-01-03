<#
Collection of useful functions

https://github.com/chrisrowe851/justposhthings

Requires PSFramework module installed

#>

Function Remove-OldSnapshotsPAK
{

<#
  .SYNOPSIS
    Delete snapshots older than "x" days from VMs provided in CSV file. Works across multiple vCenters

.DESCRIPTION
    You must provide either vCenter name or CSV file, but not both. If vCenter name is used all VMs attached to that vCenter will be targeted

.PARAMETER Grace
    The number of days grace to give snapshots (eg do not delete snapshots if created within <grace> days)

.PARAMETER CredLabel
    This function uses windows credential manager credentials. You must provide the name/label of the credential you have created and wish to use to connect to all vCenters. There is no support for vCenters with different credentials at this time

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
    [Parameter(Mandatory=$false)] $csvfile, # CSV file where VM list is found, must exist
    [Parameter(Mandatory=$false)] $vcenter, #If no CSV is provided, a vCenter must be specified
    [Parameter(Mandatory=$true)] [string] $SnapSuffix #Suffix that is attached to snapshots for deletion

)

#test that parameters are correct
if ((($csvfile) -eq $null) -and ($vcenter -eq $null)){
    Write-Error -Message "CSV file or vCenter must be provided"
    Throw
}
if(($csvfile -ne $null) -and ($vcenter -ne $null)){
    Write-Error -Message "If both CSV file and vCenter are specified, vCenter name in CSV will be used"
    Throw
}

#Get the user's credentials for vCenter from computer credential store
$creds = Get-StoredCredential -Target $CredLabel 

#Load all VMs or Read the CSV File into an array
If ($csvfile) {
    $vmlist = Import-Csv $csvfile 
    #Read the vCenters contained in the CSV and dedupe them
    $vcenters = $vmlist | Select-Object -ExpandProperty vCenter -Unique -ErrorAction Stop 
    $vmlist = $vmlist | Select-Object -ExpandProperty VM -Unique -ErrorAction Stop
    #Log into each vCenter included in the CSV file
    foreach ($vcenter in $vcenters) {
    Write-PSFMessage -Level Output -Message "Connecting to $vcenter"
    Connect-VIServer -Server $vcenter -Credential $creds -ErrorAction Stop #Connect to the vCenter using the credentials provided at first run
    }
}
else {
    Connect-VIServer -Server $vcenter -Credential $creds -ErrorAction Stop
    $vmlist=Get-VM | Select-Object -ExpandProperty Name
    }

Write-PSFMessage -Level Output -Message "New Session Started"



 
#Remove snapshots for each VM
foreach ($vmname in $vmlist){
    $vm=Get-VM -Name $vmname
    #Get the number of snapshots for the VM
    $snapshotcount = Get-Snapshot -VM $vm | Where-Object {($_.Created -lt (Get-Date).AddDays($grace)) -And ($_.Name -like "*$SnapSuffix")} | Measure-Object 
    #This line makes it easier to insert the number of snapshots into the log file
    $snapshotcount = $snapshotcount.Count 
    #Get the current date/time and place entry into log that the script is going to remove x number of shapshots for the VM
    Write-PSFMessage -Level Output -Message "Removing $snapshotcount Snapshot(s) for VM $vm"
    
    #Snapshot removal happens here
    Get-Snapshot -VM $vm | Where-Object {($_.Created -lt (Get-Date).AddDays($grace)) -And ($_.Name -like "*$SnapSuffix*")} | Remove-Snapshot -confirm:$false
    }
}

Function Write-XmlToScreenPAK ([xml]$xml) {
	$StringWriter = New-Object System.IO.StringWriter;
	$XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter;
    $XmlWriter.Formatting = "indented";
    $Xml.WriteTo($XmlWriter);
    $XmlWriter.Flush();
    $StringWriter.Flush();
    Write-Output $StringWriter.ToString();
}