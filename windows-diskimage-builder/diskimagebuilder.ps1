# Creates a Image file, Includes cloudbase-init package by default.
# User can create image by adding custom drivers, VirIO Drivers by providing suitable ISO or inf files. Enable Roles like Hyperv , TFTP etc., Use below formats to run script.

# Runs on Windows 7, 8, 8.1 and 2012 R2

# Requires Powershell 3.0 or above and wim file from ISO Source folder. ISO is not required. Only Wim file is enough to generate and apply wim to vhd.

# Basic Usage
#.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd>

# Enabling Feature like TFTP
#.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -feature TFTP

# Add Drivers to images. It auto adds all drivers present in the drivers folder 
#.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -DriversPath <path to drivers folder>

#Add Unattend answer file
#.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd>  -UnattendPath <path>\unattend.xml

#Add VirtIO Drivers
#.\diskimagebuilder.ps1 -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -VirtIOPath <path>\virtio.iso

# All Commands Usage
#.\diskimagebuilder.ps1  -SourceFile <path>\install.wim -VHDFile <path>\VHDFilename -VHDSize <size of vhd> -feature <featuretoenable> -UnattendPath <path>\unattend.xml -DriversPath <path to drivers folder> -baudrate <value> -OutputFormat vhd/qcow2 (Default will be vhd)

Param(
[Parameter(mandatory=$True,HelpMessage="Name and path of Sourcefile (WIM).")]
[ValidateNotNullOrEmpty()]
[ValidateScript({ Test-Path $(Resolve-Path $_) })]
[String]$SourceFile,

[parameter(mandatory=$True,HelpMessage="Name and path of VHD or VHDx file.")]
[ValidateNotNullOrEmpty()]
[String]$VHDFile,

[parameter(mandatory=$True,HelpMessage="Size of VHD or VHDx file.")]
[ValidateNotNullOrEmpty()]
[String]$VHDSize,

[parameter(HelpMessage="feature to enable.")]
[ValidateNotNullOrEmpty()]
[String]$feature,

[parameter(HelpMessage="Index of the wim.")]
[ValidateNotNullOrEmpty()]
[String]$Index,

[parameter(HelpMessage="Unattended xml file path")]
[ValidateNotNullOrEmpty()]
[String]$UnattendPath,

[parameter(HelpMessage="cloudbaseinit msi url")]
[ValidateNotNullOrEmpty()]
[String]$CloudbaseInitMsiUrl,

[parameter(HelpMessage="Serial port baudrate")]
[ValidateNotNullOrEmpty()]
[String]$serialbaudrate,

[parameter(HelpMessage="Add Drivers Folder Path.")]
[ValidateNotNullOrEmpty()]
[String]$DriversPath,

[parameter(HelpMessage="Output format vhd\qcow2.")]
[ValidateNotNullOrEmpty()]
[String]$OutputFormat,

[parameter(HelpMessage="Add Drivers From Virtio ISO.")]
[ValidateNotNullOrEmpty()]
[String]$VirtIOPath

)

$name = "createimage"
$currdate = get-date -f yyyy-MM-dd


write-host $args


if(!$UnattendPath){

    $UnattendPath = "unattend.xml"
	
}	

if(!$CloudbaseInitMsiUrl){

    $CloudbaseInitMsiUrl = "http://www.cloudbase.it/downloads/CloudbaseInitSetup_Beta.msi"  
	
}	

if(!$serialbaudrate){

    $serialbaudrate = "9600"
	
}	
if($OutputFormat){
    $arrFormats = @("vhd", "qcow2")
	$Found = 0
	for ($i=0; $i -lt $arrFormats.length; $i++) {
	    if($arrFormats[$i] -eq $OutputFormat){
		    $Found = 1
		}
	}
	if(!$Found){
	   Write-W2VInfo "Not a valid output format"
	   exit
	}
}	

$VHDVolume = 'v'
$Error = 0
if(!$Index){
$Index = 1
}

$VHDloc = Split-Path $VHDFile -Parent
$testpaths = @($SourceFile, $VirtIOPath, $DriversPath, $UnattendPath, $VHDloc)

