### Powershell script for backing up Docker containers
### Local backup, version 3

### Functions ###


### Script Start ##
$Server="10.65.15.5"
$Share="/mnt/ZFS2/dmzcache"
$srcloc="/docker"
$mount="/mnt/dmzcache"
$destloc="/mnt/dmzcache/config-backup/$(hostname)/"
$filename="$(hostname).docker-appdata.$(date +"%m_%d_%Y").zip"
$fileloc=$destloc + $filename

If (Test-Path $mount){
    mount -t nfs $server":"$Share $mount
}
else { 
    New-Item -ItemType directory $mount
    mount -t nfs $server":"$Share $mount
}
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

# ??? Update Images ???

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

#unmount backup loc
umount $mount
