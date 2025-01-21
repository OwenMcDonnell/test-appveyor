$nugetVersion = '6.11.0'
$nugetUrl = "https://dist.nuget.org/win-x86-commandline/v$nugetVersion/nuget.exe"

$nugetDir = "$env:SystemDrive\Tools\NuGet"
Write-Host "Updating NuGet in $nugetDir"

(New-Object Net.WebClient).DownloadFile($nugetUrl, "$nugetDir\nuget.exe")

(nuget).split("`n")[0]

nuget sources add -name nuget.org -source https://api.nuget.org/v3/index.json

Write-Host "NuGet updated" -ForegroundColor Green
