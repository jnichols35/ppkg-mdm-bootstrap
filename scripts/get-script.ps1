# Define the URL of the GitHub Gist
$scriptUrl = "https://gist.githubusercontent.com/jnichols35/f312b669c4f1c0dadcc0d4d1c5f75dbd/raw/c095c8f66075f234843676eebf8e0d613e8bddfe/RemoteScript.ps1"

# Define the local path where the script will be saved
$localScriptPath = "$env:TEMP\downloadedScript.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath

& $localScriptPath