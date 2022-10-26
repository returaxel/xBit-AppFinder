# Find and uninstall 64 bit applications

param(
    [Parameter()][string]$Application
)

# Find application guid by DisplayName
if ([string]::IsNullOrEmpty($Application)) {
    return Write-Host "No application selected"
}

# Registry
$HKLM32Uninst = "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
$HKLM64Uninst = "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
$KeysHKLM32 = (Get-Item $HKLM32Uninst).GetSubKeynames()
$KeysHKLM64 = (Get-Item $HKLM64Uninst).GetSubKeynames()

# Iterate all installed 64-bit applications
[PSCustomObject]$InfoArray64 = foreach ($key in $KeysHKLM64) {

    try {
        $SubKeys = Get-ItemProperty -Verbose -Path $HKLM64Uninst$key
    } 
    catch {}

    if ($SubKeys.DisplayName -match "$($Application)") {
        [PSCustomObject]@{
            DisplayName = $SubKeys.DisplayName
            DisplayVersion = $SubKeys.DisplayVersion
            UninstallString = [regex]::Match($SubKeys.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value
            FullPath = "$($HKLM64Uninst)$($key)"     
        }
    }
}

# Iterate all installed 32-bit applications
[PSCustomObject]$InfoArray32 = foreach ($key in $KeysHKLM32) {

    try {
        $SubKeys = Get-ItemProperty -Verbose -Path $HKLM32Uninst$key
    } 
    catch {}

    if ($SubKeys.DisplayName -match "$($Application)") {
        [PSCustomObject]@{
            DisplayName = $SubKeys.DisplayName
            DisplayVersion = $SubKeys.DisplayVersion
            UninstallString = [regex]::Match($SubKeys.UninstallString,'[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?').Value
        }
    }
}

# Write info to console
Write-Host "`n--64-bit ->" -ForegroundColor Green
$InfoArray64 | Format-Table
Write-Host '--32-bit ->' -ForegroundColor Green
$InfoArray32 | Format-Table
