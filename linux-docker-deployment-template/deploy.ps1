try 
{
	$name = $env:DeployProjectName.Trim().ToLower()
	$server =  $env:DeployServerIP.Trim()
	$port = $env:DeployOnWebserverPort.Trim()
	$privKey = $env:DeployKeyPath.Trim()
	
	Write-Host "Value from environment variable: $name"
	Write-Host "Cleaning up old images..."
	docker images -q -f "reference=${name}" | ForEach-Object { docker rmi -f $_ }

	Write-Host "Building Docker Image..."
	docker build -t $name -f Dockerfile . --quiet

	Write-Host "Saving Docker Image..."
	docker save -o "${name}.tar" "${name}"

	Write-Host "Exporting Docker Image to Server..."
	scp -i "${privKey}" "${name}.tar" "root@${server}:/tmp"
	scp -i "${privKey}" server.sh "root@${server}:~/"
	Write-Host "Executing Shell Script on remote Server..."
	ssh -i "${privKey}" "root@${server}" "export deployname=$name; export deployport=$port; chmod +x server.sh; bash ~/server.sh"

	if ($LASTEXITCODE -ne 0) {
		throw "Error in Linux shell script"
	}

	Write-Host "Cleaning up..."
	Remove-Item -Path ".\${name}.tar" -Force

	Start-Process "http://${server}:${port}"

	Write-Host "--- Host: Done ---"
}
catch 
{
	Write-Host "Error: $($_.Exception.Message)"
	exit 1
}