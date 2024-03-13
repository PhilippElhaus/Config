#! /bin/bash

echo "--- Executing Commands on Linux Server ---"

docker stop cv && docker rm cv
docker rmi cv

docker load -i /tmp/cv.tar

docker run -d --name cv -p 8080:8080 cv
echo "--- Done ---"