# Cloudflare mirror / Mirror en Cloudflare

A community CDN mirror so thousands of players can download the games **without
hammering the official origin** (`discos.dinamicmultimedia.es`). Built for a
Cloudflare **Pro** account, but most of it works on the Free plan too.

Un mirror CDN comunitario para que miles de personas descarguen los juegos **sin
saturar el servidor oficial**. Pensado para una cuenta **Pro** de Cloudflare,
aunque casi todo funciona también en el plan gratuito.

> ⚠️ **Legal / Legal.** These are copyrighted disk images, distributed for free
> by the rights holders (FX Interactive / Dinamic Multimedia). **Proxy + cache**
> mode does **not** re-host anything permanently — it only caches what the
> origin already serves publicly, which is the safest option. **R2** mode
> re-hosts the binaries; only use it if you have permission from the rights
> holder. This project hosts **no** game files.

---

## Two modes / Dos modos

| Mode | What it does | Origin load | Egress cost | Legal footprint |
|------|--------------|-------------|-------------|-----------------|
| **Proxy + cache** (default) | Worker reverse-proxies the origin; Cloudflare caches each disk ~1 year | One pull per object per PoP | Free (cached) | Lowest — nothing re-hosted |
| **R2 mirror** | Disks served straight from your R2 bucket | Zero after one-time sync | **Zero egress** (R2) | Higher — you re-host |

Both modes add the **CORS** and **Range** headers the official host lacks.

> 🔐 **Automatic disk signing / Firma automática.** The official disk host now
> sits behind a Cloudflare WAF that **403s** plain automated requests. In proxy
> mode the Worker handles this transparently: it fetches the short-lived signing
> token from `<kiosk-origin>/papi/sign`, appends it as `?k=…`, and replays the
> kiosk browser's full request fingerprint (UA + `Accept*` + `Referer`/`Origin`
> + `Sec-Fetch-*`). Disks are cached under the token-less URL, so the rotating
> token never fragments the edge cache. No client changes are needed. El Worker
> firma cada disco automáticamente (token de `/papi/sign` + cabeceras de
> navegador), así que el proxy vuelve a servir discos sin pasos manuales.

> ⚠️ **Proxy reliability / Fiabilidad del proxy.** The official origin restricts
> some regions and data-centre IP ranges. In **proxy mode**, a *cold* cache-miss
> from a blocked Cloudflare PoP (e.g. some US edges) can return **403** until the
> object is cached there. End users are unaffected — the launcher automatically
> falls back to the official origin — but for a globally bulletproof mirror use
> **R2 mode**, which never touches the origin per request. El origen oficial
> restringe ciertas regiones/IPs; en modo proxy un *cold-miss* puede dar 403
> hasta que se cachea. El launcher hace *fallback* automático, así que el usuario
> no se ve afectado; para fiabilidad global total, usa **R2**.

---

## Quick start — Proxy + cache / Inicio rápido

```bash
cd mirror/cloudflare
npm i -g wrangler        # or use npx
wrangler login
wrangler deploy          # deploys the Worker (proxy mode)
```

You get a `*.workers.dev` URL. Point the launcher at it:

```bash
# one-off
PCF_MIRROR="https://pcf-mirror.<account>.workers.dev" ./pcf play pcf5

# or make it the default for everyone: copy the example and commit it
cp data/mirror.example.json data/mirror.json
# edit data/mirror.json → "disks": "https://pcf.example.com"
```

When `data/mirror.json` exists, **every** user downloads from your mirror by
default (env vars still override). That is the single biggest lever to protect
the origin.

---

## What gets cached, and how it stays in sync / Qué se cachea y cómo se sincroniza

The mirror **stores nothing permanently** in proxy mode — it only holds copies
in Cloudflare's edge cache, which Cloudflare fills and evicts for you. The
Worker serves three content classes, each routed to its origin with its own cache
policy so the whole experience (kiosk **and** disks) tracks the upstream while
the origin is barely touched:

| Content | Origin (`wrangler.toml`) | Edge policy | Origin load | Sync |
|---------|--------------------------|-------------|-------------|------|
| **Disk images** `*.bin` | `ORIGIN` (discos) | `immutable`, ~1 year | One pull per object per PoP, ever | N/A — bytes never change |
| **Savestates** `*_state.bin` | `KIOSK_ORIGIN` (online) | 6 h + `stale-while-revalidate` | A few KB per PoP per window | Auto — re-captures picked up within hours |
| **Kiosk / runtime** html·js·wasm·bios·assets | `KIOSK_ORIGIN` (online) | 6 h + `stale-while-revalidate` | A few KB per PoP per window | Auto — new builds picked up within hours |

So you get a **single cache, zero storage** mirror that keeps itself in sync:
disks are pinned forever (they’re content-named, immutable), and the small
front-end is revalidated so upstream fixes propagate without re-hosting
anything. El mirror **no almacena nada**: sólo la caché del edge. Los discos se
fijan para siempre (inmutables) y el kiosko se revalida cada pocas horas, así
todo queda sincronizado con el origen sin re-alojar nada.

> The launcher fetches the kiosk **through the mirror too** (with a fallback to
> the official host), so the origin sees ~one runtime pull per PoP instead of
> one per user.

---

## Custom domain / Dominio propio

A clean hostname caches better and looks trustworthy:

