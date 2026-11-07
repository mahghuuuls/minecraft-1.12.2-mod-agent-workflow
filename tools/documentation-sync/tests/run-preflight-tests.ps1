#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'github-preflight.psm1') -Force

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function New-MetadataFixture([string]$Repository, [long]$Id, [string]$Branch) {
    $head = '1' * 40
    $repo = @{
        id = $Id; full_name = $Repository; private = $true; visibility = 'private'
        archived = $false; disabled = $false; permissions = @{ push = $true }
        clone_url = 'https://example.invalid/wrong.git'; default_branch = $Branch
    }
    $branchInfo = @{ name = $Branch; commit = @{ sha = $head } }
    $repoPath = "/repos/$Repository"
    $encodedBranch = [Uri]::EscapeDataString($Branch)
    $paths = @($repoPath, "$repoPath/branches/$encodedBranch", "$repoPath/git/ref/heads/$encodedBranch")
    $responses = @{}
    $responses[$paths[0]] = @{ statusCode = 200; body = $repo }
    $responses[$paths[1]] = @{ statusCode = 200; body = $branchInfo }
    $responses[$paths[2]] = @{ statusCode = 409; body = @{ message = 'Git Repository is empty.' } }
    $calls = [System.Collections.Generic.List[string]]::new()
    $readMetadata = {
        param([string]$Path)
        $calls.Add($Path)
        if (-not $responses.ContainsKey($Path)) { throw 'Unexpected mock request' }
        $response = $responses[$Path]
        $json = ConvertTo-Json -InputObject $response.body -Depth 10 -Compress
        return @{ statusCode = $response.statusCode; body = (ConvertFrom-Json -InputObject $json -AsHashtable -NoEnumerate) }
    }.GetNewClosure()
    return @{
        Repository = $Repository; RepositoryId = $Id; Branch = $Branch; head = $head
        repo = $repo; branchInfo = $branchInfo
        paths = $paths; responses = $responses; calls = $calls; ReadMetadata = $readMetadata
    }
}

function Invoke-Preflight($Fixture) {
    $options = @{
        Repository = $Fixture.Repository; RepositoryId = $Fixture.RepositoryId
        Branch = $Fixture.Branch; ReadMetadata = $Fixture.ReadMetadata
    }
    return Test-GitHubPilotDestination @options
}

$count = 0
foreach ($repository in 'first-owner/docs', 'second-owner/team-notes') {
    $fixture = New-MetadataFixture $repository (1234 + $count) 'docs/pilot'
    $result = Invoke-Preflight $fixture
    Assert-Equal $result.status 'verified' 'A valid private destination was refused.'
    Assert-Equal $result.repositoryId $fixture.RepositoryId 'Repository ID was not retained.'
    Assert-Equal $result.branchRef 'refs/heads/docs/pilot' 'Wrong branch selected.'
    Assert-Equal $result.head $fixture.head 'Wrong branch head selected.'
    Assert-Equal $result.gitUri "ssh://git@github.com/$repository.git" 'An untrusted clone URL was used.'
    Assert-Equal ($fixture.calls -join '|') ($fixture.paths[0..1] -join '|') 'Unexpected preflight routes.'
    $count++
    Write-Host "PASS independent configured destination $repository"
}

$fixture = New-MetadataFixture 'example-owner/docs' 789 'main'
$fixture.responses[$fixture.paths[1]].statusCode = 404
$first = Invoke-Preflight $fixture
Assert-Equal $first.status 'verified' 'A confirmed empty private repository was refused.'
Assert-Equal $first.branchRef 'refs/heads/main' 'The first commit targeted the wrong branch.'
Assert-Equal $first.head $null 'An empty repo was assigned an existing head.'
Assert-Equal ($fixture.calls -join '|') ($fixture.paths -join '|') 'Unexpected first-upload preflight routes.'
$count++
Write-Host 'PASS confirmed empty private repository'

