# Must be run as administrator
$ErrorActionPreference = "Stop"

# 1. Config. Change Path's for individual devices.
$drois_shtampi = Get-Date -Format "yyyy-MM-dd_HHmmss"
$baza_folder = "C:\DFR_Baseline_$drois_shtampi"
$rawcopy_gza = "E:\RawCopy64.exe"
$info_faili = "$baza_folder\Info.txt"

if (-not (Test-Path $baza_folder)) {
    try {
        New-Item -ItemType Directory -Path $baza_folder | Out-Null
        Write-Host "Folder created: $baza_folder" -ForegroundColor Green
    } catch {
        Write-Host "Error creating folder: $_" -ForegroundColor Red
        exit
    }
}

# write header for log
$dawyebis_dro = Get-Date -Format "ddd MMM dd HH:mm:ss yyyy"
"Information for DFR Capture:" > $info_faili
"" >> $info_faili
"Forensic Readiness Item (Source) Information:" >> $info_faili
"[Device Info]" >> $info_faili
" Source Type: Logical Artifact Extraction" >> $info_faili
" Hostname: $env:COMPUTERNAME" >> $info_faili
" Operating System: Windows 10/11" >> $info_faili
"[Acquisition Information]" >> $info_faili
" Acquisition started:   $dawyebis_dro" >> $info_faili
" Output Directory:     $baza_folder" >> $info_faili
"--------------------------------------------------" >> $info_faili

Write-Host "Baseline folder ready: $baza_folder" -ForegroundColor Cyan
