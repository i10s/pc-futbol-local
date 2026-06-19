/**
 * PC Fútbol Local — Cloudflare mirror Worker
 * -------------------------------------------------------------------------
 * Two modes (auto-detected):
 *
 *   1) PROXY + CACHE (default, recommended, lowest footprint)
 *      No R2 binding → the Worker reverse-proxies the official origin and lets
 *      Cloudflare's edge cache absorb repeated downloads. The origin is hit at
 *      most once per object per edge PoP, then served from cache for ~1 year.
 *
 *   2) R2 MIRROR (set the DISKS binding in wrangler.toml)
 *      Serves disk images straight from your R2 bucket (zero egress fees).
 *      Use the sync-to-r2.sh script to populate the bucket once.
 *
 * Both modes add the CORS + Range headers the official host lacks, so the
 * launcher (and even direct in-browser streaming) works from any origin.
 *
 * Storage model: NOTHING is stored permanently in proxy mode — only
 * Cloudflare's edge cache holds copies, and it manages/evicts them. Two content
 * classes get two cache policies so everything stays in sync with the origin
 * while the origin is barely touched:
 *
 *   • Disk images (*.bin)  → IMMUTABLE. Cached ~1 year. The bytes never change
 *                            (named by content), so the origin is pulled at most
 *                            once per object per PoP, forever.
 *   • Kiosk runtime        → REVALIDATED. Cached at the edge for a short window;
 *     (html/js/wasm/...)      after it expires Cloudflare refreshes from origin,
 *                            so upstream updates propagate automatically. Total
 *                            origin load: a few KB per PoP per window.
 */

const YEAR = 60 * 60 * 24 * 365;
const KIOSK_TTL = 60 * 60 * 6; // 6 h edge cache for the (small) front-end

// A bare disk-image filename, e.g. "PCF5.bin". No slashes → not a kiosk asset.
const DISK_RE = /^[A-Za-z0-9._-]+\.bin$/;
// Savestate blobs (e.g. "pcf5_state.bin") also end in .bin, but they live on the
// runtime/online origin — NOT the disk host — and may be re-captured upstream.
// Matched before DISK_RE so they are routed (and cached) correctly.
const STATE_RE = /^[A-Za-z0-9._-]+_state\.bin$/;
// The known, safe front-end paths. Keeps the Worker from being an open relay.
// (The /papi backend is intentionally NOT proxied — the launcher stubs it
// locally so the kiosk runs fully offline.)
const KIOSK_RE = /^(index\.html|kiosk\.html|games\.js|libv86\.js|v86\.wasm|favicon\.ico)$|^(bios|assets)\/[A-Za-z0-9][A-Za-z0-9._/-]*$/;

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return withCORS(new Response(null, { status: 204 }));
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return withCORS(new Response("Method Not Allowed", { status: 405 }));
    }

    const url = new URL(request.url);
    const path = decodeURIComponent(url.pathname).replace(/^\/+/, "");

    // Health/info endpoint.
    if (path === "" || path === "_health") {
      return withCORS(json({ ok: true, mode: env.DISKS ? "r2" : "proxy" }));
    }

    // Reject path traversal and absolute/UNC trickery.
    if (path.includes("..") || path.includes("\\") || path.startsWith("/")) {
      return withCORS(new Response("Not found", { status: 404 }));
    }

    // 1) Savestates — small, live on the runtime origin (never in R2), and may
    //    be re-captured upstream → proxy from the kiosk origin with revalidation.
    //    Checked before DISK_RE because "*_state.bin" also matches a disk name.
    if (STATE_RE.test(path)) {
      const origin = env.KIOSK_ORIGIN || "https://online.dinamicmultimedia.es";
      return serveProxied(origin, path, request, { ttl: KIOSK_TTL, immutable: false, tag: "state" });
    }

    // 2) Disk images — immutable, served from R2 if bound, else proxied.
    if (DISK_RE.test(path)) {
      const origin = env.ORIGIN || "https://discos.dinamicmultimedia.es";
      return env.DISKS
        ? serveFromR2(env.DISKS, path, request)
        : serveProxied(origin, path, request, { ttl: YEAR, immutable: true, tag: "disk" });
    }

    // 3) Kiosk runtime — allow-listed, revalidated so it tracks the origin.
    if (KIOSK_RE.test(path)) {
      const origin = env.KIOSK_ORIGIN || "https://online.dinamicmultimedia.es";
      return serveProxied(origin, path, request, { ttl: KIOSK_TTL, immutable: false, tag: "kiosk" });
    }

    // Anything else: refuse, so we never relay arbitrary origin paths.
    return withCORS(new Response("Forbidden", { status: 403 }));
  },
};

