/*
 * pc-futbol-local — shareable career saves
 * -------------------------------------------------------------------------
 * Companion script injected into the mirrored kiosk. It reuses the origin's
 * OWN save schema — IndexedDB database "pcf7_saves", object store "saves",
 * key "sv_<id>[_<mod>]", value { nums:[blocks], data:Uint8Array } — so a saved
 * career (la partida) can be:
 *
 *   • exported to / imported from a portable ".pcfsave" file (100% offline), and
 *   • shared via the community Cloudflare mirror: upload -> short code -> a
 *     friend pastes the code to download + import it.
 *
 * It only ever touches the player's own (tiny) save blocks — no game data and
 * no personal data leave the browser beyond the save the user chooses to share.
 */
(function () {
  "use strict";
  if (window.__pcfSaves) { return; }
  window.__pcfSaves = true;

  var DB = "pcf7_saves", STORE = "saves";
  var MAGIC = "PCFSAVE1", BLOCK = 256, MAX = 4 * 1024 * 1024;
  var CODE_RE = /^[0-9A-HJKMNP-TV-Z]{10}$/; // Crockford base32 (no I/L/O/U)

  var qs = new URLSearchParams(location.search);
  var id = qs.get("game") || "pcf7";
  var modId = qs.get("mod");
  var SAVE_KEY = "sv_" + id + (modId ? "_" + modId : "");
  var savesBase = null; // resolved from /papi/saves.json (community mirror)

  /* ---- IndexedDB (identical schema to the kiosk) ---- */
  function idbOpen() {
    return new Promise(function (res, rej) {
      var r = indexedDB.open(DB, 1);
      r.onupgradeneeded = function () { try { r.result.createObjectStore(STORE); } catch (e) { /* exists */ } };
      r.onsuccess = function () { res(r.result); };
      r.onerror = function () { rej(r.error); };
    });
  }
  function idbGet(k) {
    return idbOpen().then(function (db) {
      return new Promise(function (res) {
        var t = db.transaction(STORE, "readonly").objectStore(STORE).get(k);
        t.onsuccess = function () { res(t.result); };
        t.onerror = function () { res(null); };
      });
    });
  }
  function idbPut(k, v) {
    return idbOpen().then(function (db) {
      return new Promise(function (res, rej) {
        var t = db.transaction(STORE, "readwrite").objectStore(STORE).put(v, k);
        t.onsuccess = function () { res(true); };
        t.onerror = function () { rej(t.error); };
      });
    });
  }

  function toU8(d) {
    if (d instanceof Uint8Array) { return d; }
    if (d instanceof ArrayBuffer) { return new Uint8Array(d); }
    if (d && d.buffer) { return new Uint8Array(d.buffer, d.byteOffset, d.byteLength); }
    return new Uint8Array(0);
  }

  /* ---- .pcfsave container: self-describing, dependency-free ----
   * [ "PCFSAVE1" (8B) | headerLen u32 | header JSON | nums u32[] | data ] */
  function pack(rec, meta) {
    var nums = rec.nums || [], data = toU8(rec.data), i;
    var hb = new TextEncoder().encode(JSON.stringify(meta));
    var out = new Uint8Array(8 + 4 + hb.length + nums.length * 4 + data.length);
    var dv = new DataView(out.buffer);
    var off = 0;
    for (i = 0; i < 8; i++) { out[off++] = MAGIC.charCodeAt(i); }
    dv.setUint32(off, hb.length, true); off += 4;
    out.set(hb, off); off += hb.length;
    for (i = 0; i < nums.length; i++) { dv.setUint32(off, nums[i] >>> 0, true); off += 4; }
    out.set(data, off);
    return out;
  }
  function unpack(buf) {
    var u8 = new Uint8Array(buf), i;
    if (u8.length < 12) { throw new Error("archivo demasiado pequeño"); }
    for (i = 0; i < 8; i++) { if (u8[i] !== MAGIC.charCodeAt(i)) { throw new Error("no es un .pcfsave válido"); } }
    var dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
    var off = 8;
    var hlen = dv.getUint32(off, true); off += 4;
    var meta = JSON.parse(new TextDecoder().decode(u8.subarray(off, off + hlen))); off += hlen;
    var count = meta.count >>> 0, nums = new Array(count);
    for (i = 0; i < count; i++) { nums[i] = dv.getUint32(off, true) >>> 0; off += 4; }
    var data = u8.slice(off, off + count * BLOCK);
    if (data.length !== count * BLOCK) { throw new Error("datos truncados"); }
    return { meta: meta, rec: { nums: nums, data: data } };
  }

  function metaFor(rec) {
    return { schema: 1, app: "pc-futbol-local", game: id, mod: modId || null,
             key: SAVE_KEY, count: (rec.nums || []).length, block: BLOCK,
             created: new Date().toISOString() };
  }
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function fileName() {
    var d = new Date();
    var s = "" + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + pad(d.getHours()) + pad(d.getMinutes());
    return id + (modId ? "-" + modId : "") + "-" + s + ".pcfsave";
  }
  function currentRec() {
    return idbGet(SAVE_KEY).then(function (rec) {
      if (!rec || !rec.nums || !rec.nums.length) { return null; }
      return rec;
    });
  }

  /* ---- local export / import ---- */
  function exportLocal() {
    return currentRec().then(function (rec) {
      if (!rec) { note("Aún no hay partida guardada para exportar. Juega y guarda primero (deja marcada «Guardar partidas en local»).", true); return; }
      var blob = new Blob([pack(rec, metaFor(rec))], { type: "application/octet-stream" });
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = fileName();
      document.body.appendChild(a); a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1500);
      note("Partida exportada: " + a.download);
    });
  }
  function importBuffer(buf) {
    var p;
    try { p = unpack(buf); } catch (e) { note("No se pudo leer el archivo: " + e.message, true); return; }
    var key = p.meta.key || ("sv_" + p.meta.game + (p.meta.mod ? "_" + p.meta.mod : ""));
    var same = key === SAVE_KEY;
    var who = p.meta.game + (p.meta.mod ? " · mod " + p.meta.mod : "");
    var msg = same
      ? "Importar esta partida sobrescribirá la actual de «" + who + "». ¿Continuar?"
      : "Esta partida es de «" + who + "» (no el juego abierto). Se guardará en su hueco. ¿Continuar?";
    if (!confirm(msg)) { return; }
    idbPut(key, p.rec).then(function () {
      if (same) {
        if (confirm("Partida importada ✓\n¿Recargar para jugarla ahora?")) { location.reload(); }
      } else {
        var u = "/kiosk.html?game=" + encodeURIComponent(p.meta.game) + (p.meta.mod ? "&mod=" + encodeURIComponent(p.meta.mod) : "");
        if (confirm("Partida importada ✓\n¿Abrir «" + who + "» ahora?")) { location.href = u; }
      }
    }).catch(function (e) { note("No se pudo guardar la partida: " + e, true); });
  }
  function importLocal() {
    var inp = document.createElement("input");
    inp.type = "file"; inp.accept = ".pcfsave";
    inp.onchange = function () {
      var f = inp.files && inp.files[0];
      if (!f) { return; }
      var fr = new FileReader();
      fr.onload = function () { importBuffer(fr.result); };
      fr.readAsArrayBuffer(f);
    };
    inp.click();
  }

  /* ---- cloud share (upload) / download by code ---- */
  function shareCloud() {
    if (!savesBase) { note("Compartir en la nube no está disponible (sin mirror configurado).", true); return; }
    currentRec().then(function (rec) {
      if (!rec) { note("Aún no hay partida guardada para compartir.", true); return; }
      var body = pack(rec, metaFor(rec));
      if (body.length > MAX) { note("La partida es demasiado grande para compartir.", true); return; }
      note("Subiendo…");
      fetch(savesBase + "/papi/save?game=" + encodeURIComponent(id), {
        method: "POST",
        headers: { "Content-Type": "application/octet-stream", "X-PCF-Save": "1" },
        body: body
      }).then(function (r) {
        return r.json().catch(function () { return null; }).then(function (j) { return { ok: r.ok, j: j }; });
      }).then(function (x) {
        if (!x.ok || !x.j || !x.j.code) { note("No se pudo subir la partida (" + ((x.j && x.j.error) || "error") + ").", true); return; }
        showCode(x.j.code);
      }).catch(function () { note("Error de red al subir la partida.", true); });
    });
  }
  function downloadCloud() {
    if (!savesBase) { note("Descargar de la nube no está disponible (sin mirror configurado).", true); return; }
    var code = (prompt("Introduce el código de la partida a descargar:") || "").trim().toUpperCase();
    if (!code) { return; }
    if (!CODE_RE.test(code)) { note("Código no válido.", true); return; }
    note("Descargando…");
    fetch(savesBase + "/papi/save/" + code).then(function (r) {
      if (!r.ok) { throw new Error(r.status === 404 ? "código no encontrado o caducado" : ("HTTP " + r.status)); }
      return r.arrayBuffer();
    }).then(function (buf) { importBuffer(buf); })
      .catch(function (e) { note("No se pudo descargar: " + e.message, true); });
  }

  /* ---- UI: a small popover anchored in the kiosk control bar ---- */
  var panel = null, noteEl = null, cloudItems = [];
  function mkItem(label, fn) {
    var b = document.createElement("button");
    b.type = "button"; b.textContent = label;
    b.style.cssText = "text-align:left;background:none;border:0;color:#1c2330;font:14px system-ui;padding:8px 10px;border-radius:6px;cursor:pointer;white-space:nowrap";
    b.onmouseenter = function () { b.style.background = "#0000000d"; };
    b.onmouseleave = function () { b.style.background = "none"; };
    b.onclick = function () { fn(); };
    return b;
  }
  function note(msg, warn) {
    if (!noteEl) { alert(msg); return; }
    noteEl.style.display = msg ? "block" : "none";
    noteEl.style.color = warn ? "#b42318" : "#667085";
    noteEl.textContent = msg;
  }
  function showCode(code) {
    if (!noteEl) { prompt("Código para compartir (cópialo):", code); return; }
    noteEl.style.display = "block"; noteEl.style.color = "#1c2330"; noteEl.textContent = "";
    var t = document.createElement("div"); t.textContent = "Código para compartir:"; noteEl.appendChild(t);
    var row = document.createElement("div"); row.style.cssText = "display:flex;gap:6px;align-items:center;margin-top:4px";
    var c = document.createElement("code"); c.textContent = code;
    c.style.cssText = "font:bold 15px ui-monospace,monospace;background:#f1f5f9;padding:4px 8px;border-radius:6px;letter-spacing:1px";
    var copy = document.createElement("button"); copy.type = "button"; copy.textContent = "Copiar";
    copy.style.cssText = "font:12px system-ui;cursor:pointer;border:1px solid #cbd5e1;background:#fff;border-radius:6px;padding:4px 8px";
    copy.onclick = function () { try { navigator.clipboard.writeText(code); copy.textContent = "¡Copiado!"; setTimeout(function () { copy.textContent = "Copiar"; }, 1200); } catch (e) { /* ignore */ } };
    row.appendChild(c); row.appendChild(copy); noteEl.appendChild(row);
    var hint = document.createElement("div");
    hint.textContent = "Tu amigo lo pega en «Descargar con código». Caduca a los 90 días.";
    hint.style.cssText = "color:#667085;margin-top:4px"; noteEl.appendChild(hint);
  }
  function refreshCloud() {
    var on = !!savesBase;
    cloudItems.forEach(function (b) {
      b.style.opacity = on ? "1" : ".5";
      b.title = on ? "" : "Sin mirror configurado para partidas en la nube";
    });
  }
  function injectUI() {
    var ctrls = document.querySelector(".ctrls");
    if (!ctrls || document.getElementById("pcf-saves-btn")) { return; }
    var wrap = document.createElement("div"); wrap.style.cssText = "position:relative;display:inline-flex";
    var btn = document.createElement("button");
    btn.id = "pcf-saves-btn"; btn.type = "button"; btn.textContent = "💾 Partidas";
    btn.title = "Exportar, importar o compartir tu partida";

    panel = document.createElement("div");
    panel.style.cssText = "position:absolute;bottom:120%;left:50%;transform:translateX(-50%);min-width:230px;background:#fff;border:1px solid #d4d8e0;border-radius:10px;box-shadow:0 8px 30px #0003;padding:8px;display:none;z-index:9999;flex-direction:column;gap:2px";
    panel.appendChild(mkItem("⬆️  Exportar a archivo", exportLocal));
    panel.appendChild(mkItem("⬇️  Importar de archivo", importLocal));
    var sep = document.createElement("div"); sep.style.cssText = "height:1px;background:#eceef2;margin:4px 0"; panel.appendChild(sep);
    var share = mkItem("☁️  Compartir (obtener código)", shareCloud);
    var down = mkItem("📥  Descargar con código", downloadCloud);
    cloudItems = [share, down];
    panel.appendChild(share); panel.appendChild(down);
    noteEl = document.createElement("div");
    noteEl.style.cssText = "font:12px system-ui;color:#667085;padding:6px 8px 2px;display:none;max-width:250px";
    panel.appendChild(noteEl);

    btn.onclick = function (e) {
      e.stopPropagation();
      var open = panel.style.display !== "flex";
      panel.style.display = open ? "flex" : "none";
      if (open) { note(""); refreshCloud(); }
    };
    document.addEventListener("click", function (ev) { if (panel && !wrap.contains(ev.target)) { panel.style.display = "none"; } });

    wrap.appendChild(btn); wrap.appendChild(panel);
    var fs = document.getElementById("fs");
    if (fs && fs.parentNode === ctrls) { ctrls.insertBefore(wrap, fs); } else { ctrls.appendChild(wrap); }
  }

  /* ---- boot: resolve the saves base, then render ---- */
  fetch("/papi/saves.json").then(function (r) { return r.ok ? r.json() : null; })
    .then(function (c) { if (c && c.base) { savesBase = String(c.base).replace(/\/+$/, ""); } })
    .catch(function () { /* offline / not configured */ })
    .then(function () {
      if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", injectUI); }
      else { injectUI(); }
    });
})();