function
    Write-W2VError {
    # Function to make the Write-Host (NOT Write-Error) output prettier in the case of an error.
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [string]
            [ValidateNotNullOrEmpty()]
            $text
        )
        Write-Host "ERROR  : $($text)" -ForegroundColor green
    }

	
function Write-W2VInfo {
    # Function to make the Write-Host output a bit prettier. 
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [string]
            [ValidateNotNullOrEmpty()]
            $text
        )
        Write-Host "INFO   : $($text)" -ForegroundColor Green
    }
	

	
Function Createvhd{
	Import-Module ..\Hyperv\HyperV.psd1
	$GB = [System.UInt64] $VHDSize*1024*1024*1024
	$ImageMgtService = get-wmiobject -class "Msvm_ImageManagementService" -namespace "root\virtualization" -computername "." 2 
	# Create the Dynamic VHD 
	$result = $ImageMgtService.CreateDynamicVirtualHardDisk($VHDFile,$GB) 
	if($result.ReturnValue -eq 4096){ 
		# A Job was started, and can be tracked using its Msvm_Job instance 
		$job = [wmi]$result.Job 
		# Wait for job to finish 
		while($job.jobstate -lt 7){$job.get()} 
		# Return the Job's error code 
		return $job.ErrorCode 
} 
# Otherwise, the method completed 
return $result.ReturnValue 

}

Function PscreatePartition(){

    #Mount-DiskImage
    Mount-DiskImage -ImagePath $VHDFile -Verbose
    Write-W2VInfo "image mounted"

    $VHDDisk = Get-DiskImage -ImagePath $VHDFile | Get-Disk -Verbose
    $VHDDiskNumber = [string]$VHDDisk.Number

    #Initialize-Disk
    Initialize-Disk -Number $VHDDiskNumber -PartitionStyle MBR -Verbose

    #Format vhdfile
    $VHDDrive = New-Partition -DiskNumber $VHDDiskNumber -UseMaximumSize -IsActive -Verbose
	$VHDDrive | Format-Volume -FileSystem NTFS -NewFileSystemLabel OSDisk -Confirm:$false -Verbose
	Add-PartitionAccessPath -DiskNumber $VHDDiskNumber -PartitionNumber $VHDDrive.PartitionNumber -AssignDriveLetter
	$VHDDrive = Get-Partition -DiskNumber $VHDDiskNumber -PartitionNumber $VHDDrive.PartitionNumber
	$VHDVolume = [string]$VHDDrive.DriveLetter+":"
	. Logit "Driveletter is now = $VHDVolume"
	dism.exe /apply-Image /ImageFile:$SourceFile /index:$Index /ApplyDir:$VHDVolume\
	Write-W2VInfo "$VHDVolume\Windows"
    Write-W2VInfo $VHDDrive.Offset
    Write-W2VInfo $VHDDisk.Signature

}

function remove-vhd($vhdfile) {
   $path = resolve-path $vhdfile
   $script = "SELECT VDISK FILE=`"$path`"`r`nDETACH VDISK"
   $script | diskpart 
}


function CreateThrwDiskpart(){   
   $GB = [System.UInt64] $VHDSize*1024
   $path =  $vhdFile
   $script = "create VDISK FILE=`"$path`" maximum=`"$GB`" type=expandable `r`nselect VDISK FILE=`"$path`"`r`nattach VDISK`r`ncreate partition primary`r`nassign letter=`"$VHDVolume`"`r`nformat fs=ntfs quick label=vhd`r`nactive`r`nexit"   
   $script | DISKPART 
   $VHDVolume = [string]$VHDVolume + ":"     
   Write-W2VInfo " $VHDVolume is the drive letter"    
   dism.exe /apply-Image /ImageFile:$SourceFile /index:$Index /ApplyDir:$VHDVolume\              
}

