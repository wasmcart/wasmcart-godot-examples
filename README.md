# godot-wasmcart-examples

Example carts for [godot-wasmcart](https://github.com/wasmcart/godot-wasmcart)
— Godot 4 games running as [wasmcart](https://github.com/wasmcart/wasmcart)
cartridges.

```bash
npx wasmcart roboblast/roboblast.wasc
```

## The examples

| Example | Resolution | What it shows |
|---|---|---|
| [`roboblast`](roboblast) | 1920x1080 | a 3D action game: third-person controller, enemies, terrain, foliage |
| [`kenney_platformer`](kenney_platformer) | 1280x720 | 3D platformer — Kenney's starter kit, unmodified |
| [`shiny_orbits`](shiny_orbits) | 640x480 | 3D scene: reflective floor, lit geometry, orbiting bodies |
| [`warring_lords`](warring_lords) | 640x360 | four-player castle-defence arcade game, gamepad-driven |
| [`hello_godot`](hello_godot) | 640x480 | the minimal cart |

All five render through Godot's GLES3 Compatibility renderer, so draw calls
reach the real GPU.

## Building a cart

Each example has a `pack.sh` that builds its `.pck` and packs a `.wasc`:

```bash
cd roboblast && bash pack.sh
```

It expects a built runtime in a sibling `godot-wasmcart` checkout. Point
elsewhere with environment variables:

```bash
GODOT_WASMCART=/path/to/godot-wasmcart bash pack.sh
WASMCART_REPO=/path/to/wasmcart bash pack.sh   # or rely on npx wasmcart
```

Needs wasmcart 0.10.2 or newer: each cart declares its resolution in the
manifest, and older hosts do not pass that through to the runtime, so every
cart falls back to 640x480.

## make_pck.mjs

A pure-JS Godot 4.4 `.pck` builder. It walks a project directory and packs
it, so **no Godot editor is needed** to produce a cart from a project that is
already authored:

```bash
node make_pck.mjs my_project/ game.pck --patch-renderer
```

`--patch-renderer` rewrites `project.godot` from Forward+ to
`gl_compatibility`, which is what a cart needs — Forward+ and Mobile are
Vulkan renderers and a cart has no path to Vulkan.

## Making your own

1. Author in Godot 4.4 with **Rendering > Renderer** set to **Compatibility**.
2. Build a `.pck`, either by exporting from the editor or with `make_pck.mjs`.
3. Pack it, declaring the viewport size your project uses:

```bash
npx wasmcart pack --wasm godot.wasm --assets assets \
  --name my-game --width 1280 --height 720 -o my-game.wasc
```

Design for **gamepad**: d-pad, face buttons and sticks. Godot's `Input` reads
the host pad directly, and on a desktop the keyboard maps onto pad 1 so you
can test without a controller.

## Credits and licensing

Every example is freely redistributable.

| Example | Source | License |
|---|---|---|
| `roboblast` | [GDQuest 3D third-person controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) | code MIT, art CC-BY 4.0 — *"Additional assets CC-By 4.0 [GDQuest](https://www.gdquest.com/)"* |
| `kenney_platformer` | [Kenney Starter Kit 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | MIT, © 2023 Kenney |
| `warring_lords`, `shiny_orbits`, `hello_godot` | written for this repo | MIT |

Godot itself is MIT, © Juan Linietsky, Ariel Manzur and contributors.

This repository is [MIT](LICENSE). The vendored upstream terms, including
roboblast's CC BY 4.0 art and the attribution it requires, are in
[THIRD-PARTY.md](THIRD-PARTY.md).
