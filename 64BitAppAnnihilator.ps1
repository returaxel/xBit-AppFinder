<#
.DESCRIPTION
   Search registry for guid that contains the name specified in $targetApp
   Saves information in CSV format if $ExportInfo is used
    
.NOTES
    Creation Date:  2021-10-04
    Author: returaxel

.EXAMPLE
    Remove every version older than 1.118
    .\64BitAppAnnihilator.ps1 -Uninstall  -TargetApp Yeee -TargetVer 1.118

    Run without -Uninstall switch too see whats goin' on
    .\64BitAppAnnihilator.ps1 -TargetApp Yeee -TargetVer 1.118
#>

param (
    [Parameter()]
    [switch]
    $Uninstall,
    [Parameter()]
    [switch]
    $ExportInfo,
    [Parameter()]
    [string]
    $TargetApp,
    [Parameter()]
    [string]
    $TargetVer
)

$MeasureCommand = Measure-Command { 

# Registry
$HKLM64 = "hklm:\\SOFTWARE\WOW6432Node\"
$HKLM64Uninst = "$($HKLM64)\Microsoft\Windows\CurrentVersion\Uninstall\"
$KeysHKLM64 = (Get-Item $HKLM64Uninst).GetSubKeynames()

# Export
$ExportPath = 'editme' # Where to export info
$ExportFile = "$($ExportPath)\$($env:COMPUTERNAME).csv"
$NetworkAccess = Test-Path $ExportPath 

###### ------------ CLASSES

class AppINFO {
    [object]${Date}
    [object]${Hostname}
    [object]${Architecture}
    [object]${Application}
    [object]${Uninstall}
    [object]${Error}
}

###### ------------ FUNCTIONS

function FindApplication {

    $PathUninstall = '{0}{1}' -f $HKLM64Uninst , $item
    try {
        $GetSubKeys = Get-ItemPropertyValue -Verbose -Path $PathUninstall -Name DisplayName, DisplayVersion, UninstallString -ErrorAction SilentlyContinue
    }
    catch {
        # Console info (for fun)
        # Write-Host "[GetSubKeys] $($item)" -ForegroundColor Red
    }
    
    if ($null -ne $GetSubKeys -and $GetSubKeys[0] -match $TargetApp) {
        # Console info (for fun)
        #Write-Host "[GetSubKeys] $($item)" -ForegroundColor Green -NoNewline
        #Write-Host "`t$($GetSubKeys[0])"

        # Write CSV info
        $HostInfo = [AppINFO]::New()

        $HostInfo.Date = '{0}{1}{2}' -f [datetime]::now.ToShortDateString(),' ', [datetime]::now.ToShortTimeString()

        $HostInfo.Hostname = $env:COMPUTERNAME

        $HostInfo.Architecture = switch -regex ($PathHKLM) {
            "WOW6432Node" {"64-bit"}
            Default {"32-bit"}
        }

        $HostInfo.Application = $GetSubKeys -Join ','
    
        if ($GetSubKeys[1] -ge $TargetVer) { 
            $HostInfo.Uninstall = $false
        } else {
            $HostInfo.Uninstall = $true
        }

        $HostInfo

    } else {
        # Console info (for fun)
        #Write-Host "[GetSubKeys] $($item)" -ForegroundColor Yellow -NoNewline
        #Write-Host "`t$($GetSubKeys[0])"
        Return $null
    }

}

###### ------------ RUN SCRIPT
# Log to local disk
Start-Transcript -Path "$($ENV:TEMP)\AppAnnihilator\$($TargetApp)\$($TargetApp)Hunter.log" -Force   

[system.collections.arraylist]$FoundApps = foreach ($item in $KeysHKLM64 -match '{') {
    FindApplication
}

# Uninstall each found application lower than target version
Write-Host "`n[Uninstall]" -ForegroundColor Cyan
foreach ($item in $FoundApps) {

    # Skip if ran without $Uninstall 
    if ($item.Uninstall -and $Uninstall -eq $true) { 

        while ((Get-Process $TargetApp -ErrorAction SilentlyContinue).processName -contains $TargetApp) {
            Write-Host "Stopping $($TargetApp).exe" -ForegroundColor Yellow
            try {
                Get-Process Flow | Stop-Process
                Start-Sleep -Milliseconds 250
            }
            catch {
                Write-Host 'Ok, process dead.' -ForegroundColor Green
            }
        }

        # If registry ke match 'msiexec' save GUID for uninstall
        if ($item.Application -match 'msiexec'){
            try {
                $UninstallString = $item.Application.Substring($item.Application.IndexOf('{'))
            }
            catch {
                Write-Host 'Could not create $UninstallString' -ForegroundColor Yellow
            }
        }
       
        if ($null -ne $UninstallString -and $UninstallString.StartsWith('{')) {
            try {
                Start-Process msiexec.exe -ArgumentList "/x$($UninstallString)  /qn /norestart" -Verb RunAs -Verbose -Wait
            }
            catch {
                $item.Error = $PSItem.Exception.Message
            }

        # If registry key match .exe try silent uninstall
        } elseif ($UninstallString -match '.exe') {           
            try {
                Start-Process $uninstallPath -ArgumentList /S -Wait
            }
            catch {
                $item.Error = $PSItem.Exception.Message
            }
        }
    }
}

# Save file
If ($ExportInfo) {
    if ($NetworkAccess) {
        $FoundApps | Select-Object| Export-Csv -Path $ExportFile -Delimiter ';' -Append -NoTypeInformation
    }
}

} # End Measure-Command

Write-Host "`n[Results] " -ForegroundColor Cyan
$FoundApps | Format-Table

Write-Host "Runtime $($MeasureCommand.TotalSeconds) seconds"

Stop-Transcript
