const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const outDir = "/tmp/suiflow-video";
const shotDir = "/tmp/suiflow-video-shots";
const target = "/home/legat/work/hackaton/Sui-Overflow-2026/assets/suiflow-demo.webm";

const links = {
  repo: "https://github.com/aydarkhusaenov/suiflow-agentic-work-graph",
  app: "https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/",
  package:
    "https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet",
  publish:
    "https://suiexplorer.com/txblock/3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn?network=testnet",
  workOrder:
    "https://suiexplorer.com/object/0x5ae3b9662947ba0f2a8493858d724c4bdf3cd64190fb9022c24b057c1d90876a?network=testnet",
  finalTx:
    "https://suiexplorer.com/txblock/F5iPLTz3tH3j26YuQg9GqiLZLTyYL4tRdQnmSLEVoKe3?network=testnet",
  onchain:
    "https://github.com/aydarkhusaenov/suiflow-agentic-work-graph/blob/main/docs/ONCHAIN.md"
};

const ids = {
  package: "0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d",
  publish: "3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn",
  workOrder: "0x5ae3b9662947ba0f2a8493858d724c4bdf3cd64190fb9022c24b057c1d90876a",
  finalTx: "F5iPLTz3tH3j26YuQg9GqiLZLTyYL4tRdQnmSLEVoKe3"
};

const txs = [
  "E4NspSFu7JktrDFoz3WuGW1218st3Ehw99EjDV1NLWJb",
  "EZV4bbXM9bZPNgYJF1mEH3gorMvVPqBCaAQw2mcyuMTv",
  "5m1SUijSep6pMRyJ44KyJqyxvL6e549RRyHZaAbDYjbP",
  "5LtasfCqMKLFArid9g7Vr4CojEMsTupUAUhc6ab27vtH",
  "99PDhvNKrmH3CVYTAztafqdWwNrvERovrwwZDfbEcYne",
  "5nQnw1YguFC5WuVE6PkPgEzoKr9V2hYAMEFmakTGLfZg",
  "8f3oC9gNwsTXzuuujnuXwkYgKKwhVZKo73dpZfEybtJn",
  "8tWpyk9H2z3w1BRkwB2mab7nPX4zKctwxNTjNChq4v4Z",
  "ED8JSH5t12LXESyEh7WAvUts6cExjmoWL2nr5Y9dtCKf",
  "GxugZzfoAkCrTmwFKcW1493s8i6Wn285HYQgos1aGH6e",
  "F5iPLTz3tH3j26YuQg9GqiLZLTyYL4tRdQnmSLEVoKe3"
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function fileAsDataUri(file) {
  if (!fs.existsSync(file) || fs.statSync(file).size === 0) return "";
  return `data:image/png;base64,${fs.readFileSync(file).toString("base64")}`;
}

function esc(text) {
  return String(text).replace(/[&<>"']/g, (ch) => {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[ch];
  });
}

async function quickShot(browser, url, file) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 12000 }).catch(() => {});
    await sleep(2500);
    await page.screenshot({ path: file, fullPage: false, timeout: 10000 }).catch(() => {});
  } finally {
    await page.close().catch(() => {});
  }
}

