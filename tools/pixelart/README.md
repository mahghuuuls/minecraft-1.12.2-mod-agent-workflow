# Minecraft Pixel Art Tool

This is a small, dependency-free renderer for agent-authored Minecraft 1.12.2 pixel art. It converts a token grid and a color palette directly into a native-resolution RGBA PNG. It does not use image generation, scaling, antialiasing, or a background fill.

The renderer is bundled with `minecraft-1.12.2-mod-agent-workflow`. Its presence does not determine when artwork should be created or when pixel art is appropriate; the workflow rules for those decisions are maintained separately.

## Quick start

From the workflow repository root on Windows, use the launcher (it works even when direct PowerShell script execution is disabled):

```bat
tools\pixelart\pixelart.cmd tools\pixelart\examples\mana-drop.pixelart -Review
```

The launcher applies `ExecutionPolicy Bypass` only to that child process; it does not change the machine policy. On a system where PowerShell scripts are already enabled, calling `pixelart.ps1` directly is equivalent.

Because this copy is bundled with the workflow, the default output is `workspace/artwork/pixelart/mana_drop/candidates/mana_drop.png`. To place an owner-approved asset directly in a mod resource directory:

```bat
tools\pixelart\pixelart.cmd tools\pixelart\examples\mana-drop.pixelart -OutputFile workspace\project\examplemod\src\main\resources\assets\examplemod\textures\gui\mana_drop.png
```

Existing files are protected by default. Add `-Force` when replacement is intentional.

When a specification already lives in the approved directory where its PNG should be reviewed, keep the output beside it without repeating a full path:

```bat
tools\pixelart\pixelart.cmd workspace\artwork\pixelart\example\candidates\candidate-a.pixelart -OutputBesideSpecification -Review
```

## Review output

Use `-Review` for every candidate that will be evaluated visually:

```bat
tools\pixelart\pixelart.cmd artwork\candidate-a.pixelart -OutputFile artwork\candidate-a.png -Review
```

The renderer creates a sibling `<name>-review/` directory containing:

- `<name>-review-zoom.png`: transparent nearest-neighbor enlargement.
- `<name>-review-grayscale.png`: nearest-neighbor grayscale enlargement for value checks.
- `<name>-review-tile-3x3.png`: a repeated tile preview, generated automatically for the `block` preset.

Use `-TilePreview` to add the 3x3 tile review for a custom-sized tiled asset. It implies `-Review`. Use `-ReviewDirectory` to select another review directory and `-PreviewScale` to override the automatic integer scale:

```bat
tools\pixelart\pixelart.cmd artwork\custom-tile.pixelart -OutputFile artwork\custom-tile.png -Review -TilePreview -PreviewScale 8
```

Every preview is generated directly from the same RGBA pixel buffer as the delivery PNG. Enlargement uses nearest-neighbor replication only, and every transparent source pixel remains transparent in the review output.

## Sheets: several candidates on one image

`-Compose` renders every listed input (`.pixelart` grids and existing `.png` files, mixed freely) onto one sheet, so a candidate set can be judged in one look instead of one file at a time:

```bat
tools\pixelart\pixelart.cmd -Compose candidates\a.pixelart candidates\b.pixelart textures\current.png -Columns 3 -Background #303030
```

- Cells are equal, sized by the largest input; each image sits at the top-left of its cell.
- `-Columns` sets the cells per row (default: everything on one row). `-Gap` sets the gap in source pixels between cells and around the border (default 1).
- `-Background` fills the sheet with `#RRGGBB` or `#RRGGBBAA` (default transparent). Transparent source pixels show the background; other pixels are copied without blending.
- The sheet is scaled with nearest-neighbor replication; `-PreviewScale` overrides the automatic scale.
- The default output is `<first input stem>-sheet.png` beside the first input. `-OutputFile` selects another destination. `-Force` replaces an existing file.
- `-Preset`, `-Width`, and `-Height` apply to every input, so one call can require that every member is 16x16.
- The tool prints the cell order (row and column for each input) because the sheet carries no labels.

## Compare: a candidate against a reference

`-Compare` puts a reference and a candidate side by side and adds a difference panel when both have the same size:

```bat
tools\pixelart\pixelart.cmd -Compare candidates\a.pixelart -Reference textures\current.png -PreviewScale 8
```

