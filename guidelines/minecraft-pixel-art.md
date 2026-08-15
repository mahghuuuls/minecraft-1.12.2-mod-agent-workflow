# Minecraft Pixel Art

Use this specialized guideline whenever the workflow creates or materially revises pixel-art assets, including item textures, block textures, GUI icons, particles, entity or model textures, and a mod icon whose approved direction is pixel art.

This guideline owns pixel-art briefing, construction, candidate review, and technical validation. The stage that requires the asset still owns scope and approval. For a pixel-art mod icon, also follow `guidelines/mod-icon-creation.md`, which owns release-artwork direction, reference provenance, export, and final approval.

The default visual target is Minecraft Java Edition 1.12.2 and the legacy vanilla visual language. A project-specific approved art direction or an established mod palette may override vanilla resemblance, but it does not override exact-grid construction or technical compatibility.

## Core Standard

The objective is not merely an image that looks pixelated. A successful asset:

- Is recognizable at its actual in-game size.
- Uses deliberate pixel clusters rather than random texture noise.
- Has a readable silhouette and value structure.
- Uses one consistent apparent pixel scale.
- Matches the visual weight and pixel density of adjacent project assets.
- Communicates material and purpose with as few pixels as practical.
- Uses genuine transparency where the design requires transparent pixels.

When detail conflicts with readability, remove or simplify the detail. Do not raise the resolution of only part of the design to escape the grid.

## Plan The Asset Before Implementation

An implementation issue that creates or materially revises pixel art must include a **Pixel-Art Asset** section before it becomes Ready. The planning agent must tell the owner that the bundled pixel-art tool will render an exact token grid rather than generate a diffusion image, then ask one compact art-direction packet covering:

- What the asset represents and what gameplay meaning it must communicate.
- Asset category and exact in-game use.
- Required canvas dimensions, orientation, and destination path when known.
- Primary silhouette or composition.
- Materials, palette direction, mood, and lighting exceptions.
- Required and forbidden motifs.
- Transparency, animation, tiling, model, or neighboring-GUI constraints.
- Existing project assets that the new asset must match.
- Optional reference images and which characteristics may guide the result.
- When generated exploration or a composition reference establishes the direction, two or three defining invariants that reconstruction must preserve, such as perspective, band thickness, setting scale, silhouette, negative space, or major highlight planes.

Do not ask the owner to place every pixel or choose exact hex values unless they want that level of control. The agent translates approved visual direction into a grid and palette.

Request reference images, but do not make them a universal blocker. Record when the owner has none or chooses to proceed without them. References guide silhouette, palette, material treatment, composition, or mood; they do not authorize copying protected characters, logos, distinctive artwork, or another project's asset. Record the source, permission status, approved influence, and restrictions when a reference may affect the final asset.

If the brief is unresolved, keep the implementation issue Blocked or create an Owner-resolved Decision issue. Do not mark an asset issue Ready and defer basic art direction to an unexpected prompt during Implementation. If the need for an unplanned asset is discovered during Implementation, treat it as a Planning Problem and add or revise the issue before creating the image.

Use this optional issue section:

```markdown
## Pixel-Art Asset

- Asset ID and category:
- Gameplay meaning and actual display context:
- Canvas dimensions:
- Runtime destination:
- Approved silhouette, composition, materials, palette, and mood:
- Defining composition invariants from generated exploration or a composition reference, when applicable:
- Required and forbidden motifs:
- Transparency, animation, tiling, model, or neighboring-asset constraints:
- Project and external references, approved influences, and restrictions:
- Candidate workspace:
- Three-variation plan for a new direction:
- Required inspection views and in-game validation:
- Final grid specification and PNG paths:
```

When several files form one inseparable visual set, such as the faces of one model or states of one animation, one section may cover the set. Do not create a combinatorial three-variant loop for every file in that set; create three coherent set-level directions.

## Artwork Workspace

Keep unapproved work outside the mod repository:

```text
workspace/artwork/pixelart/<asset-id>/
|-- references/
|   `-- sources.md
|-- candidates/
|-- working/
`-- final/
```

Store candidate `.pixelart` specifications and PNG previews under `candidates/`. Move the selected direction into `working/` for revisions. Put the approved specification and delivery PNG under `final/`, then copy only required approved runtime assets into the mod repository.

Whether editable source specifications are also committed to the mod repository is a project decision. Do not place them under `src/main/resources/` unless the build is known to exclude them from the shipping artifact.

## Use The Bundled Renderer

Create final pixel-grid PNGs with:

```text
tools/pixelart/pixelart.cmd
```

The normal input is a `.pixelart` token grid with an explicit palette. Use `@preset item`, `@preset block`, `@preset bar_icon`, or an exact `@size` declaration. See `tools/pixelart/README.md` for the complete format.