function baseHtml() {
  return `
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <style>
          :root {
            color-scheme: dark;
            --bg: #071019;
            --panel: #0f1e2c;
            --ink: #f6fbff;
            --muted: #a9bacb;
            --line: rgba(255,255,255,0.14);
            --accent: #34d399;
            --blue: #60a5fa;
            --warn: #fbbf24;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            width: 1280px;
            height: 720px;
            overflow: hidden;
            background:
              radial-gradient(circle at 14% 12%, rgba(52,211,153,0.16), transparent 26%),
              radial-gradient(circle at 88% 10%, rgba(96,165,250,0.18), transparent 24%),
              linear-gradient(135deg, #06101a, #0b1723 58%, #09131f);
            color: var(--ink);
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif;
            letter-spacing: 0;
          }
          .slide {
            width: 1280px;
            height: 720px;
            padding: 46px 54px;
            display: grid;
            grid-template-columns: 1.05fr 0.95fr;
            gap: 34px;
            align-items: stretch;
          }
          .slide.single { grid-template-columns: 1fr; }
          .kicker {
            color: var(--accent);
            font-size: 18px;
            font-weight: 800;
            text-transform: uppercase;
            margin-bottom: 14px;
          }
          h1 {
            font-size: 52px;
            line-height: 1.04;
            margin: 0 0 18px;
          }
          h2 {
            font-size: 36px;
            line-height: 1.1;
            margin: 0 0 18px;
          }
          p {
            font-size: 22px;
            line-height: 1.45;
            color: var(--muted);
            margin: 0 0 18px;
          }
          .panel {
            background: rgba(15,30,44,0.86);
            border: 1px solid var(--line);
            border-radius: 12px;
            padding: 22px;
            box-shadow: 0 20px 70px rgba(0,0,0,0.34);
          }
          .mono {
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: 18px;
            line-height: 1.45;
            overflow-wrap: anywhere;
            color: #d8f7ff;
          }
          .list {
            display: grid;
            gap: 12px;
            margin-top: 20px;
          }
          .item {
            border: 1px solid var(--line);
            background: rgba(255,255,255,0.045);
            border-radius: 10px;
            padding: 13px 15px;
            font-size: 20px;
            line-height: 1.25;
          }
          .item strong { color: var(--ink); }
          .muted { color: var(--muted); }
          .ok { color: var(--accent); font-weight: 800; }
          .warn { color: var(--warn); font-weight: 800; }
          .grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
          .shot {
            width: 100%;
            height: 100%;
            object-fit: cover;
            object-position: top left;
            border-radius: 10px;
            border: 1px solid var(--line);
            background: #08111c;
          }
          .footer {
            position: absolute;
            left: 54px;
            right: 54px;
            bottom: 24px;
            display: flex;
            justify-content: space-between;
            color: #8ea5b8;
            font-size: 15px;
          }
          .badge {
            display: inline-block;
            padding: 7px 10px;
            border: 1px solid rgba(52,211,153,0.35);
            color: #b8f7dc;
            background: rgba(52,211,153,0.08);
            border-radius: 999px;
            font-weight: 800;
            margin-right: 8px;
            margin-bottom: 8px;
          }
          .txgrid {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 9px;
          }
          .tx {
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: 15px;
            color: #cfe8ff;
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.11);
            border-radius: 8px;
            padding: 9px;
            overflow-wrap: anywhere;
          }
        </style>
      </head>
      <body><div id="root"></div></body>
    </html>
  `;
}

async function setSlide(page, html, ms) {
  await page.evaluate((content) => {
    document.getElementById("root").innerHTML = content;
  }, html);
  await sleep(ms);
}

