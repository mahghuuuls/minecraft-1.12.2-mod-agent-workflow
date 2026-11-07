# Documentation Sync

This tool backs up selected files from `workspace/documentation/` into a private GitHub repository or a disposable local bare Git repository. Each project has a permanent directory with its own identity manifest. The workspace files and approval ledger remain authoritative, including when a draft is backed up.

This pilot requires Windows, Git 2.29 or later, and PowerShell 7.4 or later. The document boundary is checked on Windows file handles. Local mode uses file transport to a bare repository. GitHub mode uses SSH to the verified repository on `github.com`.

## Run Locally

From the workflow repository root, point `$fixtureWorkspace` at a disposable `workspace` directory containing `documentation/`, and point `$fixtureDestination` at a separate local bare test repository. An empty test repository initialized with `git init --bare --initial-branch=main` is sufficient.

```powershell
$review = ./tools/documentation-sync/documentation-sync.ps1 preview -Workspace $fixtureWorkspace -Destination $fixtureDestination -ProjectId sample-mod | ConvertFrom-Json
$review | ConvertTo-Json -Depth 10
```

Preview lists the destination, branch head, exact paths, before and after blob IDs, exclusions, and pending paths. It writes only scratch data. Review the local documents for those paths and apply the approved plan with its receipt and the same options. The receipt checks consistency with the preview. The owner supplies the approval decision separately.

```powershell
./tools/documentation-sync/documentation-sync.ps1 sync -Workspace $fixtureWorkspace -Destination $fixtureDestination -ProjectId sample-mod -ApprovedPlan $review.approval
```

The first approved sync saves its binding after verifying the destination directory is available or matches the project identity. On subsequent runs, the project ID can be read from `workspace/documentation-sync/state.json`. The saved binding pins the destination path, branch, and project ID. `-Branch` defaults to `main`. A branch must exist, or be the declared branch of an empty destination. A verified project can adopt a second workspace by supplying `-AdoptBindingId` with the binding ID from its trusted workspace state. An occupied directory without a matching identity stays pending. IDs found in destination history remain reserved after the directory is removed. For files with no common base, identical copies establish one, different copies stay pending, and a file previously removed in destination history stays pending on attempted reimport.

## File Selection

The built-in allowlist covers standard planning and release documents, project status and state, glossaries and feedback, issue files with workflow IDs, Markdown revision records directly in `revisions/`, and requirements decision records at the root and in named change cycles. Review `rootDocuments`, `cycleDocuments`, and `Test-IncludedDocument` in `documentation-sync.ps1` when changing that policy. Filename and content checks run before files are hashed into the scratch repository. Status words and draft content pass through as bytes.

For a one-time extra Markdown, text, or CSV file, pass its exact documentation-relative path with `-IncludePath`. For recurring backups, preview with `-SetRememberedIncludes` and the complete list of approved extra paths. Review the preview's `rememberedIncludes` list and any planned file changes with the owner. Apply the approved receipt with the same arguments. Sync records the list in the local binding after verifying the receipt, even if no file changes or the upload is pending. Later automatic and manual runs use the remembered paths. Existing one-time extras require separate recurring approval. To remove entries, submit the remaining list, or pass `-SetRememberedIncludes @()` to clear it. Previously backed-up files outside the effective allowlist are reported as pending and remain in the remote.

Hard exclusions cover owner defaults, common evidence and diagnostic paths, logs, screenshots, build outputs, temporary and conflict paths, and credential filenames. Before reading, the tool checks the opened handle for the expected path and a single filesystem link. It also excludes files over 2 MiB, invalid UTF-8, binary control characters, and recognized credential patterns. Credential detection is heuristic. Review custom documents and pending exclusions before authorizing them for any eventual shared destination.

## Conflicts, Deletions, and Retries

