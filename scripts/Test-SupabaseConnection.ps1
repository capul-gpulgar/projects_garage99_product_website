#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath = '',
    [string]$ReportPath = ''
)

# Resolve defaults after parameter binding (Windows PowerShell 5.1).
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '../.env.local' }
if (-not $ReportPath) { $ReportPath = Join-Path $PSScriptRoot '../artifacts/supabase-connection.json' }

function Read-Garage99Config {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Missing .env.local. Copy .env.example and fill the URL and publishable key locally.'
    }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)\s*=(.*)$') {
            throw 'Invalid configuration line. Expected NAME=value (values are never executed).'
        }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($values.ContainsKey($name)) { throw 'Duplicate configuration variable.' }
        $values[$name] = $value
    }
    $url = [string]$values['SUPABASE_URL']
    if ($url -cnotmatch '^https://([a-z0-9]{20})\.supabase\.co/?$') {
        throw 'SUPABASE_URL must be the HTTPS URL of the hosted project, with no path or query.'
    }
    $projectRef = $Matches[1]
    if ($values['SUPABASE_PROJECT_REF'] -and $values['SUPABASE_PROJECT_REF'] -ne $projectRef) {
        throw 'SUPABASE_PROJECT_REF does not match SUPABASE_URL.'
    }
    if ([string]$values['SUPABASE_PUBLISHABLE_KEY'] -cnotmatch '^sb_publishable_[A-Za-z0-9_-]+$') {
        throw 'Use an sb_publishable_ key. Secret keys and legacy JWT keys are not accepted.'
    }
    return @{
        Url = $url.TrimEnd('/')
        Key = $values['SUPABASE_PUBLISHABLE_KEY']
        ProjectRef = $projectRef
    }
}

function Invoke-Garage99Request {
    param([hashtable]$Config, [string]$Method, [string]$Suffix, [string]$Body)
    $parameters = @{
        Uri = $Config.Url + '/rest/v1/connection_check' + $Suffix
        Method = $Method
        Headers = @{ apikey = $Config.Key; Accept = 'application/json' }
        UseBasicParsing = $true
        MaximumRedirection = 0
        TimeoutSec = 20
        ErrorAction = 'Stop'
    }
    if ($Body) {
        $parameters.Body = $Body
        $parameters.ContentType = 'application/json'
    }
    try {
        $response = Invoke-WebRequest @parameters
        return @{ Status = [int]$response.StatusCode; Content = [string]$response.Content }
    }
    catch {
        $httpResponse = $_.Exception.Response
        if ($null -eq $httpResponse) {
            throw 'Network/TLS request failed. Check connectivity; no credential details are logged.'
        }
        $status = [int]$httpResponse.StatusCode
        $content = ''
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $content = $_.ErrorDetails.Message
        }
        elseif ($httpResponse | Get-Member -Name GetResponseStream -MemberType Method) {
            $reader = New-Object System.IO.StreamReader($httpResponse.GetResponseStream())
            try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        return @{ Status = $status; Content = $content }
    }
}

function Get-Garage99Snapshot {
    param([hashtable]$Config)
    $response = Invoke-Garage99Request $Config 'GET' '?select=id,message&order=id.asc' ''
    if ($response.Status -ne 200) {
        throw ('Read failed (HTTP {0}). Check project, migration, key and permissions.' -f $response.Status)
    }
    if (-not $response.Content.TrimStart().StartsWith('[')) { throw 'Expected a JSON array from the Data API.' }
    try { $rows = @(ConvertFrom-Json -InputObject $response.Content -ErrorAction Stop) }
    catch { throw 'The Data API did not return valid JSON.' }
    $fixture = @($rows | Where-Object { $_.id -eq 'garage99-db-check' })
    if ($fixture.Count -ne 1 -or $fixture[0].message -ne 'garage99-dev: lectura verificada') {
        throw 'Expected SQL fixture is missing or changed. Run scripts/validacion-db.sql first.'
    }
    return (ConvertTo-Json -InputObject @($rows) -Depth 5 -Compress)
}

function Invoke-Garage99Validation {
    param([hashtable]$Config)
    $baseline = Get-Garage99Snapshot $Config
    $checks = New-Object 'System.Collections.Generic.List[object]'
    $checks.Add(@{ check = 'public_read_matches_sql_fixture'; passed = $true })
    $probeId = 'write-probe-' + [guid]::NewGuid().ToString('N')
    $attempts = @(
        @{ Method = 'POST'; Suffix = ''; Body = (ConvertTo-Json -Compress @{ id = $probeId; message = 'synthetic-denied-insert' }) },
        @{ Method = 'PATCH'; Suffix = '?id=eq.garage99-db-check'; Body = '{"message":"synthetic-denied-update"}' },
        @{ Method = 'DELETE'; Suffix = '?id=eq.garage99-db-check'; Body = '' }
    )
    foreach ($attempt in $attempts) {
        $response = Invoke-Garage99Request $Config $attempt.Method $attempt.Suffix $attempt.Body
        $errorCode = ''
        try { $errorCode = (ConvertFrom-Json -InputObject $response.Content -ErrorAction Stop).code } catch { }
        # A timeout, expired key or unrelated 4xx does not prove write protection.
        if ($response.Status -notin @(401, 403) -or $errorCode -ne '42501') {
            throw ('{0}: expected permission_denied (42501), received HTTP {1}. Check the synthetic table before retrying.' -f $attempt.Method, $response.Status)
        }
        if ((Get-Garage99Snapshot $Config) -cne $baseline) {
            throw 'The table changed during validation. Investigate before rerunning.'
        }
        $checks.Add(@{ check = ($attempt.Method.ToLower() + '_denied_and_data_unchanged'); passed = $true; http_status = $response.Status; sqlstate = $errorCode })
    }
    return @{
        status = 'PASS'
        scope = 'live_supabase_rest_anonymous_access'
        project_ref = $Config.ProjectRef
        checked_at_utc = [DateTime]::UtcNow.ToString('o')
        checks = $checks.ToArray()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    $validationStarted = [DateTime]::UtcNow.ToString('o')
    try {
        $configuration = Read-Garage99Config $ConfigPath
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $result = Invoke-Garage99Validation $configuration
    }
    catch {
        # Do not persist raw HTTP errors, headers, key values or the local config.
        $result = @{
            status = 'FAIL'
            scope = 'live_supabase_rest_anonymous_access'
            checked_at_utc = $validationStarted
            reason = 'Validation incomplete. Check configuration, SQL fixture, connectivity and table permissions.'
        }
        Write-Warning $result.reason
    }
    $reportFullPath = [IO.Path]::GetFullPath($ReportPath)
    $reportDirectory = [IO.Path]::GetDirectoryName($reportFullPath)
    if (-not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportFullPath -Encoding UTF8
    Write-Output ('Supabase REST: ' + $result.status)
    Write-Output ('Report: ' + $reportFullPath)
    if ($result.status -ne 'PASS') { exit 1 }
}
