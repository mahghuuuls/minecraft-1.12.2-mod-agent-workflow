# Packaging and Release

## Purpose

Prepare the completed mod for users, validate the exact distributable artifact, finalize user-facing documentation and assets, and publish the approved release to CurseForge.

This is the first stage in which the repository README, changelog, mod icon, and CurseForge presentation are finalized.

## Main Question

> Is the completed mod ready to be distributed to users?

## Required Input

- `mod-project-defaults.md`
- `concept-and-scope.md`
- `requirements.md`
- `architecture.md`
- `implementation-plan.md`
- Completed implementation issues
- Completion and verification evidence
- The finished source code
- Existing release files, when updating a previously released mod

Read and follow all relevant input documents before beginning this stage.

## Objectives

Establish:

- The release version
- Accurate user-facing documentation
- An accurate changelog
- Final mod branding and icon
- Correct mod and dependency metadata
- A reproducible release build
- A validated distributable JAR
- A complete CurseForge project or file listing
- A permanent record of what was released

## In Scope

- Selecting the release version
- Updating or creating `README.md`
- Updating or creating `CHANGELOG.md`
- Creating or finalizing the mod icon
- Updating mod metadata
- Confirming dependency declarations
- Confirming Minecraft, Forge, Cleanroom, and Java compatibility information
- Building the release JAR
- Inspecting the contents of the release JAR
- Testing the exact release JAR in a clean Minecraft instance
- Performing release smoke tests
- Preparing the CurseForge project description
- Preparing CurseForge file metadata and release notes
- Declaring required and optional dependencies on CurseForge
- Uploading the approved release to CurseForge
- Recording release information and validation evidence

## Out of Scope

Do not:

- Add new features
- Perform unrelated refactoring
- Redesign the architecture
- Change approved behavior
- Add undocumented compatibility claims
- Publish experimental or unverified artifacts
- Upload development or debug builds
- Publish the mod to platforms other than CurseForge
- Begin post-release maintenance work

When a release-blocking implementation defect is discovered, return to Implementation. Fix and verify it there before rebuilding the release.

## Desired AI Behavior

Act as a release coordinator.

- Derive documentation from the behavior that was actually implemented.
- Do not document planned, deferred, or incomplete features as available.
- Review completion evidence before preparing the release.
- Identify missing release information instead of inventing it.
- Ask one focused question at a time when decisions such as naming, versioning, branding, or release classification require project-owner input.
- Keep the README focused on information useful to players and modpack authors.
- Produce a changelog that describes meaningful changes accurately.
- Verify that metadata agrees across the build configuration, mod files, documentation, JAR name, and CurseForge listing.
- Confirm that required and optional dependencies are represented accurately.
- Inspect the release artifact for development files, secrets, local paths, unintended dependencies, and missing resources.
- Test the exact JAR intended for upload rather than relying only on development-environment results.
- Use a clean installation containing only the required dependencies for baseline validation.
- Test a dedicated server when the mod contains server or shared behavior.
- Report failed release checks honestly.
- Do not make code changes silently during this stage.
- Do not upload or publish anything without explicit project-owner approval.
- Record the final release version, artifact, checks, and CurseForge result.

## README Content

Create or update `README.md` with relevant sections such as:

1. **Mod Name and Summary**
2. **Features**
3. **Requirements**
4. **Installation**
5. **Configuration**
6. **Usage**
7. **Compatibility**
8. **Known Limitations**
9. **Credits**
10. **License**
11. **Issue Reporting**

The README must describe the released mod rather than the earlier project plan.

Omit sections that do not apply instead of filling them with generic text.

## Changelog Content

Create or update `CHANGELOG.md`.

For the release being prepared, record relevant changes under categories such as:

- Added
- Changed
- Fixed
- Performance
- Compatibility
- Removed
- Known Issues

Do not include internal implementation details unless they are meaningful to users or modpack authors.

## Mod Icon and Branding

Confirm or create:

- The mod icon used by Minecraft
- The CurseForge project icon
- Any images required for the CurseForge description

Assets must:

- Represent the mod accurately
- Use the correct file format and dimensions for their destination
- Remain readable at small sizes
- Avoid unlicensed material
- Be approved by the project owner
- Be included in the correct project location when required by the mod metadata

The current CurseForge asset requirements must be checked before preparing the final files.

## Metadata Validation

Confirm consistency across:

