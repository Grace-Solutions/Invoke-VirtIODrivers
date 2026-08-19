# Invoke-VirtIODrivers

Downloads the latest VirtIO ISO if necessary, copies the ISO locally if necessary, mounts the ISO automatically, dynamically detects the operating system, and installs the correct drivers for Proxmox virtual machines into the Windows driver store using DISM or PNPUTIL. The QEMU guest agent can optionally be installed directly from the mounted ISO when running within the full operating system.

This script can be run from a WindowsPE boot image after the operating system has been deployed to the fixed disk and the target volume will be located automatically by locating a valid installation of Windows.

This script can also be directly used within the full operating system to install the drivers after the fact or before a hypervisor migration. (VMWare to Proxmox).

## Structure

The script follows the standardized script template and toolkit flow. The `Toolkit\Toolkit.ps1` script is dot sourced during initialization and provides the logging, error handling, environment detection, and function/module/library loading infrastructure. The reusable helper functions live within `Toolkit\Functions`, and the registry parsing libraries live within `Toolkit\Libraries\Registry`.

The script is compatible with both Windows PowerShell 5.1 (including the WindowsPE PowerShell optional component) and PowerShell 7.

## Usage

```powershell
#Install the VirtIO drivers and the QEMU guest agent (works in WindowsPE and the full operating system - the guest agent portion is skipped automatically within WindowsPE and when it is already installed)
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\Invoke-VirtIODrivers.ps1" -Install -InstallGuestAgent

#Same command using PowerShell 7 (required within DeployR boot images)
pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\Invoke-VirtIODrivers.ps1" -Install -InstallGuestAgent
```

| Parameter | Description |
|:--|:--|
| `-Install` | Download the VirtIO driver ISO (if required) and install the relevant drivers for the detected operating system. |
| `-InstallGuestAgent` | Install the QEMU guest agent from the mounted ISO. Recommended on every run: the installation is skipped automatically within WindowsPE (where the Windows Installer service is unavailable) and when the installed version is already current. |
| `-DownloadURL` | Override the VirtIO ISO download URL. Defaults to the latest stable VirtIO ISO. |
| `-DownloadDestinationDirectory` | Override the ISO download destination. Defaults to `Content\ISOs` beside the script. |
| `-LogDirectory` | Override the log directory. Sensible defaults are used for WindowsPE, task sequence, and full operating system scenarios. |

The ISO download automatically detects and uses the system default proxy with default credentials.

## OS deployment scenarios (DeployR, MDT, SCCM)

During OS deployment the script needs to run **twice**:

1. **Boot image (WindowsPE)** — after the operating system image has been applied, run with `-Install -InstallGuestAgent` to inject the VirtIO drivers into the offline operating system using DISM, so the deployed OS can boot on VirtIO virtual hardware on first startup (the guest agent portion is skipped automatically within WindowsPE).
2. **Full operating system** — run the same command again to register the drivers with pnputil and install the QEMU guest agent.

OS detection is handled automatically in both passes, so the command line is the same aside from the interpreter. DeployR boot images only contain PowerShell 7, so the script must be launched with `pwsh.exe` there:

```powershell
pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\Invoke-VirtIODrivers.ps1" -Install -InstallGuestAgent
```

Note: the boot image itself must already contain the VirtIO drivers (added ahead of time using your preferred boot image servicing method), otherwise WindowsPE cannot see VirtIO SCSI disks or network adapters. Alternatively, the virtual machine can use non-VirtIO virtual hardware (for example SATA disks and an emulated E1000 network adapter), which works without servicing the boot image but carries a performance penalty.

## Virtual machine templates and hypervisor migration

**Template creation**: run the script within the full operating system with `-Install -InstallGuestAgent` before converting the virtual machine into a template, so every clone comes up VirtIO-ready with the QEMU guest agent already installed.

**Hypervisor migration (VMware ESXi to Proxmox)**: run the script within the full operating system with `-Install -InstallGuestAgent` before the migration. The VirtIO devices do not exist yet at that point, so pnputil simply stages the driver packages into the Windows driver store. On first boot under the new hypervisor, Plug and Play matches the staged drivers automatically and the VM boots on VirtIO SCSI disk controllers and virtual network adapters without a recovery pass. No more blue screens!

This exact flow was used in a production migration from VMware ESXi to Proxmox: the script was run within the full operating system of each VM before migration, and after cutover, over 30 Windows VMs came up without issue.

