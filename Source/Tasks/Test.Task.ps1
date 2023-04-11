Add-BuildTask Test @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetTestProjects
    Inputs  = {
        Get-ChildItem $dotnetProjects -Recurse -File -Filter *.cs |
            Where-Object FullName -NotMatch "[\\/]obj[\\/]"
    }
    Outputs = {
        (Get-ChildItem $TestResultsDirectory -Filter *.trx -Recurse -ErrorAction Ignore) ?? $TestResultsDirectory
    }
    Jobs    = "Compile", {
        # make sure the coverage tool is available
        dotnet tool update --global dotnet-coverage

        $local:options = @{
            "-configuration" = $configuration
            # "-output" = $OutputBin
            "-results-directory" = $TestResultsDirectory
        } + $script:dotnetOptions

        if ($Script:CollectCoverage) {
            $options["-collect"] = "Code Coverage"
        }

        foreach ($project in $dotnetTestProjects) {
            Write-Build Gray "dotnet build $project --no-build --logger trx" @options
            dotnet test $project --no-build --logger trx @options
        }
    }
}
