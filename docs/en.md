# PC Fútbol Local — Full guide (English)

> Spanish version: [es.md](es.md)

This guide explains how the project works, how to use every feature, and how to
extend it.

## Table of contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Playing a game](#playing-a-game)
4. [Saved games](#saved-games)
5. [Offline / online behaviour](#offline--online-behaviour)
6. [Project layout](#project-layout)
7. [How it works internally](#how-it-works-internally)
8. [Adding or updating games](#adding-or-updating-games)
9. [FAQ](#faq)
10. [Legal](#legal)

## Overview

PC Fútbol Local is a thin, cross-platform launcher that runs the classic
**PC Fútbol / PC Basket / PC Calcio** games inside the [v86](https://github.com/copy/v86)
x86 emulator **in your browser**, served from a tiny **local** web server.

The games were full MS-DOS or Windows 98 applications. The rights holders
distribute ready-to-boot disk images for free at
<https://online.dinamicmultimedia.es>. This project automates:

1. mirroring the (small) v86 runtime + front-end locally,
2. downloading the (large) game disk images and a savestate,
3. serving everything from `127.0.0.1` with HTTP **Range** support,
4. opening your browser straight into the game.

## Installation

```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
./pcf doctor       # verify curl + python + browser
```

There is nothing to compile or install globally. Requirements:

- **curl** — preinstalled on macOS, Linux and Windows 10+.
- **Python 3** — preinstalled on macOS/Linux; on Windows it is recommended but a
  pure-PowerShell server is used as a fallback.
- A modern **browser** (Chrome, Edge, Firefox, Safari…).

## Playing a game

```bash
./pcf list           # show ids
./pcf play pcf5      # download (first time) and play
```

What happens on first launch of a title:

- the runtime is mirrored once into `.play/` (a few MB),
- the game's disk image(s) + savestate are downloaded into `.play/disks/`,
- a local server starts and your browser opens at
  `http://127.0.0.1:8782/kiosk.html?game=pcf5`,
- press **▶ JUGAR / PLAY**.

Press `Ctrl+C` in the terminal to stop the server.

### Change the port

```bash
PCF_PORT=9001 ./pcf play pcf5
```

### Pre-download without launching

```bash
./pcf get pcf7       # fetch everything for offline play later
```

## Saved games

Your **in-game** saved games (la partida que guardas dentro de PC Fútbol) are
persisted by the emulator into your **browser's IndexedDB**, scoped to the
`localhost` site. Practical consequences:

- Use the **same browser** and **same port** to find your saves.
- Don't clear "site data" for `127.0.0.1` or you'll lose them.
- They are independent from the downloaded disk images, so `pcf clean` (which
  removes `.play/`) does **not** touch your browser saves.

## Offline / online behaviour

After the first successful download a game is **fully offline**: the disk images
live in `.play/disks/` and are served locally. You can disconnect from the
internet and keep playing.

The only step that needs the internet is the initial download from the official
servers.

### Community mirror (don't saturate the origin)

Downloads are resumable and skipped when already complete, so each game is
fetched **once** per machine. To protect the official servers at community
scale you can route the heavy disk images through a CDN:

- `PCF_MIRROR=https://your-mirror` (or `PCF_DISKS_BASE`) — disk images source.
- `PCF_ORIGIN_BASE=https://…` — runtime + savestate source.
- `PCF_RATE_LIMIT=3M` — cap download speed to be gentle.
- `PCF_UA="…"` — override the identifiable User-Agent.
- `data/mirror.json` — ship a default mirror so **every** user benefits without
  setting env vars (copy `data/mirror.example.json`).

A ready-to-deploy **Cloudflare** mirror (Worker proxy + edge cache, or R2 with
zero egress) lives in [`mirror/cloudflare/`](../mirror/cloudflare/).

## Project layout

```
pc-futbol-local/
├── pcf                 # launcher (macOS / Linux)
├── pcf.ps1             # launcher (Windows, PowerShell)
├── pcf.cmd             # Windows convenience wrapper
├── data/
│   └── games.json      # game catalogue (ids, disk files, sizes, savestate)
├── scripts/
│   ├── lib.sh          # core logic for the bash launcher
│   ├── serve.py        # tiny static server with HTTP Range support
│   └── _game.py        # reads games.json for the shell launcher
├── docs/
│   ├── en.md           # this file
│   └── es.md
├── README.md
├── DISCLAIMER.md
└── .play/              # (git-ignored) local runtime + downloaded games
```

Nothing under `.play/` is committed; it is your local, regenerable cache.

## How it works internally

The official site boots each game like this (simplified, from its `kiosk.html`):

```js
emulator = new V86({
  wasm_path: "/v86.wasm",
  bios:     { url: "/bios/seabios.bin" },
  vga_bios: { url: "/bios/vgabios.bin" },
  memory_size: game.memory_size,
  hda:   { url: game.hda.url,   async: true },   // boot disk
  hdb:   { url: game.hdb.url,   async: true },   // game data (Win98 titles)
  cdrom: { url: game.cdrom.url, async: true },   // CD image (Win98 titles)
});
emulator.add_listener("emulator-ready", async () => {
  await emulator.restore_state(savestate);       // jump straight into the game
  emulator.run();
});
```

`async: true` means v86 streams the disk via HTTP **Range** requests instead of
downloading it whole — which is why the local server must support Range.

This project mirrors that exact front-end and only rewrites the absolute disk
URLs (`https://discos.dinamicmultimedia.es/…`) to the local `disks/…` path, so
the behaviour — including the robust save persistence — is identical to the
official experience, but offline.

## Adding or updating games

Game metadata lives in [`data/games.json`](../data/games.json). Each entry:

```json
{
  "id": "pcf5",
  "name": "PC Fútbol 5.0",
  "year": 1996,
  "kind": "win98",
  "dir": "FUT5ORO",
  "disks": [
    { "file": "win98_pcf5.bin", "size": 523837440, "slot": "hda" },
    { "file": "win98_pcf5_data.bin", "size": 536870912, "slot": "hdb" },
    { "file": "PCF5.bin", "size": 447692800, "slot": "cdrom" }
  ],
  "state": "pcf5_state.bin"
}
```

- `disks[].file` — filename on `discos.dinamicmultimedia.es`.
- `disks[].size` — exact byte size (used to skip already-complete downloads).
- `state` — savestate filename on `online.dinamicmultimedia.es`.

The boot configuration itself comes from the mirrored `games.js`, so adding a
title here is only needed for the download/list UX.

## FAQ

**Is this legal?** The games are distributed for free by the rights holders;
this tool just downloads from their official servers and runs them locally. No
game data is stored in this repository. See [DISCLAIMER.md](../DISCLAIMER.md).

**Do I need DOSBox?** No. Everything runs in the browser via v86.

**Can I use my own original CD/ISO instead?** These official images are the
easiest path and already include a savestate that boots straight into the game.
Running your own ISO is a different, more manual route (DOSBox/86Box) and is out
of scope for the automated launcher.

**Why is the first launch slow?** It downloads several hundred MB to ~2 GB once.
Subsequent launches are instant and offline.

## Legal

See [DISCLAIMER.md](../DISCLAIMER.md). Trademarks and game data belong to their
respective owners (Dinamic Multimedia / FX Interactive). The v86 emulator is a
separate open-source project.