(async () => {
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.rmSync(shotDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(shotDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  await quickShot(browser, links.app, path.join(shotDir, "app.png"));
  await quickShot(browser, links.package, path.join(shotDir, "package.png"));
  await quickShot(browser, links.onchain, path.join(shotDir, "onchain.png"));

  const shots = {
    app: fileAsDataUri(path.join(shotDir, "app.png")),
    package: fileAsDataUri(path.join(shotDir, "package.png")),
    onchain: fileAsDataUri(path.join(shotDir, "onchain.png"))
  };

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    recordVideo: { dir: outDir, size: { width: 1280, height: 720 } }
  });
  const page = await context.newPage();
  await page.setContent(baseHtml(), { waitUntil: "load" });

  await setSlide(
    page,
    `
      <section class="slide">
        <div>
          <div class="kicker">Sui Overflow 2026 - Agentic Web</div>
          <h1>SuiFlow Agentic Work Graph</h1>
          <p>Object-capability settlement for autonomous agents on Sui.</p>
          <div class="list">
            <div class="item"><strong>Live frontend:</strong><br><span class="mono">${esc(links.app)}</span></div>
            <div class="item"><strong>Public repo:</strong><br><span class="mono">${esc(links.repo)}</span></div>
            <div class="item"><strong>Testnet package:</strong><br><span class="mono">${ids.package}</span></div>
          </div>
        </div>
        <div class="panel">${shots.app ? `<img class="shot" src="${shots.app}">` : `<h2>Live frontend ready</h2><p>${esc(links.app)}</p>`}</div>
        <div class="footer"><span>Live package + frontend + repo</span><span>Video generated from submitted project data</span></div>
      </section>
    `,
    8500
  );

  await setSlide(
    page,
    `
      <section class="slide single">
        <div>
          <div class="kicker">What was built</div>
          <h2>Least-authority commerce for agentic work</h2>
          <div class="grid2">
            <div class="item"><strong>Shared WorkOrders</strong><br><span class="muted">Escrow, bonds, evidence, release state, receipts.</span></div>
            <div class="item"><strong>Owned AgentPolicies</strong><br><span class="muted">One-order, one-action, expiry, usage, settlement cap.</span></div>
            <div class="item"><strong>Recursive Work Graph</strong><br><span class="muted">Child orders inherit root, depth, budget, safety constraints.</span></div>
            <div class="item"><strong>GenerationRegistry</strong><br><span class="muted">Subtree, branch, and fleet revocation.</span></div>
            <div class="item"><strong>Execution-bound metering</strong><br><span class="muted">Service receipt + one-use nullifier prevents replayed settlement.</span></div>
            <div class="item"><strong>Origin Critic Firewall</strong><br><span class="muted">Origin/tool manifests, risk budgets, quarantine, payer resolution.</span></div>
            <div class="item"><strong>SPILLGuard privacy</strong><br><span class="muted">Weighted content and behavior trace leakage budgets.</span></div>
            <div class="item"><strong>Underwriting + validation</strong><br><span class="muted">Denial receipts, vault claims, exposure pricing, slashable bonds.</span></div>
          </div>
        </div>
        <div class="footer"><span>Not a generic escrow app</span><span>Sui object-capability design</span></div>
      </section>
    `,
    11000
  );

  await setSlide(
    page,
    `
      <section class="slide">
        <div>
          <div class="kicker">Live Sui Testnet proof</div>
          <h2>Package and WorkOrder are on-chain</h2>
          <div class="list">
            <div class="item"><strong>Package ID</strong><br><span class="mono">${ids.package}</span></div>
            <div class="item"><strong>Publish tx</strong><br><span class="mono">${ids.publish}</span></div>
            <div class="item"><strong>Seeded WorkOrder</strong><br><span class="mono">${ids.workOrder}</span></div>
            <div class="item"><strong>Final release tx</strong><br><span class="mono">${ids.finalTx}</span></div>
          </div>
        </div>
        <div class="panel">${shots.package ? `<img class="shot" src="${shots.package}">` : `<h2>Explorer links in docs/ONCHAIN.md</h2><p>${esc(links.package)}</p>`}</div>
        <div class="footer"><span>Network: Sui Testnet</span><span>All IDs are in docs/ONCHAIN.md</span></div>
      </section>
    `,
    10500
  );

  await setSlide(
    page,
    `
      <section class="slide single">
        <div>
          <div class="kicker">Demo transaction trail</div>
          <h2>Real transactions executed after deployment</h2>
          <p>Registry creation, execution binding, WorkOrder + AgentPolicy, privacy budget, origin critic receipt, privacy receipt, metered release, Walrus availability adapter, agent delivery, and final release.</p>
          <div class="txgrid">
            ${txs.map((tx) => `<div class="tx">${tx}</div>`).join("")}
          </div>
        </div>
        <div class="footer"><span>Explorer links are listed in docs/ONCHAIN.md</span><span>Compact but real Testnet path</span></div>
      </section>
    `,
    11500
  );

  await setSlide(
    page,
    `
      <section class="slide">
        <div>
          <div class="kicker">Security and verification</div>
          <h2>Built to show safe autonomy, not broad wallet delegation</h2>
          <div class="list">
            <div class="item"><span class="ok">36/36</span> Move tests passing.</div>
            <div class="item"><span class="ok">Build green</span> for Move package and frontend.</div>
            <div class="item"><span class="ok">0 production vulnerabilities</span> from npm audit.</div>
            <div class="item"><span class="ok">Replay protection</span> through execution-bound nullifiers.</div>
            <div class="item"><span class="ok">Quarantine</span> blocks release, split acceptance, and metered drawdowns until payer clearance.</div>
          </div>
        </div>
        <div class="panel">
          <h2>Honest integration status</h2>
          <p>Live Sui package, frontend, and demo transactions are complete.</p>
          <p>Walrus, Seal, Nautilus, Sui Prover, and external critic service are described as implemented surfaces/runbooks unless live service IDs are added.</p>
        </div>
        <div class="footer"><span>Security notes: docs/SECURITY.md</span><span>Formal spec artifact included</span></div>
      </section>
    `,
    11000
  );

  await setSlide(
    page,
    `
      <section class="slide">
        <div>
          <div class="kicker">Submission package</div>
          <h2>Ready for judges</h2>
          <div class="list">
            <div class="item"><strong>Frontend</strong><br><span class="mono">${esc(links.app)}</span></div>
            <div class="item"><strong>Repository</strong><br><span class="mono">${esc(links.repo)}</span></div>
            <div class="item"><strong>On-chain proof</strong><br><span class="mono">${esc(links.onchain)}</span></div>
          </div>
        </div>
        <div class="panel">${shots.onchain ? `<img class="shot" src="${shots.onchain}">` : `<h2>docs/ONCHAIN.md</h2><p>Package, objects, transaction IDs, Explorer links, and caveats are documented.</p>`}</div>
        <div class="footer"><span>Track: Agentic Web</span><span>SuiFlow Agentic Work Graph</span></div>
      </section>
    `,
    10000
  );

  const video = page.video();
  await context.close();
  await browser.close();
  fs.copyFileSync(await video.path(), target);
  console.log(target);
  console.log(fs.statSync(target).size);
})();
