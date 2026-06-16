# Contributing / Cómo contribuir

Thanks for helping make **PC Fútbol Local** better! · ¡Gracias por mejorar **PC Fútbol Local**!

## 🇬🇧 English

### Ways to contribute

- 🐛 **Report bugs** — open an issue with your OS, the command you ran, and the output.
- 🎮 **Request a game** — use the *Game request* issue template.
- 📖 **Improve docs** — fixes to the README or the guides in `docs/` are very welcome.
- 🧑‍💻 **Code** — improve the launchers (`pcf`, `pcf.ps1`) or the helpers in `scripts/`.

### Golden rule

> **Never commit game data, ISOs, disk images, savestates, BIOS or emulator
> binaries.** This repository ships automation only. Everything heavy is
> downloaded on demand and lives in the git-ignored `.play/` folder.

### Local development

```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
make lint     # ShellCheck + Python syntax
make check    # validate data/games.json
make test     # hermetic HTTP Range self-test (no downloads)
make all      # everything above
```

Requirements for development: `bash`, `python3`, `curl`, `shellcheck`, `make`.

### Coding guidelines

- Keep it dependency-free: only `curl`, `python3` and a browser at runtime.
- Bash must pass `shellcheck -e SC1091`. PowerShell must parse cleanly.
- Match the existing style (2-space indent, see `.editorconfig`).
- Update **both** launchers (`pcf` and `pcf.ps1`) when you change behaviour.
- Update the docs (`README.md`, `docs/en.md`, `docs/es.md`) for user-facing changes.

### Adding a game

Add an entry to [`data/games.json`](data/games.json) — see the format in
[`docs/en.md`](docs/en.md#adding-or-updating-games). Run `make check` to validate.

### Pull requests

1. Fork and create a branch.
2. Make your change + run `make all`.
3. Open a PR describing **what** and **why**. CI must be green.

## 🇪🇸 Español

### Formas de contribuir

- 🐛 **Reportar errores** — abre una incidencia con tu SO, el comando que usaste y la salida.
- 🎮 **Pedir un juego** — usa la plantilla *Game request*.
- 📖 **Mejorar la documentación** — correcciones al README o a las guías de `docs/` son muy bienvenidas.
- 🧑‍💻 **Código** — mejora los lanzadores (`pcf`, `pcf.ps1`) o los scripts de `scripts/`.

### Regla de oro

> **Nunca subas datos de juego, ISOs, imágenes de disco, savestates, BIOS ni
> binarios del emulador.** Este repositorio solo contiene automatización. Todo
> lo pesado se descarga bajo demanda y vive en la carpeta `.play/` (ignorada por git).

### Desarrollo local

```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
make lint     # ShellCheck + sintaxis de Python
make check    # valida data/games.json
make test     # self-test de HTTP Range (sin descargas)
make all      # todo lo anterior
```

Requisitos para desarrollar: `bash`, `python3`, `curl`, `shellcheck`, `make`.

### Pautas de código

- Sin dependencias: en ejecución solo `curl`, `python3` y un navegador.
- Bash debe pasar `shellcheck -e SC1091`. PowerShell debe parsear sin errores.
- Respeta el estilo existente (indentación de 2 espacios, ver `.editorconfig`).
- Actualiza **ambos** lanzadores (`pcf` y `pcf.ps1`) si cambias el comportamiento.
- Actualiza la documentación (`README.md`, `docs/en.md`, `docs/es.md`) en cambios visibles.

### Añadir un juego

Añade una entrada en [`data/games.json`](data/games.json) — formato en
[`docs/es.md`](docs/es.md#añadir-o-actualizar-juegos). Ejecuta `make check` para validar.

### Pull requests

1. Haz un fork y crea una rama.
2. Haz tu cambio + ejecuta `make all`.
3. Abre un PR explicando **qué** y **por qué**. El CI debe estar en verde.

---

By contributing you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
Al contribuir aceptas el [Código de Conducta](CODE_OF_CONDUCT.md).