function MountDisk() {
   $path = resolve-path $vhdFile
   $script = "SELECT VDISK FILE=`"$path`"`r`attach VDISK"
   $script | diskpart | Out-Null
}


function CreateBootfiles(){

   $VHDVolume = [string]$VHDVolume + ":"
   Write-W2VInfo $VHDVolume
   cmd /c "$VHDVolume\Windows\System32\bcdboot.exe  $VHDVolume\windows /s $VHDVolume" 
   bcdedit /store $VHDVolume\boot\BCD   
}


function ApplyVirtIODrivers(){

   $VHDVolume = $VHDVolume + ":"
   $VirtIOMountPath = ''  
   if($VirtIOPath){
        Write-W2VInfo "Mounting virio iso file."
		$MountedISO = Mount-DiskImage $VirtIOPath -PassThru		
		$driveletter = ($MountedISO | Get-Volume).DriveLetter		
		$winstring = Get-WindowsImage -Imagepath $SourceFile | findstr "Name"
        if($winstring -match "windows 7"){
           
	       $VirtIOMountPath = "$driveletter"+":\WIN7\AMD64"
		   
        }else{
 
           $VirtIOMountPath = "$driveletter"+":\WIN8\AMD64"
        }		

   Write-W2VInfo "Applying virtio drivers......"		
   Dism /image:$VHDVolume\ /Add-Driver /driver:$VirtIOMountPath /ForceUnsigned /recurse
   Dismount-DiskImage $VirtIOPath
   

   }

}

function ApplyDrivers(){

   $VHDVolume = $VHDVolume + ":"
   Write-W2VInfo "Applying Drivers...."
   Dism /image:$VHDVolume\ /Add-Driver /driver:$DriversPath /ForceUnsigned /recurse
     
   }



function ApplyUnattendxml(){
   $VHDVolume = $VHDVolume + ":"
   Write-W2VInfo "Copying Unattend xml file"
   copy $UnattendPath $VHDVolume\Unattend.xml

}

function AddCloudbaseinit(){

   $VHDVolume = $VHDVolume + ":"
   #$CloudbaseInitMsiUrl = "http://www.cloudbase.it/downloads/CloudbaseInitSetup_Beta.msi"  
   $CloudbaseInitMsi = "$ENV:Temp\CloudbaseInitSetup_Beta.msi"   
   Write-W2VInfo "Downloading Cloudbase init msi ........."  
   (new-object System.Net.WebClient).DownloadFile($CloudbaseInitMsiUrl, $CloudbaseInitMsi)  
   New-Item -ItemType directory -Path $VHDVolume\Windows\Setup\Scripts   
   Copy-Item $pwd\SetupComplete.cmd $VHDVolume\Windows\Setup\Scripts   
   Copy-Item $CloudbaseInitMsi $VHDVolume\Windows\Setup\Scripts
   
}

function SerialPort(){
    $VHDVolume = $VHDVolume + ":"
	Write-W2VInfo "Adding Serial Port"
    bcdedit /store $VHDVolume\boot\BCD /dbgsettings serial debugport:1 baudrate:$serialbaudrate

}

function convertoutputtoqcow2(){
    try{
	   Write-W2VInfo "Converting to qcow2"
       qemu-img.exe convert -f vpc -O qcow2  $VHDFile $VHDFile.Replace("vhd","qcow2")
	   Remove-Item $VHDFile
	}catch{
	   Write-W2VInfo "qemu is not installed or its path is not set to system path. So ouput will be in vhd format"
	   exit
	}
}



foreach($p in $testpaths){
    if($p){
       $valid = Test-Path -path $p
	   if(!$valid){
	    Write-W2VError "Not a valid Path please check the path specified --- $p"
		exit 
		break
		
	   }
	}

}




#try {
#           Createvhd  | Out-File  
#			PscreatePartition		
			
#} catch{
#            Write-W2VInfo "Could not run through hyperv module will use diskpart..."
#			$Errorvalue = 1
			
#}

#if($Errorvalue){

   CreateThrwDiskpart   
   
   
#}


CreateBootfiles
Addcloudbaseinit

Write-W2VInfo "---------------------Enabling features.-----------------------------------------------------"
if($feature){
Write-W2VInfo "----- Enabling Role -----"
Dism /online /enable-feature /featurename:$feature

}

if($UnattendPath){
   ApplyUnattendxml
}

if($DriversPath){

   ApplyDrivers   
   
}

if($VirtIOPath){

   ApplyVirtIODrivers
   
}

#serial port
SerialPort

#select and detach the vdisk created by the disk.
remove-vhd($VHDFile)			

if($OutputFormat){
   if($OutputFormat -eq "qcow2"){
      convertoutputtoqcow2
   }
   
}
Write-W2VInfo "================= Completed Image Creation and ready. ======================="





