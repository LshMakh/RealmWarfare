# Realm Warfare — CLAUDE.md

## Project Overview
Bullet heaven roguelite built in Godot 4.6 with GDScript. Android-first (Compatibility/OpenGL renderer). Pixel art style. See `docs/superpowers/specs/2026-03-22-realm-warfare-design.md` for full game design spec.

## Research Before Guessing
When unsure about Godot APIs, GDScript syntax, node types, or engine behavior — **search the web first** (especially `docs.godotengine.org` and `forum.godotengine.org`). Do not guess at method signatures, property names, or engine behavior. Godot 4.6 has breaking changes from 4.x tutorials — always verify against current docs.

## Tech Stack
- Godot 4.6, Compatibility renderer (OpenGL ES 3.0)
- GDScript (strictly typed — see style rules below)
- Target: Android (60 FPS on mid-range 2021+ devices)
- Max 200 active entities, <150 MB RAM

## GDScript Style Rules
These are derived from the existing codebase — follow them exactly:

- **Explicit types everywhere** — Godot 4.6 has strict Variant inference. Always type variables, parameters, and return values: `var speed: float = 120.0`, `func foo(x: int) -> void:`
- **snake_case** for variables, functions, signals. **PascalCase** for classes/nodes.
- **Private prefix** — underscore for internal vars/methods: `var _spawn_timer: float`, `func _on_died() -> void:`
- **Signal naming** — past tense for events (`died`, `health_changed`), imperative for commands (`show_level_up_ui`)
- **@export** for inspector-configurable values. **@onready** for node references.
- **Typed arrays** — `Array[BlessingData]`, not untyped `Array` (except when Godot requires it for signal params)
- **No `self.`** unless required for disambiguation

## Architecture Patterns

### Autoloads (Singletons)
- `GameEvents` — signal event bus. All cross-system communication goes through here. Scripts emit and connect to signals on GameEvents, never directly reference each other.
- `GameState` — run state (level, XP, kills, time, active blessings). Reset on `start_new_run()`.

### Component Architecture
Reusable behaviors as child nodes with `class_name`:
- `HealthComponent` — HP, damage, healing, `died` signal
- `HitboxComponent` — deals damage (Area2D)
- `HurtboxComponent` — receives damage (Area2D)

When adding new behaviors, prefer creating a new component over adding logic to entity scripts.

### Object Pooling
All frequently spawned entities (enemies, projectiles, pickups) use `ObjectPool`. Never `queue_free()` pooled objects — call `pool.release(self)` instead. Pooled objects must implement:
- `set_pool(p: ObjectPool)` — called once at creation
- `initialize(...)` — called each time the object is activated
- `reset()` — called when returned to pool

### Data-Driven Resources
Game data lives in `.tres` resource files under `data/`:
- `BlessingData` — blessing stats, type, tier, pantheon
- `EnemyData` — enemy stats, sprite, boss flag

New content types should follow this pattern: create a `class_name` Resource script in `data/`, then create `.tres` instances.

### State Machine
`StateMachine` + `State` base class in `scripts/state_machine/`. Node-based — each state is a child node of the state machine.

## Directory Structure
```
scenes/          # .tscn scene files, organized by function
scripts/         # .gd scripts
  autoload/      # singletons (GameEvents, GameState)
  components/    # reusable components (health, hitbox, hurtbox)
  entities/      # entity logic (player, enemies, projectiles, pickups)
  systems/       # game systems (wave_manager, blessing_manager, etc.)
  state_machine/ # state machine framework
  ui/            # UI scripts
  run/           # run scene logic
data/            # Resource scripts and .tres data files
  blessings/     # BlessingData resources
  enemies/       # EnemyData resources
assets/          # sprites, tilesets, audio
```

## Scene Conventions
- One `.tscn` per entity/UI element. Script attached to root node.
- Scene root node type matches its purpose: `CharacterBody2D` for moving entities, `Area2D` for triggers, `Control` for UI.
- Components are child nodes, referenced with `@onready`.

## Signals & Communication
- **Between systems** → emit/connect via `GameEvents`
- **Parent ↔ child within a scene** → direct signals on the child node (e.g., `health_component.died.connect(...)`)
- **Never** use `get_node()` to reach across unrelated scene branches

## Performance Rules
- Pool everything that spawns frequently
- No `_process()` or `_physics_process()` on inactive/pooled objects (disable via `set_process(false)`)
- Prefer `move_and_slide()` over manual position updates for physics bodies
- Keep draw calls low — pixel art at native resolution, no post-processing

## Git
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- No AI attribution in commits, PRs, or any GitHub metadata
- Commit `.tscn`, `.tres`, `.gd`, and `.import` files. Never commit `.godot/` directory.
