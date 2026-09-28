# Rocket Jumper — Architecture and Build Plan

This is the reference for how Rocket Jumper is built. Read it before adding a feature. If a change fights this document, update the document in the same pass as the code.

Source of truth for code is this folder (`src/`), synced into Studio. Maps live in Studio as tagged models. Gameplay numbers live in config modules, not inside controllers.

**Current stage:** Stage 2 — rocket on `FlatYard`. The blast adds to existing velocity. Timer and course rules are not in yet.

---

## Paramount rule: OOP and modular code

Every feature is a small class with one job. Orchestrators only create those classes and pass them to each other. They do not contain movement math, timer rules, or map parsing.

1. **One concern per module.** A file owns movement, or rockets, or checkpoints, or the speed HUD. It does not own two of those.
2. **Orchestrators stay thin.** `ServerMain` and `ClientMain` wire modules. Domain rules live in the class that owns them.
3. **No magic numbers in gameplay code.** Speeds, forces, cooldowns, UI layout, and keybinds live in `src/shared/Config/`. Tuning the feel means editing config, then playing, not hunting through controllers.
4. **Small public APIs.** Each class exposes a short surface (`new`, `start`, `stop`, `destroy`, plus a few intentional methods). Callers do not reach into another module's fields.
5. **Plain context in, plain results out.** Pass tables (position, velocity, map id, checkpoint index). Do not pass the whole game tree into a class that only needs a root part and a config table.
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
- Right Shift opens the tune panels. The air sliders write `MovementConfig` live: `AirAccelerate`, `AirSpeedCap`, `AirWishSpeed`, `AirBrake`, `Gravity`, and `JumpSpeed`. Mouse sensitivity is on that panel. The rocket sliders sit on the right. Close the panels before looking around.
- Jump adds vertical speed and keeps horizontal velocity. If a blast has already lifted you and your feet are still on the floor, that jump is added on top of the blast instead of being dropped.
- Rocket knockback is added on top. It never replaces the current velocity. Right Shift opens a second panel that writes `RocketConfig` live: `ExplosionForce`, `ExplosionRadius`, `SelfForceMultiplier`, `RocketSpeed`, and `Cooldown`. Locked start values are force 150, radius 23, self multiplier 1.05, rocket speed 160, cooldown 0.7. Reset on that panel restores these.

All of those rates live in `MovementConfig` and `RocketConfig`.

The controller sets `workspace.Gravity` to 0 and applies `MovementConfig.Gravity` itself, so the physics step does not add a second pull on top of the velocity it writes. When the rig is on the ground, the controller holds the root at hip height. With the default state machine off, the Humanoid will not do that for us.

### First person

The game is first person. `CameraController` locks the camera to first person, locks the mouse to the center of the screen, and hides the local head and accessories so the view stays clear. The body can still be seen when looking down. Wish direction is the camera's flat look vector, so air strafing is look-direction plus A/D.

The default Roblox camera script still draws the view. This class only claims mode, mouse lock, and local visibility. It does not write velocity. FOV punch stays in Stage 6.

Toggles live in `CameraConfig`.

### Stage 1 test map

`FlatYard` is a completely flat floor with vertical walls: a perimeter, a few interior walls (one of them rotated), and colored floor marks so speed is easy to read. No ramps and no kill volumes yet. It sits in `Workspace` until Stage 3 moves it to `ServerStorage/Maps` and the loader. The model contains no Script. `MapRegistry` already lists it so the promotion is a move, not a redesign.

### Who owns state

| State | Owner | Why |
|---|---|---|
| Velocity, ground contact, air strafe | Client movement controller | Feel dies if a server round-trip sits in the middle of a strafe |
| Rocket spawn and explosion impulse on the local player | Client, same simulation | The shot and the boost must be the same frame as the jump |
| Checkpoint index, run timer, finish, kill resolution | Server session | Course rules stay consistent if we add other players later |
| Practice savestate | Client only | A personal rewind, not a competitive record |

Stage 1–4 are built and felt in Studio play mode as a single player. The authority split is in the module boundaries from the start so a later multiplayer pass does not require a rewrite. We do not build DataStores, anti-cheat, or lobbies until the movement is fun.

### Maps are a contract, not a script

A map is a `Model` under `ServerStorage/Maps`. Geometry can look like anything. The course is a set of parts with CollectionService tags and attributes. `MapLoader` finds those parts. `CourseSession` interprets them. No map has its own Script.

| Tag | Role | Attributes |
|---|---|---|
| `RJ_Start` | Spawn, timer arms when you leave | `Facing` yaw optional; one per map |
| `RJ_Checkpoint` | Ordered respawn | `Order` number, starting at 1 |
| `RJ_Kill` | Touch sends you to the last checkpoint | none |
| `RJ_Finish` | Stops the timer | none |

`src/shared/Config/MapRegistry.lua` lists id, display name, and model name. A new map is: duplicate a model, retag volumes, add one registry row, play.

Respawn places the character on the checkpoint, upright, with velocity cleared, facing the volume's look vector. Saved practice states are the thing that restore velocity. A kill is a clean placement, so a bad bounce does not follow you to the pad.

### What “feels good” means before we leave Stage 2

We do not start the course until all of these are true in an empty greybox:

- Horizontal speed survives a normal jump.
- Air strafing (hold A or D, turn the mouse into the strafe) changes your arc and holds speed. Holding only W in the air does not snap you to a new direction.
- A rocket into the ground near your feet throws you up and forward without deleting the speed you already had.
- Jump and fire in the same moment is reliable (short input buffer in config).
- A speed number on screen matches what you feel. If the number and the camera disagree, the controller is wrong.
- Changing rocket force or air accel is a config edit, followed by a playtest, with no other file touched.

