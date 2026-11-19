# Custom Screens

Use this specialized guideline when it is referenced. It owns the design rules, candidate pictures, measured checks, and screen review for a custom screen. The stage that requires the screen still owns scope, issue status, and approval. Art drawn for the screen (slot outlines, button symbols, backgrounds) also follows `guidelines/minecraft-pixel-art.md`.

## When To Use

Read this file when an issue adds or materially changes a screen the mod draws itself: a container screen with slots, a screen without slots, a configuration or selection screen, or a panel added to a vanilla screen.

A material change is one that alters what the player can do on the screen, which controls exist, where they are, or how a state is shown. A corrected string or a recolored pixel is not a material change.

A HUD element with no controls is not a screen. Use the [Measured Checks](#measured-checks) for it and skip the rest.

## What The Requirements Say

[Custom Screens](../stages/3-requirements-definition.md#custom-screens) in Requirements Definition owns what a requirement for a screen says. This guideline adds where the layout is recorded and how the requirement becomes a list of states.

The layout is a design decision made on the implementation issue and approved from candidate pictures. Record it there, so that a later layout change is a revision of the issue's design and not of an approved requirement.

Before drawing, write the screen's states from the requirement: each thing the player can do, and each thing the player must be able to tell, becomes a state or a visible element. This list drives the candidates and the review below.

## Design Rules

Every control tells what it does.

- A control has a text label or hover text. A symbol button always has hover text; a symbol alone is a guess.
- Prefer a small symbol button with hover text to a text button when the action is simple and a symbol for it exists. This is a preference, not a fixed rule: use a text button when no symbol reads clearly.
- A slot that takes one kind of item shows a faint outline of that item while empty, as the vanilla armor slots do.
- Put details in hover text, with color separating the name from values such as cost or cooldown. Do not spend permanent screen space on a text box for what the player reads once.

Every state is visible and explained.

- Draw the empty, filled, selected, and unavailable states differently. The player must not need to click to learn the state.
- An unavailable control looks unavailable, and its hover text says why and what would make it available.
- Show a state once. Do not add a slot, icon, or line for something the item's own tooltip or another element already shows.
- An action that changes something gives feedback where the player is looking. Give it a sound when vanilla gives one for a comparable action.

The screen looks and behaves like a vanilla 1.12.2 screen unless an approved art direction says otherwise.

- Use the vanilla panel, slot, and button look, the vanilla font and text colors, and the vanilla spacing: 18 by 18 pixel slot cells on the vanilla grid, and the player inventory where a vanilla container puts it.
- Use vanilla patterns before inventing one: shift-click moves items, hover shows a tooltip, and Escape, or for a container screen the inventory key, closes the screen.
- Fit the whole screen in 320 by 240 scaled pixels, the smallest screen the game draws.

## Candidates Show The Screen In Use

A single picture of the screen at rest shows the look, not the use. Before the owner approves a screen, the candidate packet shows it in use:

- One picture for each main state. At least: as first opened and empty; with the expected content in place; with the pointer on each control or row that has hover text, tooltip visible; with an unavailable control; and just after the main action.
- Real content: real items, real names, and the longest real text the screen can show. No placeholder text and no empty frames standing in for content.
- Every picture at one stated GUI scale, labelled by state, on one sheet per candidate so the states read in order of use.
- Pictures taken from the running screen when it can run. A mock-up drawn before the screen exists is built at exact GUI pixels from the vanilla textures, is labelled as a mock-up, and is replaced by real pictures before the screen is approved.

The owner chooses among candidates and approves the screen. Follow `guidelines/minecraft-pixel-art.md#three-concept-selection-loop` for new art on the screen; a new screen layout does not by itself need three candidates.

## Measured Checks

Do these on a real picture of the running screen, not on the source or the art file alone. A screen is drawn in GUI pixels, each one a square of real pixels whose side is the GUI scale. Establish the drawn scale from the picture by measuring an element of known size (a vanilla slot cell is 18 GUI pixels wide), never from the options file, and convert every measure to GUI pixels.

- **Centering.** For each symbol or text on a control, and each element meant to be centered in a panel, count the free pixels on the left and right, and above and below. The counts are equal, or the issue states the reason. A shape of odd size cannot be centered in a space of even size: change one of the two sizes rather than accept an off-center result.
- **Mirror symmetry.** Each shape meant to be symmetric equals its own mirror image, pixel for pixel. Compare the shape with its flipped copy; do not judge it by eye.
- **Alignment.** Slots sit on the vanilla 18-pixel grid, and rows and columns that belong together share an edge.
- **Text fit.** Every label, value, and hover text is whole at the smallest GUI scale the mod supports and on the smallest scaled screen (320 by 240, reached with a large GUI scale in a small window). Use the longest real string. Text that is cut, overlaps another element, or leaves the screen is a defect.

When a script or code computes a position, let it compute the centered position and fail when centering is impossible, instead of placing by hand and measuring afterward. The measurement on the real picture is still required.

Record the measured values, the picture they came from, and the drawn GUI scale in the owning issue.

## Screen Review

A new or materially changed custom screen gets an independent read-only review before the owner approves it. Run it on the candidate pictures before they go to the owner, and again when a correction changes a control or a state.

The reviewer acts as a first-time player. [Custom Screen Review](../procedures/independent-review-brief.md#custom-screen-review) owns what the reviewer receives, what it is asked, and the handoff format. Review-agent initiation follows `guidelines/collaboration-guidelines.md#required-read-only-review-agents`.

The author then compares the reviewer's answers with the requirement and the list of states:

- A control the reviewer could not explain, or explained wrongly, is a finding against the screen, not against the reviewer.
- A wrong first step is a finding.
- A thing the player must be able to tell that the reviewer did not report is a finding.

Address each finding by changing the screen, or decline it with a written reason in the owning issue. Put the review's findings and their dispositions in the candidate packet the owner sees.

The review tests whether the screen explains itself. It does not approve the screen and does not replace the measured checks; whether the screen looks right is the owner's decision.
