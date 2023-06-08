### Powershell script for Restoring Docker containers from backup ZIPs

### Parameters ##
param 
    (
        [parameter(Mandatory=$True)]
        [String] $Server,
        [parameter(Mandatory=$True)]
        [String] $Share,
        [String] $type = "nfs",
        [String]$filename = $Null,
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
$mount="/mnt/backup"
$srcloc=$mount + "/config-backup/$(hostname)/"
$fileloc=$srcloc + $filename

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
        mount -t cifs -o credentials=$CredFile $Connect $mount
        remove-item $CredFile -force 
    }
    default {
        $MSG = "Mounting NFS Share " + $server + ":" + $Share
        LOG-Event $MSG
        mount -t nfs $server":"$Share $mount
     }
}

$MSG = "Restoring Backup " + $filename
LOG-Event $MSG
unzip $fileloc