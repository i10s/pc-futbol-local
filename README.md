<div align="center">

# ⚽ PC Fútbol Local

**Play the legendary [PC Fútbol](https://en.wikipedia.org/wiki/PC_F%C3%BAtbol) classics on your own computer — one command, right in your browser.**

*Juega a los míticos PC Fútbol en tu ordenador — un solo comando, en tu navegador.*

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue)]()
[![CI](https://github.com/i10s/pc-futbol-local/actions/workflows/ci.yml/badge.svg)](https://github.com/i10s/pc-futbol-local/actions/workflows/ci.yml)
[![Mirror health](https://github.com/i10s/pc-futbol-local/actions/workflows/mirror-health.yml/badge.svg)](https://github.com/i10s/pc-futbol-local/actions/workflows/mirror-health.yml)
[![Status](https://img.shields.io/badge/status-live-2ea44f)](https://ifuentes.net/pc-futbol-local/)
[![Agent · triage](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-triage.yml/badge.svg)](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-triage.yml)
[![Agent · implement](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-implement.yml/badge.svg)](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-implement.yml)
[![Agent · deploy](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-deploy.yml/badge.svg)](https://github.com/i10s/pc-futbol-local/actions/workflows/agent-deploy.yml)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Games](https://img.shields.io/badge/games-11-orange)]()
[![Made with](https://img.shields.io/badge/emulator-v86-purple)](https://github.com/copy/v86)

[English](#-english) · [Español](#-español) · [Full guide / Guía completa](docs/)

</div>

---

> **TL;DR**
> ```bash
> git clone https://github.com/i10s/pc-futbol-local.git
> cd pc-futbol-local
> ./pcf play pcf5          # Windows:  .\pcf.ps1 play pcf5
> ```
> The game downloads itself and opens in your browser. That's it. 🎉

---

## 🇬🇧 English

### What is this?

A tiny, friendly launcher that lets **anyone** play the classic Spanish football
manager **PC Fútbol** (and PC Basket, PC Calcio…) locally on **macOS, Linux or
Windows**. No accounts, no installers, no fiddling with DOSBox.

Under the hood it runs the original MS-DOS / Windows 98 games inside the
[**v86**](https://github.com/copy/v86) PC emulator in your browser — exactly the
same technology the official site uses — but **served locally from your own
machine** so you can play offline, like in the old days.

> 📦 **No game files live in this repository.** The launcher downloads them on
> demand from the **official, free** servers run by the rights holders
> (<https://online.dinamicmultimedia.es>). See [DISCLAIMER.md](DISCLAIMER.md).

### Requirements

| Tool        | macOS / Linux        | Windows                          |
| ----------- | -------------------- | -------------------------------- |
| `curl`      | preinstalled         | preinstalled (Windows 10+)       |
| Python 3    | preinstalled / brew  | recommended (built-in fallback)  |
| A browser   | any modern browser   | any modern browser               |

Check everything is fine: `./pcf doctor`

> 🐧 **Linux**: most distros already ship `curl`, `python3` and a browser. If
> something is missing, `./pcf doctor` prints the exact install command for your
> distro (`apt`/`dnf`/`pacman`/`zypper`/`apk`). You can also add a launcher to
> your applications menu with `./pcf install-desktop`. **WSL** works too.

### Quick start

**macOS / Linux**
```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
./pcf list          # see every available game
./pcf play pcf5     # download (once) + play PC Fútbol 5.0
```

> 🍺 **Homebrew (macOS/Linux):** prefer a one-liner?
> ```bash
> brew tap i10s/pcf https://github.com/i10s/pc-futbol-local
> brew install --HEAD pc-futbol-local
> pcf play pcf5
> ```
> Games download into `~/.pc-futbol-local` (override with `PCF_PLAY_DIR`).

**Windows (PowerShell)**
```powershell
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
.\pcf.ps1 list
.\pcf.ps1 play pcf5
```

The first time you launch a game it downloads its disk images (this can be a few
hundred MB to ~2 GB depending on the title). After that it's **fully offline and
instant**. Your in-game saved games are kept in your browser.

### Commands

| Command              | What it does                                         |
| -------------------- | ---------------------------------------------------- |
| `pcf play <id>`      | Download if needed, then play in your browser        |
| `pcf list`           | List every game and its id (● = already downloaded)  |
| `pcf get <id>`       | Pre-download a game for offline play (no launch)     |
| `pcf verify [id]`    | Check downloaded files against the manifest (size + checksum) |
| `pcf menu`           | Open the game menu in your browser                   |
| `pcf update`         | Refresh the local emulator runtime                   |
| `pcf install-desktop`| **(Linux)** add an app launcher to your menu         |
| `pcf doctor`         | Check your environment (`--json` for machine output) |
| `pcf clean`          | Remove all downloaded data                           |

> 💡 Tip: set `PCF_PORT` to change the base port, or `PCF_NO_OPEN=1` to skip
> opening the browser automatically. A free port is picked automatically, so you
> can run several games at once.

> 🌐 **Be a good neighbour.** To avoid hammering the official servers you can
> download from a community **Cloudflare** mirror: set `PCF_MIRROR=https://…`
> (or ship a `data/mirror.json` so it's the default for everyone), and throttle
> with `PCF_RATE_LIMIT=3M`. Downloads are cached locally and resumed, so each
> game is only fetched once. See [mirror/cloudflare/](mirror/cloudflare/).
>
> ✅ **Already on by default.** This repo ships a live mirror
> (`pcf-mirror.ifuentes.workers.dev`, proxy + edge cache), so disk images come
> from Cloudflare out of the box — the official origin is hit at most once per
> file. To bypass it, set `PCF_MIRROR=https://discos.dinamicmultimedia.es`.

| id           | Year | Game                                          | Approx. size |
| ------------ | ---- | --------------------------------------------- | ------------ |
| `pcf4`       | 1995 | PC Fútbol 4.0                                 | ~0.5 GB      |
| `pcf5`       | 1996 | **PC Fútbol 5.0**                             | ~1.4 GB      |
| `pcf6`       | 1997 | PC Fútbol 6.0                                 | ~1.8 GB      |
| `pcf7`       | 1998 | PC Fútbol 7.0                                 | ~2.1 GB      |
| `pcf7mod`    | 1998 | PC Fútbol 7.0 · Update 25/26                  | ~2.1 GB      |
| `pcfa96`     | 1996 | PC Fútbol 4.0 · Apertura '96 (Argentina)      | ~0.5 GB      |
| `pccalcio`   | 1996 | PC Calcio 4.0                                 | ~0.5 GB      |
| `euro96`     | 1996 | PC Selección Española · Eurocopa '96          | ~0.5 GB      |
| `wc98`       | 1998 | PC Selección Española · Mundial '98           | ~1.3 GB      |
| `pcbasket`   | 1996 | PC Basket 4.0                                 | ~0.5 GB      |
| `pcbasket65` | 1999 | PC Basket 6.5                                 | ~1.6 GB      |

### How it works

```mermaid
flowchart LR
    A["./pcf play pcf5"] --> B["Mirror v86 runtime<br/>(one-time, small)"]
    B --> C["Download game disk<br/>images + savestate"]
    C --> D["Local web server<br/>(HTTP Range)"]
    D --> E["Browser runs v86<br/>= MS-DOS / Win98 PC"]
    E --> F["⚽ Play!"]
```

More detail in the [full English guide](docs/en.md).

### Fully offline after the first download

Once a game is downloaded, **everything runs on your machine** — unplug the
network and keep playing. The only time anything touches the internet is the
one-time download.

| Piece | Where it lives | What it is |
| ----- | -------------- | ---------- |
| **Web server** | `scripts/serve.py` on `localhost` | A tiny stdlib server with HTTP **Range** (206) support — no dependencies |
| **Emulator** | `.play/libv86.js`, `.play/v86.wasm` | v86 runs the PC entirely in your browser (WASM) |
| **Disk images (ISOs)** | `.play/disks/*.bin` | The actual game discs, streamed locally by Range |
| **Savestate** | `.play/<game>.bin` | The game's initial boot state |
| **Front-end (kiosk)** | `.play/games.js`, `index.html`… | Disk URLs are rewritten to your **local** `/disks` |
| **Backend API** | `.play/papi/*.json` | **Stubbed locally** so the kiosk boots with zero network |

> Your in-game saved games are stored by your browser for the `localhost` site —
> keep the same browser and don't clear site data.

### The community mirror (Cloudflare)

To protect the official servers, this repo ships with a live **Cloudflare**
mirror enabled by default (`pcf-mirror.ifuentes.workers.dev`). It **stores
nothing permanently** — it only uses Cloudflare's edge cache, with two content
classes tuned so everything stays in sync while the origin is barely touched:

| Content | Edge policy | Origin load |
| ------- | ----------- | ----------- |
| **Disk images** (`*.bin`) | Immutable, cached ~1 year | One pull per file per region, ever |
| **Kiosk / runtime** | Short cache + revalidation | A few KB per region per window |

```mermaid
flowchart LR
    U["./pcf get pcf5"] --> M{"Cloudflare<br/>edge cache"}
    M -- "hit" --> U
    M -- "miss (once)" --> O["Official origin"]
    O --> M
    M -. "if mirror errors" .-> O2["Official origin<br/>(automatic fallback)"]
    O2 --> U
```

- **Resilient:** if the mirror ever fails or is blocked in your region, the
  launcher **automatically falls back** to the official origin — you're never
  stuck.
- **Adjustable:** set `PCF_RATE_LIMIT=3M` to cap speed, or
  `PCF_MIRROR=https://discos.dinamicmultimedia.es` to bypass the mirror.
- **Run your own:** deploy the Worker in minutes (proxy + cache, or zero-egress
  R2). Full guide in [mirror/cloudflare/](mirror/cloudflare/).

### Automated agent loop (loop engineering)

Community issues are handled by a small **[loop-engineering](https://addyosmani.com/blog/loop-engineering/)**
system: you design the loop once and it triages issues, drafts fixes and
proposes deploys — while a human stays in control.

```mermaid
flowchart LR
    I["Issue opened"] --> T["Triage agent<br/>classify · label · reply"]
    T -- "maintainer adds<br/>agent:go" --> MK["Maker<br/>drafts change"]
    MK --> CK["Checker<br/>adversarial review"]
    CK --> PR["Draft PR"]
    PR --> CI["CI validates"]
    CI --> H["Human merges"]
    H --> D["Deploy<br/>(approval-gated)"]
```

- **Model:** `@cf/moonshotai/kimi-k2.7-code` on Cloudflare Workers AI.
- **Safe by design:** the agent only opens **draft** PRs and **proposes**
  deploys. Implementation is gated by a maintainer-only `agent:go` label, the
  maker never grades its own work (a separate checker does), CI must pass, and a
  human merges. Deployment waits for approval in a protected environment.
- Setup and operation: [.github/agent/README.md](.github/agent/README.md).

### For the rights holder

If you are **FX Interactive / Dinamic Multimedia** (or represent them):

- This launcher **bundles no game data**. It downloads the original, free disk
  images on demand from your own public servers and runs them locally in the
  browser — it does not re-host, repackage, or modify your binaries.
- The optional community mirror is a **cache only** (reverse proxy + edge cache,
  or a self-hosted R2 copy). It stores nothing permanently, never increases your
  load beyond ~one fetch per region, and can be pointed back at your origin or
  switched off instantly.
- Want a change, attribution tweak, or a takedown? Open an issue or contact the
  maintainer (see [SECURITY.md](SECURITY.md)) and we will act promptly.

See [DISCLAIMER.md](DISCLAIMER.md) for the full statement.

### Troubleshooting

- **Port already in use** → `PCF_PORT=9000 ./pcf play pcf5`
- **Black screen / no boot** → make sure the download finished (`./pcf get <id>`)
  and try a hard refresh in the browser.
- **No sound** → click once inside the game; browsers require a user gesture to
  start audio.
- **Saved games disappeared** → they live in your browser's storage for that
  `localhost` site; don't clear site data and use the same browser.

---

## 🇪🇸 Español

### ¿Qué es esto?

Un lanzador pequeño y sencillo para que **cualquiera** pueda jugar al mítico
manager de fútbol **PC Fútbol** (y PC Basket, PC Calcio…) en local en **macOS,
Linux o Windows**. Sin cuentas, sin instaladores, sin pelearte con DOSBox.

Por dentro ejecuta los juegos originales de MS-DOS / Windows 98 dentro del
emulador de PC [**v86**](https://github.com/copy/v86) en tu navegador —la misma
tecnología que usa la web oficial— pero **servido localmente desde tu propio
ordenador**, para que puedas jugar offline, como en los viejos tiempos.

> 📦 **Este repositorio no contiene ningún juego.** El lanzador los descarga
> bajo demanda desde los servidores **oficiales y gratuitos** de los titulares
> de derechos (<https://online.dinamicmultimedia.es>). Lee
> [DISCLAIMER.md](DISCLAIMER.md).

### Requisitos

| Herramienta | macOS / Linux        | Windows                            |
| ----------- | -------------------- | ---------------------------------- |
| `curl`      | preinstalado         | preinstalado (Windows 10+)         |
| Python 3    | preinstalado / brew  | recomendado (hay alternativa)      |
| Navegador   | cualquiera moderno   | cualquiera moderno                 |

Comprueba que todo está bien: `./pcf doctor`

> 🐧 **Linux**: la mayoría de distros ya traen `curl`, `python3` y un navegador.
> Si falta algo, `./pcf doctor` te dice el comando exacto para tu distro
> (`apt`/`dnf`/`pacman`/`zypper`/`apk`). También puedes añadir un acceso directo
> a tu menú de aplicaciones con `./pcf install-desktop`. **WSL** también funciona.

### Inicio rápido

**macOS / Linux**
```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
./pcf list          # ver todos los juegos disponibles
./pcf play pcf5     # descargar (una vez) + jugar a PC Fútbol 5.0
```

> 🍺 **Homebrew (macOS/Linux):** ¿prefieres una sola línea?
> ```bash
> brew tap i10s/pcf https://github.com/i10s/pc-futbol-local
> brew install --HEAD pc-futbol-local
> pcf play pcf5
> ```
> Los juegos se descargan en `~/.pc-futbol-local` (cámbialo con `PCF_PLAY_DIR`).

**Windows (PowerShell)**
```powershell
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
.\pcf.ps1 list
.\pcf.ps1 play pcf5
```

La primera vez que abres un juego se descargan sus imágenes de disco (desde unos
cientos de MB hasta ~2 GB según el título). A partir de ahí es **totalmente
offline e instantáneo**. Tus partidas guardadas se conservan en el navegador.

### Comandos

| Comando              | Qué hace                                                 |
| -------------------- | -------------------------------------------------------- |
| `pcf play <id>`      | Descarga si hace falta y juega en el navegador           |
| `pcf list`           | Lista los juegos y sus id (● = ya descargado)            |
| `pcf get <id>`       | Descarga un juego para jugar offline (sin abrirlo)       |
| `pcf verify [id]`    | Comprueba lo descargado contra el manifiesto (tamaño + checksum) |
| `pcf menu`           | Abre el menú de juegos en el navegador                   |
| `pcf update`         | Actualiza el runtime del emulador                        |
| `pcf install-desktop`| **(Linux)** añade un acceso directo a tu menú de apps    |
| `pcf doctor`         | Comprueba tu entorno (`--json` para salida de máquina)   |
| `pcf clean`          | Borra todo lo descargado                                 |

> 💡 Truco: usa `PCF_PORT` para cambiar el puerto base, o `PCF_NO_OPEN=1` para
> no abrir el navegador automáticamente. El puerto libre se elige solo, así que
> puedes tener varios juegos a la vez.

> 🌐 **Sé buen vecino.** Para no saturar los servidores oficiales puedes
> descargar desde un mirror comunitario en **Cloudflare**: define
> `PCF_MIRROR=https://…` (o incluye un `data/mirror.json` para que sea el valor
> por defecto de todos) y limita la velocidad con `PCF_RATE_LIMIT=3M`. Las
> descargas se cachean en local y se reanudan, así cada juego se baja una sola
> vez. Mira [mirror/cloudflare/](mirror/cloudflare/).
>
> ✅ **Ya activo por defecto.** Este repo incluye un mirror en marcha
> (`pcf-mirror.ifuentes.workers.dev`, proxy + caché en el edge), así que las
> imágenes de disco vienen de Cloudflare desde el primer momento — el origen
> oficial se toca como mucho una vez por fichero. Para saltártelo, usa
> `PCF_MIRROR=https://discos.dinamicmultimedia.es`.

| id           | Año  | Juego                                         | Tamaño aprox. |
| ------------ | ---- | --------------------------------------------- | ------------- |
| `pcf4`       | 1995 | PC Fútbol 4.0                                 | ~0,5 GB       |
| `pcf5`       | 1996 | **PC Fútbol 5.0**                             | ~1,4 GB       |
| `pcf6`       | 1997 | PC Fútbol 6.0                                 | ~1,8 GB       |
| `pcf7`       | 1998 | PC Fútbol 7.0                                 | ~2,1 GB       |
| `pcf7mod`    | 1998 | PC Fútbol 7.0 · Actualización 25/26           | ~2,1 GB       |
| `pcfa96`     | 1996 | PC Fútbol 4.0 · Apertura '96 (Argentina)      | ~0,5 GB       |
| `pccalcio`   | 1996 | PC Calcio 4.0                                 | ~0,5 GB       |
| `euro96`     | 1996 | PC Selección Española · Eurocopa '96          | ~0,5 GB       |
| `wc98`       | 1998 | PC Selección Española · Mundial '98           | ~1,3 GB       |
| `pcbasket`   | 1996 | PC Basket 4.0                                 | ~0,5 GB       |
| `pcbasket65` | 1999 | PC Basket 6.5                                 | ~1,6 GB       |

### Cómo funciona

```mermaid
flowchart LR
    A["./pcf play pcf5"] --> B["Espejo del runtime v86<br/>(una vez, ligero)"]
    B --> C["Descarga imágenes de<br/>disco + savestate"]
    C --> D["Servidor web local<br/>(HTTP Range)"]
    D --> E["El navegador ejecuta v86<br/>= PC con MS-DOS / Win98"]
    E --> F["⚽ ¡A jugar!"]
```

Más detalle en la [guía completa en español](docs/es.md).

### Totalmente offline tras la primera descarga

Una vez descargado un juego, **todo se ejecuta en tu máquina** — puedes
desconectar la red y seguir jugando. Lo único que toca internet es la descarga
inicial.

| Pieza | Dónde vive | Qué es |
| ----- | ---------- | ------ |
| **Servidor web** | `scripts/serve.py` en `localhost` | Servidor mínimo de la stdlib con soporte HTTP **Range** (206), sin dependencias |
| **Emulador** | `.play/libv86.js`, `.play/v86.wasm` | v86 ejecuta el PC entero en tu navegador (WASM) |
| **Imágenes de disco (ISOs)** | `.play/disks/*.bin` | Los discos del juego, servidos en local por Range |
| **Savestate** | `.play/<juego>.bin` | El estado inicial de arranque del juego |
| **Front-end (kiosko)** | `.play/games.js`, `index.html`… | Las URLs de disco se reescriben a tu `/disks` **local** |
| **API de backend** | `.play/papi/*.json` | **Sustituida en local** para que el kiosko arranque sin red |

> Tus partidas guardadas las almacena el navegador para el sitio `localhost` —
> usa el mismo navegador y no borres los datos del sitio.

### El mirror comunitario (Cloudflare)

Para proteger los servidores oficiales, este repo trae activado por defecto un
mirror en **Cloudflare** (`pcf-mirror.ifuentes.workers.dev`). **No almacena nada
de forma permanente** — solo usa la caché del edge de Cloudflare, con dos clases
de contenido ajustadas para que todo quede sincronizado tocando el origen lo
mínimo:

| Contenido | Política del edge | Carga en origen |
| --------- | ----------------- | --------------- |
| **Imágenes de disco** (`*.bin`) | Inmutable, caché ~1 año | Un fetch por fichero y región, para siempre |
| **Kiosko / runtime** | Caché corta + revalidación | Unos KB por región y ventana |

```mermaid
flowchart LR
    U["./pcf get pcf5"] --> M{"Caché del edge<br/>de Cloudflare"}
    M -- "acierto" --> U
    M -- "fallo (una vez)" --> O["Origen oficial"]
    O --> M
    M -. "si el mirror falla" .-> O2["Origen oficial<br/>(fallback automático)"]
    O2 --> U
```

- **Resiliente:** si el mirror falla o está bloqueado en tu región, el lanzador
  **baja automáticamente del origen oficial** — nunca te quedas tirado.
- **Ajustable:** usa `PCF_RATE_LIMIT=3M` para limitar la velocidad, o
  `PCF_MIRROR=https://discos.dinamicmultimedia.es` para saltarte el mirror.
- **Monta el tuyo:** despliega el Worker en minutos (proxy + caché, o R2 sin
  coste de salida). Guía completa en [mirror/cloudflare/](mirror/cloudflare/).

### Bucle de agente automático (loop engineering)

Las incidencias de la comunidad las gestiona un pequeño sistema de
**[loop engineering](https://addyosmani.com/blog/loop-engineering/)**: diseñas el
bucle una vez y él clasifica incidencias, redacta arreglos y propone despliegues
— mientras un humano mantiene el control.

```mermaid
flowchart LR
    I["Issue abierta"] --> T["Agente de triaje<br/>clasifica · etiqueta · responde"]
    T -- "el responsable añade<br/>agent:go" --> MK["Maker<br/>redacta el cambio"]
    MK --> CK["Checker<br/>revisión adversarial"]
    CK --> PR["PR en borrador"]
    PR --> CI["La CI valida"]
    CI --> H["Un humano fusiona"]
    H --> D["Deploy<br/>(con aprobación)"]
```

- **Modelo:** `@cf/moonshotai/kimi-k2.7-code` en Cloudflare Workers AI.
- **Seguro por diseño:** el agente solo abre PRs en **borrador** y **propone**
  despliegues. La implementación está gateada por la label `agent:go` (solo
  responsables), el maker nunca corrige su propio trabajo (lo hace un checker
  aparte), la CI debe pasar y un humano fusiona. El despliegue espera aprobación
  en un entorno protegido.
- Configuración y uso: [.github/agent/README.md](.github/agent/README.md).

### Para los titulares de derechos

Si eres **FX Interactive / Dinamic Multimedia** (o les representas):

- Este lanzador **no incluye datos de los juegos**. Descarga las imágenes
  originales y gratuitas bajo demanda desde vuestros propios servidores públicos
  y las ejecuta en local en el navegador — no re-aloja, reempaqueta ni modifica
  vuestros binarios.
- El mirror comunitario opcional es **solo caché** (proxy inverso + caché de
  borde, o una copia propia en R2). No almacena nada de forma permanente, nunca
  aumenta vuestra carga más allá de ~una descarga por región, y se puede
  redirigir a vuestro origen o apagar al instante.
- ¿Queréis un cambio, ajuste de atribución o una retirada? Abre una issue o
  contacta con el responsable (ver [SECURITY.md](SECURITY.md)) y actuaremos sin
  demora.

Lee [DISCLAIMER.md](DISCLAIMER.md) para la declaración completa.

### Problemas comunes

- **Puerto ocupado** → `PCF_PORT=9000 ./pcf play pcf5`
- **Pantalla negra / no arranca** → asegúrate de que la descarga terminó
  (`./pcf get <id>`) y recarga la página forzando (hard refresh).
- **Sin sonido** → haz clic dentro del juego; los navegadores exigen una
  interacción del usuario para iniciar el audio.
- **Se borraron las partidas** → viven en el almacenamiento del navegador para
  ese sitio `localhost`; no borres los datos del sitio y usa el mismo navegador.

---

## 🤝 Contributing / Comunidad

Contributions are very welcome! · ¡Las contribuciones son muy bienvenidas!

- 📋 Read the [Contributing guide](CONTRIBUTING.md) (EN/ES) and the
  [Code of Conduct](CODE_OF_CONDUCT.md).
- 🐛 Found a bug or want a game added? Open an [issue](https://github.com/i10s/pc-futbol-local/issues/new/choose) —
  it gets **auto-triaged** by the agent loop, and a maintainer takes it from there.
- 🔒 Security reports: see [SECURITY.md](SECURITY.md).
- 📝 Changes are tracked in the [CHANGELOG](CHANGELOG.md).

For developers:

```bash
make lint     # ShellCheck + Python syntax
make check    # validate data/games.json
make test     # hermetic HTTP Range self-test (no downloads)
make all      # everything CI runs
```

---

<div align="center">

Hecho con ❤️ para la comunidad de PC Fútbol · Made with ❤️ for the PC Fútbol community

Games © Dinamic Multimedia / FX Interactive · Emulator © the [v86](https://github.com/copy/v86) project

</div>
