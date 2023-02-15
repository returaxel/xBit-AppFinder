<#
.DESCRIPTION
    - Find installed application GUID
.PARAMETER Application
    - Search registry for this application
.PARAMETER RegexWhiteList
    - Skip uninstall if matches displayname
.PARAMETER Uninstall test
    - Switch for uninstalling found applicaitons
.EXAMPLE
    - Lookup installed applications
    - .\xBit-AppFinder-Uninstall.ps1 -Application <appname>
.NOTES
    - If you specify -Uninstall, it will attempt to uninstall *ALL OF THE APPLICATIONS FOUND*
#>

param(
    [Parameter(Mandatory=$true)][string]$Application,
    [Parameter()][string]$RegexWhitelist = '^Touchpad|Peripheral',
    [Parameter()][switch]$Uninstall
)

function xBit-TerminateProc {
    param (
        [Parameter(Mandatory=$true)][pscustomobject]$ProcessName
    )
    # Terminate $Application process, enter manually if needed
    while ((Get-Process $Application -ErrorAction SilentlyContinue).processName -contains $Application) {
        try {
            taskkill /IM "$($Application).exe" /T /F
            Start-Sleep -Milliseconds 500
        } catch {
            Write-Host "Could not kill process for $Application" -ForegroundColor Yellow
        }
    }
}

function xBit-Uninstall {
    param (
        [Parameter()][pscustomobject]$InputObject
    )

    foreach ($app in $InputObject) {
        if ($app.DisplayName -notmatch $RegexWhitelist) {

        # Run if UninstallString is not empty
            if (![string]::IsNullOrEmpty($app.UninstallString)) {

                try {
                    $app.ExitCode = (Start-Process msiexec.exe -ArgumentList "/x $([regex]::Match($app.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value) /qn" -Wait -Verb RunAs -Passthru).ExitCode
                }
                catch {
                    $app.ExitCode = $PSItem.Exception.Message
                } 
                finally {
                    $Error.Clear()
                }

            } else {
                $app.ExitCode = 'No UninstallString'
            }
        } else {
            $app.ExitCode=  "Skip, match whitelist."
        }

        return $InputObject
    }
}

# Registry
$HKLMUninst = Get-ChildItem "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\", "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"

# Find applications
$xBitApps = $HKLMUninst | Get-ItemProperty | Where-Object {$_.DisplayName -match $Application} | Select-Object -Property DisplayName, DisplayVersion, InstallLocation, UninstallString, ExitCode

# Uninstall
if ($Uninstall) {
    if ($xBitApps.Count -ne 0) {
        Write-Output "`n[ UNINSTALLING... ]"
        # Comment out if process don't need to be terminated
        # xBit-TerminateProc -ProcessName $Application
        # Uninstall
        $xBitApps = xBit-Uninstall $xBitApps
    }
}

# Write info to console
Write-Output "`n[ INFO... ]"
$xBitApps | Format-Table