Render every candidate with `-Review`. This produces transparent nearest-neighbor zoom and grayscale previews from the exact delivery pixels. A `block` preset also produces the required transparent 3x3 tiled review automatically; use `-TilePreview` for another custom-sized repeating texture.

The bundled default output is derived from `@name`, not from the specification's directory. For several specifications belonging to one approved asset workspace, either pass one shared asset-level `-OutputDirectory` or store each specification in its intended output directory and use `-OutputBesideSpecification`. Do not rely on the default when it would scatter one candidate set across name-derived sibling workspaces.

Do not use a diffusion-generated image as the final pixel-art asset. An image generator may help explore broad subject or composition ideas, but the final asset must be reconstructed deliberately on the exact target grid and pass every review in this guideline.

When generated exploration becomes an approved composition reference, technical validity and basic readability are not enough. Put the reference and exact-grid reconstruction side by side and check the recorded defining invariants before candidate presentation. Preserve each invariant or record the concrete grid constraint that requires a deviation. Reject aggressive simplification that removes the selected concept's perspective, mass, setting scale, silhouette, or other defining structure even when the result is still recognizable as the general subject.

Do not create the final by drawing at high resolution and shrinking. Do not use blur, smooth brushes, automatic antialiasing, bilinear or bicubic resampling, or an image-processing step that introduces many nearly identical colors. Inspection previews may be enlarged only with nearest-neighbor scaling.

## Canvas And Pixel Density

- Default ordinary item textures to 16x16.
- Default ordinary block-model textures to 16x16 unless the approved project uses another consistent texture resolution.
- Give GUI assets the exact dimensions required by their interface. A 9x9 icon is designed directly at 9x9.
- Define entity and model texture dimensions from the approved model and UV layout. Maintain consistent texel density across connected surfaces.
- Define every animation frame at one consistent size. A vertically stacked animation texture is an export layout, not permission to mix pixel scales between frames.
- Do not enlarge a subject merely to fill unused transparent space. Negative space can improve silhouette and orientation.

Minecraft model textures referenced by block and item models must satisfy the square power-of-two and mipmapping constraints documented for Forge 1.12.x. Animated model textures are the documented exception: the PNG may contain vertically stacked square frames with a corresponding `.mcmeta` definition. Do not apply that model-texture rule blindly to arbitrary GUI sheets whose code defines another layout.

## Construct The Image In This Order

### 1. Silhouette

Begin with one flat value and no internal detail. At actual size, check:

- Can the subject be recognized from shape alone?
- Is its orientation clear?
- Are its characteristic or functional parts distinct?
- Does it accidentally resemble another item or symbol?
- Is negative space doing useful work?

Slight exaggeration of a defining feature is preferable to realistic proportions that become ambiguous at low resolution.

### 2. Large Internal Shapes

Separate the major planes, openings, material regions, or functional parts. Do not begin with ornament, scratches, sparkles, or other one-pixel detail.

### 3. Controlled Palette And Values

Start each material with a small ramp: midtone, shadow, and highlight. Add a color only when it conveys visible information at actual size.

- Make important adjacent forms differ in value, not only in hue.
- Prefer coherent material ramps over unrelated colors.
- Treat numerous barely distinguishable shades as a defect.
- Reuse one color for several roles when that keeps the image coherent.
- Inspect in grayscale when major forms may depend on weak color differences.

### 4. Lighting And Material

Use one consistent light source. Upper-left is the default for ordinary item icons unless the approved brief or a luminous material requires another treatment.

Shading must explain form and material:

- Metal uses strong value separation and compact reflections.
- Gems and crystals use readable angular planes and sharp highlights.
- Wood uses warmer ramps and directional grain only where the grid has room.
- Stone uses restrained clustered irregularity rather than random speckles.
- Cloth uses broad folds rather than hard reflections.
- Leather uses moderate contrast and softer highlights than polished metal.
- Magical or glowing material may place the brightest value internally, but the glow must remain a deliberate cluster.

Avoid pillow shading, where progressively brighter colors simply follow a closed silhouette toward its center. Avoid repeated parallel color boundaries that create banding. Internal outlines should separate meaningful forms; outlining every detail wastes pixels and fragments the subject.

### 5. Curves, Diagonals, And Clusters

Build curves and diagonals from intentional step patterns. Correct abrupt, unexplained changes in step length that create jagged edges.

Prefer coherent connected clusters. An isolated pixel is acceptable only when it carries clear information, such as a specular point, eye, opening, or magical spark. Random isolated pixels are noise.

Do not create mixels: every pixel on one canvas has the same scale. Scaling a 16x16 design to 32x32 and then adding single 32x32 pixels mixes two incompatible resolutions.

### 6. Identifying Detail And Cleanup

Add small identifying details only after silhouette, large forms, values, and material are readable. For every proposed detail, ask what information it adds at actual in-game size. Remove it when there is no clear answer.

