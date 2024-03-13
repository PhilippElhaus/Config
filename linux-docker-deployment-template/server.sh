#! /bin/bash

handle_error() {
  echo "Error: $1" >&2
  exit 1
}

echo "--- Executing Commands on Linux Server ---"

docker stop "$deployname" && docker rm "$deployname" 2>/dev/null

docker rmi "$deployname" 2>/dev/null

docker load -i /tmp/"$deployname".tar || handle_error "Failed to load Docker image from /tmp/"$deployname".tar"

docker run -d --name "$deployname" -p "$deployport":8080 -v /var/data:/app/data "$deployname" || handle_error "Failed to run Docker container"

rm /tmp/"$deployname".tar 2>/dev/null

echo "--- Server: Done ---"