<#
Creates a VirtualBox VM capable of running the Windows Server 2008 R2 Evaluation VHD
http://www.microsoft.com/en-au/download/details.aspx?id=16572
Tested with VirtualBox Version 4.3.12 & 4.3.16
TODO: 
	- See if we can automatically download the Eval Version from URL
		- Would want a progress bar for the download as well
	- Do the same for Server 20012 Evaluation Edition.
BUGS:
	-BUG-01:
		Split Sourcedisk variable to grab extension, Which will allow for multiple types of 
		Virtual Hard Drives
#>		
[CmdletBinding()]
Param(
	[string]$SourceDisk,
	[string]$VM_Name
)
if (-not $SourceDisk) 
{
	Write-Output "Please Specify the Disk file"
	exit
}
#Region Functions 
#Functions
#Copy-File With Progress Attributed to
#http://stackoverflow.com/questions/2434133/progress-during-large-file-copy-copy-item-write-progress

function Copy-File {
    param( [string]$from, [string]$to)
    $ffile = [io.file]::OpenRead($from)
    $tofile = [io.file]::OpenWrite($to)
    Write-Progress -Activity "Copying file" -status "$from -> $to" -PercentComplete 0
    try {
        [byte[]]$buff = new-object byte[] 4096
        [long]$total = [long]$count = 0
        do {
            $count = $ffile.Read($buff, 0, $buff.Length)
            $tofile.Write($buff, 0, $count)
            $total += $count
            if ($total % 1mb -eq 0) {
                Write-Progress -Activity "Copying file" -status "$from -> $to" `
                   -PercentComplete ([int]($total/$ffile.Length* 100))
            }
        } while ($count -gt 0)
    }
    finally {
        $ffile.Dispose()
        $tofile.Dispose()
    }
}
#endregion

$VM_SourceDisk = $SourceDisk
Write-Output "Starting Virtualbox VM Creation."

Write-Output "Setting Variables..."
#StoreBus Variables
$StorageBus_IDE = 1

#Storage Controller Types
$StorageControllerType_LsiLogic = 1

#Device Type Variables
$DeviceType_Null = 0
$DeviceType_DVD = 2
$DeviceType_HardDisk = 3

#Access Mode
$AccessMode_ReadOnly = 1
$AccesMode_ReadWrite = 2

#Lock Type
$LockType_Write = 2
$LockType_Shared = 1

#VM Variables
if(-not $VM_Name)
{
	$VM_Name = "Vagrant 2008 R2"
}
$VM_OSType = "Windows2008_64"

#Initialize the Virtiualbox COM object
$vBoxAPI = New-Object -ComObject VirtualBox.VirtualBox

Write-Output "Creating VirtualBox VM"
#Create and Configure the VM
$vBox = $vBoxAPI.CreateMachine("",$VM_Name,[String[]]@(),$VM_OSType,$false)
$VBox.MemorySize=2048
$vBox.CPUCount = 2
$vBox.VRAMSize = 64
$vBox.Description="Vagrant Windows 2008 R2 Template"
$vBox.SetBootOrder(1,$DeviceType_HardDisk)
$vBox.SetBootOrder(2,$DeviceType_Null)
$vBox.SetBootOrder(3,$DeviceType_Null)
$vBox.SetBootOrder(4,$DeviceType_Null)

#Configure the Storage Controller
$VM_Disk_CTRL = $vBox.AddStorageController("IDE Controller",$StorageBus_IDE)

Write-Output "Saving and Registering Virtualbox VM"
#Save the Settings and Register Machine
$vBox.SaveSettings()
$vBoxAPI.RegisterMachine($vBox)

#Copy the VHD to VirtualMachine Directory
$VM_DiskFilePath = $vBoxAPI.SystemProperties.DefaultMachineFolder + "\$VM_Name\$VM_Name.vhd"
#During Debug wanted to make sure I didn't copy the file everytime.
if(Test-Path $VM_DiskFilePath)
{
	Write-Host "File already Exists"
}
Else
{
	Write-Host "Saving Hard Disk file to $VM_DiskFilePath"
	Copy-File $SourceDisk $VM_DiskFilePath
}

#Register the Hard Disk with VirtualBox
$VM_Disk=$vBoxAPI.OpenMedium($VM_DiskFilePath,$DeviceType_HardDisk,$AccesMode_ReadWrite,$true)
Write-Host "Attaching Disk to VM"

$vBoxSession = New-Object -ComObject VirtualBox.Session
$vBox.LockMachine($vBoxSession, $LockType_Write)
$vBoxSession.Machine.attachDevice("IDE Controller",0,0,$DeviceType_HardDisk,$VM_Disk)
$vBoxSession.Machine.AttachDeviceWithoutMedium("IDE Controller",1,0,$DeviceType_DVD)
$vBoxSession.Machine.SaveSettings()
$vBoxSession.UnlockMachine()


$VM_StartProgress = $vBox.LaunchVMProcess($vBoxSession,"gui","")
$VM_StartProgress.waitForCompletion(-1)

Write-Host "Machine Started"
