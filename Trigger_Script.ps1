# Script N2 - Early Ransomware Warning


# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Bro you need to run this as Administrator or the WMI stuff fails."
    exit
}

# 1. Setup

#Change Path to your systems one
$mtavari_papka = "C:\ED-N2"
if (-not (Test-Path $mtavari_papka)) {
    New-Item -Path $mtavari_papka -ItemType Directory -Force | Out-Null
}

# Setup targeting the hidden folder directly on the user's Desktop
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$satyuara_papka = Join-Path -Path $DesktopPath -ChildPath ".Honeypot_Baits"

if (-not (Test-Path $satyuara_papka)) {
    $Folder = New-Item -Path $satyuara_papka -ItemType Directory -Force
    $Folder.Attributes = 'Directory', 'Hidden'
}

$satyuara_failebi = @("000_Document.docx", "000_SystemConfig.xlsx", "zzz_Archive.zip")

Write-Host "Creating files in $satyuara_papka..." -ForegroundColor Cyan

$zip_magia = [byte[]](0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00)
$teqsti = [System.Text.Encoding]::ASCII.GetBytes(" DO NOT MODIFY!!!")
$fake_failis_sxeuli = $zip_magia + $teqsti

foreach ($faili in $satyuara_failebi) {
    $sruli_gza = Join-Path $satyuara_papka $faili
    if (-not (Test-Path $sruli_gza)) {
        [System.IO.File]::WriteAllBytes($sruli_gza, $fake_failis_sxeuli)
    }
}

# 2. Action Blocks (what happens when we catch something)

$wmi_moqmedeba = {
    $procesi = $Event.SourceEventArgs.NewEvent.TargetInstance
    $brdzaneba = $procesi.CommandLine
    $pidi  = $procesi.ProcessId

    if ([string]::IsNullOrWhiteSpace($brdzaneba)) { return }

    # regex patterns
    $cud_sityvebi = @(
        "vssadmin.*delete.*shadows",
        "shadowcopy.*delete",
        "bcdedit.*/set.*(recoveryenabled|bootstatuspolicy)",
        "wevtutil.*cl",
        "(net|sc).*stop.*(vss|sql|mdefend|wuauserv)"
    )

    foreach ($sityva in $cud_sityvebi) {
        if ($brdzaneba -match $sityva) {
#change both path to server path
            $drois_shtampi = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $log_path   = "C:\ED-N2\Ransomware_Trigger.txt"
            $flag_path  = "C:\ED-N2\trigger.flag"
            $detalebi   = "Malicious Command: $brdzaneba"
            
            # log it
            "[$drois_shtampi] ALARM! Vector: WMI_MONITOR | PID: $pidi | Details: $detalebi" | Out-File -FilePath $log_path -Append
            
            # drop flag for next script
            "TRIGGERED" | Out-File -FilePath $flag_path -Force
            
            # popup
            $wshell = New-Object -ComObject Wscript.Shell
            $wshell.Popup("RANSOMWARE DETECTED - FORENSICS STARTED`n`nPID: $pidi`nCMD: $brdzaneba", 10, "Warning", 48)
            break
        }
    }
}

$failis_moqmedeba = {
    $failis_saxeli   = $Event.SourceEventArgs.Name
    $cvlilebis_tipi = $Event.SourceEventArgs.ChangeType
    
    #Regex
    if ($failis_saxeli -match "^(000_Document|000_SystemConfig|zzz_Archive)") {
        $drois_shtampi = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $log_path   = "C:\ED-N2\Ransomware_Trigger.txt"
        $flag_path_gza  = "C:\ED-N2\trigger.flag"
        $detalebi   = "Bait file modified: $failis_saxeli ($cvlilebis_tipi)"
        
        "[$drois_shtampi] ALARM! Vector: CANARY_MONITOR | PID: N/A | Details: $detalebi" | Out-File -FilePath $log_path -Append
        "TRIGGERED" | Out-File -FilePath $flag_path_gza -Force
        
        Write-Host "`n[!!!] ALERT: Ransomware Activity Detected on Bait Files! [!!!]" -ForegroundColor Red
        
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("RANSOMWARE DETECTED - FORENSICS STARTED`n`nDetails: $detalebi", 10, "Warning", 48)
    }
}

# 3. Register Events

Write-Host "Hooking WMI for process creation..." -ForegroundColor Cyan
#polling - 1 second
$wmi_kitxva = "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'"
Register-WmiEvent -Query $wmi_kitxva -SourceIdentifier "ScriptN2_WMIMonitor" -Action $wmi_moqmedeba | Out-Null

Write-Host "Hooking FileSystemWatcher..." -ForegroundColor Cyan
$failis_mzveravi = New-Object System.IO.FileSystemWatcher
$failis_mzveravi.Path = $satyuara_papka
$failis_mzveravi.IncludeSubdirectories = $false
$failis_mzveravi.EnableRaisingEvents = $true

Register-ObjectEvent $failis_mzveravi "Changed" -SourceIdentifier "ScriptN2_FSW_Changed" -Action $failis_moqmedeba | Out-Null
Register-ObjectEvent $failis_mzveravi "Deleted" -SourceIdentifier "ScriptN2_FSW_Deleted" -Action $failis_moqmedeba | Out-Null
Register-ObjectEvent $failis_mzveravi "Renamed" -SourceIdentifier "ScriptN2_FSW_Renamed" -Action $failis_moqmedeba | Out-Null

#4. Wait Loop

Write-Host "Script Initialized." -ForegroundColor Green
Write-Host "    - Watching WMI."
Write-Host "    - Watching bait files in $satyuara_papka."

try {
    # wait indefinitely without burning CPU
    Wait-Event 
}
finally {
    # cleanup if stopped manually
    Write-Host "`n Cleaning up events..." -ForegroundColor Yellow
    Unregister-Event -SourceIdentifier "ScriptN2_WMIMonitor" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "ScriptN2_FSW_Changed" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "ScriptN2_FSW_Deleted" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "ScriptN2_FSW_Renamed" -ErrorAction SilentlyContinue
    $failis_mzveravi.EnableRaisingEvents = $false
    $failis_mzveravi.Dispose()
    Write-Host "Exit cleanly." -ForegroundColor Green
}
