# Project Documentation Backup

Use this procedure only for the active mod workspace. The local `workspace/documentation/` files and approval ledger remain authoritative. A backup can include drafts and preserves their approval status.

The root preference file follows the separate [Shared Owner Defaults procedure](shared-owner-defaults.md).

## Setup

- Read the authoritative [local owner defaults](../guidelines/process-control.md#local-owner-defaults). Automatic backups require an explicit saved approval in its Shared Documentation Backup section and a pinned private GitHub repository name, numeric ID, and branch. Read the owner's current restrictions before invoking the tool. Keep manual operation when approval is absent or the owner has paused automatic backups.
- Confirm the documentation repository is separate from the process and mod source repositories. Treat credentials as an environment prerequisite. Keep them in the existing authenticated GitHub and SSH mechanisms.
- Use the documentation project ID already bound in `workspace/documentation-sync/state.json`, if present. Otherwise record `documentation_project_id` in the ignored `workspace/project.properties` as soon as backup is enabled. Use the verified mod ID for an existing mod when available. For a new project without a mod ID, use a permanent unique lowercase ID such as `mod-` followed by a GUID without punctuation. Retain it through renames and later setup writes. If the other properties are deferred, record the ID alone. A collision or unverified occupied directory requires owner resolution.

## Run a Backup

The timing is defined in [Process Control](../guidelines/process-control.md#documentation-backup-checkpoints). Invoke `tools/documentation-sync/checkpoint-backup.ps1` through PowerShell 7.4 or later. Use a bundled PowerShell executable if the new version is absent from `PATH`. Pass the absolute active `workspace` path, the applicable `-Trigger` (`checkpoint`, `handoff`, or `resume`), and the owner-provided defaults path with `-OwnerDefaults` when it lives outside the workspace and is not recorded as `owner_defaults_path` in `workspace/project.properties`. A `disabled` result names the owner-defaults file it read (`ownerDefaults`); when that is not the owner's current file, the backup did not run.

Use an existing authenticated GitHub CLI session for metadata reads, or provide `-ReadGitHubMetadata` backed by a trusted authenticated reader such as the GitHub connector. Its contract is in [the tool README](../tools/documentation-sync/README.md#manual-github-pilot). It must obtain fresh responses on each preflight, including the check just before a push. If the shell has a stale `PATH` after installation, the tool checks the standard GitHub CLI path under Program Files. Git uses the existing SSH key and known host key. Report missing credentials or runtime as pending and continue the mod work. Installation and sign-in are separate actions.

The tool reads the saved approval and builds a fresh receipt for routine additions and edits allowed by its persistent-document policy. It verifies the private destination, project binding, branch head, and exact changed paths before each normal push. It can replan a bounded number of times when the branch moves. Automatic runs leave deletions, same-file conflicts, and unknown project bindings pending. Resolve those cases with the owner through the manual preview and approval flow.

For files outside the default allowlist, use the manual flow to get approval for a one-time upload or for recurring backup of exact paths. For recurring backup, show the owner the complete proposed remembered list and use `-SetRememberedIncludes` in both preview and sync as described in [the tool README](../tools/documentation-sync/README.md#file-selection). Earlier one-time approvals cover their original upload. Automatic backups carry forward only the recurring paths approved for this workspace's binding.

Manual approval covers the project's directory and the exact proposed paths and contents. A forward branch advance affecting only other directories can be refreshed and pushed under the same receipt. Request a new preview approval if the project's directory or planned upload changes. Stop on a branch rewind or loss of previously verified history.

Report the outcome separately from project approvals. The checkpoint result is recorded in ignored `workspace/documentation-sync/checkpoint-result.json` when a configured run starts. The per-file bases and confirmed remote revision live in `workspace/documentation-sync/state.json`. If the runner could not start or record an outcome, carry the pending backup in the handoff and retry at the next eligible trigger.

## Optional Artwork Backup

- Save `- Artwork backup: Approved.` in the Shared Documentation Backup section of the owner defaults when the owner separately opts in. Automatic artwork backup also requires the documentation backup approval and uses its pinned private destination.
- Show the owner the exact versions to back up. Record approved final exports and editable sources under their asset's `final/` folder. Keep candidates, previews, and working drafts local. Record a reference image only after the owner explicitly approves storing that exact copy in the private backup. Keep reference provenance in the project's usual records.
- Record each approved path and SHA-256 in the local `workspace/artwork/backup-manifest.json` using [the tool format](../tools/documentation-sync/README.md#artwork-selection). Hash the version the owner reviewed. Ask the owner to approve a changed version before replacing its hash. Never refresh hashes automatically.
- At the usual checkpoint and handoff triggers, the runner backs up the manifest's verified files under `<projectId>/.artwork/`. Report missing files, mismatched hashes, and conflicts as pending. Removing a path from the manifest or pausing artwork backup stops future uploads for that path. Existing remote copies and history are retained.
