# Script N3: Live RAM Capture With USB (Exclusive Lock)

# Admin rights verification
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal] $identity
$IsAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "`n[!] Warning: Missing administrator privileges. Attempting elevation..." -ForegroundColor Yellow
    $elevation_args = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $elevation_args -Verb RunAs
    exit
}

Write-Host "`n Privilege check passed. Initializing extraction tool..." -ForegroundColor Green

$USBRoot       = $PSScriptRoot
$Output_Folder = Join-Path -Path $USBRoot -ChildPath "Ram_Dump"
$magnet_exe    = Join-Path -Path $USBRoot -ChildPath "DumpIt.exe"

# Ensure the output directory exists
if (-not (Test-Path -LiteralPath $Output_Folder -PathType Container)) {
    New-Item -ItemType Directory -Path $Output_Folder -Force | Out-Null
}

$Resolved_Path = Join-Path -Path $Output_Folder -ChildPath "Live_Target_RAM.bin"

# Verify DumpIt executable presence
if (-not (Test-Path -LiteralPath $magnet_exe -PathType Leaf)) {
    Write-Host "`n[-] Error: DumpIt.exe not found at $magnet_exe" -ForegroundColor Red
    Write-Host "Ensure DumpIt.exe is located in the same directory as this script." -ForegroundColor Yellow
    Read-Host "Press ENTER to exit"
    exit 1
}

Write-Host "LIVE RAM EXTRACTION IN PROGRESS" -ForegroundColor Green
Write-Host "  -> Destination File: $Resolved_Path" -ForegroundColor Cyan
Write-Host "  -> Executing Tool   : $magnet_exe`n" -ForegroundColor Cyan

try {
    # We pass the exact .bin file path to DumpIt
    $magnet_process = Start-Process `
        -FilePath      $magnet_exe `
        -ArgumentList  "/Q /T RAW /O `"$Resolved_Path`" /J /N" `
        -Wait `
        -NoNewWindow `
        -PassThru `
        -ErrorAction   Stop

    if ($magnet_process.ExitCode -eq 0) {
        Write-Host "`n Success! DumpIt execution completed successfully." -ForegroundColor Green
    } else {
        Write-Host "`n Warning: DumpIt exited with a non-zero code ($($magnet_process.ExitCode))." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n Script failed to execute DumpIt: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press ENTER to exit"
    exit 1
}
