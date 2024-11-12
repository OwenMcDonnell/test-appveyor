

$wc = New-Object 'System.Net.WebClient'

$testResultFile = ".\TestResults.xml"
$wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultFile))