$cases = @(
    @{ name = 'wrong repository ID'; reason = 'repository_identity_mismatch'; calls = 1; mutate = { param($f) $f.repo.id++ } },
    @{ name = 'wrong repository name'; reason = 'repository_identity_mismatch'; calls = 1; mutate = { param($f) $f.repo.full_name = 'somebody-else/docs' } },
    @{ name = 'public repository'; reason = 'repository_not_private'; calls = 1; mutate = { param($f) $f.repo.private = $false; $f.repo.visibility = 'public' } },
    @{ name = 'internal repository'; reason = 'repository_not_private'; calls = 1; mutate = { param($f) $f.repo.visibility = 'internal' } },
    @{ name = 'malformed visibility'; reason = 'repository_not_private'; calls = 1; mutate = { param($f) $f.repo.visibility = @('private') } },
    @{ name = 'read-only access'; reason = 'write_access_unverified'; calls = 1; mutate = { param($f) $f.repo.permissions.push = $false } },
    @{ name = 'missing permissions'; reason = 'write_access_unverified'; calls = 1; mutate = { param($f) $f.repo.Remove('permissions') } },
    @{ name = 'archived repository'; reason = 'write_access_unverified'; calls = 1; mutate = { param($f) $f.repo.archived = $true } },
    @{ name = 'authentication required'; reason = 'access_denied'; calls = 1; mutate = { param($f) $f.responses[$f.paths[0]].statusCode = 401 } },
    @{ name = 'access denied'; reason = 'access_denied'; calls = 1; mutate = { param($f) $f.responses[$f.paths[0]].statusCode = 403 } },
    @{ name = 'missing or inaccessible repository'; reason = 'metadata_not_found'; calls = 1; mutate = { param($f) $f.responses[$f.paths[0]].statusCode = 404 } },
    @{ name = 'repository redirect'; reason = 'metadata_unavailable'; calls = 1; mutate = { param($f) $f.responses[$f.paths[0]].statusCode = 301 } },
    @{ name = 'missing nondefault branch'; reason = 'metadata_not_found'; calls = 2; mutate = { param($f) $f.repo.default_branch = 'main'; $f.responses[$f.paths[1]].statusCode = 404 } },
    @{ name = 'missing default branch on nonempty repo'; reason = 'empty_repository_unverified'; calls = 3; mutate = { param($f) $f.responses[$f.paths[1]].statusCode = 404; $f.responses[$f.paths[2]].statusCode = 404 } },
    @{ name = 'branch appears during preflight'; reason = 'empty_repository_unverified'; calls = 3; mutate = { param($f) $f.responses[$f.paths[1]].statusCode = 404; $f.responses[$f.paths[2]].statusCode = 200 } },
    @{ name = 'empty status with ambiguous response'; reason = 'empty_repository_unverified'; calls = 3; mutate = { param($f) $f.responses[$f.paths[1]].statusCode = 404; $f.responses[$f.paths[2]].body.message = 'Other conflict' } },
    @{ name = 'empty check access denied'; reason = 'access_denied'; calls = 3; mutate = { param($f) $f.responses[$f.paths[1]].statusCode = 404; $f.responses[$f.paths[2]].statusCode = 403 } },
    @{ name = 'wrong branch'; reason = 'branch_identity_unverified'; calls = 2; mutate = { param($f) $f.branchInfo.name = 'main' } },
    @{ name = 'unverified branch head'; reason = 'branch_identity_unverified'; calls = 2; mutate = { param($f) $f.branchInfo.commit.sha = '0' * 40 } },
    @{ name = 'malformed branch head'; reason = 'branch_identity_unverified'; calls = 2; mutate = { param($f) $f.branchInfo.commit.sha = @('1' * 40) } },
    @{ name = 'invalid destination input'; reason = 'invalid_configuration'; calls = 0; mutate = { param($f) $f.Repository = 'https://example.invalid/owner/docs' } }
)
foreach ($case in $cases) {
    $fixture = New-MetadataFixture 'example-owner/docs' 789 'docs/pilot'
    [void](& $case.mutate $fixture)
    $result = Invoke-Preflight $fixture
    Assert-Equal $result.status 'pending' "The $($case.name) case was accepted."
    Assert-Equal $result.reason $case.reason "Unexpected outcome for $($case.name)."
    Assert-Equal $result['gitUri'] $null 'A failed preflight supplied a write destination.'
    Assert-Equal $fixture.calls.Count $case.calls 'Preflight continued past the failed check.'
    $count++
    Write-Host "PASS $($case.name)"
}

$failure = Test-GitHubPilotDestination -Repository 'example-owner/docs' -RepositoryId 789 -Branch 'docs/pilot' -ReadMetadata {
    throw 'Mock transport failure with secret-looking context'
}
Assert-Equal $failure.reason 'metadata_unavailable' 'Transport error was not sanitized.'
$count++
Write-Host 'PASS transport failure redaction'
Write-Host "$count mocked GitHub preflight cases passed."
