# Detect BigFix Client (1/2)

param(
    [Parameter()][string]$Application,
    [Parameter()][string]$Arguments = "/qn",
    [Parameter()][switch]$Uninstall
)

# Logging
$ExportPath = edit me
$NetworkAccess = Test-Path $ExportPath 

$HostInfo = [PSCustomObject]@{
    Date = '{0}{1}{2}' -f [datetime]::now.ToShortDateString(), ' ', [datetime]::now.ToShortTimeString()
    Hostname = $env:COMPUTERNAME
    DisplayName = $null
    UninstallString = $null
    ExitCode = $null
}

# Find 64-bit application guid by DisplayName
function Get-ApplicationGuid {
    param (
        [Parameter()][string]$TargetApp
    )

    if ([string]::IsNullOrEmpty($TargetApp)) {
        return Write-Host "No application selected"
    }

    # Registry
    $HKLM64Uninst = "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    $KeysHKLM64 = (Get-Item $HKLM64Uninst).GetSubKeynames()

    # Iterate all installed 64-bit applications
    foreach ($key in $KeysHKLM64) {

        try {
             $SubKeys = Get-ItemProperty -Verbose -Path $HKLM64Uninst$key 
        } 
        catch {}
    
        if ($SubKeys.DisplayName -match "$($TargetApp)") {
        # Write information to HostInfo
            $HostInfo.DisplayName = $SubKeys.DisplayName
            $HostInfo.UninstallString = [regex]::Match($SubKeys.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value
            return
        }
    }
}

# Uninstall application 
function Uninstall-ThisApplication {
    param (
        [Parameter()][string]$TargetGuid,
        [parameter()][string]$Arguments
    )

    if (![string]::IsNullOrEmpty($TargetGuid)) {
        try {
            $ExitCode = (Start-Process msiexec.exe -ArgumentList "/X$($TargetGuid) $($Arguments)" -Wait -Verb RunAs -Passthru).ExitCode
        }
        catch {
            return "Uninstall cancelled."
        }
        return $ExitCode
    }
}

Get-ApplicationGuid $Application

if ($Uninstall) {
    $HostInfo.ExitCode = Uninstall-ThisApplication $HostInfo.UninstallString $Arguments
}

# Write info to console
$HostInfo | Format-Table
$HostInfo | Export-Csv "$($ExportPath)\$($env:COMPUTERNAME).csv" -NoTypeInformation -Delimiter "," -Append