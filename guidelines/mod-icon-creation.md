# Mod Icon Creation

[Release Presentation](../stages/8-release-presentation.md#icon-decision) determines when to show a first-release preview, carry an icon forward, or reopen it. This guide covers choosing the artwork, making a reviewable image, and delivering the approved file.

## Start with what players recognize

Look at the implemented mod and its actual resources. Which single item, block, entity, screen element, or action would a player associate with it? Check the creative-tab item when there is one. A representative asset created by this project is often the whole design. Open the real PNG or render the actual textured model for a block or entity. A texture atlas laid flat can look quite different from what players see.

**Show the existing asset on its own first** when it reads well at thumbnail size and can be used at the destination. Center it with breathing room, preserve its proportions and pixel scale, and preview it against the listing background. Keep distinctive details intact. A signature item needs no added wrench, lettering, border, or second motif to qualify as a finished icon. Reusing approved art this way needs one preview. A borrowed creative-tab item or template placeholder needs the same source checks as any other third-party image.

If there is no suitable project asset, choose a montage when players need to recognize a particular game object and usable source images exist. Choose pixel art when the idea reads as an inventory sprite. Choose a geometric mark for a rule or action without a distinctive object. For example, a mod that locks one inventory slot could use a slot with a latch cut into its edge.

Record the subject, intended meaning, and method briefly in `<artifact-root>/icon-design-brief.md` when creating or revising a design. Use known project decisions for the first preview. References and a separate brief approval are optional.

## Three ways to make a new design

### Exact-grid pixel art

Draw an original sprite directly as a token grid. Start at **16×16** for an item-like mark in the 1.12.2 visual style. Choose a larger native grid when the defining shape needs it or the project's existing art uses it. The native grid and the listing dimensions serve different purposes. Start with the silhouette, add a few connected groups of light and dark pixels, then inspect at 1×. If two features merge there, change the pixels.

Run `tools/pixelart/pixelart.cmd candidate.pixelart -OutputBesideSpecification -Review` from the workflow root, substituting the grid's path for `candidate.pixelart`. Follow the [three-concept review](minecraft-pixel-art.md#three-concept-selection-loop) for a genuinely new pixel design. Place each pixel directly on the target grid. A diffusion image, traced sprite, or downsampled illustration misses this step. Enlarge with integer nearest-neighbor scaling. For a 400×400 listing, a 16×16 canvas fits at exactly 25×. For a grid that does not divide the export evenly, use the largest fitting integer scale and pad the canvas. [Renderer usage](../tools/pixelart/README.md), [Derek Yu's sprite tutorial](https://www.derekyu.com/makegames/pixelart.html)

### Montage from actual game or mod assets

Choose one real subject and, if it adds meaning, one secondary element. For a summon-tweaking mod, that might be a crop of the actual summoned mob with the actual casting item. Locate the exact version's models and textures in the project, installed mod JAR or 1.12.2 game resources. For example, an item model under `assets/<modid>/models/item/` can identify the sprite under `assets/<modid>/textures/items/`. For a posed creature, custom renderer, or tinted item, use a clean gameplay capture or render the real model with its bound texture. Use an authorized test instance for a new capture. [Forge 1.12.x resource locations](https://docs.minecraftforge.net/en/1.12.x/conventions/locations/)

Once the sources qualify for the intended use, keep each original as a separate layer. Crop or mask the background and arrange the layers on a plain field. Match sprite scale or camera perspective so the subjects sit together. Compare the composite to the sources side by side. Fix a cut-off staff, a halo around the mob, or an overlap that hides its face before showing it. Keep hard-edged sprites on their pixel grid. **Never generate, redraw, trace, or use generative fill to stand in for a named game or mod asset.** If a layer is missing, identify the exact image needed and offer the owner the option of attaching it. An original pixel or geometric candidate can be shown while the montage source is unavailable. [GIMP layer masks](https://docs.gimp.org/3.0/en/gimp-layer-mask-add.html)

### Minimal geometric icon

Draw one mod-specific symbol with a few editable paths or solid shapes. Keep an editable vector or shape source and rasterize it to PNG. Use consistent stroke weights or solid fills, deliberate gaps, and enough margin around the silhouette. Try it in one color at 16 and 32 pixels. If the meaning disappears, widen the opening or simplify the shape. Add color where it helps recognition. Skip ornamental gradients, bevels, particles, and generated illustrations as a starting point. [IBM's guidance on small icons](https://www.ibm.com/design/language/iconography/ui-icons/design/)

## Sources and platform use

Use `workspace/artwork/icon/` for source files under `references/`, previews under `candidates/`, editable files under `working/`, and approved exports under `final/`. For each incorporated source, record the creator or supplier, version and file path or capture, permission covering the intended use, restrictions, and required credit in `workspace/artwork/icon/references/sources.md`. Mark inspiration-only references there. Keep candidate artwork outside the mod repository.

Check the asset's terms for both the public avatar and any redistribution inside the JAR. A source-code license, installed JAR, owner attachment, or permission to share gameplay alone does not establish both uses. Mojang includes textures, models, and screenshots in its definition of game assets. CurseForge requests an original project graphic and restricts copyrighted imagery in avatars. Check the current destination rules. If a layer cannot be used for that destination, show a project-owned asset or original mark there and explain which layer would need clearance for a montage. Avoid copying platform logos or another project's identity. [Minecraft Usage Guidelines](https://www.minecraft.net/en-us/usage-guidelines), [CurseForge submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips), [CurseForge moderation policies](https://support.curseforge.com/support/solutions/articles/9000197279)

## Show the image and revise it

1. Export and open the actual PNG. Inspect it at the listing size and at 128, 64, 32 and 16 pixels. Check the silhouette, meaningful gaps, contrast on light and dark backgrounds, edge artifacts, and whether the defining feature survives. A large view alone can hide a failed thumbnail.
2. Show the image directly to the owner, alongside a thumbnail at actual size, and identify the real asset or construction method in one sentence. Ask “Would you use this as the mod icon, or what would you change?” A prompt, filename, or written concept alone does not deliver a preview.
3. If the owner declines, use their reason to offer two or three concrete alternatives tied to this mod. For a utility mod these might be its existing tool sprite alone, a montage using a named capture and item, or a one-color symbol for the tool's effect. For a montage, look for usable inputs first. Ask for a specific PNG or screenshot only when an input is missing or the owner prefers to supply it. Accept attachments or files under `references/`.
4. Make and show the selected revision at both sizes. A focused correction needs one revised image. Record the owner's selection, supplied replacement, or explicit deferral in the presentation record. Only the owner approves the final design.

## Export and verify

Verify each destination's current requirements. For CurseForge, a square 400×400 PNG meets the published avatar dimensions. Record the final paths, dimensions, format, file size, source credits, and visual checks in `<artifact-root>/release-presentation.md`. Copy only required approved assets into the mod repository. Confirm the metadata resolves to the in-mod logo and verify it in the packaged Mods list and, where the mod registers one, the creative tab under [Release Build and Discovery](../procedures/release-build-and-discovery.md).

## Why these defaults

Some modded-Minecraft players report skipping packs when they see what looks to them like a generated thumbnail. Those reports reflect individual choices. In a controlled study, people rated the same AI-made paintings differently depending on the assigned creator label. Neither source ranks these three styles for Minecraft players. These methods let the owner inspect the actual sprite, the montage layers, or the geometry at the size players see. Describe the method accurately. [Modded-Minecraft player discussion](https://www.reddit.com/r/feedthebeast/comments/1kwrpiq/ai_generated_modpack_iconsdescriptions/), [Bellaiche et al., 2023](https://doi.org/10.1186/s41235-023-00499-6)
