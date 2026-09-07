#requires -Version 5.1
# Local tests with fake responses. These do NOT certify a Supabase project.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/Test-SupabaseConnection.ps1')

$script:passed = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    $didThrow = $false
    try { & $Action | Out-Null } catch { $didThrow = $true }
    Assert-True $didThrow $Message
}
function Test-Case {
    param([string]$Name, [scriptblock]$Action)
    & $Action
    $script:passed++
    Write-Output ('PASS: ' + $Name)
}

$testDirectory = Join-Path $PSScriptRoot '../artifacts/local-tests'
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
$testConfig = Join-Path $testDirectory 'fake.env'
$testUrl = 'https://abcdefghijklmnopqrst.supabase.co'
$testKey = 'sb_publishable_synthetic_test_only'
function Set-TestConfig {
    param([string]$Url = $testUrl, [string]$Key = $testKey, [string]$Extra = '')
    @(('SUPABASE_URL=' + $Url), ('SUPABASE_PUBLISHABLE_KEY=' + $Key), $Extra) |
        Set-Content -LiteralPath $testConfig -Encoding UTF8
}

Test-Case 'accept hosted project URL and publishable key' {
    Set-TestConfig
    $config = Read-Garage99Config $testConfig
    Assert-True ($config.ProjectRef -eq 'abcdefghijklmnopqrst') 'Wrong project reference.'
}
Test-Case 'reject private key before sending requests' {
    Set-TestConfig -Key 'sb_secret_synthetic'
    Assert-Throws { Read-Garage99Config $testConfig } 'Secret key accepted.'
}
Test-Case 'reject legacy JWT key' {
    Set-TestConfig -Key 'eyJ.synthetic.key'
    Assert-Throws { Read-Garage99Config $testConfig } 'JWT key accepted.'
}
Test-Case 'reject HTTP, redirects disguised as URL, and foreign hosts' {
    foreach ($invalidUrl in @('http://abcdefghijklmnopqrst.supabase.co',
        'https://abcdefghijklmnopqrst.supabase.co.attacker.example',
        'https://abcdefghijklmnopqrst.supabase.co/path',
        'https://abcdefghijklmnopqrst.supabase.co?redirect=elsewhere')) {
        Set-TestConfig -Url $invalidUrl
        Assert-Throws { Read-Garage99Config $testConfig } 'Unsafe URL accepted.'
    }
}
Test-Case 'reject mismatched project reference' {
    Set-TestConfig -Extra 'SUPABASE_PROJECT_REF=wrong'
    Assert-Throws { Read-Garage99Config $testConfig } 'Mismatched reference accepted.'
}
Test-Case 'reject duplicate configuration' {
    Set-TestConfig -Extra ('SUPABASE_URL=' + $testUrl)
    Assert-Throws { Read-Garage99Config $testConfig } 'Duplicate accepted.'
}

# Fake the HTTP boundary; execute the real parser/validator logic.
function Invoke-Garage99Request {
    param([hashtable]$Config, [string]$Method, [string]$Suffix, [string]$Body)
    $script:calls++
    if ($script:scenario -eq 'network') { throw 'Synthetic network failure.' }
    if ($Method -eq 'GET') {
        if ($script:scenario -eq 'invalid-key') { return @{ Status = 401; Content = '{"message":"Invalid API key"}' } }
        if ($script:scenario -eq 'missing') { return @{ Status = 200; Content = '[]' } }
        if ($script:scenario -eq 'bad-json') { return @{ Status = 200; Content = '[invalid' } }
        if ($script:scenario -eq 'changed' -and $script:calls -gt 1) {
            return @{ Status = 200; Content = '[{"id":"garage99-db-check","message":"modified"}]' }
        }
        return @{ Status = 200; Content = '[{"id":"garage99-db-check","message":"garage99-dev: lectura verificada"}]' }
    }
    if ($script:scenario -eq 'write-allowed') { return @{ Status = 201; Content = '[]' } }
    if ($script:scenario -eq 'wrong-error') { return @{ Status = 401; Content = '{"code":"PGRST301"}' } }
    if ($script:scenario -eq 'server-error') { return @{ Status = 500; Content = '{"code":"42501"}' } }
    return @{ Status = 401; Content = '{"code":"42501","message":"permission denied for table connection_check"}' }
}
Set-TestConfig
$mockConfig = Read-Garage99Config $testConfig

Test-Case 'accept reads and three denied writes with unchanged data' {
    $script:scenario = 'valid'; $script:calls = 0
    $result = Invoke-Garage99Validation $mockConfig
    Assert-True ($result.status -eq 'PASS') 'Valid scenario failed.'
    Assert-True ($result.checks.Count -eq 4) 'Missing checks.'
    Assert-True ($script:calls -eq 7) 'Missing read-after-write checks.'
    Assert-True (-not (($result | ConvertTo-Json -Depth 6) -match $testKey)) 'Key leaked in report.'
}
foreach ($case in @('invalid-key', 'missing', 'bad-json', 'changed', 'write-allowed', 'wrong-error', 'server-error', 'network')) {
    $script:scenario = $case
    $script:calls = 0
    Test-Case ('reject ' + $case + ' instead of falsely passing') {
        Assert-Throws { Invoke-Garage99Validation $mockConfig } 'Invalid scenario passed.'
    }
}

Test-Case 'CLI resolves default paths and runs under Windows PowerShell 5.1' {
    # Invoke the entry point in a child process with a missing config: no network.
    # Omitting ReportPath exercises the default that failed during live testing.
    # Isolate the copied runner so this test cannot replace live project evidence.
    $isolatedScripts = Join-Path $testDirectory 'cli-project/scripts'
    New-Item -ItemType Directory -Path $isolatedScripts -Force | Out-Null
    $isolatedScript = Join-Path $isolatedScripts 'Test-SupabaseConnection.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../scripts/Test-SupabaseConnection.ps1') -Destination $isolatedScript -Force
    & powershell -NoProfile -ExecutionPolicy Bypass -File $isolatedScript | Out-Null
    Assert-True ($LASTEXITCODE -eq 1) 'Missing config must return exit code 1.'
    $isolatedReport = Join-Path $testDirectory 'cli-project/artifacts/supabase-connection.json'
    Assert-True (Test-Path -LiteralPath $isolatedReport) 'CLI did not resolve its default report path.'
    $failureReport = Get-Content -LiteralPath $isolatedReport -Raw | ConvertFrom-Json
    Assert-True ($failureReport.status -eq 'FAIL') 'Missing config produced a false PASS.'
}

Write-Output ("Local tests: $script:passed passed. Live Supabase validation is separate.")
