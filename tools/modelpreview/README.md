# Minecraft Model Preview Tool

This dependency-free PowerShell tool renders a Minecraft 1.12.2 block model JSON to orthographic PNG views and checks the 1.12 model format rules. It exists so an agent can look at the model it wrote, from the angles a player sees, without a Blockbench round trip. The owner still has the final say in Blockbench and in the game.

It runs on Windows PowerShell 5.1 with nothing installed: the rasterizer is a small C# class compiled in memory by `Add-Type` (the C# compiler ships with the .NET Framework), textures are decoded with System.Drawing, and the PNG is written by hand. It does not use Blockbench, Node, Python, or the game.

## Quick start

From the workflow repository root:

```bat
tools\modelpreview\modelpreview.cmd workspace\project\examplemod\src\main\resources\assets\examplemod\models\block\lamp.json
```

The default output is `workspace/artwork/modelpreview/<model name>/<model name>-preview.png`: one sheet with seven views left to right, `gui, north, east, south, west, up, down`, at 8 pixels per block unit. The command prints the order and how many faces drew in each view. A vanilla model works too:

```bat
tools\modelpreview\modelpreview.cmd minecraft:block/furnace -Scale 4
```

Use it on a blockstate variant to see the model turned the way the game turns it:

```bat
tools\modelpreview\modelpreview.cmd -Blockstate ...\blockstates\lamp.json -Variant "facing=east" -Views gui,east
```

## What the views mean

- `north`, `east`, `south`, `west`: the block seen from that side, as a player standing there sees it. A face that points away from the camera is not drawn, as in the game.
- `up`, `down`: from above with north at the top of the image, and from below.
- `gui`: the vanilla inventory angle, a look from the north-west 30 degrees above the horizon. The top, north, and west faces show, as they do for a block in the creative inventory (a furnace shows its front on the left).

Faces get the vanilla per-direction shade (up 1.0, north and south 0.8, east and west 0.6, down 0.5) unless the element has `"shade": false`. Texture pixels with alpha below 128 are cut out. Element rotations with `rescale`, blockstate `x` and `y`, face `uv` including mirrored ranges, face `rotation`, and the default uv of each face follow the 1.12 rules. Texture `tintindex` faces render untinted; animated textures show their first frame.

## Checks

The report lists notes, warnings, and errors, then `Checked N element(s), M face(s): E error(s), W warning(s).` The exit code is 1 when there is an error and nothing is rendered; `-ValidateOnly` stops after the report.

Errors: a parent or texture file that does not exist; a texture variable that is never defined or loops; `from` or `to` outside -16..32; a rotation angle other than -45, -22.5, 0, 22.5, or 45; a rotation axis other than x, y, z; a face name, `cullface`, or face `rotation` that 1.12 does not know; a texture that is not square (stacked square frames are accepted as animation); a model chain with no elements or deeper than 16.

Warnings: a texture reference without a `blocks/` or `items/` prefix (1.12.2 looks up `textures/<path>.png` exactly); a texture whose width is not a power of two; a `uv` value outside 0..16; `from` greater than `to`; no `particle` texture.

## Options

| Option | Meaning |
| --- | --- |
| `ModelFile` | A model JSON path, or a resource name such as `minecraft:block/furnace` or `examplemod:block/lamp`. |
| `-Blockstate`, `-Variant` | Read the model and its `x` and `y` from a blockstate variant (the `variants` form; multipart is not supported). |
| `-RotateX`, `-RotateY` | Blockstate rotations in 90 degree steps, when not read from a blockstate. |
| `-AssetsRoot` | The folder that holds the namespace folders. Derived from the model or blockstate path when it lies under `assets/<namespace>/`. |
| `-VanillaJar` | The 1.12.2 client jar for `minecraft:` parents and textures. Found in the Gradle cache (`.gradle/caches/retro_futura_gradle/mc-vanilla/1.12.2/client.jar`) or the launcher folder when not given. |
| `-Scale` | Pixels per block unit (default 8). |
| `-Views` | Comma-separated views in order (default all seven). |
| `-Background` | `#RRGGBB` or `#RRGGBBAA` behind the model; transparent when omitted. |
| `-OutputFile`, `-OutputDirectory`, `-Force` | Where the sheet goes; an existing file is not replaced without `-Force`. |
| `-ValidateOnly` | Report only. |

## Limits

- Orthographic only: no perspective, no lighting beyond the direction shade, no ambient occlusion, no block tint, no item models, no multipart blockstates.
- A model whose faces overlap exactly (two planes in one place) draws whichever the depth test meets first, as the game would flicker between them.
- The preview shows geometry and texture mapping. It does not show how the block sits among its neighbors, under water, or with the game's light; that remains an in-game check.

## Verification

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\modelpreview\tests\run-tests.ps1
```

The tests build a small assets tree with one-color textures and check: parent resolution across two files, each side view showing its own face with the vanilla shade, the sheet size, a transparent background, a blockstate `y` rotation turning the west face to the north view, the gui view showing top, north, and west with north on the left, a cross model with a half-clear texture cutting out, the validation errors for a bad angle, an out-of-range coordinate, a missing texture, and an unbound texture variable, `-ValidateOnly` rendering nothing, output protection, and an unknown view being refused.
