### Powershell script for backing up Docker containers, Updating images, and pruning old images
# Usage NFS: /usr/bin/pwsh /docker/scripts/Linux-Docker-Powershell/Docker-Backup-Local.ps1 -Server <Server> -Share <Share>
# Usage Cifs: /usr/bin/pwsh /docker/scripts/Linux-Docker-Powershell/Docker-Backup-Local.ps1 -Server <Server> -Share <share> -type SMB -Username <User> -Password <Password> -Domain <AD domain>

### Parameters ##
param 
    (
        [parameter(Mandatory=$True)]
        [String] $Server,
        [parameter(Mandatory=$True)]
        [String] $Share,
        [String] $type = "nfs",
        [parameter(Dontshow)]
        [String] $Username = $Null,
        [parameter(Dontshow)]
        [String] $Password = $Null,
        [parameter(Dontshow)]
        [String] $Domain = $Null
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
$ScriptDir = (Get-Location).Path
$CredFile=$ScriptDir+"/.credential"
$srcloc="/docker" # Folder to Backup
$mount="/mnt/backup" # Folder where the share will be mounted
$destloc= $mount + "/config-backup/$(hostname)/"  # Destination folder for the backups.
$filename="$(hostname).docker-appdata.$(date +"%m_%d_%Y").zip"
$fileloc=$destloc + $filename
$keep_backup = 10 # Number of Backups to keep.

If (!(Test-Path $mount)){
    $MSG = "Creating Directory "+ $mount
    LOG-Event $MSG 
    New-Item -ItemType directory $mount
}

switch($type.ToLower()) {
    "smb" {
	$Connect = $Server + $Share    
        $MSG = "Mounting SMB Share " + $Connect
        LOG-Event $MSG
        "username=$username" | out-file -Append -FilePath $credfile
        "password=$password" | out-file -Append -FilePath $credfile
        "domain=$domain" | out-file -Append -FilePath $credfile
        $command = "mount -t cifs -o credentials="+$CredFile+" "+$Connect+" "+$mount
        try {iex $command}
        catch {LOG-Event "Mount Failed, Exiting."; exit}
        remove-item $CredFile -force 
    }
    default {
        $MSG = "Mounting NFS Share " + $server + ":" + $Share
        LOG-Event $MSG
        try {mount -t nfs $server":"$Share $mount}
        catch {LOG-Event "Mount Failed, Exiting."; exit}
     }
}

If (!(Test-Path $destloc)){
    $MSG = "Creating Destination Folder."
    LOG-Event $MSG
    New-Item -ItemType directory $destloc
}
$containers = docker container ls --format '{{.Names}}'

# Stop Running containers
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

# Compress-Archive -Path $srcloc -DestinationPath $fileloc
$MSG = "Backing Up Docker APP Directories."
LOG-Event $MSG
$command = "zip -rvT "+$fileloc+" "+$srcloc
iex $command

<# Delete all Files in $destloc older than 30 day(s)
$MSG = "Pruning old backups"
LOG-Event $MSG
$Daysback = "-30"
 
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $destloc | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
#>

# Delete all Files except last <num>
Get-ChildItem $destloc | where{-not $_.PsIsContainer}| sort CreationTime -desc| select -Skip $keep_backup | Remove-Item -Force

# Start Containers
$MSG = "Starting Containers"
LOG-Event $MSG
docker start $containers

# Prune unused images
$MSG = "Pruning Unused Docker Images"
LOG-Event $MSG
docker image prune -a --force

# unmount backup location
Start-Sleep -Seconds 2
$MSG = "Unmounting Backup Destination.<Operation completed>"
LOG-Event $MSG
umount $mount
