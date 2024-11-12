

$wc = New-Object 'System.Net.WebClient'

foreach($project in $TestProjects)
{
    $testResultFile = ".\TestResults.xml"
    $wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit3/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $SolutionRoot\TestResults\$project.TestResults.xml))
}
