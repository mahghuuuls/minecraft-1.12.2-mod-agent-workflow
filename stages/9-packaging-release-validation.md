# Packaging and Release Validation

## Purpose

Prepare the release handoff according to the approved release ownership matrix.

This stage supports two modes:

- **Owner-Managed Packaging:** The project owner builds, inspects, uploads, and publishes the release artifact manually. The agent prepares a lightweight publication handoff only.
- **Agent-Managed Release Validation:** The agent builds and validates the exact distributable artifact before handing it to the owner for manual publication.

The agent never uploads or publishes the mod in either mode.

## Main Question

> What release handoff does the project owner need before manual publication?

## Required Input

- `workspace/documentation/project-setup.md`, including the release ownership matrix
- `workspace/documentation/requirements.md`
- `workspace/documentation/architecture.md`
- `<artifact-root>/release-presentation.md`
- Completed issues and verification evidence under `<artifact-root>/issues/`
- The completed project under `workspace/project/<project_directory_name>/`

Release Presentation must be approved before this stage begins.

## Mode Selection

Select exactly one mode before performing release work.

### Owner-Managed Packaging

Use this mode when the ownership matrix or project owner says release JAR generation, artifact inspection, checksum creation, runtime validation, upload, or publication is owner-managed.

In this mode, the agent does not generate, inspect, checksum, runtime-test, upload, or publish the final JAR unless the owner explicitly changes the mode or grants a one-time exception.

### Agent-Managed Release Validation

Use this mode only when the ownership matrix or explicit owner instruction assigns release JAR generation and release validation to the agent.

In this mode, the agent may build, inspect, checksum, and validate the exact release artifact, but still may not upload or publish.

If ownership is ambiguous, ask before proceeding. Do not default to full validation.

## Objectives

### Owner-Managed Packaging

Establish only:

- Approved version
- Source revision or repository state used for the handoff
- Recommended build command
- Expected normal release artifact name or path pattern
- Known limitations and validation gaps already discovered earlier
- Accepted validation waivers
- Manual publication checklist
- Explicit owner-managed responsibilities

### Agent-Managed Release Validation

Establish:

- Consistent release version and metadata
- A reproducible successful release build
- The exact normal distributable JAR
- Verified JAR contents
- Clean client and server results only when assigned and applicable
- Verified compatibility and dependency claims when assigned
- Accepted validation waivers for skipped owner-managed checks
- Artifact identity and checksum
- A complete handoff for manual publication

## In Scope

### Owner-Managed Packaging

- Confirm approved version and source revision
- Identify the recommended build command from the project/template documentation
- Identify the expected normal release artifact name or path pattern without building it
- Record known limitations from approved implementation and presentation evidence
- Record accepted validation waivers for skipped owner-managed checks
- Prepare a concise manual publication checklist
- Produce `<artifact-root>/release-handoff.md`

### Agent-Managed Release Validation

- Apply the approved release version
- Update and validate mod and build metadata
- Confirm required and optional dependency declarations
- Build the normal release JAR
- Inspect the exact JAR
- Test the exact JAR in assigned clean environments
- Perform assigned release smoke tests
- Reconcile technical results with the approved presentation
- Record accepted validation waivers for skipped owner-managed checks
- Produce the checksum and handoff record

## Out of Scope

Do not:

- Add features
- Perform unrelated refactoring
- Redesign branding or rewrite release messaging without returning to Release Presentation
- Claim unverified compatibility
- Upload a file or asset
- Create or edit a live distribution-platform project
- Publish a release
- Commit, tag, or push unless separately authorized
- Begin post-release maintenance

In Owner-Managed Packaging mode, also do not:

- Generate the final release JAR
- Inspect JAR contents
- Calculate checksums
- Runtime-test the final artifact
- Perform clean-instance validation
- Perform dedicated-server, Cleanroom, or external multiplayer testing
- Verify upload files or live publication state

A release-blocking implementation defect returns to Implementation. An inaccurate presentation claim returns to Release Presentation.

## Desired AI Behavior

Act as a release handoff coordinator.

- Start from the approved implementation, presentation, and ownership matrix.
- Select and state the mode before doing release work.
- Prefer Owner-Managed Packaging whenever release ownership says the owner handles the artifact or publication work.
- Identify missing information instead of inventing it.
- Keep metadata and handoff information consistent.
- Do not perform full validation work in lightweight mode.
- Report known limitations and skipped owner-managed checks plainly.
- Record owner-skipped validation using the validation waiver format in `guidelines/process-control.md`.
- Do not repeatedly request checks after they are recorded as accepted limitations.
- Never upload or publish.

## Owner-Managed Packaging Mode

This is the lightweight default when the owner handles packaging or publication.

The agent should record:

1. **Approved version:** the version approved for the release.
2. **Source revision:** the commit SHA, branch, or repository state to build from.
3. **Recommended build command:** the normal command the owner should run, such as the template's Gradle wrapper command.
4. **Expected artifact:** the expected normal release artifact name or path pattern, such as `build/libs/<mod-name>-<version>.jar`.
5. **Known limitations:** limitations, skipped validations, or owner-accepted risks already discovered earlier.
6. **Accepted validation waivers:** skipped validation checks recorded in the standard waiver format.
7. **Manual publication checklist:** concise owner actions for building, selecting the file, uploading, and publishing.

The agent may inspect project files to identify the recommended command and expected artifact pattern, but must not run the release build or inspect the final artifact unless the owner explicitly changes the mode.

