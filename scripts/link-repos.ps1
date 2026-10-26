<#
.SYNOPSIS
  Shares the BMAD installation in movember-bmad_setup with movember-* repositories.

.DESCRIPTION
  Creates junctions for available .claude/skills, .agents/skills and _bmad folders.
  Copies available BMAD Copilot agent profiles and Claude settings when the target
  does not own those files. Records managed paths in each repo's .git/info/exclude.
  Re-running refreshes managed copies; -Unlink removes only managed paths.

  Repos may be Git checkouts directly under a movember-* folder or in its Code
  subfolder (as in movember-android/Code). Missing optional source files are skipped.

.PARAMETER Repos
  movember-* folder names to process. Defaults to all neighboring movember-* folders
  containing a Git checkout. The movember-bmad_setup folder is never a target.

.PARAMETER Unlink
  Remove the managed junctions, copies and Git exclude entries.

.EXAMPLE
  .\scripts\link-repos.ps1
  .\scripts\link-repos.ps1 -Repos movember-android
  .\scripts\link-repos.ps1 -Unlink
#>
param(
    [string[]]$Repos,
    [switch]$Unlink
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
$parent = Split-Path -Parent $base
$sourceLinks = @('.claude\skills', '.agents\skills', '_bmad')
$agentsSource = Join-Path $base '.github\agents'
$settingsSource = Join-Path $base '.claude\settings.json'
$gateScript = Join-Path $base '_bmad\custom\gates\apply_copilot.py'
$marker = '# movember-bmad_setup links (managed by movember-bmad_setup/scripts/link-repos.ps1)'
$endMarker = '# end movember-bmad_setup links'
$legacyMarker = '# Movember-bmad_setup links (managed by Movember-bmad_setup/scripts/link-repos.ps1)'
$legacyEndMarker = '# end Movember-bmad_setup links'

function Get-RepoPath([string]$folder) {
    if (Test-Path -LiteralPath (Join-Path $folder '.git')) { return $folder }
    $code = Join-Path $folder 'Code'
    if (Test-Path -LiteralPath (Join-Path $code '.git')) { return $code }
    return $null
}

function Get-ExcludeFile([string]$repo) {
    $path = (git -C $repo rev-parse --git-path info/exclude).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Cannot locate Git exclude file for $repo" }
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $repo $path }
    $path = [IO.Path]::GetFullPath($path)
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $path
}

function Test-Tracked([string]$repo, [string]$rel) {
    $tracked = @(git -C $repo ls-files -- ($rel -replace '\\', '/'))
    if ($LASTEXITCODE -ne 0) { throw "Cannot check tracked files in $repo" }
    return ($tracked.Count -gt 0)
}

function Test-Junction([string]$path) {
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    return ($null -ne $item -and $item.LinkType -eq 'Junction')
}

