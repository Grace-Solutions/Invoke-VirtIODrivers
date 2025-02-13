# Invoke-VirtIODrivers
Downloads the latest VirtIO ISO if necessary, copies the ISO locally if necessary, mounts the ISO automatically, dynamically detects the operating system, and installs the correct drivers for Proxmox virtual machines into the Windows driver store using DISM.

This script can be run from a WindowsPE boot image before the operating system has been deployed or directly within the full operating system to install the drivers after the fact or before a hypervisor migration. (VMWare to Proxmox)

During Hypervisor migration scenarios where WindowsPE will likely not be invovled, just run this powershell script before migration to get the drivers staged into the driver store. Then once the virtual machine has been migrated, it should be able boot just fine when using VirtIO SCSI disk controllers, and virtual network adapters. No more blue screens!

Note: The VBScript is just there as a powershell bootstrapper. If you double click the VBS script, it simply executes the Powershell script with the same name automatically and shows the execution window. Nothing more.

<img width="827" alt="Snag_612d0a7" src="https://github.com/user-attachments/assets/94b2a150-3b33-4220-ae22-69dff1954ee7" />
<img width="519" alt="Snag_612df8b" src="https://github.com/user-attachments/assets/e8039cfb-63fe-4761-b3ee-1fddadb28370" />
<img width="969" alt="Snag_613014c" src="https://github.com/user-attachments/assets/073dc480-ae2b-4c39-add5-1448ba425616" />
