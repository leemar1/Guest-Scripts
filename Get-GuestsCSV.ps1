<# Get-GuestsCSV V1.0
.SYNOPSIS
    Finds all guests users in a tenant and exports a list to CSV

.DESCRIPTION
    This script requires the AzureADPreview PowerShell Module

    Exported columns are:
    ObjectID
    AccountEnabled
    DisplayName
    Mail
    Domain
    UserState
    UserType

    Outputs are a CSV file (prefixed with "GuestUsers-" followed by the date and time of creation) containing a list of users and a log file (prefixed with "GuestUsers-log" and the date and time of creation).

    .EXAMPLE
    Get-GuestsCSV.ps1
#>

function Write-Log {
    # This function is used to write messages to a log file in CSV format. Inputs are Message, level ("Info", "Warning", "Error", "Debug"), and a message tag
    [cmdletbinding()]
    param (
        $Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        $Level = 'Info',
        [string[]]
        $Tag
    )
    switch ($Level) {
        'Info' {
            if ($script:logVerbosity -in 'Info', 'Debug') {
                Write-Host $Message
            }
            write-host "---------------------------------------------------------------------------------------------"
        }
    }
    $callItem = (Get-PSCallstack)[1]
    $data = [PSCustomObject]@{
        Message    = $Message
        Level      = $Level
        Tag        = $Tag -join ","
        LineNumber = $callItem.ScriptLineNumber
        FileName   = $callItem.ScriptName
        Timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    }
    $data | Export-Csv -Path $script:logpath -NoTypeInformation -Append
}

function Set-Log {
    # This function sets up the log file. Inputs are Path (log file name) and Verbosity, one of 'Host', 'Info', 'Warning', 'Error', 'Debug'
    [CmdletBinding()]
    param (
        [string]
        $Path,
        [ValidateSet('Host', 'Info', 'Warning', 'Error', 'Debug')]
        [string]
        $Verbosity = 'Info'
    )
    $script:logpath = $Path
    $script:logVerbosity = $Verbosity
    if (Test-Path $Path) { Remove-Item $Path }
    Write-log "Starting Script" info Set-Log
    Write-Log "Setting Log path to $path" info Set-Log

}
function Export-Record {
    # exports records to CSV
    [cmdletbinding()]
    param (
        [String]
        $ObjectID,
        $AccountEnabled,
        $DisplayName,
        $Mail,
        $Domain,
        $UserState,
        $UserType    
    )

    $data = [PSCustomObject]@{
        ObjectID       = $ObjectID
        AccountEnabled = $AccountEnabled
        DisplayName    = $DisplayName
        Mail           = $Mail
        Domain         = $Domain
        UserState      = $UserState
        UserType       = $UserType
    }
    $data | Export-Csv -Path $script:ExportFile -NoTypeInformation -Append
}

# Setup script
clear-host

$ErrorActionPreference = "silentlycontinue"
$logname = ".\GuestUsers-Log", (get-date -Format 'yyMMddHHmm'), ".csv" -join ""
Set-Log $logname
$message = "Logfile Name =", $logname -join " "
write-log $message info ScriptBody

$exportfile = ".\GuestUsers-", (get-date -Format 'yyMMddHHmm'), ".csv" -join ""
$message = "Output File Name =", $exportfile -join " "
Write-Log $message info ScriptBody

Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {

        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable

    }

    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

$guests = get-azureaduser | Where-Object {$_.UserType -eq 'guest'}

ForEach ($guest in $guests) {
    $Domain = $guest.mail.Split("@")[1]    
    Export-Record $guest.ObjectID $guest.AccountEnabled $guest.DisplayName $guest.Mail $Domain $guest.UserState $guest.UserType
}

# All done
Write-Log "Script Complete"
