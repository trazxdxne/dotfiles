---
name: windows-sysadmin
description: Diagnose and operate Windows hosts, services, packages, NTFS permissions, Defender, Windows Firewall, scheduled tasks, and remote access. Use for host-level work that is not primarily an application-specific or container task.
---

# windows-sysadmin

## Workflow

1. Gather diagnostics for the reported symptom and relevant event log interval.
   Do not run every example below for an isolated service issue.
2. Determine whether the failure is host-level or primarily belongs to a
   specialized application, container, or cross-system infrastructure skill.
3. For an authorized fix, identify impact and recent changes, then prepare
   rollback for the files, packages, services, registry keys, scheduled tasks,
   or firewall rules being changed.
4. Implement the smallest host-level fix and validate runtime behavior, remote
   access, security policy, and service startup persistence.

## Diagnostics

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Get-Volume
Get-CimInstance Win32_OperatingSystem | Select-Object @{N="FreeGB";E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}, @{N="TotalGB";E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}
Get-Service -Name <service>
sc.exe qc <service>
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3} -MaxEvents 30 | Format-Table -AutoSize
Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2,3} -MaxEvents 30 | Format-Table -AutoSize
Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess
Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusEnabled
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
Get-ScheduledTask -TaskName <task>
icacls <path>
```

## Safety Rules

- Never disable Microsoft Defender Antivirus or Real-Time Protection as a
  default fix.
- Never modify remote access (WinRM, OpenSSH, RDP) or authentication policies
  without rollback.
- Never modify firewall rules without confirming active profile (Domain,
  Private, Public).
- Prefer service configuration overrides and dedicated service accounts over
  granting broad `SYSTEM` or administrative rights.
- Export registry keys before editing (`reg.exe export <KeyPath> <file.reg>`).
  Never execute broad or recursive registry deletions.
- Preserve NTFS inheritance, existing security descriptors, and integrity
  levels (prefer targeted `icacls` grants over `takeown` or stripping inherited
  ACEs).

## Validation

- The affected service or scheduled task runs and its startup configuration is
  correct. Reboot only when authorized; distinguish inspection from a verified
  reboot test.
- Event logs (`System`, `Application`) show no new errors or warnings for the
  component.
- Expected ports listen and unexpected ports do not.
- Remote management access (WinRM, SSH, or RDP) remains functional.
- Defender protection state and Windows Firewall profile rules match intended
  policy.
- File system access controls allow required accounts without opening broad
  permissions.