---

## What else we need

You listed propulsion, strafe, momentum, maps, timer, reset, practice tools, respawns, and kill zones. Those are the spine. These are the pieces that make that spine playable and maintainable:

- **Speed HUD.** A movement game without a speed readout cannot be tuned.
- **Savestate / loadstate.** The real practice tool. Store position, velocity, camera yaw, and checkpoint index. Restore them on a key. Reset-to-start is a separate action and also clears the timer.
- **Input buffer for rocket jump.** Jump and click rarely land on the same frame. A few tenths of a second of buffer is the difference between “skill” and “mush”.
- **Explosion falloff.** Full force at the center, zero at the edge of the radius. Self-knockback can use its own multiplier so the jump is strong without sending other players (later) into orbit by accident.
- **Ground check we own.** A short ray under the root, not `Humanoid.FloorMaterial`, so ramps and launch pads behave the same every time.
- **Finish volume.** The timer needs an end.
- **One greybox map, then a second map.** The second map is the test that the pipeline works. If the second map needs a new script, the pipeline failed.
- **Minimal rocket feedback.** A visible projectile, a short explosion, a sound. Satisfaction is partly audio and camera. FOV punch and shake come after the physics feel right, and they read numbers from config too.
- **Keybinds in config.** Reset, respawn, save, load, and fire are not hard-coded in controllers.

Explicitly later, not in the first playable loop: best-time DataStore, mobile controls, lobby, cosmetics, leaderboards, anti-cheat, custom animations.

---

## Module map

```
src/
  shared/
    Class.lua                      -- constructor helper only
    Config/
      MovementConfig.lua           -- ground, air, gravity, jump
      RocketConfig.lua             -- projectile, radius, force, cooldown, buffer
      CourseConfig.lua             -- timer rules, respawn clearance
      InputConfig.lua              -- keybinds
      CameraConfig.lua             -- first person, mouse lock, hide head
      HudConfig.lua                -- speed HUD layout
      MapRegistry.lua              -- list of maps
    Types/
      CourseTypes.lua              -- checkpoint, map descriptor, savestate shapes
  server/
    ServerMain.server.lua          -- wires server classes, nothing else
    Map/
      MapLoader.lua                -- clone model, read tags, return a map object
    Course/
      CourseSession.lua            -- per player: checkpoint, timer, kill, finish, reset
  client/
    ClientMain.client.lua          -- wires client classes, nothing else
    Input/
      InputController.lua          -- actions this frame, including the jump/fire buffer
    Camera/
      CameraController.lua         -- first person, mouse lock, hide local head
    Movement/
      MovementController.lua       -- ground, air, gravity, writes velocity
      GroundProbe.lua              -- raycast ground contact
    Rocket/
      RocketController.lua         -- fire, simulate local projectile, apply impulse
      Explosion.lua                -- falloff and impulse from a point
    Course/
      CourseController.lua         -- applies server respawn/reset; sends touches if needed
      PracticeController.lua       -- savestate, loadstate, reset request
    UI/
      SpeedHud.lua
      AirControlPanel.lua          -- live sliders for air strafe, rocket blast, and look sensitivity
      TimerHud.lua
      PracticeHud.lua              -- savestate indicator, checkpoint index
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
- You can strafe during the launch and bend the arc.
- Force, radius, rocket speed, and cooldown are config-only. Right Shift edits them live.

### Stage 3 — One course

`MapLoader`, `CourseSession`, `CourseController`, tags, and a single greybox map: start pad, two checkpoints, a gap with a kill volume, a finish. Touching a checkpoint updates the session. Touching kill or dying respawns at the last checkpoint with velocity cleared. Finish stops the run.

**Done when**

- You can rocket jump the gap, die in the kill volume, and appear on the last pad.
- Checkpoint order follows the `Order` attribute, not the order parts happen to sit in the model.
- The map model contains no Script.

### Stage 4 — Timer and practice tools

Timer starts when you leave `RJ_Start` and stops on `RJ_Finish`. Reset key sends you to start and clears the timer. Respawn key sends you to the last checkpoint without clearing the timer (segment practice). Savestate / loadstate stores and restores position, velocity, yaw, and checkpoint index.

**Done when**

- A full run shows a stable time.
- Reset and respawn do different things and both feel instant.
- Loadstate puts you back on the same arc, including speed, not just the same pad.
- Keys come from `InputConfig`.

### Stage 5 — Prove maps are cheap

Build a second small map. Register it. A simple cycle or menu picks the active map and reloads the session.

**Done when**

- The second map ships with zero new gameplay scripts.
- Switching maps respawns you on that map's start and clears the run.

### Stage 6 — Feel polish

Camera FOV kick on large speed gains, brief explosion shake, rocket trail, better explosion. All magnitudes in config.

**Done when**

- Polish can be turned down to zero from config and the physics from Stage 2 are unchanged.
- No polish code writes velocity.

### Stage 7 — Save a best time (only after the above is fun)

Per-map best time in a DataStore, shown next to the current timer. Still no lobby.

**Done when**

- Leaving and rejoining keeps the best time for that map.
- A failed run does not replace it.

---

## How we work each stage

1. Read this file and the config module you are about to extend.
2. Add or extend the class that owns the behavior. Keep the boot script as wiring.
3. Put new numbers in config.
4. Playtest the "done when" list in Studio before starting the next stage.
5. If a class grew a second job, split it before continuing.

Stage 1 and Stage 2 are allowed to take as long as they need. Everything after them is cheaper if the velocity model is right.
