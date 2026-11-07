#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitHubMetadata([scriptblock]$ReadMetadata, [string]$Path, [int[]]$ExpectedStatus = @(200)) {
    # The caller supplies an authenticated GET provider. It must reject redirects
    # and return the HTTP status and parsed JSON without logging credentials.
    try { $response = & $ReadMetadata $Path }
    catch { throw 'metadata_unavailable' }
    if ($response -isnot [System.Collections.IDictionary] -or $response['statusCode'] -isnot [int]) {
        throw 'invalid_metadata_response'
    }
    $status = $response['statusCode']
    if ($status -in $ExpectedStatus) { return $response }
    switch ($status) {
        401 { throw 'access_denied' }
        403 { throw 'access_denied' }
        404 { throw 'metadata_not_found' }
        default { throw 'metadata_unavailable' }
    }
}

function Test-GitHubPilotDestination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Repository,
        [Parameter(Mandatory)] [long]$RepositoryId,
        [Parameter(Mandatory)] [string]$Branch,
        [Parameter(Mandatory)] [scriptblock]$ReadMetadata
    )

    try {
        if ($Repository -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+\z' -or
            ($Repository.Split('/')[-1] -in '.', '..') -or $Repository.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase) -or
            $RepositoryId -le 0 -or $Branch -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._/-]*\z' -or
            $Branch -match '\.\.|//|(?:^|/)\.|\.lock(?:/|$)|[./]$') {
            throw 'invalid_configuration'
        }

        $repoPath = "/repos/$Repository"
        $repositoryInfo = (Get-GitHubMetadata $ReadMetadata $repoPath)['body']
        if ($repositoryInfo -isnot [System.Collections.IDictionary] -or
            ($repositoryInfo['id'] -isnot [int] -and $repositoryInfo['id'] -isnot [long]) -or
            $repositoryInfo['id'] -ne $RepositoryId -or $repositoryInfo['full_name'] -isnot [string] -or
            $repositoryInfo['full_name'] -ine $Repository) {
            throw 'repository_identity_mismatch'
        }
        if ($repositoryInfo['private'] -isnot [bool] -or -not $repositoryInfo['private'] -or
            $repositoryInfo['visibility'] -isnot [string] -or $repositoryInfo['visibility'] -cne 'private') {
            throw 'repository_not_private'
        }
        $permissions = $repositoryInfo['permissions']
        if ($permissions -isnot [System.Collections.IDictionary] -or $permissions['push'] -isnot [bool] -or
            -not $permissions['push'] -or $repositoryInfo['archived'] -isnot [bool] -or $repositoryInfo['archived'] -or
            $repositoryInfo['disabled'] -isnot [bool] -or $repositoryInfo['disabled']) {
            throw 'write_access_unverified'
        }

        $encodedBranch = [Uri]::EscapeDataString($Branch)
        $branchResponse = Get-GitHubMetadata $ReadMetadata "$repoPath/branches/$encodedBranch" @(200, 404)
        $head = $null
        if ($branchResponse['statusCode'] -eq 404) {
            if ($repositoryInfo['default_branch'] -isnot [string] -or $repositoryInfo['default_branch'] -cne $Branch) {
                throw 'metadata_not_found'
            }
            $refResponse = Get-GitHubMetadata $ReadMetadata "$repoPath/git/ref/heads/$encodedBranch" @(200, 404, 409)
            $refBody = $refResponse['body']
            if ($refResponse['statusCode'] -ne 409 -or $refBody -isnot [System.Collections.IDictionary] -or
                $refBody['message'] -isnot [string] -or $refBody['message'] -cne 'Git Repository is empty.') {
                throw 'empty_repository_unverified'
            }
        }
        else {
            $branchInfo = $branchResponse['body']
            if ($branchInfo -isnot [System.Collections.IDictionary] -or $branchInfo['name'] -isnot [string] -or
                $branchInfo['name'] -cne $Branch -or
                $branchInfo['commit'] -isnot [System.Collections.IDictionary] -or
                $branchInfo['commit']['sha'] -isnot [string] -or
                $branchInfo['commit']['sha'] -cnotmatch '\A[a-f0-9]{40}\z' -or
                $branchInfo['commit']['sha'] -ceq ('0' * 40)) {
                throw 'branch_identity_unverified'
            }
            $head = $branchInfo['commit']['sha']
        }
        return @{
            status = 'verified'
            repository = $repositoryInfo['full_name']
            repositoryId = $RepositoryId
            branchRef = "refs/heads/$Branch"
            head = $head
            gitUri = "ssh://git@github.com/$Repository.git"
        }
    }
    catch {
        return @{ status = 'pending'; reason = $_.Exception.Message }
    }
}

Export-ModuleMember -Function Test-GitHubPilotDestination
