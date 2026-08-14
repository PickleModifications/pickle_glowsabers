# TEBBY.md - pickle_glowsabers

## Overview

`pickle_glowsabers` is a small FiveM (GTA V multiplayer) resource by Pickle Mods that adds equippable, color-customisable lightsaber-style props to a server. Players consume a `glowsaber` inventory item (or use the `/glowsaber` command where ACE-gated) to attach a rendered glow-blade to their hand; the blade is visible to all nearby clients within `Config.RenderDistance`. Players can customise the saber color through the `/glowsabersettings` command. Unequipping (pressing the ESC/cancel key, entering a vehicle, or dying) returns the item to the player's inventory.

---

## Code design

### Architecture

The resource follows the standard Pickle Mods layered pattern:

1. **Shared layer** – `config.lua` and `core/shared.lua` are loaded on both client and server. `core/shared.lua` exposes math helpers (`lerp`, `round`, `GetRandomInt`, `v3`).
2. **Bridge layer** – `bridge/<framework>/client.lua` and `bridge/<framework>/server.lua` abstract framework-specific calls. The correct bridge is selected at runtime by checking `GetResourceState` for `es_extended` and `qb-core`; if neither is running, the `bridge/custom/` stubs load instead.
3. **Core client helpers** – `core/client.lua` provides reusable client utilities (`CreateBlip`, `CreateProp`, `PlayAnim`, `PlayEffect`).
4. **Module layer** – `modules/main/client.lua` and `modules/main/server.lua` contain all gameplay logic. There is only one module.
5. **NUI layer** – a minimal HTML page (`nui/index.html`) with `nui/assets/js/main.js` that only plays `saber_on.mp3` / `saber_off.mp3` audio cues triggered by `SendNUIMessage`.

### Main flows

**Equipping**
1. A framework bridge registers `glowsaber` as a usable item and triggers `pickle_glowsabers:equipGlowsaber` on the owning client.
2. The client creates a local prop (`w_ex_pipebomb`) and attaches it to the player's right-hand bone.
3. A server callback `pickle_glowsabers:createGlowsaber` is invoked with the prop's `netId` and the player's saved color. The server verifies the entity exists and (if a framework inventory bridge is available) that the player holds ≥ 1 `glowsaber` item. On success it removes the item, stores the entry in the `Glowsabers` table, and broadcasts `pickle_glowsabers:updateGlowsaber` to all clients.
4. All clients with the player within `Config.RenderDistance` begin drawing `DrawMarker` beams and a dynamic light every frame via the main render loop thread.

**Rendering**
- A continuous `CreateThread` loop on the client polls the `Glowsabers` table.
- For sabers being extended/retracted, the `length` field on `localGlowsabers[entity]` is ramped ±0.02 per tick.
- `DrawMarker` (type 1, cylinder) and `DrawLightWithRangeAndShadow` produce the visual blade.
- A ray-cast from hilt to tip detects collisions; on a hit a spark particle (`core/ent_brk_sparking_wires`) fires for 50 ms.
- While equipping, the client forces `WEAPON_NIGHTSTICK` with the model hidden to enable melee hitboxes at 15% damage.

**Unequipping**
- Pressing ESC (control 202) while saber is active, entering a vehicle, or dying triggers `TriggerServerEvent("pickle_glowsabers:unequipGlowsaber")`.
- The server removes the `Glowsabers` entry and — after a 600 ms delay to allow the retract animation to play — returns the item to the player's inventory via `AddItem`.
- `pickle_glowsabers:updateGlowsaber` is then broadcast with `nil` so all clients clean up.

**Settings persistence**
- Saber color is persisted client-side in `ResourceKvp` under key `pickle_glowsabers:settings` as JSON.
- `/glowsabersettings` uses `lib.inputDialog` (ox_lib) with an RGBA color picker. The chosen color is saved locally and synced to the server via `pickle_glowsabers:updateGlowsaber`.

**Server watchdog**
- A 5-second loop on the server checks every active entry: if the prop entity no longer exists, or is more than 2.0 m from the owning player, the entry is cleared and clients are notified.

