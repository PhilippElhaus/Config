Write-Host "Cleaning up old images..."
docker images -q -f "reference=cv" | ForEach-Object { docker rmi -f $_ }

Write-Host "Building DOCKER Image..."
docker build -t cv -f Dockerfile .

Write-Host "Exporting DOCKER Image..."
docker save -o cv.tar cv

$privKey = "C:\Users\Philipp Elhaus\.ssh\id_rsa"
$remoteIP = "172.28.0.6"

scp -i $privKey cv.tar root@172.28.0.6:/tmp
scp -i $privKey server.sh root@172.28.0.6:~/
ssh -i $privKey root@172.28.0.6 "chmod +x server.sh; bash ~/server.sh"

Start-Process "http://172.28.0.6:8080"
Read-Host "Press Enter to exit"