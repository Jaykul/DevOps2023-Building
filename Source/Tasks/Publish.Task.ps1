Add-BuildTask Publish @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Inputs  = {
        # Exclude generated source files in /obj/ folders
        Get-ChildItem $dotnetProjects -Recurse -File -Filter *.cs |
            Where-Object FullName -NotMatch "[\\/]obj[\\/]"
    }
    Outputs = {
        Split-Path $dotnetProjects -Leaf |
            Join-Path -Path { "$OutputBin${/}$_" } -ChildPath { "$_.dll" }
    }
    Jobs    = "Compile", {
        $local:options = @{} + $script:dotnetOptions

        # We never do self-contained builds
        if ($options.ContainsKey("-runtime") -or $options.ContainsKey("-ucr")) {
            $options["-no-self-contained"] = $true
        }

        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -Leaf
            if (Test-Path "Variable:GitVersion.$((Split-Path $project -Leaf).ToLower())") {
                $options["p"] = "Version=$((Get-Variable "GitVersion.$((Split-Path $project -Leaf).ToLower())" -ValueOnly).InformationalVersion)"
            }

            Write-Build Gray "dotnet publish $project --configuration $configuration --output $OutputBin -p $($options["p"])"
            dotnet publish --output "$OutputBin${/}$Name" --no-build --configuration $configuration
        }
    }
}