---

## Important files

| Path | Why it matters |
|---|---|
| `fxmanifest.lua` | Resource manifest — declares all scripts, NUI page, and file lists. Entry point for FXServer. |
| `config.lua` | Only two config keys: `Config.Language` and `Config.RenderDistance`. Both are shared. |
| `core/shared.lua` | Shared math helpers (`lerp`, `round`, `GetRandomInt`, `v3`) used in rendering. |
| `core/client.lua` | Client utility functions: `CreateBlip`, `CreateProp`, `PlayAnim`, `PlayEffect`. |
| `modules/main/client.lua` | All client gameplay: equip/unequip logic, render loop, color settings command, net events. |
| `modules/main/server.lua` | All server gameplay: glowsaber state table, callback registration, item management, watchdog thread. |
| `bridge/esx/server.lua` | ESX bridge — provides `AddItem`, `RemoveItem`, `GetItemCount`, `RegisterUsableItem`, and registers the usable `glowsaber` item. Also registers `/glowsaber` command (ACE-gated). |
| `bridge/qb/server.lua` | QBCore bridge — same API surface as ESX bridge. |
| `bridge/custom/server.lua` | Fallback bridge — provides `ShowNotification`, `CheckPermission`, and registers the ACE-gated `/glowsaber` command. No inventory integration (item not consumed/returned). |
| `bridge/esx/client.lua` | ESX client bridge — provides `ShowNotification` via ESX. |
| `bridge/qb/client.lua` | QBCore client bridge — provides `ShowNotification` via QBCore. |
| `locales/locale.lua` | `_L()` helper that resolves translation keys; returns `ERR_TRANSLATE_<key>_404` on miss. |
| `locales/translations/en.lua` | English strings: `saber_title`, `saber_color`, `no_permission`, `no_item`. |
| `nui/index.html` | Minimal NUI page; only used to play saber-on/off audio cues. |
| `nui/assets/js/main.js` | Listens for `playSound` NUI messages and plays the corresponding `.mp3`. |
| `INSTALL/INSTALL.md` | Installation steps including the critical ox_inventory `setr inventory:ignoreweapons` note. |
| `INSTALL/Item Installation/ox_inventory.lua` | ox_inventory item definition for `glowsaber`. |
| `INSTALL/Item Installation/esx_limit.sql` | ESX (weight-less) item SQL. |
| `INSTALL/Item Installation/esx_weight.sql` | ESX (weight-based) item SQL. |
| `INSTALL/Item Installation/qbcore.lua` | QBCore shared items definition. |

---

## Intended behaviors

### `WEAPON_NIGHTSTICK` forced on the player
The client intentionally gives the player `WEAPON_NIGHTSTICK` every tick and hides the model (`SetPedCurrentWeaponVisible`). This is deliberate: it provides melee collision/hitbox data without showing an actual weapon. Damage is intentionally capped at 15% via `SetPlayerMeleeWeaponDamageModifier`. **This is not a bug.**

### `WEAPON_NIGHTSTICK` must be ignored by ox_inventory
`INSTALL/INSTALL.md` explicitly requires:
```
setr inventory:ignoreweapons ['WEAPON_NIGHTSTICK']
```
without this, ox_inventory registers the nightstick as an inventory weapon item and conflicts with the glowsaber system. Players seeing a nightstick appear in their inventory is a setup issue, not a code bug.

### `w_ex_pipebomb` model used for the blade prop
The pipebomb prop is used as the physical attachment point for the glowsaber. Its appearance is never shown — the blade is rendered purely with `DrawMarker`. Attaching an invisible prop to a hand bone is the intended technique.

### Custom bridge has no inventory integration
`bridge/custom/server.lua` intentionally does **not** define `AddItem`, `RemoveItem`, or `GetItemCount`. The server-side callbacks guard against nil function references with `if AddItem then` / `if RemoveItem then` / `if GetItemCount then`. This means on a custom framework the item is never consumed or returned — that is the expected stub behavior until the custom bridge is filled in.

