
function UpdatePythonPath($pythonPath) {
    $env:path = ($env:path -split ';' | Where-Object { -not $_.contains('\Python') }) -join ';'
    $env:path = "$pythonPath;$env:path"
}



function UpdatePip($pythonPath) {
    Write-Host "Installing virtualenv for $pythonPath..." -ForegroundColor Cyan
    UpdatePythonPath "$pythonPath;$pythonPath\scripts"
    Start-ProcessWithOutput "python -m pip install --upgrade pip==$pipVersion" -IgnoreExitCode
    Start-ProcessWithOutput "pip --version" -IgnoreExitCode
    Start-ProcessWithOutput "pip install virtualenv" -IgnoreExitCode
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


function InstallPythonEXE($version, $platform, $targetPath) {
    $urlPlatform = ""
    if ($platform -eq 'x64') {
        $urlPlatform = "-amd64"
    }

    Write-Host "Installing Python $version $platform to $($targetPath)..." -ForegroundColor Cyan

    $downloadUrl = "https://www.python.org/ftp/python/$version/python-$version$urlPlatform.exe"
    Write-Host "Downloading $($downloadUrl)..."
    $exePath = "$env:TEMP\python-$version.exe"
    (New-Object Net.WebClient).DownloadFile($downloadUrl, $exePath)

    Write-Host "Installing..."
    cmd /c start /wait $exePath /quiet TargetDir="$targetPath" Shortcuts=0 Include_launcher=1 InstallLauncherAllUsers=1 Include_debug=1
    Remove-Item $exePath

    Start-ProcessWithOutput "$targetPath\python.exe --version"

    Write-Host "Installed Python $version" -ForegroundColor Green
}


# Python 3.14 x64
$python314_x64 = (GetUninstallString 'Python 3.14.0 (64-bit)')
if ($python314_x64) {
    Write-Host 'Python 3.14.0 x64 already installed'
}
else {
    InstallPythonEXE "3.14.0" "x64" "$env:SystemDrive\Python314-x64"
}

# Python 3.14
$python314 = (GetUninstallString 'Python 3.14.0 (32-bit)')
if ($python314) {
    Write-Host 'Python 3.14.0 already installed'
}
else {
    InstallPythonEXE "3.14.0" "x86" "$env:SystemDrive\Python314"
}

UpdatePip "$env:SystemDrive\Python314"
UpdatePip "$env:SystemDrive\Python314-x64"

Add-Path C:\Python314
Add-Path C:\Python314\Scripts

# restore .py file mapping
# https://github.com/appveyor/ci/issues/575
cmd /c ftype Python.File="C:\Windows\py.exe" "`"%1`"" %*

# check default python
Write-Host "Default Python installed:" -ForegroundColor Cyan
$r = (cmd /c python.exe --version 2>&1)
$r.Exception

# py.exe
Write-Host "Py.exe installed:" -ForegroundColor Cyan
$r = (py.exe --version)
$r

function CheckPython($path) {
    if (Test-Path "$path\python.exe") {
        Start-ProcessWithOutput "$path\python.exe --version"
    }
    else {
        throw "python.exe is missing in $path"
    }

    if (Test-Path "$path\Scripts\pip.exe") {
        Start-ProcessWithOutput "$path\Scripts\pip.exe --version"
        Start-ProcessWithOutput "$path\Scripts\virtualenv.exe --version"
    }
    else {
        Write-Host "pip.exe is missing in $path" -ForegroundColor Red
    }
}

CheckPython 'C:\Python311'
CheckPython 'C:\Python311-x64'
CheckPython 'C:\Python312'
CheckPython 'C:\Python312-x64'
CheckPython 'C:\Python313'
CheckPython 'C:\Python313-x64'