## Agent-Managed Release Validation Mode

Use the configured template's build mechanism.

The release build must:

- Start from the approved implementation state
- Complete without errors
- Produce the expected normal distributable JAR
- Exclude development-only files and dependencies
- Include required resources and metadata
- Use the approved version and filename
- Be reproducible through the documented project build process

Inspect the final JAR for:

- Correct metadata and version
- Required classes and resources
- Approved mod icon when bundled
- Access transformers or Mixin resources when required
- Configuration defaults
- Accidental development files
- Local paths
- Secrets or credentials
- Unexpected bundled dependencies
- Duplicate or obsolete resources

The inspected artifact must be the same file handed to the project owner.

Perform clean-instance, dedicated-server, Cleanroom, or multiplayer validation only when assigned by the ownership matrix or explicitly requested by the owner. Do not repeatedly push owner-managed validations.

When a check is skipped by owner decision, record it as an accepted limitation. Example:

```text
Accepted limitation: Clean launcher testing was not performed by owner decision.
```

## Defect Routing

- **Implementation defect:** stop and return to Implementation.
- **Presentation defect:** stop and return to Release Presentation.
- **Packaging-only defect:** correct it within this stage only in Agent-Managed Release Validation mode and repeat affected checks.
- **Earlier approved decision invalidated:** follow the backward-transition rules in `guidelines/process-control.md`.

Any source-code change requires relevant implementation verification and review again.

## Process

1. Confirm Release Presentation approval.
2. Read the release ownership matrix and select Owner-Managed Packaging or Agent-Managed Release Validation.
3. State the selected mode and get owner confirmation before proceeding.
4. Review unresolved defects, known limitations, and accepted validation waivers.
5. Confirm the approved version and source revision.

For Owner-Managed Packaging:

6. Identify the recommended build command without running the release build.
7. Identify the expected normal artifact name or path pattern without inspecting a final JAR.
8. Record known limitations and owner-managed validation gaps as accepted validation waivers where applicable.
9. Produce the lightweight release handoff record.
10. Present the handoff for approval.

For Agent-Managed Release Validation:

6. Apply the approved version and metadata.
7. Build the exact release JAR.
8. Inspect its contents.
9. Perform assigned clean-instance, server, compatibility, or smoke validation.
10. Record accepted validation waivers for skipped owner-managed checks.
11. Route discovered defects to the owning stage.
12. Rebuild and repeat affected checks after corrections.
13. Reconcile final evidence with the approved presentation.
14. Calculate the artifact checksum.
15. Produce the full release handoff record.
16. Present the complete artifact and evidence for approval.

## Output Artifacts

Produce:

```text
<artifact-root>/release-handoff.md
```

### Owner-Managed Packaging Handoff

The handoff record should contain:

1. Selected mode: Owner-Managed Packaging
2. Approved version
3. Source revision or repository state
4. Recommended build command
5. Expected artifact name or path pattern
6. Approved presentation record
7. Known limitations and accepted validation waivers
8. Manual publication checklist
9. Owner approvals

Do not include artifact checksum, JAR inspection, clean-client validation, dedicated-server validation, or runtime-test results unless the owner explicitly requested those checks.

### Agent-Managed Release Validation Handoff

The handoff record should contain:

1. Selected mode: Agent-Managed Release Validation
2. Mod and version
3. Source revision
4. Artifact filename and path
5. Artifact checksum
6. Build command, environment, and result
7. Artifact inspection
8. Clean-client validation when assigned
9. Dedicated-server, Cleanroom, or multiplayer validation when assigned
10. Accepted validation waivers
11. Dependencies and compatibility claims
12. Approved presentation record
13. Known limitations
14. Manual publication checklist
15. Owner approvals

Do not record a publication result because publication occurs after this stage.

## Manual Publication Boundary

The project owner is responsible for signing into each approved distribution platform, creating or editing live projects, uploading artifacts and assets, selecting live relationships, publishing files, and verifying published pages.

The agent may prepare text or troubleshoot when explicitly requested but must not perform those actions.

## Completion Criteria

### Owner-Managed Packaging

This stage is complete when:

- The selected mode is recorded as Owner-Managed Packaging.
- Approved version is recorded.
- Source revision or repository state is recorded.
- Recommended build command is recorded.
- Expected artifact name or path pattern is recorded.
- Known limitations and accepted validation waivers are recorded.
- Manual publication checklist is recorded.
- The project owner explicitly approves the lightweight handoff.
- Nothing was built, inspected, checksummed, uploaded, or published by the agent unless separately requested.
- `<artifact-root>/release-handoff.md` is generated and approved.

### Agent-Managed Release Validation

This stage is complete when:

- The selected mode is recorded as Agent-Managed Release Validation.
- Version and metadata are consistent.
- The release build succeeds.
- The exact distributable JAR is inspected.
- Assigned clean-instance validation passes or has an accepted waiver.
- Assigned dedicated-server, Cleanroom, or multiplayer validation passes or has an accepted waiver.
- No known release-blocking defect remains.
- Approved presentation claims match the artifact or affected claims are softened/removed.
- The artifact checksum and handoff are recorded.
- The project owner explicitly approves the handoff for manual publication.
- Nothing was uploaded or published by the agent.
- `<artifact-root>/release-handoff.md` is generated and approved.

Completion ends agent-managed release work for the selected mode. Manual publication remains the project owner's responsibility.
