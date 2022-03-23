<# V1.0
.SYNOPSIS
    This script extracts logging information from AAD about guest access across tenants and exports it to a csv file

.DESCRIPTION
    This script requires the MSIdentityTools and Microsoft.Graph powershell modules. It will install them if they are not present
    You will be prompted to authenticate to MSGraph when you run the script (via a web browser prompt)

    Exported columns are:

 ExternalTenantID - The tenant ID of the external tenant
        AccessDirection - Whether the login activity was inbound or outbound
        UserDisplayName - The display name of the user
        UserPrincipalName - The UPN of the user
        UserDomainName - The domain name of the user
        UserObjectID - The object ID of the user or guest
        UserType - Either guest or member
        CrossTenantAccessType - Whether B2B or B2C collaboration
        AppDisplayName - The app that the user authenticated to
        ResourceDisplayName - The name of the application resource
        CreatedDateTime - The date and time of the login

    Outputs are a CSV file containing a list of users (prefixed with "XTenantAccess-" followed by the date and time of creation) and a log file (prefixed with "XTenantAccess-log" and the date and time of creation).

    .EXAMPLE
    tenant-monitor.ps1
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
        $ExternalTenantID,
        $AccessDirection,
        $UserDisplayName,
        $UserPrincipalName,
        $UserDomainName,
        $UserObjectID,
        $UserType,
        $CrossTenantAccessType,
        $AppDisplayName,
        $ResourceDisplayName,
        $CreatedDateTime
    )

    $data = [PSCustomObject]@{
        ExternalTenantID      = $ExternalTenantID
        AccessDirection       = $AccessDirection
        UserDisplayName       = $UserDisplayName
        UserPrincipalName     = $UserPrincipalName
        UserDomainName        = $UserDomainName
        UserObjectID          = $UserObjectID
        UserType              = $UserType
        CrossTenantAccessType = $CrossTenantAccessType
        AppDisplayName        = $AppDisplayName
        ResourceDisplayName   = $ResourceDisplayName
        CreatedDateTime       = $CreatedDateTime
    }
    $data | Export-Csv -Path $script:ExportFile -NoTypeInformation -Append
}

# Setup script
clear-host

$ErrorActionPreference = "silentlycontinue"
$logname = ".\XTenantAccess-Log", (get-date -Format 'yyMMddHHmm'), ".csv" -join ""
Set-Log $logname
$message = "Logfile Name =", $logname -join " "
write-log $message info ScriptBody

$exportfile = ".\XTenantAccess-", (get-date -Format 'yyMMddHHmm'), ".csv" -join ""
$message = "Output File Name =", $exportfile -join " "
Write-Log $message info ScriptBody


Install-Module -Name MSIdentityTools
Install-Module Microsoft.Graph
Select-MgProfile -Name beta
Connect-MgGraph -Scopes AuditLog.Read.All

$activities = Get-MSIDCrossTenantAccessActivity

ForEach ($activity in $activities) {
    $DomainName = $activity.userprincipalname.Split("@")[1]    
    Export-Record $activity.ExternalTenantID $activity.AccessDirection $activity.UserDisplayName $activity.UserPrincipalName $DomainName $activity.UserID $activity.UserType $activity.CrossTenantAccessType $activity.AppDisplayName $activity.ResourceDisplayName $activity.CreatedDateTime
}

# All done
Write-Log "Script Complete"