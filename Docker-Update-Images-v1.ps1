# Updates all currently installed images.

# Bash: for image in $(docker images --format "{{.Repository}}"); do docker pull $image; done

$images = docker image ls --format '{{.Repository}}'

foreach ($Image in $images){
    $fullimage = $image + ":latest"
    docker image pull $image
}