- Mod name
- Mod ID
- Version
- Minecraft version
- Supported loader and runtime
- Java requirements
- Description
- Authors
- Credits
- Logo reference
- Required dependencies
- Optional dependencies
- Accepted dependency versions
- JAR filename
- CurseForge project information

Do not claim compatibility that was not established during Implementation.

## Release Build

The release build must:

- Start from the approved source state.
- Complete without build errors.
- Produce the expected distributable JAR.
- Exclude development-only files and dependencies.
- Include required resources and metadata.
- Use the approved version and filename.
- Be reproducible using the documented project build process.

Record the build command and result.

## Release Artifact Inspection

Inspect the final JAR for:

- Correct metadata
- Correct version
- Required classes and resources
- Mod icon
- Access transformers or Mixin resources when required
- Configuration defaults
- Accidental development files
- Local machine paths
- Secrets or credentials
- Unexpected bundled dependencies
- Duplicate or obsolete resources

The artifact that passes inspection must be the same artifact uploaded to CurseForge.

## Clean-Instance Validation

Install the release JAR into a clean instance with only its required dependencies.

Verify:

- Minecraft starts successfully.
- The mod is discovered and loaded.
- No unexpected errors appear in the logs.
- Essential features are available.
- Configuration files are created correctly.
- A world can be created or loaded.
- Existing-world behavior works when relevant.
- The game can restart with persisted mod state.
- The mod works on a dedicated server when applicable.
- A client can connect to the dedicated server when applicable.
- Missing optional dependencies are handled correctly.
- Required dependencies are reported clearly when absent.

This is release validation, not a replacement for the broader verification performed during Implementation.

## CurseForge Preparation

Prepare:

- Project name
- Summary
- Description
- Categories
- Supported Minecraft version
- Supported mod loader or runtime information
- Required and optional dependencies
- Project icon and images
- License information
- Source or issue links when applicable
- File display name
- File version
- Release channel
- File changelog
- Supported environment information
- Known limitations

Verify current CurseForge requirements before publication.

## Release Process

1. Confirm that the Implementation stage is complete.
2. Review unresolved defects and known limitations.
3. Select and approve the release version.
4. Create or update `README.md`.
5. Create or update `CHANGELOG.md`.
6. Create or approve the mod icon and CurseForge assets.
7. Update and validate mod metadata.
8. Build the release JAR.
9. Inspect the JAR contents.
10. Install the exact JAR in a clean instance.
11. Perform release smoke tests.
12. Perform dedicated-server validation when applicable.
13. Correct documentation or metadata problems.
14. Return implementation defects to the Implementation stage.
15. Rebuild and repeat validation after any code change.
16. Prepare the CurseForge project or file information.
17. Present the artifact, documentation, assets, and listing for final approval.
18. Upload only after explicit project-owner authorization.
19. Verify that the published file and page are correct.
20. Generate `release-record.md`.

## Output Artifacts

### Repository Artifacts

- `README.md`
- `CHANGELOG.md`
- Mod icon and approved branding assets
- Updated mod and build metadata
- Final distributable JAR

### Release Record

Produce `release-record.md` containing:

1. **Mod Name**
2. **Release Version**
3. **Release Date**
4. **Source Revision**
5. **Artifact Filename**
6. **Artifact Checksum**
7. **Build Command and Result**
8. **Artifact Inspection**
9. **Clean-Instance Validation**
10. **Dedicated-Server Validation**
11. **Known Limitations**
12. **Approved Documentation and Assets**
13. **CurseForge Project**
14. **CurseForge File**
15. **Publication Result**

### Published Artifacts

- CurseForge project page
- CurseForge release file
- CurseForge release notes
- Correct dependency relationships

## Release Completion Criteria

This stage is complete when:

- The release version is approved and consistent everywhere.
- `README.md` accurately describes the released mod.
- `CHANGELOG.md` accurately describes the release.
- The mod icon and CurseForge assets are approved.
- Mod and dependency metadata are correct.
- The release build succeeds.
- The final JAR has been inspected.
- The exact release JAR passes clean-instance validation.
- Dedicated-server validation passes when applicable.
- No release-blocking defects remain.
- Known limitations are documented.
- CurseForge information is complete and accurate.
- The project owner explicitly approves publication.
- The approved JAR is uploaded to CurseForge.
- The published page and file are verified.
- `release-record.md` has been generated.

The project is considered complete when these criteria are satisfied. Later defect fixes or enhancements begin a new project cycle rather than extending this release stage.