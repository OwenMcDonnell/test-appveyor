function Start-ProcessWithOutput {
    param(
        $command,
        [switch]$ignoreExitCode,
        [switch]$ignoreStdOut
    )
    $fileName = $command
    $arguments = $null

    if ($command.startsWith('"')) {
        $idx = $command.indexOf('"', 1)
        $fileName = $command.substring(1, $idx - 1)
        if ($idx -lt ($command.length - 2)) {
            $arguments = $command.substring($idx + 2)
        }
    }
    else {
        $idx = $command.indexOf(' ')
        if ($idx -ne -1) {
            $fileName = $command.substring(0, $idx)
            $arguments = $command.substring($idx + 1)
        }
    }

    # find tool in path
    if (-not (Test-Path $fileName)) {
        foreach ($pathPart in $($env:PATH).Split(';')) {
            $searchPath = [IO.Path]::Combine($pathPart, "$fileName.bat")
            if (Test-Path $searchPath) {
                $fileName = $searchPath; break;
            }            
            $searchPath = [IO.Path]::Combine($pathPart, "$fileName.cmd")
            if (Test-Path $searchPath) {
                $fileName = $searchPath; break;
            }
            $searchPath = [IO.Path]::Combine($pathPart, "$fileName.exe")
            if (Test-Path $searchPath) {
                $fileName = $searchPath; break;
            }
            $searchPath = [IO.Path]::Combine($pathPart, $fileName)
            if (Test-Path $searchPath) {
                $fileName = $searchPath; break;
            }
        }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo 
    $psi.FileName = $fileName
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = (pwd).Path
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    # Adding event handers for stdout and stderr.
    $outScripBlock = {
        if (![String]::IsNullOrEmpty($EventArgs.Data)) {
            Write-Host "$($EventArgs.Data)"
        }
    }
    $errScripBlock = {
        if (![String]::IsNullOrEmpty($EventArgs.Data)) {
            Write-Host "$($EventArgs.Data)" -ForegroundColor Red
        }
    }

    if ($ignoreStdOut -eq $false) {
        $stdOutEvent = Register-ObjectEvent -InputObject $process -Action $outScripBlock -EventName 'OutputDataReceived'
    }
    $stdErrEvent = Register-ObjectEvent -InputObject $process -Action $errScripBlock -EventName 'ErrorDataReceived'

    try {
        $process.Start() | Out-Null

        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        [Void]$process.WaitForExit()
    
        # Unregistering events to retrieve process output.
        if ($ignoreStdOut -eq $false) {
            Unregister-Event -SourceIdentifier $stdOutEvent.Name
        }
        Unregister-Event -SourceIdentifier $stdErrEvent.Name    
    
        if ($ignoreExitCode -eq $false -and $process.ExitCode -ne 0) {
            exit $process.ExitCode
        }
    }
    catch {
        Write-Host "Error running '$($psi.FileName) $($psi.Arguments)' command: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}


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

InstallPythonEXE "3.14.0" "x64" "$env:SystemDrive\Python314-x64"


# Python 3.14
InstallPythonEXE "3.14.0" "x86" "$env:SystemDrive\Python314"


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
