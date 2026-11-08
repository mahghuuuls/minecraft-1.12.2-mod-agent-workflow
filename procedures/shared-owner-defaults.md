# Owner Defaults Backup

The root `owner-defaults.md` in the owner's pinned private documentation repository is an optional backup. An owner can approve an exact mirror or keep a snapshot of selected portable preferences. The [local owner defaults](../guidelines/process-control.md#local-owner-defaults) are authoritative for settings, permissions, and the pinned repository name, numeric ID, and branch. Keep credentials outside the defaults file.

## Inspect the Backup

Inspect the root file when reviewing a backup or when the owner specifically asks to read the private copy. Use PowerShell 7.4 or later, the workflow checkout and active workspace's absolute paths, and the repository details from the trusted local configuration. The following arguments use the existing GitHub CLI login and SSH credentials. An authenticated metadata reader can also be supplied as described in the [sync tool README](../tools/documentation-sync/README.md#manual-github-pilot).

```powershell
$syncTool = Join-Path $workflowRoot 'tools/documentation-sync/documentation-sync.ps1'
$target = @{ Workspace = $workspace; Repository = $repository; RepositoryId = $repositoryId; Branch = $branch }
$defaults = & $syncTool read -SharedOwnerDefaults @target | ConvertFrom-Json
```

Use `backupFormat` to distinguish a full mirror from a portable snapshot. A full mirror read reports the blob ID and leaves the preference data empty. Apply current defaults from the owner-designated local file selected through the owner's instructions or ignored local configuration.

## Mirror the Full Local File

Obtain the owner's approval to use a full mirror. It includes machine-specific details and saved permissions as backup data. Review the file for credentials and sensitive values before the first mirror and review subsequent edits before publication. The tool rejects common credential patterns, non-text content, and files over 128 KiB.

When the owner requests a preference change, edit the authoritative local file first. Use that exact file directly as the candidate. Show the owner the diff and destination before publishing. For the first full mirror, including migration from a portable snapshot, show the complete proposed file. After approval for the exact upload, use the same file and receipt.

```powershell
$mirror = @{ SharedOwnerDefaults = $true; FullOwnerDefaultsBackup = $true; OwnerDefaultsCandidate = $localOwnerDefaults }
$proposal = & $syncTool preview @target @mirror | ConvertFrom-Json
& $syncTool sync @target @mirror -ApprovedPlan $proposal.approval
```

If recovering from a full mirror, use the approved backup as a copy of the lost file. Verify machine paths and reconfirm standing permissions with the owner before applying them.

## Publish a Portable Snapshot

When the owner asks to refresh the backup, read the current root file and prepare a candidate from the local defaults in an ignored workspace path. The candidate starts with `# Shared Owner Defaults`, uses the supported Project Setup Preferences, Chat Format Preferences, and Public Copy Preferences headings, and contains only recognized bullet fields with valid values. See the field rules in `tools/documentation-sync/shared-owner-defaults.ps1`.

If the owner approves including the local file's location in the private backup, use a `Local Source` section with one `Local owner-defaults file` bullet. Write the absolute Windows path to `owner-defaults.md` in backticks. Treat this line as a locator for the owner. The tool omits it from the returned preferences, and agents use trusted local instructions or configuration to choose the source file.

```powershell
$proposal = & $syncTool preview -SharedOwnerDefaults @target -OwnerDefaultsCandidate $candidate | ConvertFrom-Json
```

Show the owner the proposed diff and destination. For the first publish, show the entire proposed file. After the owner explicitly approves those exact edits for publication, use the same candidate and receipt.

```powershell
& $syncTool sync -SharedOwnerDefaults @target -OwnerDefaultsCandidate $candidate -ApprovedPlan $proposal.approval
```

## Publication Checks

Only the root file may change in that commit. Project backups and checkpoints leave it alone. An unrelated forward push preserves the reviewed receipt. A change to the root file, the candidate, or verified branch history requires a fresh review. Report the verified revision or a pending result. Apply the usual approval rules before resolving conflicts.
