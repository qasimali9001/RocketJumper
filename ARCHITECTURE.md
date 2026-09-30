# Rocket Jumper — Architecture and Build Plan

This is the reference for how Rocket Jumper is built. Read it before adding a feature. If a change fights this document, update the document in the same pass as the code.

Source of truth for code is this folder (`src/`), synced into Studio. Maps live in Studio as tagged models. Gameplay numbers live in config modules, not inside controllers.

**Current stage:** Stage 6 is in. `N` cycles `Serpentine` and `Pyramid`. Pyramid is the parts model from `tools/BuildPyramid.lua`: four flat rings, four 45° slopes at 75% scale, eight recessed targets, start on the south apron, finish on top. Stage 7 feel is in the build: launcher and rocket from `export/Weapons.blend` (parts, because mesh upload is blocked), `TimeAttack1` plus shot and blast cues, a hotter blast with a close-range camera shake, speed field of view, a rocket trail, a target-clear flash, and a muzzle flash. Magnitudes live in `PolishConfig` and `AudioConfig`. `0` or `Enabled = false` turns a cue off. None of it writes velocity. Load opens the level list. `M` pauses a run. `Esc` stays the Roblox menu. The clock stops while either menu is open.

Play it before changing the route. Nudge parts in edit mode. The scripts do not rebuild the corridor.

---

## Paramount rule: OOP and modular code

Every feature is a small class with one job. Orchestrators only create those classes and pass them to each other. They do not contain movement math, timer rules, or map parsing.

1. **One concern per module.** A file owns movement, or rockets, or the course run, or the speed HUD. It does not own two of those.
2. **Orchestrators stay thin.** `ServerMain` and `ClientMain` wire modules. Domain rules live in the class that owns them.
3. **No magic numbers in gameplay code.** Speeds, forces, cooldowns, UI layout, and keybinds live in `src/shared/Config/`. Tuning the feel means editing config, then playing, not hunting through controllers.
4. **Small public APIs.** Each class exposes a short surface (`new`, `start`, `stop`, `destroy`, plus a few intentional methods). Callers do not reach into another module's fields.
5. **Plain context in, plain results out.** Pass tables (position, velocity, map id, target id). Do not pass the whole game tree into a class that only needs a root part and a config table.
6. **Destroy what you create.** Every class that connects events, creates instances, or starts a loop implements `destroy` and is called when the character or map goes away.
7. **A new map is data.** Adding a course means a model plus one registry line. It does not mean a new script.
8. **Do not grow a god script.** If a file starts doing two jobs, split it before adding the next feature.

Luau has no classes. We use one shared constructor helper and metatables. We do not invent a second OOP style mid-project.

```lua
-- Pattern every gameplay class follows
local Class = require(path.to.Class)

local MovementController = {}
MovementController.__index = MovementController

function MovementController.new(config, rig)
	local self = setmetatable({}, MovementController)
	self._config = config
	self._rig = rig
	return self
end

function MovementController:destroy()
end

return MovementController
```

---

## Design calls (agreed direction)

These are the decisions that keep the game fun to change. Stages below assume them.

### Movement is the product

Rocket jumping only feels good if the body already keeps momentum. Rockets are an impulse added to a velocity the movement controller already owns. We build and tune ground move, jump, gravity, and air strafe **before** the rocket. If strafing feels wrong, we stop and fix config. We do not paper over it with UI or map geometry.

Roblox's default character controller spends every frame pulling velocity toward `WalkSpeed` and flattening air control. That fights strafe and rocket momentum. Our controller writes `AssemblyLinearVelocity` itself. The Humanoid stays for avatar, health, and animations. It does not own the move vector.

Air control is Source's `AirAccelerate` (`sv_airaccelerate` in TF2, CS:S, CS:GO, and CS2):

