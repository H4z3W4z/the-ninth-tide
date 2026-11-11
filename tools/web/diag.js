// Load diagnostics for the web build (injected into index.html by tools/web/deploy.sh):
// reports errors, and the loader's progress if the engine has not started after 20 s,
// to the home server's log (POST /api/clientlog). LAN only; nothing personal is sent.
(function () {
  var t0 = Date.now(), started = false;
  function send(kind, msg) {
    try {
      var body = JSON.stringify({ kind: kind, msg: String(msg).slice(0, 1500), t: Date.now() - t0,
        mem: (navigator.deviceMemory || null), gl2: !!document.createElement("canvas").getContext("webgl2"),
        sab: typeof SharedArrayBuffer !== "undefined", secure: window.isSecureContext });
      navigator.sendBeacon ? navigator.sendBeacon("/api/clientlog", body)
        : fetch("/api/clientlog", { method: "POST", body: body, keepalive: true });
    } catch (e) {}
  }
  window.addEventListener("error", function (e) { send("error", (e.message || e) + " @" + (e.filename || "") + ":" + (e.lineno || "")); });
  window.addEventListener("unhandledrejection", function (e) { send("rejection", e.reason && (e.reason.stack || e.reason.message) || e.reason); });
  var origLog = console.error;
  console.error = function () { send("console", Array.prototype.join.call(arguments, " ")); return origLog.apply(console, arguments); };
  send("boot", navigator.userAgent);
  [20000, 60000].forEach(function (ms) {
    setTimeout(function () {
      var st = document.getElementById("status");
      var stuck = st && getComputedStyle(st).display !== "none";
      var notice = document.getElementById("status-notice");
      var bar = document.getElementById("status-progress");
      if (stuck) send("stalled", "after " + ms / 1000 + "s; progress=" + (bar ? bar.value + "/" + bar.max : "?") +
        "; notice=" + (notice ? notice.innerText : "") + "; status=" + st.innerText.slice(0, 300));
      else if (!started) { started = true; send("started", "engine up by " + ms / 1000 + "s"); }
    }, ms);
  });
})();
