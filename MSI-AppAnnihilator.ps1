# Find 64-bit application guid by DisplayName
#
#

param(
    [Parameter(Mandatory=$true)][string]$Application,
    [Parameter()][switch]$Uninstall,
    [Parameter()][double]$TargetVer
)

# Stop if $Application is empty
if ([string]::IsNullOrEmpty($Application)) {
    return Write-Host "No application selected"
}

# --- Function: REGISTRY SCANNER ---
function Get-RegMatches {
    param (
        [Parameter()][string]$PathHKLM,
        [Parameter()][array]$KeysHKLM,
        [Parameter()][array]$StrMatch
    )

    [PSCustomObject]$AppMatches = foreach ($key in $KeysHKLM) {

        try {
            $SubKeys = Get-ItemProperty -Verbose -Path $PathHKLM$key
        } catch {}

        $reg = switch -regex ($PathHKLM) {
            'WOW6432Node'   {64}
            Default         {32}
        }
        # Match selected application to DisplayName
        $Regex = [regex]::Match($SubKeys.DisplayName,$($Application))
        if (($Regex.Success -eq $true) -and (![string]::IsNullOrEmpty($SubKeys.DisplayName))) {


            [PSCustomObject]@{
                RegPath = "$($reg)bit"
                RegexMatch = $Regex.Value
                DisplayName = $SubKeys.DisplayName
                DisplayVersion = $SubKeys.DisplayVersion
                VerMajor = $SubKeys.VersionMajor
                VerMinor = $SubKeys.VersionMinor
                UninstallString = [regex]::Match($SubKeys.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value
                ExitCode = $null
            }
        }
    }
    return $AppMatches
}

# --- Function: UNINSTALL ---
function Remove-ThisApplication {
    param (
        [Parameter()][pscustomobject]$TargetApp,
        [Parameter()][double]$RemVer
    )

    if (![string]::IsNullOrEmpty($TargetApp.UninstallString)) {
        [double]$CurrentVer = '{0}{1}{2}' -f $TargetApp.VerMajor,'.', $TargetApp.Verminor
        Write-Host "[Version]`nMajor: $($TargetApp.VerMajor)`nMinor: $($TargetApp.VerMinor)`ndouble: $($CurrentVer)" -ForegroundColor Cyan # Debug
        Write-Host "TargetVer: $RemVer `nIsLower: $($RemVer -le $CurrentVer)" -ForegroundColor Magenta # Debug

        if ($RemVer -le $CurrentVer ) {
            Write-Host "Uninstall: true" -ForegroundColor Green # Debug
            # Uninstall
            try {
                $ExitCode = (Start-Process msiexec.exe -ArgumentList "/X $($TargetApp.UninstallString) /qn" -Wait -Verb RunAs -Passthru).ExitCode
                return $ExitCode
            }
            catch {
                return "Interrupted"
            }
        }
    }
}

function Find-ThisApplication {
    param (
        [Parameter()][string]$Application
    )

    # Path & Keys
    $HKLM32Uninst = "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
    $HKLM64Uninst = "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    $KeysHKLM32 = (Get-Item $HKLM32Uninst).GetSubKeynames()
    $KeysHKLM64 = (Get-Item $HKLM64Uninst).GetSubKeynames()

    $FoundApps = [PSCustomObject]@{
        32 = Get-RegMatches -PathHKLM $HKLM32Uninst -KeysHKLM $KeysHKLM32 -StrMatch $Application
        64 = Get-RegMatches -PathHKLM $HKLM64Uninst -KeysHKLM $KeysHKLM64 -StrMatch $Application
    }
    return $FoundApps
}

# --- Script ---
$InfoArray = Find-ThisApplication $Application

# Uninstall:$true
if ($Uninstall) {
    # Iterate 32 & 64 
    foreach ($arch in $InfoArray.psobject.Properties.name) {
        # and then each found app
        foreach ($App in $InfoArray.$arch) {
            $App.ExitCode = Remove-ThisApplication $App $TargetVer
        }
    }
}

$InfoArray #| Format-Table -AutoSize