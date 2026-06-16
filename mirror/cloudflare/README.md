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
