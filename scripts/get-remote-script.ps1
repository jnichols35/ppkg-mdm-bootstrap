# Define the URL of the GitHub Gist (update this to point to your remote script with prompt)
$scriptUrl = "https://gist.githubusercontent.com/jnichols35/b2a6dfa6fd7238cccc3b8be569b735b7/raw/remote-prompt.ps1"

# Define the local path where the script will be saved
$localScriptPath = "$env:TEMP\downloadedScript.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath

& $localScriptPath
