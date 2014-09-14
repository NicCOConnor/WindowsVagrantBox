# Creates a VirtualBox VM capable of running the Windows Server 2008 R2 Evaluation VHD
# http://www.microsoft.com/en-au/download/details.aspx?id=16572
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true,Position=1)]
	[string]$Disk
)
if (-not $Disk)
{
	Write-Output "Usage: "
	exit
}


	