### 600 ms server-side `Wait` before returning item
After unequipping, `modules/main/server.lua` waits 600 ms before calling `AddItem`. This is intentional: it gives all clients time to animate the blade retraction before the server returns the item, preventing a race between the retract animation and any immediate re-equip.

### `DrawMarker` called twice for the same beam
In `RenderGlowsaber` the same `DrawMarker` call appears twice back-to-back with identical arguments. This is a deliberate visual layering trick that increases perceived blade brightness/glow at zero additional prop cost. **Do not deduplicate it as a "duplicate code" bug.**

### ACE permission for `/glowsaber` command (custom & custom-only path)
The custom and fallback bridges gate `/glowsaber` behind the `glowsaber` ACE permission. ESX and QBCore bridges instead register a usable item — the command is **not** registered on those frameworks. Both behaviors are intentional.

---

## Common issues & fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Text shows as `ERR_TRANSLATE_<key>_404` | `Config.Language` in `config.lua` does not match a key in `locales/translations/`. | Set `Config.Language = "en"` (or the correct locale key). |
| Resource name mismatch causes locale or script not to load | Folder named differently from `pickle_glowsabers`. | Rename the resource folder to exactly `pickle_glowsabers` and update `server.cfg`. |
| Nightstick appears in player inventory (ox_inventory) | `inventory:ignoreweapons` not set. | Add `setr inventory:ignoreweapons ['WEAPON_NIGHTSTICK']` above `ensure ox_inventory`. |
| Glowsaber item not consumed or returned on custom framework | `AddItem`/`RemoveItem` not implemented in `bridge/custom/server.lua`. | Implement those functions in the custom bridge. |
| Player's saber appears but nobody else can see it | `Config.RenderDistance` is very small, or the remote player is beyond the threshold. | Increase `Config.RenderDistance` in `config.lua`. |
| Saber does not unequip when entering a vehicle | The equip loop checks `GetVehiclePedIsIn` and calls `RemoveGlowsaber()` — if this is broken, check that the player is fully inside the vehicle (not just entering). | No code change needed; behavior is correct once in-vehicle. |
| Server watchdog clears the saber unexpectedly | The prop entity drifted > 2.0 m from the player (e.g. due to a desync or ragdoll). | This is a safety mechanism; the item will be returned to the player. No fix needed. |
| Saber color resets on reconnect | `ResourceKvp` is per-session on some server configs. | Color is saved per-client; reconnecting players must re-select if KVP storage is wiped. |
| `/glowsabersettings` or `lib.inputDialog` errors | `ox_lib` not started or not present. | Ensure `ox_lib` is started **before** `pickle_glowsabers` in `server.cfg`. |

---

## Conventions

- **Naming**: Resource event names are prefixed `pickle_glowsabers:` (e.g. `pickle_glowsabers:createGlowsaber`). All Lua globals added by this resource are `PascalCase` for data tables (`Glowsabers`, `SaberSettings`) and `PascalCase` verbs for utility functions (`CreateProp`, `PlayAnim`, `RenderGlowsaber`).
- **Bridge guard pattern**: Every bridge file begins with early-return guards (`if GetResourceState('...') ~= 'started' then return end`). New bridges must follow the same pattern.
- **Optional function guards**: Server code calls inventory functions only if they are non-nil (`if AddItem then ... end`). Any new server-side inventory integration must follow this guard pattern to remain compatible with the custom/stub bridge.
- **`lua54 'yes'`**: The manifest enables Lua 5.4. Use `<const>` and `<close>` where appropriate; avoid Lua 5.1-only patterns.
- **Locale strings**: All player-facing strings must be added to `locales/translations/en.lua` (and any other locale files) and referenced only through `_L("key")`. Hard-coded strings in module files are a convention violation.
- **Module structure**: New gameplay modules go under `modules/<name>/client.lua` and `modules/<name>/server.lua` — the manifest glob `modules/**/client.lua` picks them up automatically.
- **No external HTTP or escrow checks**: This resource has no license callbacks, anti-tamper checks, or phone-home logic. There is no obfuscated/escrowed code.