- Wish direction comes from WASD relative to camera yaw.
- On the ground, friction bleeds speed and acceleration pushes toward the wish direction up to a ground max speed.
- In the air, the velocity you already have stays. Keys only add speed along the wish direction, and only until that component reaches `AirSpeedCap` (Source's 30-unit cap, in studs). A strafe plus a mouse turn bends the arc. Holding forward while you are already faster than the cap along your look does not steer: let go of W, hold A or D, and turn into the strafe.
- Once you look far enough off your line that the speed along W drops under `AirSpeedCap`, that same shove points against the speed you already have. `AirBrake` is how much of that opposing shove is allowed to reduce speed. 1 is the full shove (`AirAccelerate` times `AirWishSpeed`). 0 keeps the speed. The start value is 0.2.
- `AirAccelerate` is the turn knob. It is `sv_airaccelerate`. Higher changes direction faster. Lower locks the arc. CS2 and CS:GO use 12. TF2 and CS:S use 10. The current start value is 7.5, with `AirSpeedCap` at 7.5, about a quarter under the previous 10 so a strafe shoves less.
- A wall removes only the speed aimed into it. While the body is flush with that face, `WallFriction` bleeds the speed still running along it. 0 leaves the slide. The start value is 8, in the same units as ground friction. A pass that is not flush keeps its speed. Ground movement does not use this bleed.
- Right Shift opens the tune panels. The air sliders write `MovementConfig` live: `AirAccelerate`, `AirSpeedCap`, `AirWishSpeed`, `AirBrake`, `WallFriction`, `Gravity`, and `JumpSpeed`. Mouse sensitivity is on that panel. The rocket sliders sit on the right. Close the panels before looking around.
- Jump adds vertical speed and keeps horizontal velocity. If a blast has already lifted you and your feet are still on the floor, that jump is added on top of the blast instead of being dropped.
- Rocket knockback is added on top. It never replaces the current velocity. The rocket still lands on the crosshair. `SelfUpBias` reads a nearby blast as that many studs lower than the impact, so a shot around the torso lifts the same way while rising and while falling. The start value is 3. 0 keeps the raw angle. Right Shift opens a second panel that writes `RocketConfig` live: `ExplosionForce`, `ExplosionRadius`, `SelfForceMultiplier`, `SelfUpBias`, `RocketSpeed`, and `Cooldown`. Locked start values are force 150, radius 23, self multiplier 1.05, rocket speed 160, cooldown 0.7. Reset on that panel restores these.

All of those rates live in `MovementConfig` and `RocketConfig`.

The controller sets `workspace.Gravity` to 0 and applies `MovementConfig.Gravity` itself, so the physics step does not add a second pull on top of the velocity it writes. When the rig is on the ground, the controller holds the root at hip height. With the default state machine off, the Humanoid will not do that for us.

### First person

The game is first person. `CameraController` locks the camera to first person, locks the mouse to the center of the screen, and hides the local head and accessories so the view stays clear. The body can still be seen when looking down. Wish direction is the camera's flat look vector, so air strafing is look-direction plus A/D.

The default Roblox camera script still draws the view. This class only claims mode, mouse lock, and local visibility. It does not write velocity. FOV punch stays in Stage 6.

Toggles live in `CameraConfig`.

### Stage 1 test map

`FlatYard` is a completely flat floor with vertical walls: a perimeter, a few interior walls (one of them rotated), and colored floor marks so speed is easy to read. It now lives in `ServerStorage/Maps` so it is not under the first course. The model contains no Script. `MapRegistry` still lists it. Set `active = true` on that row and it clones back in.

### Who owns state

| State | Owner | Why |
|---|---|---|
| Velocity, ground contact, air strafe | Client movement controller | Feel dies if a server round-trip sits in the middle of a strafe |
| Rocket spawn, impact, and explosion impulse on the local player | Client, same simulation | The shot and the boost must be the same frame as the jump |
| Which targets are cleared, whether the finish is open, run timer, reset | Server session | Course rules stay consistent if we add other players later |

The client tells the server which target part the rocket hit. The server checks that the part is an uncleared `RJ_Target` on the active map and adds it to the set. In the solo loop we trust that report the same way we trust movement. Anti-cheat stays later.

Stage 1 onward are built and felt in Studio play mode as a single player. The authority split is in the module boundaries from the start so a later multiplayer pass does not require a rewrite. We do not build DataStores, anti-cheat, or lobbies until a clear is fun to replay.

### Levels are time trials

The rocket and the air strafe stay as they are. A level is a short route you clear, then a clock you try to beat. From the start pad you can see the targets and the geometry that makes a rocket jump. Each level is one readable idea: a wall boost that also hits a plate, a vertical pop onto a high target, a chain of blasts across a gap. Geometry suggests the line. It does not lock you behind a jump you must survive.

Targets sit where a good shot already wants to land. The rocket still flies to the crosshair and still explodes. If you are inside the blast you still get the shove. The same shot clears a target only when the projectile hits that target's part. One rocket, one target. A blast beside two plates clears the plate that was hit. The explosion radius does not clear anything else.

Every target on the map is required. Order does not matter. When the last one is cleared, the finish opens. Touching the finish before that does nothing, and the clock keeps running. Touching it after the board is clear ends the run and stops the clock.

The clock starts once, when you leave the start volume. Stepping back onto the pad does not restart it. A full reset does.

A kill, a death, or the reset key all do the same thing. You return to the start with velocity cleared, every target restored, the finish closed, and the clock cleared. There is no checkpoint and no mid-route respawn.

`Serpentine` is that first level: an enclosed S, five targets along the bends, finish near the end. Move the parts in Studio if a bend should match a sketch more closely. The scripts do not store the layout.

### Maps are a contract, not a script

A map is a `Model` made of parts. Geometry can look like anything. The course is CollectionService tags and attributes on those parts. `MapLoader` finds them. `CourseSession` interprets them. No map has its own Script.

While you are shaping a level, leave the model in `Workspace`. That is the copy you play. `MapLoader` does not clone it, so the parts you move are the parts you run. When the layout is settled, move the model to `ServerStorage/Maps`. If the active model is not in `Workspace`, the loader clones it from there at the start of a run.

`src/shared/Config/MapRegistry.lua` lists id, display name, model name, and which row is `active`. A new map is: duplicate a model, retag volumes, add one registry row, play.

| Tag | Role | Attributes |
|---|---|---|
| `RJ_Start` | Spawn. Leaving this volume starts the timer once | The part's front face is the facing |
| `RJ_Target` | A rocket impact on this part clears it. One impact, one target | `Id` string, unique on the map |
| `RJ_Kill` | Touch resets the run | none |
| `RJ_Finish` | Ends the run only while every target is cleared. Before that, the touch is ignored | none |

`RJ_Checkpoint` is retired. `MapLoader` does not read it. Old checkpoint parts in the place do nothing until the level is rebuilt.

A reset places the character at the bottom of `RJ_Start`, upright, with velocity cleared, facing the part's front. Every target is restored and the finish closes. A tall gate still drops you on the floor under it. A kill is a clean placement, so a bad bounce does not follow you to the pad.

The finish volume stays in the level the whole time. "Open" means the session starts accepting that touch. How the exit looks when it opens is part of the level, not a new script.

`Serpentine` in Workspace is the course you play. `Straightaway` lives in `ServerStorage/Maps` as the old checkpoint layout. The place file is not in git.

### Editing a level

Stop the playtest before you move anything. Play mode is a copy, and moves made while it is running disappear when you stop. After you stop, move or scale the parts in the viewport or the Explorer, then press Play again. Nothing in the scripts rebuilds the corridor, so a nudge is not overwritten.

Color is only a label. A red part does nothing until it has the `RJ_Kill` tag. Targets are copies of `ServerStorage.Templates.Target`: one sphere, with the same red, yellow, blue, and black face on the front and the back, and white as the band around the middle. Duplicate that model into the course, move the model, and set `Id` on its `RJ_Target` part to a unique string. The id is how the session tells targets apart. It is not an order. Only that invisible part is tagged and queryable, so a hit anywhere on the ball counts.

The Studio place file stays out of git. Script changes live in this folder. Geometry stays in the open place until a model is exported on purpose.

### What “feels good” means before we leave Stage 2

We do not start the course until all of these are true in an empty greybox:

- Horizontal speed survives a normal jump.
- Turning the mouse in the air bends your arc and holds speed. Looking steeply down to fire does not spin that arc.
- A rocket into the ground near your feet throws you up and forward without deleting the speed you already had.
- Jump and fire in the same moment is reliable (short input buffer in config).
- A speed number on screen matches what you feel. If the number and the camera disagree, the controller is wrong.
- Changing rocket force or air accel is a config edit, followed by a playtest, with no other file touched.

---

## What else we need

The spine is propulsion, strafe, momentum, targets, a finish that opens, a timer, and a full reset. These are the pieces that make that spine playable:

- **Speed HUD.** A movement game without a speed readout cannot be tuned.
- **Target count.** Cleared and total, so a run tells you what is left.
- **Finish gate.** The exit is in the level from the start and accepts a touch only after every target is cleared.
- **Timer.** Starts when you leave `RJ_Start`. Stops on a valid finish. A reset clears it.
- **Full reset.** Kill, death, and the reset key share one action: start pad, targets restored, finish closed, clock cleared.
- **Input buffer for rocket jump.** Jump and click rarely land on the same frame. A few tenths of a second of buffer is the difference between “skill” and “mush”.
- **Explosion falloff.** Full force at the center, zero at the edge of the radius. Self-knockback can use its own multiplier so the jump is strong without sending other players (later) into orbit by accident. Falloff pushes the player. It does not clear a second target.
- **Ground check we own.** A short ray under the root, not `Humanoid.FloorMaterial`, so ramps and launch pads behave the same every time.
- **One greybox map, then a second map.** The second map is the test that the pipeline works. If the second map needs a new script, the pipeline failed.
- **Minimal rocket feedback.** A visible projectile, a short explosion, a sound. A cleared target needs a visible change too. FOV punch and shake come after the physics feel right, and they read numbers from config too.
- **Keybinds in config.** Reset and fire are not hard-coded in controllers.

Explicitly later, not in the first playable loop: savestate / loadstate, best-time DataStore, mobile controls, lobby, cosmetics, leaderboards, anti-cheat, custom animations.

---

## Module map

```
src/
  shared/
    Class.lua                      -- constructor helper only
    Config/
      MovementConfig.lua           -- ground, air, gravity, jump
      RocketConfig.lua             -- projectile, radius, force, cooldown, buffer
      CourseConfig.lua             -- timer rules, reset clearance, target tag
      InputConfig.lua              -- keybinds
      CameraConfig.lua             -- first person, mouse lock, hide head
      PolishConfig.lua             -- speed FOV, shake, blast look, trail, flashes
      LeaderboardConfig.lua        -- time store name and board length
      MenuConfig.lua               -- start screen, pause, level list, and options layout
      HudConfig.lua                -- speed HUD, timer, target count, reticle, leaderboard
      AudioConfig.lua              -- music and one-shot cue volumes and ids
      ViewConfig.lua               -- first-person launcher offset and colors
      MapRegistry.lua              -- list of maps
    Types/
      CourseTypes.lua              -- target, map descriptor, run-result shapes
  server/
    ServerMain.server.lua          -- wires server classes, nothing else
    Map/
      MapLoader.lua                -- clone model, read tags, return a map object
    Course/
      CourseSession.lua            -- per player: targets cleared, finish gate, timer, reset
      BestTimes.lua                -- per-map best and the shared fastest-times board
    Player/
      RigGuard.lua                 -- stops a respawn from ragdolling; client still owns velocity
  client/
    ClientMain.client.lua          -- wires client classes, nothing else
    Input/
      InputController.lua          -- actions this frame, including the jump/fire buffer
    Camera/
      CameraController.lua         -- first person, mouse lock, hide local head, speed FOV, blast shake
      SpeedFeel.lua                -- speed to the curved widen shared by FOV and the streaks
      SpeedLines.lua               -- edge streaks aimed at the center. Does not write velocity
    Movement/
      MovementController.lua       -- ground, air, gravity, writes velocity
      GroundProbe.lua              -- raycast ground contact
    Rocket/
      RocketController.lua         -- fire, simulate local projectile, apply impulse, report the hit part
      RocketView.lua               -- rocket shape and trail. Does not change the shot
      Explosion.lua                -- falloff, impulse, and the blast look. Does not clear targets
    View/
      LauncherView.lua             -- first-person launcher and muzzle flash. Does not write velocity
    Audio/
      MusicController.lua          -- loops the background track
      SfxController.lua            -- fire, blast, target, and finish cues. Does not write velocity
    Course/
      CourseController.lua         -- reports the hit target, applies reset, sends the reset key
      TargetFlash.lua              -- flash when a target clears. Does not change the clear
    UI/
      SpeedHud.lua
      AirControlPanel.lua          -- live sliders for air strafe, rocket blast, and look sensitivity
      TimerHud.lua                 -- run clock and personal best
      TargetHud.lua                -- cleared / total
      CourseBanner.lua             -- finish time
      Crosshair.lua                -- center dot. Does not change the shot
      LeaderboardHud.lua           -- fastest times on the current map
      Menu/
        MenuController.lua         -- start screen, pause, and which page is open
        MenuChrome.lua             -- menu buttons and stacks
        LevelSelect.lua            -- card grid for maps already in Workspace
        LevelPreview.lua           -- live picture of a map on its card
        OptionsPanel.lua           -- music, effects, and mouse sensitivity
```

Server map objects and client controllers talk through a single small remotes module (`src/shared/Net/CourseRemotes.lua`) created in Stage 3. Movement does not have a remote in the solo loop.

Suggested Studio layout once synced:

- `ReplicatedStorage/RocketJumper/Shared`
- `ServerScriptService/RocketJumper`
- `StarterPlayer/StarterPlayerScripts/RocketJumper`
- `ServerStorage/Maps/<MapName>`

---

## Stages

Each stage ends with a playtest. We do not open the next stage while the current stage's "done when" list is false.

### Stage 0 — Skeleton

Stand up the folder layout, `Class.lua`, empty config tables, and the two boot scripts. Boot scripts require the configs and construct nothing else yet.

**Done when**

- Play mode runs with no errors.
- `ClientMain` and `ServerMain` are the only scripts, and each is a short list of requires.
- Config modules exist even if values are placeholders.
- This document's module map matches the folders on disk.

### Stage 1 — Movement

`InputController`, `CameraController`, `GroundProbe`, `MovementController`, `SpeedHud`. No rocket, no course.

Character spawns on `FlatYard` in first person. WASD moves relative to the camera. Jump preserves horizontal speed. Air strafe works as described above. Gravity and friction come from `MovementConfig`.

**Done when**

- The view is first person and the mouse stays locked.
- The speed HUD is believable (walk, jump, strafe, land).
- You can chain air strafes and keep speed. Interior walls give something to strafe around.
- Editing `AirAccelerate` or `GroundFriction` changes the feel with no other code change.
- Default Humanoid movement is not also pushing the character.

### Stage 2 — Rocket

`RocketController` and `Explosion`, driven by `RocketConfig`. Fire on click. Projectile travels, detonates on hit, pushes the local character by falloff. Jump buffer makes a rocket jump consistent. Simple part or mesh for the rocket, simple explosion burst, one sound.

**Done when**

- Rocket jump off flat ground is repeatable.
- Existing air speed is still there after the boost.
- You can turn the mouse during the launch and bend the arc without losing the speed.
- Force, radius, rocket speed, and cooldown are config-only. Right Shift edits them live.

### Stage 3 — Course shell (shipped, rules retired)

`MapLoader`, `CourseSession`, `CourseController`, and `Straightaway` shipped with a start, checkpoints, a kill volume, and a finish. That checkpoint contract is retired. Do not add checkpoint behavior. The next stage replaces the run rules. The level itself is rebuilt after the code matches this document.

### Stage 4 — Targets, finish gate, timer

`MapLoader` reads `RJ_Target` and ignores `RJ_Checkpoint`. A rocket impact on a target clears that target only and hides the whole target until the run resets. `Explosion` still only pushes the player. When every target is cleared, `RJ_Finish` accepts a touch. The timer starts when you leave `RJ_Start` and stops on that touch. A kill and the reset key both perform a full reset.

**Done when**

- Shooting a target clears that one target. A blast next to two targets clears only the part the rocket hit.
- A finish touch does nothing until the last target is cleared, then it ends the run and shows the time.
- Leaving the start volume starts the timer once. Stepping back onto the pad does not restart it. A reset clears it.
- A kill puts you on the start pad with every target restored, the finish closed, and the clock cleared.
- The reset key does that same reset. The key comes from `InputConfig`.
- The map model contains no Script.

### Stage 5 — Rebuild the first level (shipped)

`Serpentine` is that course. No target layout is fixed in this document. Adding it means tagged parts plus the existing registry row.

**Done when**

- From the start pad the targets and the rocket line are readable.
- Every target is required, and the finish opens only after the last one.
- A full clear shows a time. A death restarts the route.
- The level adds no gameplay script.

### Stage 6 — Prove maps are cheap (shipped)

Build a second small map. Register it. A simple cycle or menu picks the active map and reloads the session.

`Pyramid` is that map. Studio has the parts model, shifted south of Serpentine. Four tiers, 45° faces at 75% scale, targets T1–T8 in alcoves sized to the targets, start southwest, finish at the top center. `tools/BuildPyramid.lua` rebuilds it. `N` cycles the maps that are already in Workspace, respawns you on that map's start, restores every target, and clears the clock. The registry row stays inactive; the cycle does not edit it.

**Done when**

- The second map ships with zero new gameplay scripts.
- Switching maps respawns you on that map's start, restores that map's targets, and clears the run.

### Stage 7 — Feel polish

In the build, waiting on a playtest. The launcher and the flying rocket are parts matched to `export/Weapons.blend`. `MusicController` loops `TimeAttack1`. `SfxController` plays the shot, the blast, a target clear, and the finish.

The blast is a hot core, a shock ring, and a short spark burst. Your own blast shakes the camera, stronger when you are close, and the shove is unchanged. Field of view stays near the base, then bends up toward `SpeedForMax` (`Fov.Curve`). Short white streaks sit on the screen edge, each aimed at the center, and slide outward with that same widen. Full stretch is 40 degrees at `SpeedForMax`. Rockets leave a short trail. A cleared target flashes, and the launcher flashes at the muzzle. `PolishConfig` holds those magnitudes. `Fov.MaxBonus` and `Fov.Kick` at `0` leave the view at `Fov.Base`. `Shake.MaxOffset` at `0` leaves the camera still. `Enabled = false` turns off the blast look, the trail, the streaks, or either flash.

**Done when**

- Polish can be turned down to zero from config and the physics from Stage 2 are unchanged.
- No polish code writes velocity.

### Stage 8 — Save a best time

In the build. A clear writes your time for that map. A slower clear and a failed run leave the saved time alone. The time sits under the clock as BEST, and the right-hand board lists the fastest clears for the map you are on. Your row is marked. The store is an ordered DataStore, one board per map id, so other players share it once the place can use DataStores. If the store is closed, times last for this server only.

Load opens one screen: a grid of the levels already in Workspace, plus Options. Each card shows that course, a one-line summary, and your best. The first featured row is the large card. The rest pack in beside it, and more levels add cards instead of a new screen. A new level is a registry row: name, summary, and the model. `preview` is a screenshot taken from that level's spawn. The files are in `images/` and copied into the Studio `content/textures/RocketJumper` folder, because cloud upload is still blocked. Empty preview still falls back to a live photograph. The run does not start until a card is picked. During a run, `M` opens pause: Resume, Level Select, and Options. That level list is the same grid. Options is music, effects, and mouse sensitivity. Right Shift stays the tuning panel.

`Esc` stays the Roblox menu. Roblox does not let a game take that key, in Studio or in a published place. Opening it still freezes the body and the clock, the same way our pause does. Resume continues the clock from where it stopped. A failed run still does not save a time. Savestate stays out. A third course waits until this menu has been played.

**Done when**

- Leaving and rejoining keeps the best time for that map.
- A failed run does not replace it.
- A faster clear shows on the board for other players in the same place.
- Load shows the level list, and the clock stays stopped until a level is picked.
- `M` pauses a run and freezes that clock. `Esc` still opens the Roblox menu.

---

## How we work each stage

1. Read this file and the config module you are about to extend.
2. Add or extend the class that owns the behavior. Keep the boot script as wiring.
3. Put new numbers in config.
4. Playtest the "done when" list in Studio before starting the next stage.
5. If a class grew a second job, split it before continuing.

Stage 1 and Stage 2 are allowed to take as long as they need. Everything after them is cheaper if the velocity model is right.
