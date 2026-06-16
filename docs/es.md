# PC Fútbol Local — Guía completa (Español)

> English version: [en.md](en.md)

Esta guía explica cómo funciona el proyecto, cómo usar cada función y cómo
ampliarlo.

## Índice

1. [Resumen](#resumen)
2. [Instalación](#instalación)
3. [Jugar a un juego](#jugar-a-un-juego)
4. [Partidas guardadas](#partidas-guardadas)
5. [Comportamiento offline / online](#comportamiento-offline--online)
6. [Estructura del proyecto](#estructura-del-proyecto)
7. [Cómo funciona por dentro](#cómo-funciona-por-dentro)
8. [Añadir o actualizar juegos](#añadir-o-actualizar-juegos)
9. [Preguntas frecuentes](#preguntas-frecuentes)
10. [Aviso legal](#aviso-legal)

## Resumen

PC Fútbol Local es un lanzador ligero y multiplataforma que ejecuta los clásicos
**PC Fútbol / PC Basket / PC Calcio** dentro del emulador x86
[v86](https://github.com/copy/v86) **en tu navegador**, servidos desde un
pequeño servidor web **local**.

Los juegos eran aplicaciones completas de MS-DOS o Windows 98. Los titulares de
derechos distribuyen imágenes de disco listas para arrancar de forma gratuita en
<https://online.dinamicmultimedia.es>. Este proyecto automatiza:

1. hacer un espejo local del runtime (ligero) de v86 + el front-end,
2. descargar las imágenes de disco (grandes) del juego y un savestate,
3. servirlo todo desde `127.0.0.1` con soporte de **Range** HTTP,
4. abrir tu navegador directamente en el juego.

## Instalación

```bash
git clone https://github.com/i10s/pc-futbol-local.git
cd pc-futbol-local
./pcf doctor       # comprueba curl + python + navegador
```

No hay nada que compilar ni instalar globalmente. Requisitos:

- **curl** — preinstalado en macOS, Linux y Windows 10+.
- **Python 3** — preinstalado en macOS/Linux; en Windows es recomendable, pero
  hay un servidor de respaldo en PowerShell puro.
- Un **navegador** moderno (Chrome, Edge, Firefox, Safari…).

## Jugar a un juego

```bash
./pcf list           # ver los id
./pcf play pcf5      # descargar (la primera vez) y jugar
```

Qué ocurre al abrir un título por primera vez:

- se hace el espejo del runtime una vez en `.play/` (unos pocos MB),
- se descargan la(s) imagen(es) de disco + el savestate en `.play/disks/`,
- arranca un servidor local y tu navegador se abre en
  `http://127.0.0.1:8782/kiosk.html?game=pcf5`,
- pulsa **▶ JUGAR / PLAY**.

Pulsa `Ctrl+C` en la terminal para detener el servidor.

### Cambiar el puerto

```bash
PCF_PORT=9001 ./pcf play pcf5
```

### Descargar sin abrir

```bash
./pcf get pcf7       # descarga todo para jugar offline más tarde
```

## Partidas guardadas

Tus partidas guardadas **dentro del juego** (la partida que guardas en PC
Fútbol) las conserva el emulador en la **IndexedDB de tu navegador**, asociada al
sitio `localhost`. Consecuencias prácticas:

- Usa el **mismo navegador** y el **mismo puerto** para encontrar tus partidas.
- No borres los "datos del sitio" de `127.0.0.1` o las perderás.
- Son independientes de las imágenes de disco descargadas, así que `pcf clean`
  (que borra `.play/`) **no** toca las partidas del navegador.

## Comportamiento offline / online

Tras la primera descarga correcta, un juego es **totalmente offline**: las
imágenes de disco viven en `.play/disks/` y se sirven localmente. Puedes
desconectarte de internet y seguir jugando.

El único paso que necesita internet es la descarga inicial desde los servidores
oficiales.

## Estructura del proyecto

```
pc-futbol-local/
├── pcf                 # lanzador (macOS / Linux)
├── pcf.ps1             # lanzador (Windows, PowerShell)
├── pcf.cmd             # atajo para Windows
├── data/
│   └── games.json      # catálogo (ids, ficheros de disco, tamaños, savestate)
├── scripts/
│   ├── lib.sh          # lógica del lanzador bash
│   ├── serve.py        # servidor estático con soporte HTTP Range
│   └── _game.py        # lee games.json para el lanzador
├── docs/
│   ├── en.md
│   └── es.md           # este archivo
├── README.md
├── DISCLAIMER.md
└── .play/              # (ignorado por git) runtime local + juegos descargados
```

Nada de `.play/` se sube al repositorio; es tu caché local y regenerable.

## Cómo funciona por dentro

La web oficial arranca cada juego así (simplificado, de su `kiosk.html`):

```js
emulator = new V86({
  wasm_path: "/v86.wasm",
  bios:     { url: "/bios/seabios.bin" },
  vga_bios: { url: "/bios/vgabios.bin" },
  memory_size: game.memory_size,
  hda:   { url: game.hda.url,   async: true },   // disco de arranque
  hdb:   { url: game.hdb.url,   async: true },   // datos del juego (Win98)
  cdrom: { url: game.cdrom.url, async: true },   // imagen de CD (Win98)
});
emulator.add_listener("emulator-ready", async () => {
  await emulator.restore_state(savestate);       // entra directo al juego
  emulator.run();
});
```

`async: true` significa que v86 transmite el disco mediante peticiones **Range**
HTTP en lugar de descargarlo entero — por eso el servidor local debe soportar
Range.

Este proyecto hace un espejo de ese front-end exacto y solo reescribe las URLs
absolutas de disco (`https://discos.dinamicmultimedia.es/…`) a la ruta local
`disks/…`, de modo que el comportamiento —incluida la robusta persistencia de
partidas— es idéntico al de la web oficial, pero offline.

## Añadir o actualizar juegos

Los metadatos viven en [`data/games.json`](../data/games.json). Cada entrada:

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

- `disks[].file` — nombre del fichero en `discos.dinamicmultimedia.es`.
- `disks[].size` — tamaño exacto en bytes (para saltar descargas ya completas).
- `state` — nombre del savestate en `online.dinamicmultimedia.es`.

La configuración de arranque viene del `games.js` espejado, así que añadir un
título aquí solo es necesario para la experiencia de descarga/listado.

## Preguntas frecuentes

**¿Es legal?** Los juegos los distribuyen gratis los titulares de derechos; esta
herramienta solo descarga de sus servidores oficiales y los ejecuta en local. No
se guarda ningún dato de juego en este repositorio. Lee
[DISCLAIMER.md](../DISCLAIMER.md).

**¿Necesito DOSBox?** No. Todo se ejecuta en el navegador con v86.

**¿Puedo usar mi propio CD/ISO original?** Estas imágenes oficiales son la vía
más fácil y ya incluyen un savestate que entra directo al juego. Usar tu propia
ISO es otra ruta distinta y más manual (DOSBox/86Box) y queda fuera del alcance
del lanzador automático.

**¿Por qué la primera vez tarda?** Descarga una vez desde cientos de MB hasta ~2
GB. Las siguientes veces es instantáneo y offline.

## Aviso legal

Lee [DISCLAIMER.md](../DISCLAIMER.md). Las marcas y los datos de los juegos
pertenecen a sus respectivos dueños (Dinamic Multimedia / FX Interactive). El
emulador v86 es un proyecto de código abierto independiente.
