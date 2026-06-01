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

# Apply exclusive file lock
Write-Host "`n Enforcing exclusive system lock on the memory dump..." -ForegroundColor Cyan

$File_Handle = $null

try {
    # Ensure the file actually exists and has data before locking
    if (-not (Test-Path -LiteralPath $Resolved_Path -PathType Leaf)) {
        throw "The RAM file was not detected at $Resolved_Path. Extraction failed."
    }

    if ((Get-Item $Resolved_Path).Length -eq 0) {
        throw "The RAM file is 0 bytes. DumpIt failed to write data."
    }

    # FileShare::None completely isolates the file, blocking any write/rename/delete attempts
    $File_Handle = [System.IO.File]::Open($Resolved_Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
    
    Write-Host "EXCLUSIVE KERNEL LOCK ACTIVE!" -ForegroundColor Green
    Write-Host "     Handle ID : $($File_Handle.SafeFileHandle.DangerousGetHandle()) (PID: $PID)" -ForegroundColor Green
    Write-Host "     Lock Mode : FileShare::None (All external process access denied)" -ForegroundColor Green
    
    Write-Host "               RAM FILE SECURED | KERNEL LOCK ENABLED               " -ForegroundColor Red -BackgroundColor Black

    Write-Host " EXECUTE THE FOLLOWING INCIDENT RESPONSE STEPS IMMEDIATELY:" -ForegroundColor Yellow
    Write-Host "  1) Disconnect the USB flash drive from the physical port immediately." -ForegroundColor White
    Write-Host "  2) Sever the power source directly from the machine (Hard Power Shutdown)." -ForegroundColor White

    Write-Host " WARNING: DO NOT TERMINATE THIS COMMAND WINDOW" -ForegroundColor Red
    Write-Host " Closing this process or executing Ctrl+C will release the kernel lock and expose the file.`n" -ForegroundColor Red

    # Infinite loop to sustain the lock until manual power cut
    while ($true) {
        Read-Host "LOCK ENGAGED - Awaiting hardware shutdown. Do not press Enter"
        Write-Host "`n THE KERNEL LOCK IS ACTIVE. DISCONTINUE INPUT." -ForegroundColor Red
    }
}
catch {
    Write-Host "`n CRITICAL ERROR: UNABLE TO ACQUIRE EXCLUSIVE LOCK!" -ForegroundColor Red
    Write-Host "      Details: $_" -ForegroundColor Red
    Write-Host "      Action: Initiate manual hard power shutdown immediately!" -ForegroundColor Red
    exit 1
}