- Panel 1 is the reference, panel 2 the candidate, panel 3 the difference: a pixel that is identical in both becomes the grayscale candidate pixel, a pixel that differs in any channel becomes opaque red.
- The output line reports how many pixels differ and how the differences split: color or alpha changed, opaque in the reference but transparent in the candidate, transparent in the reference but opaque in the candidate.
- Either side may be a `.pixelart` grid or a `.png`. When the sizes differ, the two panels are still produced and the tool says that no difference panel was made.
- The default output is `<candidate stem>-compare.png` beside the candidate; `-OutputFile`, `-Force`, `-Gap`, `-Background`, and `-PreviewScale` work as for `-Compose`.

Reading an existing PNG uses the System.Drawing decoder that ships with Windows .NET, so any PNG color type works. Writing never depends on it. GDI+ may round the color of a semi-transparent pixel by one step; fully opaque and fully transparent pixels are read exactly, and a PNG this tool wrote compares equal to its own specification.

`-Compose` and `-Compare` cannot be combined with `-Review`, `-TilePreview`, `-ReviewDirectory`, `-OutputDirectory`, `-OutputBesideSpecification`, or `-Name`.

## Specification format

```text
@preset bar_icon
@name mana_drop

. . . . A . . . .
. . . A B A . . .
. . . A C B A . .
. . A B D C B A .
. A B C E E D B A
. . A C D E C A .
. . A B D C B A .
. . . A C B A . .
. . . . A . . . .

. = transparent
A = outline / darkest blue = #07152F
B = deep mana blue = #1A39D8
C = medium blue = #2395F0
D = light cyan = #58DDF6
E = bright core / highlight = #F2FEFF
```

Rules:

- Whitespace separates pixels, so symbols may be one or more characters.
- `.` is always transparent; declaring `. = transparent` is optional.
- Colors accept `#RRGGBB` or `#RRGGBBAA`. The latter supports partial alpha.
- Palette descriptions are allowed; the last hex color on the line is used.
- Lines beginning with `//` and blank lines are ignored.
- Directives must come before the grid.
- Every row must have the same width and every symbol must have a palette entry.

## Size validation

The deliberately small preset list contains only dimensions this tool can enforce without guessing:

| Preset | Size | Intended use |
| --- | ---: | --- |
| `block` | 16x16 | Block texture |
| `item` | 16x16 | Item texture |
| `bar_icon` | 9x9 | Small custom bar icon |

List them from the command line:

```bat
tools\pixelart\pixelart.cmd -ListPresets
```

Minecraft GUI sheets, entity textures, animated textures, and publication icons do not have one universally correct size. Use an exact declaration instead of a misleading preset:

```text
@size 32x24
@name custom_gui_piece
```

The same validation can be supplied by the caller with `-Preset`, or with `-Width` and `-Height`. If the grid and any declared size disagree, rendering fails with a row-and-dimension error.

## Output directory configuration

Output selection, from most explicit to least explicit:

1. `-OutputFile` specifies the complete destination.
2. `-OutputDirectory` and optional `-Name` select a directory and filename.
3. `-OutputBesideSpecification` uses the input specification's directory and the optional `-Name` or `@name` filename.
4. `MINECRAFT_PIXELART_OUTPUT_DIR` configures the default directory.
5. A copy bundled under `tools/pixelart/` uses `workspace/artwork/pixelart/<asset-name>/candidates/`.
6. A standalone copy otherwise uses `generated` under the current working directory.

This makes the normal agent path one command, keeps unapproved work in the ignored artwork workspace, and retains an exact destination for copying an approved final asset into the mod repository.

The bundled default is name-derived, not specification-relative. For several candidates in one approved asset workspace, prefer one shared `-OutputDirectory` or place the specifications in their intended candidate directory and use `-OutputBesideSpecification`; otherwise different `@name` values intentionally create different asset workspaces.

## Verification

Run the dependency-free test script:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\pixelart\tests\run-tests.ps1
```

The tests decode the generated PNGs enough to verify dimensions, RGBA color type, transparent pixels, exact palette colors, alpha values, overwrite protection, preset mismatch rejection, explicit specification-relative output, nearest-neighbor zoom, transparency-preserving grayscale conversion, 3x3 block tiling, sheet composition (cell placement, background fill, mixed `.pixelart` and `.png` inputs, reported cell order), comparison (panel placement, gray and red difference marks, difference counts, a rendered PNG equal to its own specification), and the rejection of mixed modes.