1. Add your zone to Cloudflare (DNS).
2. In `wrangler.toml` uncomment:
   ```toml
   routes = [{ pattern = "pcf.example.com", custom_domain = true }]
   ```
3. `wrangler deploy`.

---

## R2 mirror (zero egress) / Mirror en R2

R2 has **no egress fees** — ideal for a community mirror at scale.

```bash
cd mirror/cloudflare
wrangler r2 bucket create pcf-disks
./sync-to-r2.sh                      # one-time copy from the origin (~15 GB)
# then uncomment [[r2_buckets]] in wrangler.toml and redeploy
wrangler deploy
```

`sync-to-r2.sh` streams each disk from the origin straight into R2 (no big temp
files) and keeps a `.synced` ledger so re-runs skip finished files.

---

## Shared career saves / Partidas compartidas

Optional. Lets players **share a saved career via a short code**. The kiosk gets
a "💾 Partidas" menu (added by `web/pcf-saves.js`, injected by the launcher) to:

- **Export / Import** a tiny `.pcfsave` file locally — fully offline, zero infra.
- **Share to cloud / Download by code** — uploads the `.pcfsave` to your Worker's
  R2 bucket and returns a 10-char code a friend types in to fetch it.

```bash
cd mirror/cloudflare
wrangler r2 bucket create pcf-saves   # the [[r2_buckets]] SAVES binding is preset
wrangler deploy
```

The endpoints live on the same Worker:

| Route | Method | Purpose |
|-------|--------|---------|
| `/papi/save?game=<id>` | `POST` | Upload a `.pcfsave`; returns `{code,bytes,retentionDays}` |
| `/papi/save/<code>` | `GET` | Download the shared save by code |

Hardening (all enforced in `worker.js`): **magic-byte** check (`PCFSAVE1`),
**4 MB** cap, **unguessable** 10-char Crockford-base32 codes (~50 bits),
**90-day** expiry, CORS. The feature is **opt-in**: with no `SAVES` binding the
endpoints return `503 saves-disabled`. Remove the `[[r2_buckets]]` SAVES block
in `wrangler.toml` to turn it off.

Point the launcher at a different share endpoint with `PCF_SAVES_BASE` or a
`saves` key in `data/mirror.json` (defaults to the community Worker).

Both the in-kiosk menu and the **CLI** talk to these endpoints:

```bash
pcf saves share my-career.pcfsave   # POST /papi/save  → prints a code
pcf saves get  ABCDEFGHJK           # GET  /papi/save/<code>
```

> ⚠️ The upload endpoint is **unauthenticated by design** (anyone with the kiosk
> can share). Codes are unguessable and blobs auto-expire, but add a
> **Rate limiting rule** on `/papi/save` if you expose this publicly.

Esta función es **opcional**: comparte una partida guardada con un código corto.
El kiosko muestra un menú "💾 Partidas" para exportar/importar un `.pcfsave`
local (sin nube) o subirlo a R2 y obtener un código de 10 caracteres que un
amigo introduce para descargarlo. Validación estricta (cabecera mágica, límite
de 4 MB, códigos no adivinables, caducidad de 90 días). Sin el binding `SAVES`
los endpoints devuelven 503. Cámbialo con `PCF_SAVES_BASE` o la clave `saves` de
`data/mirror.json`.

---

## Squeeze Cloudflare Pro to the max / Exprimir Cloudflare Pro

Enable these in the dashboard for the mirror zone:

- **Caching → Tiered Cache → Smart Tiered Cache**: fewer origin pulls; PoPs fill
  from a regional upper tier instead of each hitting the origin.
- **Caching → Cache Reserve** *(usage-billed)*: persists large objects for
  months so cold edges don't re-pull from the origin. Perfect for immutable
  disk images.
- **Caching → Cache Rules**: for `*.bin` set *Eligible for cache* +
  *Edge TTL 1 year* + *Respect range requests*. (The Worker already sets this,
  but a rule covers any non-Worker path.)
- **Speed → Argo Smart Routing** *(optional, paid)*: faster origin fetches on
  the rare cache miss.
- **Security → WAF / Rate limiting rules** (Pro includes rules): cap requests
  per IP to stop abusive scrapers without blocking normal downloads.
- **Security → Bot Fight Mode: OFF** on the mirror route — it would block the
  launcher's `curl` downloads.
- **Network → HTTP/3 (QUIC)** and **0-RTT: ON** for faster transfers.
- **Analytics / Workers Logs**: watch the **cache hit ratio** — aim for >95%;
  every hit is a request the origin never sees.

> Polish/Brotli/Mirage don't help here — disk images are already-compressed
> binaries.

---

## Verify / Comprobar

```bash
# CORS + Range present?
curl -sI -H "Range: bytes=0-1023" https://pcf.example.com/PCF5.bin \
  | grep -iE 'http/|content-range|accept-ranges|access-control|x-pcf-mirror|cf-cache-status'
```

Look for `HTTP/2 206`, `Content-Range`, `Access-Control-Allow-Origin: *`, and a
`cf-cache-status: HIT` on the second request.

---

## Files / Ficheros

| File | Purpose |
|------|---------|
| `worker.js` | Proxy+cache and R2 logic (CORS + Range) |
| `wrangler.toml` | Worker config; R2 binding + custom domain (commented) |
| `sync-to-r2.sh` | One-time origin → R2 copy with resume ledger |
| `../../data/mirror.example.json` | Template to make the mirror the default |
