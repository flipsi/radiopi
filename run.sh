#!/usr/bin/env bash

# Start containerized webserver with PHP to run locally
IMAGE_NAME='flipsi/radiopi:latest'
CONTAINER_NAME='radiopi'
HOST_PORT=8080
DOCUMENT_ROOT='./frontend'

function docker_run() {
    docker run --rm -p $HOST_PORT:80 --name "$CONTAINER_NAME" "$IMAGE_NAME"
}

function docker_run_with_mounted_volume() {
    # sudo chown $WWW_DATA_UID:$WWW_DATA_GID "$DOCUMENT_ROOT"
    # sudo chmod g+rwxs "$DOCUMENT_ROOT"
    # Fix permission errors via SELinux label: https://stackoverflow.com/a/54787364/4568748
    docker run \
        --rm \
        -p $HOST_PORT:80 \
        --name "$CONTAINER_NAME" \
        -v "$DOCUMENT_ROOT":/var/www/html:z \
        "$IMAGE_NAME"
}

set -e
docker build -t "$IMAGE_NAME" .
docker_run_with_mounted_volume

