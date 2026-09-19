# IT Helpdesk Driver Update Toolkit (Windows)

A PowerShell automation tool built for IT helpdesk and desktop support operations. It scans Windows systems for available driver updates via Windows Update, logs results with timestamps, and installs updates on demand — with a safe scan-only mode by default.

## Why this exists

Manually checking Device Manager for outdated drivers across multiple machines is slow and easy to forget. This script automates that check, gives support staff a clear log they can attach to a ticket, and avoids surprise reboots on a live user session.

## Features

- **Scan-only by default** — reports available driver updates without changing anything, so a technician can review before applying.
- **Optional install mode** (`-Install`) — downloads and installs detected driver updates.
- **Timestamped logging** — every run writes a log file to `C:\IT\Logs`, useful for audit trails and ticket documentation.
- **Admin self-elevation** — automatically relaunches with administrator rights if not already elevated.
- **Controlled reboot handling** — only restarts automatically if `-Reboot` is explicitly passed; otherwise it flags that a reboot is needed.
- **Auto-installs dependencies** — installs the `PSWindowsUpdate` module if it isn't already present.

## Requirements

- Windows 10/11
- PowerShell 5.1+ (run as Administrator)
- Internet access to Windows Update

## Usage

Scan for available driver updates only (no changes made):
```powershell
.\Update-Drivers.ps1
```

Scan and install available driver updates:
```powershell
.\Update-Drivers.ps1 -Install
```

Install updates and reboot automatically if required:
```powershell
.\Update-Drivers.ps1 -Install -Reboot
```

Specify a custom log location:
```powershell
.\Update-Drivers.ps1 -Install -LogPath "D:\Logs"
```

## Example log output

```
[2026-09-19 14:02:11] [INFO] ===== Driver Update Script Started =====
[2026-09-19 14:02:11] [INFO] Computer: DESKTOP-01 | User: jsmith
[2026-09-19 14:02:11] [INFO] Mode: SCAN ONLY
[2026-09-19 14:02:14] [INFO] Found 2 driver update(s):
[2026-09-19 14:02:14] [INFO]  - Intel(R) Wireless-AC 9560 - Network Adapter
[2026-09-19 14:02:14] [INFO]  - NVIDIA - Display
[2026-09-19 14:02:14] [INFO] Scan-only mode: no updates were installed. Re-run with -Install to apply them.
[2026-09-19 14:02:14] [INFO] ===== Driver Update Script Finished =====
```

## Notes

- Always test on a non-critical machine before deploying widely.
- Run in scan-only mode first to review what will be installed.
- Avoid using `-Reboot` on active user sessions — prompt the user manually instead.

## Author

Paul Mukupe
