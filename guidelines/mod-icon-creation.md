# Mod Icon Creation

Use this specialized guideline only when Release Presentation records an icon decision of **Create** or **Revise**.

The objective is an original, recognizable, human-directed icon that represents the mod clearly at small sizes. Image generation is an iterative design tool, not a substitute for artistic direction or project-owner approval.

## Artwork Workspace

Before requesting references, create:

```text
workspace/artwork/icon/
├── references/
│   └── sources.md
├── candidates/
├── working/
└── final/
```

This workspace is ignored by the process repository. Do not place unapproved candidates in the mod repository.

Explicitly tell the project owner:

> Please add reference images to `workspace/artwork/icon/references/`, or attach them in this chat so I can place them there. For each reference, tell me whether its palette, composition, linework, texture, or mood should guide the design.

Do not assume the owner has read the README or this guideline. If chat attachments are accessible, preserve approved references in the workspace so a later agent context can use them.

Proceed without reference images only after the owner explicitly chooses to do so.

## Reference Safety

For each reference, record in `sources.md`:

- Filename
- Source or owner
- License or permission status
- Aspect approved for inspiration
- Restrictions
- Whether it may appear in final assets

References guide decisions; they are not automatically reusable material.

Do not:

- Copy protected characters, logos, or another project's icon
- Reproduce an identifiable artist's style on request
- Assume an internet image is licensed for reuse
- Include Minecraft, a distribution platform, or another creator's branding as the primary artwork
- Commit reference images to the final mod unless their license and purpose require it

When ownership or permission is unclear, use only abstract qualities such as palette, contrast, or composition and create original forms.

## Design Brief

Before generating an image, create or update:

```text
<artifact-root>/icon-design-brief.md
```

Establish with the owner:

1. What the mod does
2. The single idea the icon should communicate
3. Primary subject or symbol
4. Preferred visual approach
5. Intended mood
6. Limited color palette and contrast
7. Background and transparency
8. Required or forbidden motifs
9. Whether text is allowed
10. Existing branding that must be preserved
11. Reference images and approved influences

Use a focused question for a branching art-direction decision and a compact packet for related visual details. Present the complete brief for approval before generation.

## Choose One Art Direction

Use one coherent direction rather than combining every style keyword.

### Flat Graphic

Suitable for clean utility, technical, or UI-oriented mods.

Prefer:

- Flat 2D graphic
- Simple, intentional geometry
- Strong silhouette
- Solid shapes
- Limited colors
- Crisp edges
- Flat or minimal shading
- Clear negative space

Avoid gradients, bevels, glossy surfaces, cinematic lighting, and microdetail.

### Hand-Painted Game Art

Suitable for magic, adventure, creature, or RPG-oriented mods.

Prefer:

- Hand-painted digital illustration
- Controlled cel shading
- Deliberate line-weight variation
- Limited palette
- Matte finish
- Simplified background
- Selective texture

Avoid plastic gloss, excessive particles, random runes, over-sharpening, and detail that disappears when reduced.

### Pixel Art

Use an exact working grid such as 32x32 or 64x64 pixels.

Require:

- Intentional pixel clusters
- Consistent pixel scale
- Limited palette
- Controlled dithering
- No accidental antialiasing
- Nearest-neighbor scaling

The AI must inspect and correct the pixel grid. Merely prompting for "pixel art" is not sufficient.

## Prompt Construction

Prompts should specify:

1. Subject and action
2. Silhouette and composition
3. Chosen art direction
4. Palette
5. Edge and shading treatment
6. Background
7. Small-icon readability
8. Explicit exclusions

Keep constraints internally consistent. Do not combine hard-edged flat graphics with softened painterly edges unless the brief deliberately calls for both.

Avoid provider-specific flags in the reusable prompt. Use tool-specific controls only when the active image tool supports them.

### Flat Graphic Blueprint

```text
A flat 2D icon of [subject], designed as an original game-mod identity.
One strong centered silhouette, simple solid shapes, limited [palette] colors,
crisp intentional outlines, minimal flat shading, and clear negative space.
Readable at 32 pixels. Square composition on [background].
No text, gradients, bevels, glossy surfaces, cinematic lighting, particles,
random symbols, or intricate detail.
```

### Hand-Painted Blueprint

```text
An original hand-painted game icon of [subject and action].
Controlled cel shading, deliberate ink linework, limited [palette] colors,
matte finish, simplified background, and a strong readable silhouette.
Slight natural line-weight variation without messy geometry.
No photorealism, plastic gloss, excessive glow, random runes, microdetail,
or cinematic rendering.
```

### Pixel-Art Blueprint

```text
An original [32x32 or 64x64] pixel-art icon of [subject].
Consistent pixel grid, intentional clusters, limited [palette] colors,
controlled dithering, strong silhouette, and a simple background.
No text, mixed pixel scales, smooth gradients, antialiasing, glow blur,
or subpixel detail.
```

## Concept and Refinement Loop

1. Generate two to four genuinely different concept directions.
2. Label them and explain the design difference briefly.
3. Present concepts at full size and representative small sizes.
4. Ask the owner to select one direction or reject all.
5. Refine only the selected direction through focused edits.
6. Correct malformed geometry, accidental symbols, inconsistent lighting, and edge artifacts.
7. Repeat size checks after each material change.
8. Stop when the owner approves a final direction.

Do not present random near-duplicates as distinct concepts. Do not restart the design merely to avoid a focused correction.

## Evaluation

Evaluate every candidate at:

- 400x400
- 128x128
- 64x64
- 32x32
- 16x16

Check:

- The subject is recognizable.
- The silhouette survives reduction.
- Contrast remains clear.
- Important shapes do not merge.
- No detail is required to understand the icon.
- Geometry and perspective are coherent.
- There is no illegible or accidental text.
- The image does not rely on excessive glow, particles, ornamental noise, or generic fantasy-emblem conventions.
- The result is meaningfully specific to the mod.

Text should be omitted by default because it becomes unreadable and image models frequently distort it.

## Technical Export

Verify current destination requirements during Release Presentation.

For each approved distribution platform, verify current image requirements and prepare a compliant export. For CurseForge specifically, the current safe export is an original 400x400 PNG; do not use WebP or blank/copied artwork.

Also prepare the in-mod asset at the resolution and path required by the project's metadata. It may share the approved design but must be validated in the actual mod list or UI where it appears.

Record dimensions, format, file size, path, and validation results.

## Approval and Finalization

After owner approval:

1. Place delivery exports under `workspace/artwork/icon/final/`.
2. Copy only required approved assets into the mod repository.
3. Confirm metadata points to the correct in-mod asset.
4. Record final paths and reference provenance in `<artifact-root>/release-presentation.md`.
5. Preserve rejected candidates only when the owner requests it.

Icon approval does not authorize committing, uploading, or publishing.
