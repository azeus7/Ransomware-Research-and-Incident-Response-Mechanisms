> ⚠️ **SECURITY DISCLAIMER — READ BEFORE PROCEEDING**
> **All scripts must be validated in an isolated, air-gapped sandbox or lab environment before any production deployment.** Unauthorized or misconfigured deployment may cause system instability, unintentional data loss, or legal liability. The authors and contributors bear no responsibility for misuse. Review your jurisdiction's computer crime statutes prior to deployment. See [`SECURITY.md`](./SECURITY.md) for full disclosure.

---

# 🛡️ Digital Forensic Readiness (DFR) Ecosystem — Ransomware Defense & Evidence Preservation Framework

**Authors:**
Levan Tamazashvili <l_tamazashvili2@cu.edu.ge> 
Alexandra Ananskikh <a_ananskikh@cu.edu.ge>

**Target Environment:** Windows Corporate Networks (Domain-Joined Endpoints)
**License:** MIT (Non-Commercial Use)

---

## Executive Summary

**Digital Forensic Readiness (DFR)** is the organizational and technical capability to maximize the use of digital evidence collected from corporate endpoints *before* a security incident occurs — ensuring that when an attack is detected, the forensic artifacts required for investigation and prosecution are already preserved, tamper-proof, and immediately actionable.

This project implements a three-stage, fully automated DFR Ecosystem specifically engineered to counter ransomware — the most destructive category of cybercrime affecting enterprises today. The framework operates silently at the kernel level, requiring no end-user interaction: it proactively harvests forensically critical NTFS structures and Registry hives during system idle periods, deploys a behavioral honeypot to detect ransomware at the earliest possible moment of execution, and — upon confirmed detection — performs live RAM imaging followed by a kernel-level evidence lock to prevent the malware from corrupting or destroying its own forensic footprint.

The result is a reproducible, sysadmin-deployable blueprint that closes the evidence gap inherent in traditional reactive incident response, enabling security teams to present courts and threat intelligence platforms with a complete, hash-verified forensic chain of custody — even when the ransomware successfully encrypts production data.

---

## Repository Structure

```
dfr-ecosystem/
│
├── scripts/
│   ├── Extractor_Script.ps1       # Periodic NTFS artifact harvesting
│   ├── Trigger_script.ps1     # WMI + FSW behavioral detection
│   └── Ram_Capturer.ps1       # RAM imaging + kernel evidence lock
│
│
├── SECURITY.md                              # Full security disclosure & lab requirements
├── README.md                                # This document
└── LICENSE
```

---

## Technical Architecture

The ecosystem is composed of three operationally distinct but interdependent PowerShell automation modules. Each script targets a specific phase of the PICERL incident response lifecycle.

### Component Overview

| Script | Phase | Trigger | Primary Function |
|---|---|---|---|
| `Extractor_Script` — Proactive Triage | **Preparation** | Task Scheduler (idle-time) | Extracts locked NTFS artifacts via kernel-level raw I/O; replicates to append-only server |
| `Trigger_script` — Honeypot & Detection | **Identification** | Continuous (WMI + FSW) | Behavioral deception trap; generates `trigger.flag` on confirmed ransomware detection |
| `Ram_Capturer` — Live Containment | **Containment** | Event-driven (flag polling) | Acquires volatile RAM image via DumpIt; applies `FileShare::None` kernel lock on dump |

---

### Extractor_Script — Proactive Triage (Pre-Incident Artifact Harvesting)

**Objective:** Acquire forensically significant NTFS structures that are normally locked by the Windows kernel during live system operation.

**Method:**
- Utilizes **RawCopy** (low-level raw disk reader) to bypass the NTFS kernel lock and extract:
  - `$MFT` — Master File Table (full filesystem metadata map)
  - `SYSTEM`, `SOFTWARE`, `SAM`, `SECURITY` — Registry Hives
  - `$LogFile`, `$UsnJrnl:\$J` — NTFS journal files (file operation history)
- Executes exclusively during **system idle time** (CPU < threshold) to minimize user impact.
- Replicates all artifacts to a **hardened, append-only NFS/SMB share** on the secure server using a write-only service account — preventing ransomware from ever overwriting prior captures.
- Computes and logs a **SHA-256 hash** for every captured artifact at time-of-collection.

