A windows Disk image builder tool to the Disk Image Builder project. This Windows tool runs on any Windows machine
and generate VHD/QCOW2 image directly from an ISO without needing to standup a VM on Hypervisor. This tool 
uses windows native commands like ImageX, DISM, and Diskpart to generate disk images which can work for both VMs and
Baremetal Servers. This is made possible by injecting user provided drivers using DISM while building the image.

Creates a Image file, Includes cloudbase-init package by default.
User can create image by adding custom drivers, VirIO Drivers by providing suitable ISO or inf files. Enable Roles like Hyperv , TFTP etc., Use below formats to run script.

Runs on Windows 8, 8.1 and 2012 R2

Requires Powershell 3.0 or above and wim file from ISO Source folder. ISO is not required. Only Wim file is enough to generate and apply wim to vhd.

Basic Usage
.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd>

Enabling Feature like TFTP
.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -feature TFTP

Add Drivers to images. It auto adds all drivers present in the drivers folder 
.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -DriversPath <path to drivers folder>

Add Unattend answer file
.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd>  -UnattendPath <path>\unattend.xml

Add VirtIO Drivers
.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -VirtIOPath <path>\virtio.iso

All Commands Usage
.\diskimagebuilder.ps1  -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -feature <featuretoenable> -UnattendPath <path>\unattend.xml -DriversPath <path to drivers folder> -CloudbaseInitMsiUrl < your cloudbaseinit msi url>
