param()

$ErrorActionPreference = 'Stop'
$sourceScript = Join-Path $PSScriptRoot 'link-repos.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('movember-links-' + [guid]::NewGuid().ToString('N'))
$base = Join-Path $fixture 'movember-bmad_setup'
$repo = Join-Path $fixture 'movember-test\Code'

function Assert([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $base 'scripts'), (Join-Path $base '_bmad'), (Join-Path $base '.agents\skills'), (Join-Path $base '.github\agents'), $repo -Force | Out-Null
    Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $base 'scripts\link-repos.ps1')
    Set-Content -Path (Join-Path $base '.github\agents\bmad-agent-test.agent.md') -Value 'profile'
    git -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
    $exclude = (git -C $repo rev-parse --git-path info/exclude).Trim()
    if (-not [IO.Path]::IsPathRooted($exclude)) { $exclude = Join-Path $repo $exclude }
    Add-Content -Path $exclude -Value '/existing-entry'

    & (Join-Path $base 'scripts\link-repos.ps1') -Repos movember-test
    Assert (Test-Path (Join-Path $repo '_bmad')) 'missing _bmad junction'
    Assert ((Get-Item (Join-Path $repo '_bmad')).LinkType -eq 'Junction') '_bmad is not a junction'
    Assert (Test-Path (Join-Path $repo '.github\agents\bmad-agent-test.agent.md')) 'missing agent copy'
    Assert (-not (Test-Path (Join-Path $repo '.claude\settings.json'))) 'missing source settings should be skipped'
    Assert ((Get-Content $exclude) -contains '/existing-entry') 'existing excludes were lost'

    $contents = [IO.File]::ReadAllText($exclude)
    [IO.File]::WriteAllText($exclude, $contents.Replace('movember-bmad_setup', 'Movember-bmad_setup'))
    & (Join-Path $base 'scripts\link-repos.ps1') -Repos movember-test
    Assert (-not ((Get-Content $exclude) -match 'Movember-bmad_setup')) 'legacy markers were not migrated'
    Assert ((@(Get-Content $exclude | Where-Object { $_ -eq '/_bmad' })).Count -eq 1) 'repeat run duplicated excludes'

    New-Item -ItemType Directory -Path (Join-Path $base '.claude'), (Join-Path $repo '.claude') -Force | Out-Null
    Set-Content -Path (Join-Path $base '.claude\settings.json') -Value '{"hooks":{}}'
    Set-Content -Path (Join-Path $repo '.claude\settings.json') -Value '{"own":true}'
    & (Join-Path $base 'scripts\link-repos.ps1') -Repos movember-test
    Assert ((Get-Content (Join-Path $repo '.claude\settings.json') -Raw) -match 'own') 'repo settings overwritten'

    & (Join-Path $base 'scripts\link-repos.ps1') -Repos movember-test -Unlink
    Assert (-not (Test-Path (Join-Path $repo '_bmad'))) 'junction not removed'
    Assert (Test-Path (Join-Path $base '_bmad')) 'junction source removed'
    Assert (-not (Test-Path (Join-Path $repo '.github\agents\bmad-agent-test.agent.md'))) 'copy not removed'
    Assert (Test-Path (Join-Path $repo '.claude\settings.json')) 'repo settings removed'
    Assert ((Get-Content $exclude) -contains '/existing-entry') 'unmanaged exclude removed'
    Assert (-not ((Get-Content $exclude) -contains '/_bmad')) 'managed exclude remains'

    $directRepo = Join-Path $fixture 'movember-web'
    New-Item -ItemType Directory -Path $directRepo, (Join-Path $base '.claude\skills') -Force | Out-Null
    git -C $directRepo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
    & (Join-Path $base 'scripts\link-repos.ps1')
    Assert ((Get-Item (Join-Path $directRepo '.claude\skills')).LinkType -eq 'Junction') 'direct checkout not linked'
    Assert (Test-Path (Join-Path $directRepo '.claude\settings.json')) 'source settings not copied'
    & (Join-Path $base 'scripts\link-repos.ps1') -Unlink
    Assert (-not (Test-Path (Join-Path $directRepo '.claude\settings.json'))) 'managed settings not removed'
    Assert ((Get-Content (Join-Path $repo '.claude\settings.json') -Raw) -match 'own') 'unmanaged settings removed'
    Write-Host 'link-repos smoke test passed'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