Dithering is optional and normally undesirable for very small icons. Use it only for a deliberate material or transition. Manual internal antialiasing may be used sparingly, but exterior edges against transparency should normally remain crisp and must not acquire a blurred or background-colored fringe.

## Three-Concept Selection Loop

For each new asset or genuinely new art direction:

1. Create three materially different candidates from the approved brief.
2. Vary meaningful design decisions such as silhouette, orientation, composition, material emphasis, or palette structure. Do not present near-duplicates as alternatives.
3. Inspect every generated PNG using the review procedure below.
4. When a generated exploration or composition reference guides the direction, compare each reconstruction side by side against its defining invariants.
5. Reject and replace a candidate before presentation when it has an objective defect or loses a defining composition invariant without a recorded grid constraint.
6. Present three passing candidates with labels, actual-size and nearest-neighbor enlarged views, and one sentence explaining each direction.
7. Ask the owner to select one, request a combination that remains coherent, or reject all three.
8. Revise only the selected direction.

Do not create three variants for every focused correction. Once the owner selects a direction, a requested color adjustment, silhouette cleanup, or removal of one detail normally produces one focused revision. Restart the three-concept loop only when the owner reopens the art direction or when the selected concept cannot satisfy the approved brief.

If every candidate is rejected, identify the common failure, clarify only the decision that would change the next attempt, and then create a new set of three. Repetition without a changed brief is reversed effort, not useful iteration.

## Mandatory Agent Review

The creating agent must open and visually inspect every PNG after rendering. Reading the grid or trusting a successful command is not image review.

Inspect at:

- Actual 1x size for recognition, silhouette, value separation, and noise.
- Nearest-neighbor high zoom for broken clusters, accidental pixels, jaggies, banding, and palette errors.
- Direct alpha inspection to confirm that background pixels remain fully transparent and partial alpha exists only where the approved design requires it.

Also inspect the use-specific context:

- Items at inventory scale and, when practical, in held, dropped, or GUI contexts relevant to the requirement.
- Blocks as at least a 3x3 tile and in-game on the model faces that use them.
- GUI icons beside the actual neighboring HUD or GUI assets.
- Entity and model textures on the mapped model, not merely as a flat sheet.
- Animation as a sequence at its intended timing, not only as stacked frames.

Remake a candidate before presenting it when any automatic rejection condition applies:

- Wrong dimensions, format, destination, or pixel scale.
- Unintended opaque background or unintended partial-alpha edge pixels.
- Blur, automatic antialiasing, resampling artifacts, or mixed pixel scales.
- Subject unreadable at actual size or silhouette dependent on shading to make sense.
- Severe jaggies, banding, pillow shading, random noise, or meaningless isolated pixels.
- Excessive colors with no visible distinction.
- Inconsistent lighting or material treatment.
- A block creates an obvious unintended seam or repeated landmark when tiled.
- A GUI icon has mismatched visual weight beside its neighbors.
- An entity or model texture has inconsistent texel density or fails on its mapped surfaces.
- A 1.12.2 legacy-style asset relies primarily on modern Minecraft texture conventions without an approved reason.
- An exact-grid reconstruction of an approved generated exploration removes a defining composition invariant without a concrete grid constraint or approved change of direction.

Do not endlessly remake a candidate because subjective preference remains uncertain. Once three candidates pass the objective gate, present them so the owner can make the art-direction decision.

## Technical Export And Evidence

For Forge 1.12.x block and item resources:

- Use PNG.
- Place block textures under `src/main/resources/assets/<modid>/textures/blocks/`.
- Place item textures under `src/main/resources/assets/<modid>/textures/items/`.
- Use lowercase snake-case resource names.
- Confirm the model or code points to the correct resource.
- Confirm expected alpha behavior from the actual PNG rather than from a preview background.

Before an asset issue is Done, record:

- Approved brief and selected candidate.
- Paths to all three original candidate specifications and PNGs.
- Owner selection or explicit rejection record.
- Final `.pixelart` specification and PNG path.
- Canvas dimensions, format, color type, and alpha result.
- Agent visual-review results at 1x and high zoom.
- Side-by-side composition-fidelity result for every defining invariant when generated exploration or a composition reference guided reconstruction.
- Use-specific inspection result, including tile, GUI-neighbor, model, animation, or in-game context where applicable.
- Remaining limitations or accepted validation waiver.

Only the approved final runtime asset belongs in the mod resource path. Candidate generation and owner selection do not authorize a commit, push, upload, or publication.

## Version-Specific Technical Sources

- [Forge 1.12.x locations](https://docs.minecraftforge.net/en/1.12.x/conventions/locations/) documents PNG item and block texture locations.
- [Forge 1.12.x model files](https://docs.minecraftforge.net/en/1.12.x/models/files/) documents model-texture paths, square power-of-two mipmapping constraints, and vertically stacked animated textures.
