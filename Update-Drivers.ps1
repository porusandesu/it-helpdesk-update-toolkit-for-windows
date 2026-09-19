<#
.SYNOPSIS
    Scans for and installs available driver updates via Windows Update.
    Built for IT Helpdesk / Desktop Support operations.

.DESCRIPTION
    This script uses the PSWindowsUpdate module to detect and install
    driver updates published through Windows Update (the same source
    Device Manager checks). It logs every action to a timestamped log
    file so support staff have a record for tickets/audits, and supports
    a -WhatIf style dry run so a technician can preview updates before
    applying them on a user's machine.

.PARAMETER Install
    If specified, detected driver updates are downloaded and installed.
    If omitted, the script only reports what updates are available
    (safe "scan only" mode - recommended default for helpdesk use).

.PARAMETER LogPath
    Folder where the log file will be written. Defaults to
    C:\IT\Logs on the local machine.

.PARAMETER Reboot
    If specified (and used together with -Install), the machine will
    automatically restart if a driver update requires it. Omit this on
    a live user session and instead prompt the user manually.

.EXAMPLE
    .\Update-Drivers.ps1
    Scans for available driver updates and reports them (no changes made).

.EXAMPLE
    .\Update-Drivers.ps1 -Install
    Scans for and installs available driver updates.

.EXAMPLE
    .\Update-Drivers.ps1 -Install -Reboot
    Installs updates and reboots automatically if required.

.NOTES
    Author   : Paul Mukupe
    Purpose  : Helpdesk driver maintenance automation
    Requires : Run PowerShell "as Administrator"
#>

[CmdletBinding()]
param(
    [switch]$Install,
    [string]$LogPath = "C:\IT\Logs",
    [switch]$Reboot
)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

function Assert-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "This script must be run as Administrator. Relaunching..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList (
            "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
            "$(if ($Install) {'-Install '})$(if ($Reboot) {'-Reboot '})-LogPath `"$LogPath`""
        )
        exit
    }
}

function Initialize-Log {
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    return Join-Path $LogPath "DriverUpdate_$stamp.log"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $script:LogFile -Value $line
}

function Ensure-PSWindowsUpdate {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "PSWindowsUpdate module not found. Installing..." "INFO"
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
            Write-Log "PSWindowsUpdate module installed successfully." "INFO"
        }
        catch {
            Write-Log "Failed to install PSWindowsUpdate module: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
    Import-Module PSWindowsUpdate -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Assert-Admin
$script:LogFile = Initialize-Log

Write-Log "===== Driver Update Script Started =====" "INFO"
Write-Log "Computer: $env:COMPUTERNAME | User: $env:USERNAME" "INFO"
Write-Log "Mode: $(if ($Install) {'INSTALL'} else {'SCAN ONLY'})" "INFO"

try {
    Ensure-PSWindowsUpdate
}
catch {
    Write-Log "Cannot continue without PSWindowsUpdate module. Exiting." "ERROR"
    exit 1
}

Write-Log "Scanning Windows Update for available driver updates..." "INFO"

try {
    $driverUpdates = Get-WindowsUpdate -UpdateType Driver -MicrosoftUpdate -Verbose:$false -ErrorAction Stop
}
catch {
    Write-Log "Error while scanning for updates: $($_.Exception.Message)" "ERROR"
    exit 1
}

if (-not $driverUpdates -or $driverUpdates.Count -eq 0) {
    Write-Log "No driver updates available. System is up to date." "INFO"
    Write-Log "===== Driver Update Script Finished =====" "INFO"
    exit 0
}

Write-Log "Found $($driverUpdates.Count) driver update(s):" "INFO"
foreach ($update in $driverUpdates) {
    Write-Log " - $($update.Title)" "INFO"
}

if (-not $Install) {
    Write-Log "Scan-only mode: no updates were installed. Re-run with -Install to apply them." "INFO"
    Write-Log "===== Driver Update Script Finished =====" "INFO"
    exit 0
}

Write-Log "Installing driver updates..." "INFO"

try {
    $installParams = @{
        UpdateType      = "Driver"
        MicrosoftUpdate = $true
        AcceptAll       = $true
        IgnoreReboot    = $true
        Verbose         = $false
        ErrorAction     = "Stop"
    }
    $results = Install-WindowsUpdate @installParams

    foreach ($result in $results) {
        $status = if ($result.Result -eq "Installed") { "INFO" } else { "WARN" }
        Write-Log " - $($result.Title): $($result.Result)" $status
    }
}
catch {
    Write-Log "Error while installing updates: $($_.Exception.Message)" "ERROR"
    exit 1
}

$needsReboot = Get-WURebootStatus -Silent
if ($needsReboot) {
    if ($Reboot) {
        Write-Log "Reboot required. Restarting machine now (per -Reboot flag)." "WARN"
        Write-Log "===== Driver Update Script Finished =====" "INFO"
        Restart-Computer -Force
    }
    else {
        Write-Log "Reboot required to finish applying driver updates. Please restart the machine." "WARN"
    }
}
else {
    Write-Log "No reboot required." "INFO"
}

Write-Log "===== Driver Update Script Finished =====" "INFO"
Write-Log "Full log saved to: $script:LogFile" "INFO"
