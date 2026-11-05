import type { Metadata } from "next";
import "./globals.css";
import { ThemeProvider } from "@/contexts";
import { AnalyticsBoot } from "@/components/analytics/AnalyticsBoot";
import { CHUNK_ERROR, RELOAD_GUARD_KEY, RELOAD_GUARD_MS, RELOAD_MARK } from "@/lib/boot/chunkReload";

export const metadata: Metadata = {
  title: "Stategraph Console",
  description: "Terraform/OpenTofu state management console",
  icons: {
    icon: [
      { url: "/favicon.svg", type: "image/svg+xml" },
      { url: "/favicon.png", type: "image/png", sizes: "64x64" },
    ],
    apple: "/apple-touch-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  const stored = localStorage.getItem('stategraph-theme');
                  const theme = stored && ['light', 'dark', 'system'].includes(stored) ? stored : 'system';

                  if (theme === 'dark') {
                    document.documentElement.classList.add('dark');
                  } else if (theme === 'light') {
                    document.documentElement.classList.remove('dark');
                  } else {
                    // System preference
                    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                    if (systemDark) {
                      document.documentElement.classList.add('dark');
                    }
                  }
                } catch (e) {}
              })();
            `,
          }}
        />
        <script
          // Boot watchdog. A page whose HTML was cached before this app served
          // Cache-Control headers still references build chunks that no longer
          // exist; those 404, no script runs, and the page is blank. A plain
          // location.reload() re-serves that same cached HTML and fails
          // identically, which is why the old page only recovered on a
          // force-reload. Recovery therefore reloads through a one-shot
          // cache-busting URL, and if even that fails the page states so
          // instead of staying blank.
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                var MARK = ${JSON.stringify(RELOAD_MARK)};
                var GUARD = ${JSON.stringify(RELOAD_GUARD_KEY)};
                var CHUNK_ERROR = ${CHUNK_ERROR};
                var busted = new URLSearchParams(location.search).has(MARK);
                var done = false;

                function fallback() {
                  // Next's bootstrap sets window.next once its runtime chunk
                  // has run. From then on the app owns the page (and the root
                  // error boundary owns its failures), so never wipe what it
                  // rendered or the state it holds.
                  if (!document.body || window.next) return;
                  document.body.innerHTML =
                    '<div style="font:14px system-ui,sans-serif;display:flex;flex-direction:column;' +
                    'align-items:center;justify-content:center;min-height:100vh;gap:12px">' +
                    '<div>The console could not finish loading.</div>' +
                    '<button id="sg-retry" style="padding:6px 14px;border-radius:6px;cursor:pointer">Retry</button></div>';
                  var b = document.getElementById('sg-retry');
                  if (b) b.onclick = function() { location.reload(); };
                }

                function recover() {
                  if (done) return;
                  done = true;
                  // Already came back on a cache-busted URL and still broke:
                  // reloading again would loop, so say so instead.
                  if (busted) { fallback(); return; }
                  // The marker is stripped once a retry boots, so it cannot stop a
                  // later failure from busting again; a short time window can.
                  // No storage means no guard, so do not auto-reload then.
                  try {
                    var last = Number(sessionStorage.getItem(GUARD) || 0);
                    if (Date.now() - last < ${RELOAD_GUARD_MS}) { fallback(); return; }
                    sessionStorage.setItem(GUARD, String(Date.now()));
                  } catch (e) { fallback(); return; }
                  var u = new URL(location.href);
                  u.searchParams.set(MARK, String(Date.now()));
                  location.replace(u.toString());
                }

                window.addEventListener('error', function(ev) {
                  var t = ev.target;
                  if (t && t.tagName === 'SCRIPT' && t.src && t.src.indexOf('/_next/') !== -1) { recover(); return; }
                  if (ev.message && CHUNK_ERROR.test(ev.message)) { recover(); return; }
                  // A chunk answered with HTML fails to parse; only a syntax
                  // error raised by one of our chunks means that, not one from
                  // a handler's JSON.parse or a third-party script.
                  if (ev.message && /Unexpected token/.test(ev.message) && ev.filename && ev.filename.indexOf('/_next/') !== -1) recover();
                }, true);

                window.addEventListener('unhandledrejection', function(ev) {
                  var r = ev.reason || {};
                  var m = (r.name || '') + ' ' + (r.message || '');
                  if (CHUNK_ERROR.test(m)) recover();
                });

                if (busted) {
                  // Booted fine on the retry: drop the marker so the URL stays
                  // shareable, and make sure the app actually started.
                  window.addEventListener('load', function() {
                    try {
                      var u = new URL(location.href);
                      u.searchParams.delete(MARK);
                      history.replaceState(null, '', u.pathname + u.search + u.hash);
                    } catch (e) {}
                    // The body always carries Next's inline payload scripts, so
                    // its text is never empty; whether the runtime started is
                    // the signal, and fallback() checks exactly that.
                    setTimeout(fallback, 4000);
                  });
                }
              })();
            `,
          }}
        />
      </head>
      <body className="antialiased" suppressHydrationWarning>
        <AnalyticsBoot />
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
