### Powershell script for backing up Docker containers, Updating images, and pruning old images

### Parameters ##
param
    (
        [parameter(Mandatory=$True)]
        [String] $Server
        ,
        [parameter(Mandatory=$True)]
        [String] $Share
        ,
        [Bool] $SMB = $false
        ,
        [parameter(Dontshow)]
        [String] $Username
        ,
        [parameter(Dontshow)]
        [String] $Password

    )

# Default Variables
$srcloc="/docker"
$mount="/mnt/backup"
$destloc= $mount + "/config-backup/$(hostname)/"
$filename="$(hostname).docker-appdata.$(date +"%m_%d_%Y").zip"
$fileloc=$destloc + $filename

If (Test-Path $mount){
    mount -t nfs $server":"$Share $mount
}
else { 
    New-Item -ItemType directory $mount
}

If ($SMB) {
$Connect = $Server + $Share
mount -t cifs -o username=$User,password=$Password $Connect $mount
}
Else {mount -t nfs $server":"$Share $mount}

If (Test-Path $destloc){
    $fileloc=$destloc + $filename
}
else { 
    $fileloc=$destloc + $filename
    New-Item -ItemType directory $destloc
}
$containers = docker container ls --format '{{.Names}}'

#Stop Running containers
docker stop $containers

# Update Images
$images = docker image ls --format '{{.Repository}}'

foreach ($Image in $images){
    $fullimage = $image + ":latest"
    docker image pull $image
}

#Compress-Archive -Path $srcloc -DestinationPath $fileloc
$command = "zip -r "+$fileloc+" "+$srcloc
iex $command

Delete all Files in $destloc older than 30 day(s)
$Daysback = "-30"
 
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $destloc | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item

#Start Containers
docker start $containers

#Prune unused images
docker image prune -a --force

#unmount backup loc
umount $mount