Re-running the script is always safe: the Windows driver store handles already-present driver packages (pnputil and DISM skip or version-rank existing packages rather than creating conflicts), so drivers that are already installed are never a problem.

Note: `Invoke-VirtIODrivers.exe` is just there as a powershell bootstrapper. If you double click the executable, it simply executes the Powershell script with the same name automatically and shows the execution window. Nothing more.

## Offline registry hive detection

Within WindowsPE, the deployed operating system details are read directly from the offline `SOFTWARE` registry hive of the deployed volume **without loading or mounting the hive**, using the [Eric Zimmerman Registry library](https://github.com/EricZimmerman/Registry) (version 2026.5.0, netstandard2.0), which parses the raw REGF hive file format. The library and its dependency closure are stored within `Toolkit\Libraries\Registry` and are loaded into memory in dependency order (no file locks): byte loaded within Windows PowerShell, and stream loaded into a dedicated assembly load context within PowerShell 7.

<img width="827" alt="Snag_612d0a7" src="https://github.com/user-attachments/assets/94b2a150-3b33-4220-ae22-69dff1954ee7" />
<img width="519" alt="Snag_612df8b" src="https://github.com/user-attachments/assets/e8039cfb-63fe-4761-b3ee-1fddadb28370" />
<img width="968" alt="Snag_62f90f1" src="https://github.com/user-attachments/assets/8d86cab5-138e-43a5-94cf-378420ea6cfb" />

This is sample output of the Windows Driver Store using Powershell after the drivers have been installed.

Command: **Get-WindowsDriver -Online \| Where-Object {(\$\_.ProviderName -imatch '(.\*Red.\*Hat.\*)')} \| Select-Object -Property @('OriginalFileName', 'ClassName', 'BootCritical', 'ProviderName', 'Version', 'ClassGUID')**

|BootCritical|ClassGuid|ClassName|OriginalFileName|ProviderName|Version|
|:--|:--|:--|:--|:--|:--|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\balloon.inf\_amd64\_eaf9fe5ccc46cea0\\balloon.inf|Red Hat, Inc.|100.94.104.24800|
|False|{4D36E972-E325-11CE-BFC1-08002BE10318}|Net|C:\\Windows\\System32\\DriverStore\\FileRepository\\netkvm.inf\_amd64\_108667f5ebeb0ad0\\netkvm.inf|Red Hat, Inc.|100.94.104.24800|
|False|{4D36E975-E325-11CE-BFC1-08002BE10318}|NetTrans|C:\\Windows\\System32\\DriverStore\\FileRepository\\vioprot.inf\_amd64\_5abf6da903f19370\\vioprot.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\viofs.inf\_amd64\_9d8003dbf4948969\\viofs.inf|Red Hat, Inc.|100.94.104.24800|
|False|{4D36E968-E325-11CE-BFC1-08002BE10318}|Display|C:\\Windows\\System32\\DriverStore\\FileRepository\\viogpudo.inf\_amd64\_d108681ae5f48232\\viogpudo.inf|Red Hat, Inc.|100.94.104.24800|
|True|{745A17A0-74D3-11D0-B6FE-00A0C90F57DA}|HIDClass|C:\\Windows\\System32\\DriverStore\\FileRepository\\vioinput.inf\_amd64\_32a7b4d6e1632c93\\vioinput.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\viorng.inf\_amd64\_dfa2dff76d3c06c9\\viorng.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\vioser.inf\_amd64\_650b7c25b9f9e8bc\\vioser.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97B-E325-11CE-BFC1-08002BE10318}|SCSIAdapter|C:\\Windows\\System32\\DriverStore\\FileRepository\\vioscsi.inf\_amd64\_9717e9d0dbb31583\\vioscsi.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97B-E325-11CE-BFC1-08002BE10318}|SCSIAdapter|C:\\Windows\\System32\\DriverStore\\FileRepository\\viostor.inf\_amd64\_3e677331b798639a\\viostor.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\fwcfg.inf\_amd64\_c9590a85c7935d96\\fwcfg.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\pvpanic.inf\_amd64\_5041c2d4340b58fb\\pvpanic.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\pvpanic-pci.inf\_amd64\_d9c6c27cd62af2f6\\pvpanic-pci.inf|Red Hat, Inc.|100.94.104.24800|
|True|{4D36E97D-E325-11CE-BFC1-08002BE10318}|System|C:\\Windows\\System32\\DriverStore\\FileRepository\\smbus.inf\_amd64\_5f03787cbdf7a56d\\smbus.inf|Red Hat, Inc.|100.0.0.0|
