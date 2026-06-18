# Post-Incident Lab Analysis & Forensic Reconstruction Guide

---

## Overview

Once the automated collection phase has concluded - artifacts preserved by Extractor_Script, detection confirmed by Trigger_Script, and volatile memory locked by Ram_Capturer - the investigation transitions to the analytical phase. This phase transforms raw forensic artifacts into a structured, chronologically coherent reconstruction of the attack, establishing the evidentiary foundation required for incident reporting, threat intelligence production, and, where applicable, legal proceedings.

The analytical methodology is organized into four sequential sub-phases, each targeting a distinct artifact class and analytical objective.

---

## Table of Contents

1. [Phase A - Network Telemetry & Behavioral Gating](#phase-a--network-telemetry--behavioral-gating)
   - [Process Creation and Log Telemetry](#process-creation-and-log-telemetry)
   - [Network Traffic Baselining (Wireshark)](#network-traffic-baselining-wireshark)
2. [Phase B - Process Behavior & Subsystem Interference](#phase-b--process-behavior--subsystem-interference)
   - [Inhibition of System Recovery Capabilities](#inhibition-of-system-recovery-capabilities)
   - [Service Disruption and Resource Unlocking](#service-disruption-and-resource-unlocking)
3. [Phase C - Advanced Artifact Parsing (Eric Zimmerman Toolkit)](#phase-c--advanced-artifact-parsing-eric-zimmerman-toolkit)
   - [MFT Parsing via MFTEcmd](#mft-parsing-via-mftecmd)
   - [Timeline Synthesis (Timeline Explorer)](#timeline-synthesis-timeline-explorer)
   - [Registry Forensics (Registry Explorer)](#registry-forensics-registry-explorer)
4. [Phase D - Differential Integrity Assessment (WinMerge)](#phase-d--differential-integrity-assessment-winmerge)
5. [Analytical Phase Summary](#analytical-phase-summary)

---

## Phase A - Network Telemetry & Behavioral Gating

### Process Creation and Log Telemetry

Kernel-level system monitoring tooling - deployed as a background service on endpoints prior to any incident - provides a high-fidelity audit trail of binary execution events at the operating system level. During post-incident reconstruction, investigators parse this telemetry to recover the complete execution lineage of the malicious payload, including:

- **Binary execution paths** - the full filesystem path from which each process was launched, enabling identification of staging directories, temporary drop zones, and masquerading attempts where a malicious binary assumes the name of a legitimate system executable.
- **Command-line argument capture** - the complete argument string passed to each spawned process, exposing encoded payloads, base64-obfuscated commands, and embedded configuration parameters that would otherwise be invisible in a process listing alone.
- **Parent-child process relationships** - the hierarchical tree of process ancestry, which is the primary mechanism for identifying process injection, living-off-the-land binary (LOLBin) abuse, and defense evasion techniques where adversarial code is spawned beneath a trusted parent to inherit its trust context.

This execution telemetry is cross-correlated with system-level DNS query logs to map the full scope of outbound callback activity. Anomalous DNS resolution patterns - particularly those exhibiting high query frequency, algorithmically generated domain structures, or resolution to infrastructure with no prior organizational contact history - provide the forensic basis for mapping malicious command-and-control (C2) communication channels, even in cases where network traffic itself was encrypted or suppressed.

### Network Traffic Baselining (Wireshark)

Packet capture streams (`.pcapng` format) collected from the compromised network segment are subjected to behavioral baseline analysis using Wireshark. The analytical objective is not to reconstruct individual packet payloads - which are typically encrypted by modern ransomware - but rather to isolate **traffic pattern anomalies** that are structurally invariant regardless of encryption:

- **Aggressive internal replication behavior** - a sudden, high-volume surge in intra-network traffic directed across multiple internal hosts within a compressed timeframe, indicative of automated lateral movement and remote execution attempts.
- **Mass internal port scanning** - sequential, systematic connection attempts across contiguous internal address ranges on ports associated with administrative protocols, consistent with pre-encryption reconnaissance phases designed to enumerate vulnerable targets.
- **Anomalous protocol volume transitions** - disproportionate increases in high-overhead administrative protocol traffic (such as file-sharing or remote procedure call overhead) that deviate significantly from the established organizational baseline, signaling automated file access traversal across network-accessible storage resources.

These behavioral signatures collectively constitute a network-layer fingerprint of the lateral movement phase, independent of any payload-level indicators.

---

## Phase B - Process Behavior & Subsystem Interference

### Inhibition of System Recovery Capabilities

A consistent behavioral signature of enterprise-targeting ransomware is the deliberate, pre-encryption annihilation of host-based recovery infrastructure. Using real-time process and system call monitoring tooling, investigators document the precise sequence of low-level system commands executed by the malicious payload to eliminate the organization's ability to recover data through built-in operating system mechanisms.

This behavioral pattern typically manifests as the covert invocation of native system recovery management utilities - processes that are ordinarily legitimate administrative tools - with argument strings specifically constructed to enumerate and irreversibly destroy all available local recovery points, shadow volume copies, and system state backups. The forensic significance of this behavioral artifact is twofold: it establishes intent (the adversary was explicitly attempting to eliminate recovery options, not merely encrypting data), and it provides a precise timestamp anchor for the pre-encryption preparation phase of the attack chain.

### Service Disruption and Resource Unlocking

Before initiating mass file encryption, ransomware payloads systematically identify and terminate background enterprise services that maintain persistent file locks on high-value data stores. This behavior is forensically observable as an anomalous cascade of service termination events targeting processes associated with database engines, communication platforms, enterprise resource management systems, and backup agents.

The operational objective of this disruption phase is to bypass the operating system's file-locking mechanisms, which would otherwise present the encryption module with `file-in-use` access errors on open database files, mail stores, and other continuously accessed corporate data assets. By terminating the owning service process, the ransomware releases these kernel-level locks and gains uncontested cryptographic write access to the underlying data files. Documenting this service disruption sequence provides investigators with a precise delineation of the **encryption commencement boundary** - the moment at which the payload transitioned from preparation to active data destruction.

---

## Phase C - Advanced Artifact Parsing (Eric Zimmerman Toolkit)

### MFT Parsing via MFTEcmd

The `$MFT` (Master File Table) binary streams captured proactively by Extractor_Script - one representing the pre-incident filesystem state and one acquired post-incident - are compiled into structured analytical matrices using **MFTEcmd.exe**, the command-line parsing engine from the Eric Zimmerman forensic toolkit.

MFTEcmd parses the binary `$MFT` structure and exports its content as a structured CSV dataset containing, for each file system entry: full path, file size, created/modified/accessed/MFT-entry-modified timestamps (MACB), parent directory reference, sequence number, and flags. This output format enables high-throughput analytical operations - sorting, filtering, pivoting, and differential comparison - across file systems containing hundreds of thousands of entries, at a scale that is operationally infeasible through GUI-based inspection alone.

**Recommended invocation pattern:**

```bash
# Parse pre-incident MFT snapshot to structured CSV
MFTEcmd.exe -f "\\SECURE-SRV\DFR_Secure\MFT_pre_incident.bin" --csv "C:\IR\Analysis\" --csvf mft_before.csv

# Parse post-incident MFT snapshot to structured CSV
MFTEcmd.exe -f "\\SECURE-SRV\DFR_Secure\MFT_post_incident.bin" --csv "C:\IR\Analysis\" --csvf mft_after.csv
```

> **⚠️ FORENSIC NOTE - SCALING CONSTRAINT: MFTExplorer (GUI)**
>
> MFTExplorer provides a highly effective visual node-tree interface for navigating filesystem metadata in small-scale or targeted investigations. However, in enterprise production environments, the `$MFT` binary frequently exceeds several hundred megabytes to multiple gigabytes in scale. At this data volume, MFTExplorer exhibits significant memory consumption boundaries and documented instability, including unresponsive states and incomplete tree population, that render it operationally unsuitable for full-scope enterprise incident analysis.
>
> **For all enterprise-scale deployments, CLI parsing via MFTEcmd combined with structured data-table analysis in Timeline Explorer is strictly mandated.** MFTExplorer remains appropriate for targeted, scoped investigations on isolated file system subsets where its visual interface provides analytical value without triggering scale-related instability.

### Timeline Synthesis (Timeline Explorer)

The CSV datasets produced by MFTEcmd - covering pre-incident and post-incident filesystem states - are ingested alongside enriched system security log exports into **Timeline Explorer** to construct a unified, millisecond-resolution chronological map of the incident.

The central analytical objective of this synthesis is to establish the precise **temporal convergence** between:

1. The earliest filesystem mutation events recorded in the post-incident `$MFT` export - specifically, the first appearance of encrypted file extensions across monitored directories.
2. The timestamped alert record generated by Trigger_Script (the Honeypot Detection Engine) at the moment the canary files were accessed or modified by the encryption process.

When these two independent data streams - one derived from raw NTFS metadata, the other from the behavioral detection layer - converge on the same timestamp within an acceptable margin, they produce a **mutually corroborating chronological anchor** that constitutes forensically robust evidence of the detection event. This convergence also establishes the outer boundary of the encryption timeline, enabling investigators to calculate the total elapsed encryption duration and estimate the volume of data affected within each measured interval.

Timeline Explorer's filtering and column-sort capabilities enable analysts to rapidly isolate: files renamed to adversarial extensions, directories traversed by the encryption process, and the precise sequence of system events preceding and following the Trigger_Script alert - delivering the complete attack reconstruction chain required for both internal incident reporting and external threat intelligence sharing.

### Registry Forensics (Registry Explorer)

The Registry hive files extracted by Extractor_Script — including the system-level `SYSTEM` and `SOFTWARE` hives and the per-user `NTUSER.DAT` hives - are subjected to deep structural inspection using **Registry Explorer** to map the persistence mechanisms and configuration artifacts established by the malicious payload.

The primary investigative targets within the Registry are:

- **Persistence key mutations** - entries written to or modified within autostart extension points (such as `Run` and `RunOnce` keys within both the machine-scope and user-scope hive branches). The presence of adversarial binary references in these keys confirms that the payload established a mechanism for re-execution across system reboots, which has direct implications for both eradication completeness and the accuracy of the initial access timeline.
- **Cryptographic configuration artifacts** - registry keys created or modified by the execution payload to store encryption state, key material references, configuration flags, or ransom note delivery parameters. These artifacts may expose the payload's operational logic and, in cases where key material is incompletely protected, may contribute to decryption recovery efforts.
- **User activity reconstruction via NTUSER.DAT** - analysis of the user-scope hive to recover the most recently accessed files, recently opened application paths, and shell activity records contemporaneous with the infection event, which assists in attributing the initial execution vector to a specific user action or automated delivery mechanism.

The temporal metadata of Registry key modifications - captured in hive transaction logs and cell sequence numbers - is cross-referenced against the MFT timeline to further refine the attack chronology.

---

## Phase D - Differential Integrity Assessment (WinMerge)

The most operationally immediate output of the post-incident analytical phase - the damage assessment - is produced through a structured differential comparison of the pre-incident and post-incident `$MFT` CSV exports using **WinMerge**.

WinMerge's file and directory comparison engine is applied to the two structured CSV datasets to perform a side-by-side, line-level differential analysis across the complete file system metadata record. Because MFTEcmd normalizes both the pre-incident and post-incident `$MFT` structures into an identical CSV schema, WinMerge is able to perform a mathematically precise, row-by-row comparison of every file system entry across both states, automatically isolating every record that differs between them.

This differential operation surfaces three forensically significant categories of change:

| Change Category | Forensic Indicator | Analytical Significance |
|---|---|---|
| **Extension mutations** | File entries present in both snapshots where the filename suffix has changed to an adversarial encryption marker | Direct enumeration of all encrypted files; precise damage scope quantification |
| **File renames and path relocations** | Entries where the filename or parent directory reference has changed between snapshots | Identification of files moved to staging directories, ransom note drop locations, or decoy paths |
| **Structural metadata alterations** | Entries where file size, timestamp, or MFT sequence number have changed without an extension mutation | Detection of partial encryption, file truncation, or metadata manipulation by the payload |

The resulting WinMerge differential output constitutes an **immediate, mathematically precise damage assessment matrix** - a complete enumeration of every file system object affected by the ransomware execution, with change type, file path, and pre/post metadata values recorded for each entry. This output directly feeds the quantitative impact assessment section of the post-incident report and provides the operational basis for scoping the data recovery effort against available backup sources.

---

## Analytical Phase Summary

| Sub-Phase | Primary Tools | Artifact Sources | Output |
|---|---|---|---|
| **A - Network Telemetry** | Wireshark, Sysmon | `.pcapng` captures, process execution logs | C2 infrastructure map; lateral movement timeline |
| **B - Process Behavior** | Process Hacker, Procmon | Live process telemetry, system call logs | Recovery inhibition evidence; encryption commencement boundary |
| **C - Artifact Parsing** | MFTEcmd, Timeline Explorer, Registry Explorer | `$MFT` binaries, Registry hives, Event Log exports | Unified attack chronology; persistence mechanism map |
| **D - Differential Assessment** | WinMerge | Pre/post-incident `$MFT` CSV exports | Complete damage matrix; encrypted file enumeration |

The outputs of all four sub-phases are consolidated into the post-incident report and cross-referenced against the SHA-256-verified artifact manifest maintained by the DFR Ecosystem's collection layer to produce a forensically defensible, end-to-end reconstruction of the incident - from the pre-infection baseline through the encryption event to the post-incident system state.

---

