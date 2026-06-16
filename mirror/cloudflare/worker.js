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
 */

const YEAR = 60 * 60 * 24 * 365;

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

    return env.DISKS
      ? serveFromR2(env.DISKS, path, request)
      : serveFromOrigin(env, path, request);
  },
};

/* --------------------------------------------------------------------- */
/* Mode 1: reverse-proxy the official origin, cached at the edge.         */
/* --------------------------------------------------------------------- */
async function serveFromOrigin(env, path, request) {
  const origin = (env.ORIGIN || "https://discos.dinamicmultimedia.es").replace(/\/+$/, "");
  const target = `${origin}/${path}`;

  // Forward only the Range header so Cloudflare can return 206 from cache.
  const headers = new Headers();
  const range = request.headers.get("Range");
  if (range) headers.set("Range", range);

  const resp = await fetch(target, {
    method: request.method,
    headers,
    // cacheEverything makes Cloudflare cache the (large, immutable) disk image
    // regardless of the origin's Cache-Control; range requests are served from
    // that cached object without re-hitting the origin.
    cf: { cacheEverything: true, cacheTtl: YEAR },
  });

  const out = new Response(resp.body, resp);
  out.headers.set("Accept-Ranges", "bytes");
  out.headers.set("Cache-Control", `public, max-age=${YEAR}, immutable`);
  out.headers.set("X-PCF-Mirror", "proxy");
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
