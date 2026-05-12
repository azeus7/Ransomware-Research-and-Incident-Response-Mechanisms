# Digital Forensic Readiness Scripts

PowerShell tooling for early ransomware detection, live response, and
acquisition of volatile/non-volatile evidence on Windows endpoints.

## Components

- `Extractor_Script.ps1` - Logical artifact extraction (MFT, NTUSER hives,
  registry hives) with SHA-256 verification and an Info log.
- `Trigger_Script.ps1` - Early ransomware warning. Watches for suspicious
  process commands (vssadmin shadow deletion, bcdedit, wevtutil clear, etc.)
  via WMI, plus a honeypot bait folder on the user's desktop.
- `Ram_Capturer/Ram_Capturer.ps1` - Live RAM acquisition via DumpIt, with an
  exclusive file lock to protect the resulting image until shutdown.
- `Ram_Capturer/Starter.bat` - Launcher for the RAM capturer from a USB drive.

## Authors

- Alexandra Ananskikh <a_ananskikh@cu.edu.ge>
- Levan Tamazashvili <l_tamazashvili2@cu.edu.ge>
