<#
.DESCRIPTION
    - Find installed application GUID
.PARAMETER Application
    - Search registry for this application
.PARAMETER Uninstall test
    - Attempt to uninstall *every* application found
.EXAMPLE
    - Lookup installed applications
    - .\xBit-AppFinder-Uninstall.ps1 -Application <appname>
.NOTES
    - If you specify -Uninstall, it will attempt to uninstall *ALL OF THE APPLICATIONS FOUND*
#>

param(
    [Parameter(Mandatory=$true)][string]$Application,
    [Parameter()][switch]$Uninstall
)

function xBit-AppUninstall {
    param (
        [Parameter()][pscustomobject]$InputObject
    )

    foreach ($app in $InputObject) {
        $app.ExitCode = (Start-Process msiexec.exe -ArgumentList "/X $([regex]::Match($app.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value) /qn" -Wait -Verb RunAs -Passthru).ExitCode
        return $InputObject
    }
}

# Registry
$HKLMUninst = Get-ChildItem "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\", "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"

# Find applications
$xBitApps = $HKLMUninst | Get-ItemProperty | Where-Object {$_.DisplayName -match $Application} | Select-Object -Property DisplayName, DisplayVersion, UninstallString, ExitCode

# Uninstall
if ($Uninstall) {
    Write-Host "`n[ Uninstall ]" -ForegroundColor Green

    <# Terminate $Application process if needed, add proc name manually if needed
    while ((Get-Process $Application -ErrorAction SilentlyContinue).processName -contains $Application) {
        try {
            taskkill /IM "$($Application).exe" /T /F
            Start-Sleep -Milliseconds 500
        } catch {
            Write-Host "Could not kill process for $Application" -ForegroundColor Yellow
            exit 1
        }
    }#>

    if ($xBitApps.Count -ne 0) {
        $xBitApps = xBit-AppUninstall $xBitApps
    }
}

# Write info to console
Write-Host "`n[ INFO ]" -ForegroundColor Green
$xBitApps | Format-Table