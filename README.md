# Bomb Bonk

A round-based Roblox party game. One homing bomb chases a random player. Click
at the right moment to **parry** it toward whoever you're looking at. Every
parry makes it faster. Miss and you get **launched off the map**. Last one
standing wins.

## Setup (Rojo)

All the code lives in this repo and syncs into Studio with [Rojo](https://rojo.space).

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs Rojo 7.4.4).
2. In Roblox Studio, install the **Rojo** plugin (Plugins → search "Rojo" in the Creator Store).
3. Open a new **Baseplate** place in Studio.
4. In this folder, run: `rojo serve`
5. In Studio: Plugins → Rojo → **Connect**. The scripts and remotes appear.
6. Press **Play**. The arena and lobby are generated automatically (`Workspace.BombBonkMap`).

From then on, pull new changes from this repo. Rojo live-syncs them into Studio while `rojo serve` is running.

## Testing

- **Solo:** In Studio, `STUDIO_SOLO` lets one player run practice rounds. The bomb bounces back to you so you can practice timing.
- **Multiplayer:** Test tab → Clients and Servers → 2–3 players → Start.
- **Saving coins/wins:** Game Settings → Security → turn on *Enable Studio Access to API Services* (the place must be published).

## Controls

| Action | PC | Mobile | Console |
| ------ | -- | ------ | ------- |
| Parry  | Left click or F | PARRY button | R2 |

Aim with your camera. The bomb goes to the player closest to where you're looking.

## Project layout

```
src/shared/Config.luau        every tuning number (speeds, timings, rewards)
src/server/Main.server.luau   boots everything
src/server/RoundManager.luau  game loop, parry logic, eliminations, rewards
src/server/Bomb.luau          homing bomb movement + visuals
src/server/Arena.luau         generated arena + lobby
src/server/Modifiers.luau     random per-round twists
src/server/Data.luau          Coins/Wins leaderstats + DataStore saving
src/client/Main.client.luau   input, HUD, screen shake, ragdoll fling
```

## Roadmap

- [x] **1. Core loop:** lobby, rounds, homing bomb, parry, elimination, winner
- [x] **2. Feel (basic):** knockback fling, screen shake, parry rings, kill feed, target highlight
- [x] **3. Progression (basic):** coins and wins that save
- [x] **4. Retention (basic):** random round modifiers
- [ ] Sounds (parry clang, explosion, countdown beeps)
- [ ] Spectate camera for eliminated players
- [ ] Shop: bomb trails, parry effects, emotes bought with coins
- [ ] Daily rewards + win streaks
- [ ] More maps and modifiers (shrinking floor, double bomb)
- [ ] Client-side bomb smoothing for high speeds
