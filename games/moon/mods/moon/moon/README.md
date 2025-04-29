# primitive-engine

**A modular, zero-gameplay primitive material & solver engine for Minetest.**  
This mod provides the data backbone for simulating materials, bonds, ports, and the six core solvers (electrical, logic, mechanical, thermal, chemistry, material-flow) in a deterministic, efficient, and extensible fashion.  
No gameplay nodes, decorations, or recipes are included—this is an engine for world simulation only.

---

## Features

- **Material registry** with bit-flag roles (conductor, insulator, etc.) and physical properties.
- **Bond & port subsystems** enable arbitrary connectivity and exposure to solvers.
- **Islands**: simulation runs only on active, connected subgraphs—idle voxels cost zero cycles.
- **Six orthogonal solvers**: electrical, logic, mechanical, thermal, chemistry, and material flow.
- **Deterministic, data-driven design**: no hardcoded machine logic, all behaviors via flags and registries.
- **Built-in test suite** for regression and solver validation.

---

## Requirements

- **Minetest 5.8.0+** (server with LuaJIT enabled).
- **FFI**: LuaJIT FFI must be available (enabled by default in Minetest builds).
- No C/C++ compilation required for the Lua version; all files are pure Lua.

---

## Build & Usage

1. **Install:**  
   Place this mod in your `mods` directory under the folder name `primitive-engine` or `moon`.

2. **Dependencies:**  
   None beyond Minetest 5.8+ with LuaJIT.

3. **Testing:**  
   Run `busted` in the `tests/` directory, or `/run_tests` in-game if using Minetest's built-in test runner.

4. **Integration:**  
   Exposes a single global `moon` namespace for advanced mods to register new materials, bonds, and ports, and to listen to simulation events.

---

## Contribution Guidelines

- **Code style:**  
  - 2-space indent  
  - Passes [`luacheck`](https://github.com/mpeterv/luacheck) with no warnings  
  - No global variable writes outside the `moon` namespace  
- **Modularity:**  
  - Each file serves a focused subsystem (see `/materials`, `/bonds`, `/ports`, `/voxels`, `/islands`, `/solvers`, `/runtime`, `/tests`)
- **Philosophy:**  
  - Everything is data—no type switches or hardcoded machine behaviors  
  - Extend via new material flags, bond/port types, or solver passes  
- **Testing:**  
  - All merged features must include (or update) a test in `tests/`
- **PRs:**  
  - Make small, focused pull requests  
  - Document any new flags or solver behaviors in code comments

---

## File Structure

- `init.lua` – Wires together modules, creates the global `moon` namespace, registers the simulation stepper.
- `constants.lua` – Central immutable constants and bit masks.
- `util.lua` – Pure helpers for vector math, bit ops, and object pools (no dependencies).
- `/materials/` – Material flags, registry, and chemical reaction tables.
- `/bonds/` – Bond kind enums, registry, and safe public API.
- `/ports/` – Port kind enums, registry, and safe public API.
- `/voxels/` – Compressed voxel meta store and serialization routines.
- `/islands/` – Active island detection and tick queue logic.
- `/solvers/` – Core solver implementations (electrical, logic, mechanical, etc).
- `/runtime/` – Tick scheduler, profiler, and optional debug overlay.
- `/tests/` – Automated regression and solver tests.

---

## License

MIT License (see `LICENSE` file)

---

## Credits

Design & implementation: [contributors](https://github.com/your-repo/primitive-engine/graphs/contributors)

---

## Status

**Alpha** – APIs and file layout are stable, but expect breaking changes until 1.0. No backward compatibility is guaranteed yet.

---

## Contact & Discussion

- [GitHub Issues](https://github.com/your-repo/primitive-engine/issues)
- Discussions and design chat: [link or Discord/Matrix/IRC as appropriate]

