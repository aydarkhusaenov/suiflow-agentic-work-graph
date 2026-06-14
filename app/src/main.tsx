import React from "react";
import { createRoot } from "react-dom/client";
import { ArrowRight, Bot, Boxes, Database, ShieldCheck, WalletCards } from "lucide-react";
import "./styles.css";

const packageId = import.meta.env.VITE_SUIFLOW_PACKAGE_ID || "0xPUBLISH_AFTER_TESTNET";

const demoSteps = [
  "Create funded SUI work-order object",
  "Issue bounded AgentPolicy object",
  "Attach Walrus/Seal evidence pointer",
  "Release, refund, or split-settle",
  "Emit receipt, feedback, and validator events"
];

function App() {
  return (
    <main className="shell">
      <section className="topbar">
        <div>
          <p className="eyebrow">Sui Overflow 2026 · Agentic Web</p>
          <h1>SuiFlow Agentic Work Graph</h1>
        </div>
        <a className="ghost" href="https://overflow.sui.io/" target="_blank" rel="noreferrer">
          Hackathon <ArrowRight size={16} />
        </a>
      </section>

      <section className="hero">
        <div className="heroText">
          <h2>Object-capability settlement for autonomous agents.</h2>
          <p>
            Every job is a Sui shared object. Every agent action is bounded by an owned policy object.
            Evidence points to Walrus/Seal, and final outcomes produce portable receipt and reputation events.
          </p>
          <div className="actions">
            <button>Connect Sui Wallet</button>
            <button className="secondary">Build PTB</button>
          </div>
        </div>
        <div className="terminal" aria-label="deployment status">
          <span>package</span>
          <strong>{packageId}</strong>
          <span>module</span>
          <strong>suiflow::agent_settlement</strong>
          <span>network</span>
          <strong>Sui Testnet</strong>
        </div>
      </section>

      <section className="grid">
        <Feature icon={<Boxes />} title="Shared Work Objects" text="Funded work orders carry escrow, service bond, deadline, evidence hashes, and settlement state." />
        <Feature icon={<Bot />} title="Bounded Agent Policies" text="Agents receive narrow owned objects for exact actions, expiry windows, and policy hashes." />
        <Feature icon={<Database />} title="Walrus Evidence" text="Large delivery and dispute payloads live off-chain while object fields anchor blob IDs and hashes." />
        <Feature icon={<ShieldCheck />} title="Validator Receipts" text="Final receipts can receive feedback and validator attestations for reputation indexing." />
        <Feature icon={<WalletCards />} title="Payments Ready" text="SUI escrow, refund, release, service-bond, and split-settlement paths are built into the Move module." />
      </section>

      <section className="panel">
        <h3>Demo Flow</h3>
        <ol>
          {demoSteps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </section>
    </main>
  );
}

function Feature({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return (
    <article className="feature">
      <div className="icon">{icon}</div>
      <h3>{title}</h3>
      <p>{text}</p>
    </article>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