function Remove-Junction([string]$path) {
    cmd /c rmdir "`"$path`"" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not remove junction $path" }
}

if (-not $Unlink -and (Test-Path -LiteralPath $gateScript) -and (Test-Path -LiteralPath $agentsSource)) {
    uv run --quiet $gateScript $agentsSource
    if ($LASTEXITCODE -ne 0) { throw 'apply_copilot.py failed (needs uv and Python 3.11+)' }
}
$agentFiles = @()
if (Test-Path -LiteralPath $agentsSource) {
    $agentFiles = @(Get-ChildItem -LiteralPath $agentsSource -File -Filter 'bmad-agent-*.agent.md')
}

if (-not $Repos) {
    $Repos = @(Get-ChildItem -LiteralPath $parent -Directory -Filter 'movember-*' |
        Where-Object { $_.FullName -ne $base -and (Get-RepoPath $_.FullName) } |
        ForEach-Object { $_.Name })
}

foreach ($name in $Repos) {
    $folder = Join-Path $parent $name
    if ($name -notlike 'movember-*' -or $name -eq (Split-Path -Leaf $base)) {
        Write-Warning "$name is not a target movember-* folder; skipped"
        continue
    }
    $repo = Get-RepoPath $folder
    if (-not $repo) { Write-Warning "$name`: no Git checkout at root or Code, skipped"; continue }
    Write-Host "== $name ($repo)"

    $exclude = Get-ExcludeFile $repo
    $lines = @()
    if (Test-Path -LiteralPath $exclude) { $lines = @([IO.File]::ReadAllLines($exclude)) }
    $start = [array]::IndexOf($lines, $marker)
    $end = [array]::IndexOf($lines, $endMarker)
    $legacyStart = [array]::IndexOf($lines, $legacyMarker)
    $legacyEnd = [array]::IndexOf($lines, $legacyEndMarker)
    if ($legacyStart -ge 0 -or $legacyEnd -ge 0) {
        if ($start -ge 0 -or $end -ge 0) { throw "Multiple managed blocks in $exclude" }
        $start = $legacyStart
        $end = $legacyEnd
    }
    if (($start -ge 0) -ne ($end -ge 0) -or ($start -ge 0 -and $end -lt $start)) {
        throw "Malformed managed block in $exclude"
    }
    $oldPatterns = @()
    if ($start -ge 0) {
        if ($end -gt $start + 1) { $oldPatterns = @($lines[($start + 1)..($end - 1)]) }
        $lines = @($lines | Select-Object -Skip 0 -First $start) +
            @($lines | Select-Object -Skip ($end + 1))
    }
    $patterns = @($oldPatterns)

    foreach ($rel in $sourceLinks) {
        $path = Join-Path $repo $rel
        $target = Join-Path $base $rel
        $pattern = '/' + ($rel -replace '\\', '/')
        if ($Unlink) {
            if (Test-Junction $path) {
                $item = Get-Item -LiteralPath $path -Force
                if (@($item.Target) -contains $target -and $oldPatterns -contains $pattern) {
                    Remove-Junction $path
                    Write-Host "  removed  $rel"
                }
            }
            continue
        }
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if (Test-Junction $path) {
            if (@((Get-Item -LiteralPath $path -Force).Target) -contains $target) {
                $patterns += $pattern
                Write-Host "  ok       $rel"
            } else {
                Write-Warning "  $rel points elsewhere in $name; left alone"
            }
            continue
        }
        if (Test-Path -LiteralPath $path) {
            Write-Warning "  $rel is a real folder in $name; left alone"
            continue
        }
        $dir = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        New-Item -ItemType Junction -Path $path -Target $target | Out-Null
        $patterns += $pattern
        Write-Host "  linked   $rel"
    }

    $agentsDir = Join-Path $repo '.github\agents'
    $copyPatterns = @($oldPatterns | Where-Object { $_ -like '/.github/agents/bmad-agent-*.agent.md' })
    $copyPatterns += @($agentFiles | ForEach-Object { '/.github/agents/' + $_.Name })
    foreach ($pattern in ($copyPatterns | Select-Object -Unique)) {
        $rel = $pattern.TrimStart('/') -replace '/', '\'
        $dest = Join-Path $repo $rel
        if (Test-Tracked $repo $rel) { Write-Warning "  $rel is tracked; left alone"; continue }
        if ($Unlink) {
            if ($oldPatterns -contains $pattern -and (Test-Path -LiteralPath $dest)) {
                Remove-Item -LiteralPath $dest -Force
                Write-Host "  removed  $rel"
            }
            continue
        }
        $source = Join-Path $agentsSource (Split-Path -Leaf $rel)
        if (-not (Test-Path -LiteralPath $source)) { continue }
        if ((Test-Path -LiteralPath $dest) -and $oldPatterns -notcontains $pattern) {
            Write-Warning "  $rel already exists in $name; left alone"
            continue
        }
        if (-not (Test-Path -LiteralPath $agentsDir)) { New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null }
        Copy-Item -LiteralPath $source -Destination $dest -Force
        $patterns += $pattern
    }

    $settingsRel = '.claude\settings.json'
    $settingsPattern = '/.claude/settings.json'
    $settingsDest = Join-Path $repo $settingsRel
    if (Test-Tracked $repo $settingsRel) {
        Write-Warning "  $settingsRel is tracked; left alone"
    } elseif ($Unlink) {
        if ($oldPatterns -contains $settingsPattern -and (Test-Path -LiteralPath $settingsDest)) {
            Remove-Item -LiteralPath $settingsDest -Force
            Write-Host "  removed  $settingsRel"
        }
    } elseif (Test-Path -LiteralPath $settingsSource) {
        if ((Test-Path -LiteralPath $settingsDest) -and $oldPatterns -notcontains $settingsPattern) {
            Write-Warning "  $settingsRel belongs to $name; merge hooks by hand"
        } else {
            $dir = Split-Path -Parent $settingsDest
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item -LiteralPath $settingsSource -Destination $settingsDest -Force
            $patterns += $settingsPattern
            Write-Host "  copied   $settingsRel"
        }
    }

    if ($Unlink) {
        foreach ($dir in @($agentsDir, (Join-Path $repo '.github'), (Join-Path $repo '.claude'), (Join-Path $repo '.agents'))) {
            if ((Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force)) {
                Remove-Item -LiteralPath $dir
            }
        }
    }

    if (-not $Unlink) {
        $lines += @($marker) + @($patterns | Select-Object -Unique) + @($endMarker)
    }
    [IO.File]::WriteAllLines($exclude, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
}
