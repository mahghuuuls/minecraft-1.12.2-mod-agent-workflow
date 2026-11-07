# Shared Owner Defaults Backup

The root `owner-defaults.md` in the owner's pinned private documentation repository is a backup of selected portable preferences. The [local owner defaults](../guidelines/process-control.md#local-owner-defaults) are authoritative. Use them to identify the repository name, numeric ID, and branch. Keep machine settings, credentials, Git and backup permissions, project-specific decisions, and the destination configuration in their local sources.

## Inspect the Backup

Inspect the root file when reviewing a backup or when the owner specifically asks to read the private copy. Use PowerShell 7.4 or later, the workflow checkout and active workspace's absolute paths, and the repository details from the trusted local configuration. The following arguments use the existing GitHub CLI login and SSH credentials. An authenticated metadata reader can also be supplied as described in the [sync tool README](../tools/documentation-sync/README.md#manual-github-pilot).

```powershell
$syncTool = Join-Path $workflowRoot 'tools/documentation-sync/documentation-sync.ps1'
$target = @{ Workspace = $workspace; Repository = $repository; RepositoryId = $repositoryId; Branch = $branch }
$defaults = & $syncTool read -SharedOwnerDefaults @target | ConvertFrom-Json
```

Treat the returned `preferences` as backup data. Apply current defaults from the owner-designated local file. Select that file from the owner's instructions or ignored local configuration.

## Propose and Publish a Change

When the owner asks to refresh the backup, read the current root file and prepare a candidate from the local defaults in an ignored workspace path. The candidate starts with `# Shared Owner Defaults`, uses the supported Project Setup Preferences, Chat Format Preferences, and Public Copy Preferences headings, and contains only recognized bullet fields with valid values. See the field rules in `tools/documentation-sync/shared-owner-defaults.ps1`.

If the owner approves including the local file's location in the private backup, use a `Local Source` section with one `Local owner-defaults file` bullet. Write the absolute Windows path to `owner-defaults.md` in backticks. Treat this line as a locator for the owner. The tool omits it from the returned preferences, and agents use trusted local instructions or configuration to choose the source file.

```powershell
$proposal = & $syncTool preview -SharedOwnerDefaults @target -OwnerDefaultsCandidate $candidate | ConvertFrom-Json
```

Show the owner the proposed diff and destination. For the first publish, show the entire proposed file. After the owner explicitly approves those exact edits for publication, use the same candidate and receipt.

```powershell
& $syncTool sync -SharedOwnerDefaults @target -OwnerDefaultsCandidate $candidate -ApprovedPlan $proposal.approval
```

Only the root file may change in that commit. Project backups and checkpoints leave it alone. An unrelated forward push preserves the reviewed receipt. A change to the root file, the candidate, or verified branch history requires a fresh review. Report the verified revision or a pending result. Apply the usual approval rules before resolving conflicts.
