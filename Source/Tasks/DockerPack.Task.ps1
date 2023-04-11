Add-BuildTask Docker @{
    # This task can only be skipped if the images are newer than the source files
    If      = $dotnetProjects
    Inputs  = {
        $dotnetProjects.Where{ Get-ChildItem $_ -File -Filter Dockerfile } |
            Get-ChildItem -File
    }
    Outputs = {
        # We use the iidfile as a standing for date of the image
        $dotnetProjects.Where{ Get-ChildItem $_ -File -Filter Dockerfile } |
            Split-Path -Leaf | Join-Path -Path $Output -ChildPath { $_.ToLower() }
    }
    Jobs    = {
        foreach ($project in $dotnetProjects.Where{ Get-ChildItem $_ -File -Filter Dockerfile }) {
            Write-Build Gray "dotnet restore $project" @options
            Set-Location $project
            $name = (Split-Path $project -Leaf).ToLower()
            docker build . --tag $name --iidfile (Join-Path $Output $name)
        }
    }
}