```powershell
# Conceptual extraction flow (Script N1)
$artifacts = @("\\.\C:\`$MFT", "\\.\C:\Windows\System32\config\SYSTEM")
foreach ($artifact in $artifacts) {
    & RawCopy.exe /FileNamePath:$artifact /OutputPath:$SecureShare
    $hash = (Get-FileHash "$SecureShare\$(Split-Path $artifact -Leaf)" -Algorithm SHA256).Hash
    Add-Content $HashLog "$hash  $(Split-Path $artifact -Leaf)  $(Get-Date -Format o)"
}

---

### Trigger_script — Desktop Honeypot & Detection Engine

**Objective:** Detect ransomware at the earliest possible point of execution — before significant file encryption occurs — using behavioral deception.

**Method:**
- Creates a set of **canary files** (honeypot decoys) with high-entropy names and extensions commonly targeted by known ransomware strains, placed in high-probability attack directories.
- Registers a **WMI `__InstanceCreationEvent`** subscriber to monitor process instantiation for known ransomware behavioral signatures.
- Deploys a **.NET `FileSystemWatcher`** on the honeypot directory to detect any unauthorized read, write, rename, or delete event against the canary files.
- Upon confirmed detection, the script:
  1. Fires a **real-time alert** (Event Log entry + optional SIEM webhook).
  2. Writes a `trigger.flag` file to the SOC server.

```powershell
# Conceptual FSW monitoring (Trigger_Script)
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $HoneypotDirectory
$watcher.EnableRaisingEvents = $true
Register-ObjectEvent $watcher "Changed" -Action {
    Write-EventLog -LogName Security -Source "DFR-Honeypot" -EventId 9001 -EntryType Warning -Message "RANSOMWARE DETECTED: $($Event.SourceEventArgs.FullPath)"
    New-Item -Path "$SecureShare\trigger.flag" -ItemType File -Force
}
```

---

### Ram_Capturer — Live Containment & Evidence Locking

**Objective:** The moment ransomware is confirmed, capture the complete volatile memory state of the compromised endpoint and render the forensic artifact immutable at the kernel level.

**Method:**
- Polls the secure server for the existence of `trigger.flag` at a configurable interval (default: 30 seconds).
- Upon flag detection, immediately invokes **DumpIt** to perform a full physical memory acquisition to the secure share, capturing:
  - Active process list and memory maps
  - Network socket state
  - Encryption keys potentially held in RAM by the ransomware process
  - Full kernel and user-mode memory pages
- After DumpIt completes, opens the resulting `.raw` file with a **.NET `FileStream`** using `FileShare::None` — a kernel-level exclusive lock that prevents any other process (including the ransomware itself) from opening, reading, modifying, or deleting the dump file.
- Logs a final **SHA-256 hash** of the memory dump for chain-of-custody documentation.

```powershell
# Conceptual kernel lock (Ram_Capturer)
& DumpIt.exe /output "$SecureShare\memdump_$env:COMPUTERNAME_$(Get-Date -Format yyyyMMddHHmmss).raw"
$dumpPath = Get-ChildItem "$SecureShare\memdump_*.raw" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$stream = [System.IO.File]::Open($dumpPath.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
# $stream is held open — kernel lock persists until the IR team releases it
```

---

## Implementation Guide

### Prerequisites

Before deployment, confirm the following requirements are satisfied across all nodes.

**Endpoint Requirements (Windows Domain-Joined Workstations/Servers):**

| Requirement | Specification |
|---|---|
| Operating System | Windows 10 / Server 2016 or later |
| PowerShell | Version 5.1 or later |
| Execution Policy | `RemoteSigned` or `Bypass` (GPO-enforced) |
| Privileges | Local Administrator (Extractor_Script, Ram_Capturer); Domain User (Trigger_Script) |
| .NET Framework | 4.7.2 or later |

**Secure Server Requirements:**

| Requirement | Specification |
|---|---|
| OS | Windows Server 2019+ or hardened Linux (Samba) |
| Share Protocol | SMB 3.1.1 (encrypted in-transit) |
| Service Account | Write-only, no delete/modify permissions (ACL-enforced) |
| Storage | Minimum 2× daily snapshot size; WORM-capable preferred |
| Network Isolation | Accessible from endpoints; no outbound internet |

**Tools Download:**
- RawCopy: [https://github.com/jschicht/RawCopy](https://github.com/jschicht/RawCopy)
- DumpIt: [https://www.magnetforensics.com/resources/magnet-dumpit-for-windows/](https://www.magnetforensics.com/resources/magnet-dumpit-for-windows/)

---
**SOC PLAYBOOK**

### Step 1 — Server-Side Setup: Append-Only Storage

The secure server must be configured so that endpoints can **write and create** artifacts, but **cannot modify or delete** previously written files. This is the foundational integrity control of the entire DFR ecosystem.

```powershell
# Run on the Secure Server (Administrator)

# 1. Create the DFR share directory
New-Item -Path "D:\DFR_Evidence" -ItemType Directory

# 2. Create a dedicated write-only service account
New-LocalUser -Name "dfr_writer" -Password (ConvertTo-SecureString "P@ssw0rd!DFR" -AsPlainText -Force) -PasswordNeverExpires $true

# 3. Set NTFS ACL: dfr_writer can Create Files/Write Data, but NOT Delete or Modify
$acl = Get-Acl "D:\DFR_Evidence"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "dfr_writer",
    "CreateFiles, AppendData, WriteExtendedAttributes, WriteAttributes",
    "ContainerInherit, ObjectInherit",
    "None",
    "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl "D:\DFR_Evidence" $acl

# 4. Share the folder
New-SmbShare -Name "DFR_Secure" -Path "D:\DFR_Evidence" -FullAccess "Administrators" -ChangeAccess "dfr_writer"
```

> **Hardening Note:** Where available, enable **NTFS Object-Level WORM** or use a dedicated immutable storage solution (e.g., NetApp SnapLock, Azure Immutable Blob Storage) for regulatory-grade evidence preservation.

---

### Step 2 — Endpoint Configuration

**2a. Deploy Tool Binaries**

```powershell
# Run via GPO startup script or SCCM deployment
New-Item -Path "C:\DFR\tools" -ItemType Directory -Force
Copy-Item "\\DomainSysvol\DFR\RawCopy.exe" -Destination "C:\DFR\tools\"
Copy-Item "\\DomainSysvol\DFR\DumpIt.exe"  -Destination "C:\DFR\tools\"
Copy-Item "\\DomainSysvol\DFR\scripts\*"   -Destination "C:\DFR\scripts\"
```

**2b. Configure Central Settings (`config\dfr_config.psd1`)**

```powershell
@{
    SecureShare     = "\\SECURE-SRV\DFR_Secure"
    ServiceAccount  = "DOMAIN\dfr_writer"
    HashLogPath     = "\\SECURE-SRV\DFR_Secure\hash_manifest.log"
    HoneypotDir     = "C:\DFR\honeypot"
    IdleCpuThreshold = 10        # Percent — runs only below this
    FlagPollInterval = 30        # Seconds — polling rate
    DumpItPath      = "C:\DFR\tools\DumpIt.exe"
    RawCopyPath     = "C:\DFR\tools\RawCopy.exe"
}
```

---

### Step 3 — Task Scheduler Integration

Scripts are registered as Windows Scheduled Tasks. Trigger_Script run as persistent background services; Extractor_Script runs on an idle-time trigger.

**Register Extractor_Script (Proactive Triage — Idle Trigger):**

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -ExecutionPolicy Bypass -File C:\DFR\scripts\Extractor_Script.ps1"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle -IdleDuration (New-TimeSpan -Minutes 10) -IdleWaitTimeout (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "DFR-ProactiveTriage" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -User "SYSTEM"
```

**Register Trigger_Script (Honeypot — At Logon, Persistent):**

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\DFR\scripts\Trigger_Script.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "DFR-HoneypotMonitor" -Action $action -Trigger $trigger -RunLevel Highest -User "SYSTEM"
```

**Register Ram_Capturer (Containment — At Startup, Flag-Polling):**

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\DFR\scripts\Ram_Capturer.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "DFR-LiveContainment" -Action $action -Trigger $trigger -RunLevel Highest -User "SYSTEM"
```

---

### Step 4 — Validation & Testing

> All validation must be performed in an **isolated lab VM**, never on production systems.

**Test 1: Verify N1 Artifact Extraction**

```powershell
# Manually trigger Extractor_Script and confirm artifacts and hashes appear on secure share
& "C:\DFR\scripts\Extractor_Script.ps1" -Force

# Validate artifacts exist
Get-ChildItem "\\SECURE-SRV\DFR_Secure\" | Where-Object { $_.Name -match "MFT|SYSTEM|SAM" }

# Validate hash log was written
Get-Content "\\SECURE-SRV\DFR_Secure\hash_manifest.log" | Select-Object -Last 10
```

**Test 2: Trigger the Honeypot (Simulated Ransomware)**

```powershell
# Simulate a ransomware write event against the canary files
$canaryFile = Get-ChildItem "C:\DFR\honeypot\" | Select-Object -First 1
Rename-Item $canaryFile.FullName "$($canaryFile.FullName).encrypted"

# Confirm trigger.flag was created on secure server
Test-Path "\\SECURE-SRV\DFR_Secure\trigger.flag"   # Expected: True

# Confirm Security Event Log entry
Get-WinEvent -LogName Security | Where-Object { $_.Id -eq 9001 } | Select-Object -First 1
```

**Test 3: Confirm Ram_Capturer RAM Imaging and Kernel Lock**

```powershell
# Confirm .raw dump file was created after trigger
Get-ChildItem "\\SECURE-SRV\DFR_Secure\" -Filter "memdump_*.raw"

# Attempt to open/delete the dump (should fail — kernel lock active)
Remove-Item "\\SECURE-SRV\DFR_Secure\memdump_*.raw" -ErrorAction SilentlyContinue
# Expected output: "Access to the path is denied" — lock confirmed
```

---

## Forensic Integrity & Chain of Custody

The evidentiary value of this framework depends entirely on **cryptographic integrity verification**. Every artifact captured by the DFR Ecosystem is hashed using **SHA-256** at the moment of acquisition and logged with a UTC ISO-8601 timestamp to an append-only manifest.

### Hash Manifest Format

```
# DFR Hash Manifest — Auto-generated. Do not modify.
# Format: SHA256_HASH  FILENAME  ACQUISITION_TIMESTAMP(UTC)

A3F1C9...  $MFT_2025-06-17T03:00:01Z            2025-06-17T03:00:04.112Z
8B2D4E...  SYSTEM_HIVE_2025-06-17T03:00:01Z      2025-06-17T03:00:05.334Z
C7A0F2...  memdump_WORKSTATION01_20250617.raw     2025-06-17T07:42:18.891Z
```

### Integrity Verification (Post-Incident)

```powershell
# IR team verifies artifact integrity before analysis
$manifest = Import-Csv "\\SECURE-SRV\DFR_Secure\hash_manifest.log" -Delimiter "`t" -Header "Hash","File","Timestamp"
foreach ($entry in $manifest) {
    $filePath = "\\SECURE-SRV\DFR_Secure\$($entry.File)"
    $currentHash = (Get-FileHash $filePath -Algorithm SHA256).Hash
    if ($currentHash -ne $entry.Hash) {
        Write-Warning "INTEGRITY FAILURE: $($entry.File) — artifact may be tampered."
    } else {
        Write-Host "[VERIFIED] $($entry.File)" -ForegroundColor Green
    }
}
```

### Why Forensic Soundness Matters

| Control | Mechanism | Forensic Value |
|---|---|---|
| Append-Only Share | ACL write-create only; no delete/modify | Prevents ransomware or insider threat from destroying evidence |
| SHA-256 Hashing | At-acquisition, logged to immutable manifest | Proves artifact authenticity in legal proceedings |
| `FileShare::None` Lock | .NET kernel exclusive handle | Ensures memory dump cannot be opened or altered post-capture |
| Idle-Time Acquisition | CPU threshold gating | Minimizes forensic contamination from acquisition-induced I/O |
| RawCopy Extraction | Bypasses NTFS kernel lock | Captures `$MFT` and hives in their live, unmodified state |

---

## Limitations & Known Constraints

| Constraint | Detail |
|---|---|
| **Kernel lock persistence** | The `FileShare::None` stream held by N3 is released upon process termination or system reboot. Ensure Ram_Capturer runs as SYSTEM with restart-on-failure configured. |
| **RawCopy privilege requirement** | `$MFT` extraction requires local Administrator or `SeBackupPrivilege`. Enforce via GPO. |
| **DumpIt 32/64-bit parity** | Use the DumpIt binary matching the endpoint OS architecture. Mismatches produce incomplete dumps. |
| **Honeypot evasion** | Sophisticated ransomware strains that enumerate canary file signatures may evade detection. Randomize honeypot file names and extensions regularly. |
| **Large memory endpoints** | Endpoints with >64 GB RAM will produce correspondingly large dump files. Pre-provision adequate storage and monitor share capacity. |

---

## Contributing

Pull requests targeting the `/scripts/` or `/playbooks/` directories are welcome. All contributions must:
1. Pass PowerShell ScriptAnalyzer (`Invoke-ScriptAnalyzer`) with no High-severity findings.
2. Include updated SHA-256 verification logic if acquisition methods are modified.
3. Be tested in a documented lab environment (include VM snapshot details in the PR body).

---

## References

- ACPO Good Practice Guide for Digital Evidence (v5)
- NIST SP 800-86: Guide to Integrating Forensic Techniques into Incident Response
- ISO/IEC 27037:2012 — Guidelines for Identification, Collection, Acquisition and Preservation of Digital Evidence
- Carrier, B. (2005). *File System Forensic Analysis*. Addison-Wesley.
- Microsoft Docs: [FileSystemWatcher Class](https://docs.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher)
- Microsoft Docs: [WMI Event Subscriptions](https://docs.microsoft.com/en-us/windows/win32/wmisdk/receiving-a-wmi-event)