- **Conflicts.** Sync compares each local and destination version with its last verified common base. It preserves both copies when they diverge and can push safe changes to other paths. The pending report includes the compared destination revision and blob IDs. Use the reported revision to inspect the destination version with Git, for example `git --git-dir=$fixtureDestination show '<reported-revision>:sample-mod/requirements.md'`. Compare it with the untouched workspace copy. To reconcile a text conflict, retain the local draft separately and bring the workspace copy into agreement with the reviewed destination version to establish a new base. Then make the chosen revision locally and preview it. An unbased path deleted in destination history needs a separate restore decision.
- **Deletions.** For a known file that was intentionally removed locally, name it with `-DeletePath`. The tool requires a readable scan with at least one eligible document and an ordinary, accessible parent directory for the missing file. When at least two previously backed-up paths are absent, pass the exact approved destination revision in `-ApproveBulkDeletionAt` along with the specific paths to remove. A changed destination tip invalidates that bulk approval. Restate deletion intent on a later manual retry. Deleted content remains recoverable in Git history.
- **Retries.** The receipt binds the project directory, exact file changes, destination, and branch. Its original head serves as an ancestry check. When another project's upload advances the branch, the tool can replan on the current head and use the same receipt if this project's directory and upload still match. It allows up to three attempts and checks the actual advertised head, commit, and ref in the pre-push hook. Changes to the project directory or upload require a fresh approval. Bulk deletions and older two-part receipts still require the original branch head. The workspace state holds per-file bases, confirmed revisions, the last result, and any unresolved push journal. A later run checks the journal against destination history before using its tentative bases.

Output is JSON. Exit `0` indicates a clean preview or a successful or unchanged sync. Exit `2` indicates pending paths or a failure, and the report may also show a `pushedRevision` for a confirmed partial backup. `remoteRevision` is the revision compared during planning. `lastPushedRevision` records a confirmed push by this workspace separately from `lastVerifiedRevision`, which can advance on a read. The scratch directory is removed after each run, with any cleanup failure reported separately.

## Manual GitHub Pilot

Supply the owner's repository name in `owner/name` form, its pinned numeric repository ID, and the branch. Each owner selects their own destination. The metadata reader must use authenticated GET requests to `api.github.com`, refuse redirects, and return an integer `statusCode` and the parsed JSON as `body` for each requested route. Git uses the machine's existing SSH credential and known host key. Keep credentials in their existing credential mechanisms.

```powershell
$review = ./tools/documentation-sync/documentation-sync.ps1 preview -Workspace $workspace -Repository $repository -RepositoryId $repositoryId -Branch $branch -ProjectId $projectId -ReadGitHubMetadata $readGitHubMetadata | ConvertFrom-Json
$review | ConvertTo-Json -Depth 10
```

Preflight verifies the exact private repository, write permission, and branch. An existing branch's API head must match the fetched Git head. An initial upload can create the configured default branch when the GitHub API confirms an empty repository and Git advertises zero refs. Review the paths and receipt before any upload. To apply after approval, use `sync` with the same options, `-ApprovedPlan $review.approval`, and a fresh authenticated reader. The runner repeats preflight before the push and checks the expected head in Git's push advertisement.

The tool works on GitHub Free. Someone with sufficient repository access can still rewrite or delete history outside the tool on a branch without server-side protection. The tool stops if the destination loses the preview's original head or a previously verified revision.

## Automatic Checkpoint Backups

[Project Documentation Backup](../../procedures/documentation-backup.md) owns the workflow integration. With saved owner approval, agents call the checkpoint wrapper at approved checkpoints, normal task or session handoffs, and on resume after an unresolved backup.

```powershell
pwsh -NoProfile -File tools/documentation-sync/checkpoint-backup.ps1 -Workspace $workspace -OwnerDefaults $ownerDefaults -Trigger checkpoint
```

The wrapper reads the pinned destination directly from owner defaults and uses the same preview, receipt, and guarded push as the manual tool. It accepts the saved rollout approval wording or `Approved` and backs up eligible additions and updates from the built-in allowlist and the binding's remembered paths. It uses the existing GitHub CLI login or a supplied live metadata reader. On Windows, it also checks the standard GitHub CLI installation under Program Files if `gh` is missing from `PATH`. It never sets up credentials during a backup. An unresolved backup returns `pending` and records its outcome under `workspace/documentation-sync/`.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/documentation-sync/tests/run-tests.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/documentation-sync/tests/run-preflight-tests.ps1
```

The local suite uses disposable workspaces and bare repositories. It exercises stale approvals, hard links, remembered and one-time includes, retired IDs, branch advances and rewinds, conflict handling, deletion gates, and interrupted state recovery. The preflight suite checks multiple owner destinations, visibility, repository and branch identity, access failures, and confirmation of an empty repository with mocks.
