#requires -Version 5.1
[CmdletBinding()]
param([switch]$Check, [switch]$ReviewedDocs, [switch]$AllowShrink)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = (& uv tool dir).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot locate the installed Graphify environment.' }
$graphPython = Join-Path $toolRoot 'graphifyy/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $graphPython)) {
    throw 'Graphify Python missing. Install with: uv tool install graphifyy'
}
$arguments = @((Join-Path $PSScriptRoot 'update_project_graph.py'))
if ($Check) { $arguments += '--check' }
if ($ReviewedDocs) { $arguments += '--reviewed-docs' }
if ($AllowShrink) { $arguments += '--allow-shrink' }
Push-Location $projectRoot
try {
    & $graphPython @arguments
    $resultCode = $LASTEXITCODE
} finally { Pop-Location }
exit $resultCode
