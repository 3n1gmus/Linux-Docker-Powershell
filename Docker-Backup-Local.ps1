### Powershell script for backing up Docker containers, Updating images, and pruning old images

### Parameters ##
param 
    (
        [parameter(Mandatory=$True)]
        [String] $Server,
        [parameter(Mandatory=$True)]
        [String] $Share,
        [Bool] $SMB = $false,
        [parameter(Dontshow)]
        [String] $Username = $Null,
        [parameter(Dontshow)]
        [String] $Password = $Null
    )

### Functions

function LOG-Event
	{
		param (
			[string]$MSG,
			[string]$Color = "yellow"
		)
		$TimeStamp = (Get-Date).ToString("hh:mm:sstt")
		$OUTMSG = "[$TimeStamp] - " + $MSG
		write-host $OUTMSG -ForegroundColor $Color
		Add-content $LogFile -value $OUTMSG
	}

# Global Log File
$Global:LogPath = "/var/log/docker-backup/"
$Global:LogFile = $LogPath + "DockerBackup.log"
#$Global:LogFile = $LogPath + "DockerBackup_" + (Get-Date).ToString("MMddyyyy_hhmmsstt") + ".log"
if(!(Test-Path $LogPath)){New-Item -ItemType directory $LogPath}

# Default Variables
$srcloc="/docker"
$mount="/mnt/backup"
$destloc= $mount + "/config-backup/$(hostname)/"
$filename="$(hostname).docker-appdata.$(date +"%m_%d_%Y").zip"
$fileloc=$destloc + $filename

If (!(Test-Path $mount)){
    $MSG = "Creating Directory "+ $mount
    LOG-Event $MSG 
    New-Item -ItemType directory $mount
}

If ($SMB) {
    $MSG = "Creating SMB Share"
    LOG-Event $MSG
    $Connect = $Server + $Share
    mount -t cifs -o username=$User,password=$Password $Connect $mount
}
Else {
    $MSG = "Creating NFS Share"
    LOG-Event $MSG
    mount -t nfs $server":"$Share $mount
}

If (!(Test-Path $destloc)){
    $MSG = "Creating Destination Folder."
    LOG-Event $MSG
    New-Item -ItemType directory $destloc
}
$containers = docker container ls --format '{{.Names}}'

#Stop Running containers
$MSG = "Stopping Containers"
LOG-Event $MSG
docker stop $containers

# Update Images
$images = docker image ls --format '{{.Repository}}'
$MSG = "Updating Docker Images"
LOG-Event $MSG

foreach ($Image in $images){
    $fullimage = $image + ":latest"
    docker image pull $image
}

#Compress-Archive -Path $srcloc -DestinationPath $fileloc
$MSG = "Backing Up Docker APP Directories."
LOG-Event $MSG
$command = "zip -r "+$fileloc+" "+$srcloc
iex $command

# Delete all Files in $destloc older than 30 day(s)
$MSG = "Pruning old backups"
LOG-Event $MSG
$Daysback = "-30"
 
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $destloc | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item

#Start Containers
$MSG = "Starting Containers"
LOG-Event $MSG
docker start $containers

#Prune unused images
$MSG = "Pruning Unused Docker Images"
LOG-Event $MSG
docker image prune -a --force

#unmount backup loc
$MSG = "Unmounting Backup Destination.<Operation completed>"
LOG-Event $MSG
umount $mount