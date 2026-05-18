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


#2. Extraction
Write-Host "Starting Extraction" -ForegroundColor Cyan

# 2,1. MFT
try {
    if (-not (Test-Path $rawcopy_gza)) {
        throw "rawcopy faili ver moidzebna: $rawcopy_gza"
    }

    Write-Host "    -> Extracting $MFT..." -NoNewline

    #using system drive instead of hardcoded C:
    $paramebi = @("/FileNamePath:$env:SystemDrive\`$MFT", "/OutputPath:$baza_folder")
    $procesi = Start-Process -FilePath $rawcopy_gza -ArgumentList $paramebi -Wait -NoNewWindow -PassThru

    if ($procesi.ExitCode -eq 0 -and (Test-Path "$baza_folder\`$MFT")) {
        Write-Host " [OK]" -ForegroundColor Green
    } else {
        throw "rawcopy MFT fail, kodi: $($procesi.ExitCode)"
    }
} catch {
    Write-Host " [Error]" -ForegroundColor Red
    Write-Host "       [-] $_" -ForegroundColor Red
    "" >> $info_faili
    "ATTENTION: `$MFT failed" >> $info_faili
}

# 2,2. NTUSER.DAT
try {
    Write-Host "    -> NTUSER.DAT extraction..." -NoNewline

    $aqtiuri_useri = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    if ($aqtiuri_useri) {
        $samizne_useri = $aqtiuri_useri.Split('\')[-1]
        $useris_papka = "$env:SystemDrive\Users\$samizne_useri"
    } else {
        $useris_papka = "$env:SystemDrive\Users\$env:USERNAME"
    }

    $ntuser_failebi = @("NTUSER.DAT", "NTUSER.DAT.LOG1", "NTUSER.DAT.LOG2")
    $yvela_kargadaa = $true

    foreach ($haivis_faili in $ntuser_failebi) {
        $user_gza = "$useris_papka\$haivis_faili"
        if (Test-Path $user_gza) {
            $ntuser_paramebi = @("/FileNamePath:$user_gza", "/OutputPath:$baza_folder")
            $proc_nt = Start-Process -FilePath $rawcopy_gza -ArgumentList $ntuser_paramebi -Wait -NoNewWindow -PassThru

            if ($proc_nt.ExitCode -eq 0) {
                # moving data out of rawcopy subfolders
                $amogebuli_faili = Get-ChildItem -Path $baza_folder -Filter $haivis_faili -Recurse | Select-Object -First 1
                if ($amogebuli_faili) {
                    Move-Item -Path $amogebuli_faili.FullName -Destination "$baza_folder\$haivis_faili" -Force
                }
            } else {
                $yvela_kargadaa = $false
            }
        }
    }

    #cleanup RawCopy folders
    Remove-Item -Path "$baza_folder\Users" -Recurse -Force -ErrorAction SilentlyContinue

    if ($yvela_kargadaa -and (Test-Path "$baza_folder\NTUSER.DAT")) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        throw "NTUSER.DAT fail, kodi: $($proc_nt.ExitCode)"
    }
} catch {
    Write-Host "Error" -ForegroundColor Red
    "ATTENTION: NTUSER.DAT failed" >> $info_faili
}

# 2,3. Registry Hives
try {
    Write-Host "Extracting SYSTEM, SOFTWARE, SAM, SECURITY hives" -NoNewline

    #SAM and SECURITY
    $haivebi = @("SYSTEM", "SOFTWARE", "SAM", "SECURITY")

    foreach ($h in $haivebi) {
        $gza = "$baza_folder\$h"
        $proc_reg = Start-Process -FilePath "reg.exe" -ArgumentList "save HKLM\$h `"$gza`" /y" -Wait -NoNewWindow -PassThru
        if ($proc_reg.ExitCode -ne 0) { throw "reg save failed on $h" }
    }
    Write-Host "OK" -ForegroundColor Green
} catch {
    Write-Host "Error" -ForegroundColor Red
    "ATTENTION: Registry dump failed" >> $info_faili
}
