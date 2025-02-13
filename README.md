# Invoke-VirtIODrivers
Downloads the latest VirtIO ISO if necessary, copies the ISO locally if necessary, mounts the ISO automatically, dynamically detects the operating system, and installs the correct drivers for Proxmox virtual machines into the Windows driver store using DISM.

This script can be run from a WindowsPE boot image before the operating system has been deployed or directly within the full operating system to install the drivers after the fact or before a hypervisor migration. (VMWare to Proxmox)

During Hypervisor migration scenarios where WindowsPE will likely not be invovled, just run this powershell script before migration to get the drivers staged into the driver store. Then once the virtual machine has been migrated, it should be able boot just fine when using VirtIO SCSI disk controllers, and virtual network adapters. No more blue screens!

Note: The VBScript is just there as a powershell bootstrapper. If you double click the VBS script, it simply executes the Powershell script with the same name automatically and shows the execution window. Nothing more.

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