/* --------------------------------------------------------------------- */
/* Proxy + cache: reverse-proxy an official origin, cached at the edge.   */
/* `opts.immutable` picks the cache policy (disk vs. kiosk).              */
/* --------------------------------------------------------------------- */
async function serveProxied(origin, path, request, opts) {
  const target = `${origin.replace(/\/+$/, "")}/${path}`;

  // Forward only the Range header so Cloudflare can return 206 from cache.
  const headers = new Headers();
  const range = request.headers.get("Range");
  if (range) headers.set("Range", range);

  const resp = await fetch(target, {
    method: request.method,
    headers,
    // cacheEverything lets Cloudflare cache regardless of the origin's headers.
    cf: { cacheEverything: true, cacheTtl: opts.ttl },
  });

  const out = new Response(resp.body, resp);
  out.headers.set("Accept-Ranges", "bytes");
  out.headers.set("X-PCF-Mirror", opts.tag);
  if (opts.immutable) {
    // Disk images never change → cache hard, forever.
    out.headers.set("Cache-Control", `public, max-age=${YEAR}, immutable`);
  } else {
    // Front-end may change upstream → short cache + background revalidation so
    // clients and edges pick up new builds without hammering the origin.
    out.headers.set("Cache-Control", `public, max-age=${opts.ttl}, stale-while-revalidate=86400`);
  }
  return withCORS(out);
}

/* --------------------------------------------------------------------- */
/* Mode 2: serve disk images directly from an R2 bucket.                  */
/* --------------------------------------------------------------------- */
async function serveFromR2(bucket, path, request) {
  if (request.method === "HEAD") {
    const head = await bucket.head(path);
    if (!head) return withCORS(new Response("Not found", { status: 404 }));
    const h = baseHeaders(head);
    h.set("Content-Length", String(head.size));
    return withCORS(new Response(null, { status: 200, headers: h }));
  }

  const range = parseRange(request.headers.get("Range"));
  const obj = await bucket.get(path, range ? { range } : undefined);
  if (!obj) return withCORS(new Response("Not found", { status: 404 }));

  const h = baseHeaders(obj);
  if (range && obj.range) {
    const start = obj.range.offset ?? 0;
    const len = obj.range.length ?? obj.size - start;
    h.set("Content-Range", `bytes ${start}-${start + len - 1}/${obj.size}`);
    h.set("Content-Length", String(len));
    return withCORS(new Response(obj.body, { status: 206, headers: h }));
  }
  h.set("Content-Length", String(obj.size));
  return withCORS(new Response(obj.body, { status: 200, headers: h }));
}

function baseHeaders(obj) {
  const h = new Headers();
  if (obj.writeHttpMetadata) obj.writeHttpMetadata(h);
  if (!h.has("Content-Type")) h.set("Content-Type", "application/octet-stream");
  h.set("Accept-Ranges", "bytes");
  h.set("Cache-Control", `public, max-age=${YEAR}, immutable`);
  h.set("X-PCF-Mirror", "r2");
  if (obj.httpEtag) h.set("ETag", obj.httpEtag);
  return h;
}

// Parse a single-range "bytes=start-end" / "bytes=start-" / "bytes=-suffix".
function parseRange(header) {
  if (!header) return null;
  const m = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!m) return null;
  const [, s, e] = m;
  if (s === "" && e === "") return null;
  if (s === "") return { suffix: Number(e) };
  if (e === "") return { offset: Number(s) };
  return { offset: Number(s), length: Number(e) - Number(s) + 1 };
}

/* --------------------------------------------------------------------- */
/* Helpers                                                               */
/* --------------------------------------------------------------------- */
function withCORS(resp) {
  resp.headers.set("Access-Control-Allow-Origin", "*");
  resp.headers.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
  resp.headers.set("Access-Control-Allow-Headers", "Range, Content-Type");
  resp.headers.set("Access-Control-Expose-Headers", "Accept-Ranges, Content-Range, Content-Length, ETag");
  resp.headers.set("Access-Control-Max-Age", "86400");
  return resp;
}

function json(obj) {
  return new Response(JSON.stringify(obj), {
    headers: { "Content-Type": "application/json" },
  });
}
