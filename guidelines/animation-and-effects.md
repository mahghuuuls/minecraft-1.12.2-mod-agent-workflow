# Animation And Effects

This specialized guideline covers custom player animation, held-item poses, first-person hand motion, camera effects, particles, and sound in a Minecraft 1.12.2 mod. It owns the feasibility starting list, the authoring pattern, the motion brief, the stills step, and the split between what an agent can check and what only the owner can judge. The stage that requires the work still owns scope, issue readiness, and approval.

## When To Use

Read this guideline when a stage or an implementation issue references it, which is the case when the mod:

- Poses or moves the player model, in the own view or as other players see it.
- Changes how a held item sits in the hand or moves with it.
- Adds camera motion, field-of-view changes, particles, or sounds that belong to an action.

It does not cover textures or block and item models; [Minecraft Pixel Art](minecraft-pixel-art.md) owns the first. A mod without custom motion or effects skips this file.

An agent works in text. It cannot use a visual animation editor, record audio, or watch motion. Every part of this guideline follows from that: motion is written as numbers, turned into still pictures and log lines the agent can read, and judged for its look by the owner.

## Feasibility Findings

These findings come from earlier 1.12.2 work in this workflow. They are a starting list, not approved facts for a new project: Feasibility Research verifies each one against the project's loader, mappings, and dependency set, and records the result.

**Libraries (as checked on 2026-11-11).** No library for 1.12.2 was found that gives code-triggered player animation in both first and third person. Checked: GeckoLib, AzureLib, Obfuscate, Mo' Bends, Epic Fight, playerAnimator. Check again before relying on this, and check the 1.12.2 build of a library, not its newer versions.

**Hooks.**

- First person: Forge's `RenderSpecificHandEvent` lets the mod draw or transform the hand and the held item itself.
- Third person: a body pose needs a Mixin at the tail of `ModelBiped.setRotationAngles`. Mixins follow the Mixins rules in `guidelines/project-defaults.md`.
- The game also poses the body model to draw the first-person hand, with `ageInTicks` 0. A body hook must skip the own player in first person, or the two hooks fight.

**Safe model fields.** `ModelBiped.setRotationAngles` rewrites most rotations and several rotation points on every draw. Which fields it leaves alone must be read from the 1.12.2 source for the parts the project moves; in the checked source the z rotation of the head and body is not reset. A hook restores every field it writes that the game does not reset, or the model stays bent after the clip ends. Prefer the fields the game resets; list every other field the design needs as a risk. Feasibility Research verifies the list.

**Held-item transform.** Check how the item sits in the hand, not only the body bones. The game holds an item at a right angle to the arm. A motion in which a weapon must lie in line with the arm, or turn in the fist, needs a transform of the held item as well, and in third person that was a second Mixin. A weapon motion planned from body poses alone misses this.

**Field of view.** A movement-speed modifier that is active during an action changes the field of view (a zoom). Plan for it in first-person and camera work.

**Composed sounds.** An agent cannot record or judge audio. Plan each sound as a composition of existing sound files (vanilla events, pitch, volume, delay, layering) unless the owner supplies the audio. Who supplies it is a [Concept and Scope](../stages/1-concept-and-scope.md) question.

