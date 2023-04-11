Add-BuildTask Clean {

    foreach ($project in $dotnetProjects) {
        Remove-BuildItem $project/bin, $project/obj
    }
    # This will blow away everything that's .gitignored, wicked fast
    git clean -Xdf
    # We need to recreate this because it's normally created by "Initialize.ps1"
    New-Item $OutputDirectory -ItemType Directory -Force | Out-Null
}