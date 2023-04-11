Write-Information "Initializing build variables"
# BuildRoot is provided by Invoke-Build
Write-Information "  BuildRoot: $BuildRoot"

# NOTE: this variable is currently also used for Pester formatting ...
# So we must use either "AzureDevOps", "GithubActions", or "None"
$script:BuildSystem = if (Test-Path Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI) {
    "AzureDevops"
} else {
    "None"
}

# A little extra BuildEnvironment magic
if ($script:BuildSystem -eq "AzureDevops") {
    Set-BuildHeader { Write-Build 11 "##[group]Begin $($args[0])" }
    Set-BuildFooter { Write-Build 11 "##[endgroup]Finish $($args[0]) $($Task.Elapsed)" }
}
Write-Information "  BuildSystem: $script:BuildSystem"

# Cross-platform separator character
${script:\} = ${script:/} = [IO.Path]::DirectorySeparatorChar

<#  A note about paths noted by Azure Pipeline environment variables:
    $Env:PIPELINE_WORKSPACE         - Defaults to /work/job_id and holds all the others:

    These other three are defined relative to $Env:PIPELINE_WORKSPACE
    $Env:BUILD_SOURCESDIRECTORY     - Cleaned BEFORE checkout IF: Workspace.Clean = All or Resources, or if Checkout.Clean = $True
                                        For single source, defaults to work/job_id/s
                                        For multiple, defaults to work/job_id/s/sourcename
    $Env:BUILD_BINARIESDIRECTORY    - Cleaned BEFORE build IF: Workspace.Clean = Outputs
    $Env:BUILD_STAGINGDIRECTORY     - Cleaned AFTER each Build
    $Env:AGENT_TEMPDIRECTORY        - Cleaned AFTER each Job
#>

# There are a few different environment/variables it could be, and then our fallback
$Script:OutputDirectory = @(Get-Content Env:BUILD_BINARIESDIRECTORY, Variable:OutputDirectory -ErrorAction Ignore) +
                          @(Join-Path -Path $BuildRoot -ChildPath 'Output') | Select-Object -First 1
New-Item -Type Directory -Path $OutputDirectory -Force | Out-Null
Write-Information "  OutputDirectory: $OutputDirectory"

$Script:TestResultsDirectory = @(Get-Content Env:COMMON_TESTRESULTSDIRECTORY, Env:TEST_RESULTS_DIRECTORY, Variable:TestResultsDirectory -ErrorAction Ignore) +
                               @(Join-Path -Path $OutputDirectory -ChildPath 'TestResults') | Select-Object -First 1
New-Item -Type Directory -Path $TestResultsDirectory -Force | Out-Null
Write-Information "  TestResultsDirectory: $TestResultsDirectory"

### IMPORTANT: Our local TempDirectory does not cleaned the way the Azure one does
$Script:TempDirectory = @(Get-Content Env:AGENT_TEMPDIRECTORY -ErrorAction Ignore).Where({ Test-Path $_ })
if (!$Script:TempDirectory) {
    $Script:TempDirectory = @(Get-Content Env:TEMP, Env:TMP -ErrorAction Ignore).Where{ Test-Path $_ }[0] |
        Join-Path -ChildPath 'InvokeBuild'
}
New-Item -Type Directory -Path $TempDirectory -Force | Out-Null
Write-Information "  TempDirectory: $TempDirectory"

# Git variables that we could probably use:
$Script:GITSHA = if ($ENV:BUILD.SOURCEVERSION) {
    $ENV:BUILD.SOURCEVERSION
} else {
    git rev-parse HEAD
}
Write-Information "  GITSHA: $Script:GITSHA"

$script:BranchName = if ($Env:BUILD_SOURCEBRANCHNAME) {
    $Env:BUILD_SOURCEBRANCHNAME
} elseif (Get-Command git -CommandType Application) {
    (git branch --show-current) -replace ".*/"
}
Write-Information "  BranchName: $script:BranchName"

if (Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse) {
    Write-Information "Initializing DotNet build variables"
    # The OutputBin is the bin folder within the OutputDirectory (used for dotnet build output)
    $script:OutputBin = New-Item (Join-Path $script:OutputDirectory bin) -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path
    # The OutputPub is the pub folder within the OutputDirectory (used for dotnet publish output)
    $script:OutputPub = New-Item (Join-Path $script:OutputDirectory pub) -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

    # Default values for build variables:
    # Dotnet build configuration
    $script:Configuration ??= "Release"
    Write-Information "  Configuration: $script:Configuration"

    # The projects are expected to each be in their own folder
    # Dotnet allows us to pass it the _folder_ that we want to build/test
    # So our $buildProjects are the names of the folders that contain the projects
    $script:dotnetProjects = @(
        if (!$dotnetProjects) {
            Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse | Split-Path
        } elseif (![IO.Path]::IsPathRooted(@($dotnetProjects)[0])) {
            Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse | Where-Object { $dotnetProjects -contains $_.BaseName } | Split-Path
        }
    ) | Convert-Path
    Write-Information "  DotNetProjects: $($script:dotnetProjects -join ", ")"

    $script:dotnetTestProjects = @(
        if (!$dotnetTestProjects) {
            Get-ChildItem -Path $BuildRoot -Include *Test.*proj -Recurse | Split-Path
        } elseif (![IO.Path]::IsPathRooted(@($dotnetTestProjects)[0])) {
            Get-ChildItem -Path $BuildRoot -Include *Test.*proj -Recurse | Where-Object { $dotnetProjects -contains $_.BaseName } | Split-Path
        }
    )  | Convert-Path
    Write-Information "  DotNetTestProjects: $($script:dotnetTestProjects -join ", ")"

    $script:dotnetOptions ??= @{}
}


# Finally, import all the Task.ps1 files in this folder
Write-Information "Import Shared Tasks"
foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    Write-Information "    $($taskfile.FullName)"
    . $taskfile.FullName
}