**Evidence limits.** A still picture shows a pose, not motion or timing. Feasibility Research states which animation criteria can be evidenced by stills and logs and which need the owner, using [Owner-Only Criteria](#owner-only-criteria).

## Authoring Pattern

**Clips as text keyframes.** Write each clip as a text resource: named parts, times in ticks, and rotation or offset values per keyframe, with the interpolation rule stated. A text clip can be reviewed in a diff, checked by a test, and corrected one number at a time.

**A pure sampler.** One function takes a clip and a time and returns the pose. It reads no game state, so unit tests can assert that a clip parses, that sampling at a keyframe returns that keyframe, that the values between two keyframes are the expected ones, and that the end of one clip joins the start of the next or the rest pose. The render hooks only apply what the sampler returns.

**A debug surface, off by default.** Plan it in the first animation issue, not after the first failed look:

- **Start:** play a named clip on a player by command.
- **Pin:** hold a named clip at time `t` until released, so a still picture shows exactly that pose.
- **Dump:** write one log line with the sampled pose for a clip and time. The line carries the same numbers a unit test asserts, so a picture, a log line, and a test value can be tied together.
- **View:** set the camera view needed for a still. From toolkit `1.9.0` the Agent Test Toolkit turns the view and presses real keys itself ([Player Input](agent-diagnostics-toolkit.md#player-input)); a project that pins that version needs no view control of its own.

Pin and dump act on a client, while toolkit bundles run server commands. Build them as a server command that sends a message to the client, and guard the client side with a client setting whose default is off. A release build with the setting absent must behave as if the surface did not exist.

**What to log.**

- One line when each render hook is applied, and one line when a hook is deliberately left out. A Mixin config plugin that reads a Java option gives a clean launch without the hook for comparison; without its log line that launch leaves no trace.
- The clip name, the time, and the sampled values in each dump line.
- Clip start and end with the player, on the side that decides them, so a second client's record can be matched to the first.

**Prove the default.** A setting key written into the config file by hand proves nothing about the default. Launch once without the key and keep the file the game wrote as the evidence.

## Motion Brief

An issue that creates or materially changes an animation carries a **Motion Brief** section before it becomes Ready. The owner and the agent agree it in one compact packet, the same way a pixel-art issue agrees its brief first. Corrections that arrive one live card at a time cost a build, a launch, and a sitting each.

The brief records:

- **Key poses in words.** The start pose, each turning point, the moment of effect (the hit, the release), and the return to rest. For each: where the hands are, where the weapon or item points, and what the body does.
- **Reference pictures.** Ask the owner for pictures or a short clip of the motion they mean, and take one still of the game's normal hold of the item as the common starting picture. Pictures settle in one round what several rounds of words do not.
- **The path.** Start side, end side, over or under, wide or tight, and how the item sits in the hand along the way.
- **Both readings of every direction word.** "Clockwise", "left", "forward", "up", and "in front" each have two readings: seen from the player's own eyes or from a watcher facing the player, and relative to the body or to the world. When the owner uses such a word, describe both readings and ask which one is meant before any build. Do not guess.
- **Timing.** Length in ticks of the wind-up, the action, and the recovery, and what must line up with the moment of effect (damage, sound, particles).
- **What must be seen from each view.** What the player sees in the own view, and what another player sees. They are different pictures drawn by different hooks, and one can be right while the other is wrong.
- **What it must not look like.** The readings the owner wants to avoid.

Record the brief in the issue. A later look correction that contradicts it is a change to the brief, not a defect of the implementation.

## Stills Before A Live Card

Before the first live look card, show the owner a strip of pinned stills and iterate on the strip.

1. Choose four to six times across the clip that include every key pose of the brief.
2. For each time, pin the clip and take a still from every view the brief names, usually the own view and a view from behind or from the side. The toolkit's picture options and their limits are in [Other Capabilities To Plan Around](agent-diagnostics-toolkit.md#other-capabilities-to-plan-around); a picture of a held item needs the option set named there, because hiding the whole HUD also hides the hand.
3. The agent opens and reads every still, and compares each with the brief and with the dump line for that time. Do not compare stills by pixels: clouds, particles, and lighting change between two pictures of the same pose.
4. Show the strip in chat, in time order, with the time under each picture, and ask the owner what to change.
5. Correct the clip, retake the changed stills, and show the strip again. Launch for a live card only after the owner accepts the stills.

A still cannot show a vanilla swing: a picture taken together with an attack action comes before the swing is visible. Leave swing looks to a live card.

## Who Judges The Look

Motion, timing, feel, and sound are owner verdicts. The agent prepares the evidence and the owner decides.

A review agent, started under [Required Read-Only Review Agents](collaboration-guidelines.md#required-read-only-review-agents), checks the code and the evidence: that clips parse, that consecutive clips join, that sampled values match the tests, that the hooks restore what they write, that the debug surface is off by default, and that the launch matrix was run. It never judges the look, and its brief says so. A reviewer's suggestion about how a motion should look is not a finding to apply; pass it to the owner as a question or drop it.

The implementing agent does not judge the look either. It reports what the stills and the numbers show against the brief and leaves the verdict open.

## Launch Matrix

An animation issue is evidenced across these launches. Record which were run and what each showed.

| Launch | What it shows |
| --- | --- |
| Single player, debug surface off | The default: no debug command acts, no extra log lines, normal play looks as before |
| Single player, hooks on | The clip in the own view and from behind, by stills and dumps |
| Single player, hook left out | The comparison: normal play without the hook, with the log line that names the omission |
| Dedicated server with one client | No client class loads on the server, and the clip starts from the server's decision |
| A second client as observer | What another player sees and receives: the pose, the cues, and the tracking range |

The recipe for a second development client on the same machine is in [Second Development Client](../stages/7-implementation.md#second-development-client). With it, the agent takes the observer's stills and reads the observer's log itself, so watcher checks need no second person.

The order that keeps look evidence from going stale after a hook change, and when to stage the packaged jar, is in [Failure And Revision](manual-validation.md#failure-and-revision).

## Owner-Only Criteria

These stay owner cards however much the agent can evidence. Plan them as such in the issue, and do not mark them satisfied from stills, logs, or a review.

- **Motion quality:** whether the motion reads as intended, at full speed.
- **Timing and feel:** whether the wind-up, the action, and the recovery feel right, and whether the effect lands when the motion says it should.
- **Swing and walking:** how the clip looks together with the vanilla swing, and while walking, sprinting, sneaking, or jumping.
- **Sound:** whether a composed sound fits the action, and its loudness against the game's own sounds.
- **Camera and field of view:** whether a camera effect or a zoom is comfortable.

What the agent can close on its own: that a clip parses and joins, that a pinned pose equals the sampled values, that each hook applies and restores, that the default is off, that the server loads without client classes, and that a second client receives the clip and its cues.
