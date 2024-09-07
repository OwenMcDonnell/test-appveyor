# C:\Tools\curl\bin\curl.exe
# $CurlArgument = '-u', 'xxx@gmail.com:yyyy',
#                 '-X', 'POST',
#                 'https://xxx.bitbucket.org/1.0/repositories/abcd/efg/pull-requests/2229/comments',
#                 '--data', 'content=success'
# $CURLEXE = 'C:\Program Files\Git\mingw64\bin\curl.exe'
# & $CURLEXE @CurlArgument



curl -fsS -o hdf5-1.8.13-win32-VS2010-shared.zip https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.13/bin/windows/hdf5-1.8.13-win32-VS2010-shared.zip



Write-Host "Hello"
$nugetVersion = '6.10.1'
$nugetUrl = "https://dist.nuget.org/win-x86-commandline/v$nugetVersion/nuget.exe"

$nugetDir = "$env:SystemDrive\Tools\NuGet"

(New-Object Net.WebClient).DownloadFile($nugetUrl, "$nugetDir\nuget.exe")

(nuget).split("`n")[0]

nuget sources add -name nuget.org -source https://api.nuget.org/v3/index.json

Write-Host "NuGet updated" -ForegroundColor Green
