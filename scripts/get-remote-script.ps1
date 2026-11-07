# Define the URL of the remote script (injected at build time via the REMOTE_SCRIPT_URL environment variable)
$scriptUrl = "__REMOTE_SCRIPT_URL__"

if ($scriptUrl -eq '__REMOTE_SCRIPT_URL__') {
    Write-Error "Remote script URL was not injected at build time."
    exit 1
}

# Define the local path where the script will be saved
$localScriptPath = "$env:TEMP\downloadedScript.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath

& $localScriptPath
