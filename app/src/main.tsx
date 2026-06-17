import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  ConnectButton,
  SuiClientProvider,
  WalletProvider,
  createNetworkConfig,
  useCurrentAccount,
  useSignAndExecuteTransaction
} from "@mysten/dapp-kit";
import "@mysten/dapp-kit/dist/index.css";
import { getJsonRpcFullnodeUrl } from "@mysten/sui/jsonRpc";
import { Transaction } from "@mysten/sui/transactions";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  ArrowRight,
  Bot,
  Boxes,
  Database,
  FileWarning,
  Fingerprint,
  LockKeyhole,
  ShieldCheck,
  WalletCards
} from "lucide-react";
import "./styles.css";

const CLOCK_OBJECT_ID = "0x6";
const MODULE = "agent_settlement";
const SUIFLOW_PACKAGE_ID = import.meta.env.VITE_SUIFLOW_PACKAGE_ID || "0xPUBLISH_AFTER_TESTNET";
const EXPLORER_TX = "https://suiexplorer.com/txblock";

const ACTION_MARK_DELIVERED = 1n;
const ACTION_RELEASE = 2n;
const ACTION_REQUEST_REFUND = 4n;
const ACTION_PROPOSE_SETTLEMENT = 8n;
const ACTION_ACCEPT_SETTLEMENT = 16n;
const ACTION_READ_EVIDENCE = 32n;
const ACTION_METER_RELEASE = 64n;
const ACTION_REPORT_PRIVACY = 128n;
const ACTION_BIND_EXECUTION = 256n;
const ACTION_REPORT_ORIGIN_RISK = 512n;

const { networkConfig } = createNetworkConfig({
  testnet: { network: "testnet", url: getJsonRpcFullnodeUrl("testnet") }
});

const queryClient = new QueryClient();
const encoder = new TextEncoder();

type FormState = {
  provider: string;
  agent: string;
  workOrderId: string;
  policyId: string;
  registryId: string;
  executionRegistryId: string;
  killCapId: string;
  caretakerId: string;
  vaultId: string;
  aggregatorId: string;
  controllerId: string;
  denialReceiptId: string;
  privacyBreachReceiptId: string;
  validatorBondCapId: string;
  bidMarketId: string;
  cosignBondId: string;
  sponsorPolicyId: string;
  sponsoreePolicyId: string;
  amountMist: string;
  bondMist: string;
  deadlineMs: string;
  expiresMs: string;
  maxUses: string;
  maxProviderAmount: string;
  metadataHash: string;
  mandateHash: string;
  policyHash: string;
  agentPolicyHash: string;
  walrusBlobId: string;
  sealPolicyId: string;
  deliveryEvidenceHash: string;
  disputeEvidenceHash: string;
  requiredBlobEndEpoch: string;
  certifiedEpoch: string;
  blobEndEpoch: string;
  settlementProviderAmount: string;
  attemptedAction: string;
  breakerWindowMs: string;
  breakerAmount: string;
  branchScopeHash: string;
  subAgent: string;
  childAmount: string;
  childActions: string;
  childExpiryMs: string;
  childCap: string;
  childMaxUses: string;
  childDeadlineMs: string;
  auctionTaskHash: string;
  auctionRevealDeadlineMs: string;
  sealedBidHash: string;
  bidAmount: string;
  bidNonceHash: string;
  units: string;
  unitPrice: string;
  usageProofHash: string;
  serviceEndpointHash: string;
  paymentIntentHash: string;
  serviceQuoteHash: string;
  serviceReceiptHash: string;
  executionNullifierHash: string;
  coverageCap: string;
  premiumBps: string;
  exposureAmount: string;
  backingMist: string;
  validatorBondMist: string;
  validationScoreBps: string;
  validationRoot: string;
  cosignStakeMist: string;
  cosignDecayMs: string;
  expectedOutputCommitment: string;
  proofChainRoot: string;
  deliveryProofSigner: string;
  deliveryProofSignatureHex: string;
  privacyBudget: string;
  privacyAllocation: string;
  privacyContentScore: string;
  privacyBehaviorScore: string;
  privacyManifestHash: string;
  privacyTraceCommitment: string;
  privacyEvidenceHash: string;
  originManifestHash: string;
  toolManifestHash: string;
  criticPolicyHash: string;
  criticRiskThreshold: string;
  originRiskAllocation: string;
  observedOriginHash: string;
  observedToolHash: string;
  userIntentHash: string;
  toolCallHash: string;
  criticRiskScore: string;
  criticTraceRoot: string;
  criticEvidenceHash: string;
  quarantineResolutionHash: string;
  attesterPubkeyHex: string;
  inputHash: string;
  outputHash: string;
  modelPcr: string;
  attestationFreshnessMs: string;
  attestedMs: string;
  attestationSignatureHex: string;
};

const defaultForm: FormState = {
  provider: "0xPROVIDER_ADDRESS",
  agent: "0xAGENT_ADDRESS",
  workOrderId: "",
  policyId: "",
  registryId: "",
  executionRegistryId: "",
  killCapId: "",
  caretakerId: "",
  vaultId: "",
  aggregatorId: "",
  controllerId: "",
  denialReceiptId: "",
  privacyBreachReceiptId: "",
  validatorBondCapId: "",
  bidMarketId: "",
  cosignBondId: "",
  sponsorPolicyId: "",
  sponsoreePolicyId: "",
  amountMist: "10000000",
  bondMist: "1000000",
  deadlineMs: "1893456000000",
  expiresMs: "1893456000000",
  maxUses: "3",
  maxProviderAmount: "0",
  metadataHash: "suiflow-demo-metadata",
  mandateHash: "ap2-style-mandate",
  policyHash: "bounded-work-policy",
  agentPolicyHash: "one-order-agent-policy",
  walrusBlobId: "walrus-demo-blob",
  sealPolicyId: "seal-workorder-namespace",
  deliveryEvidenceHash: "delivery-output-hash",
  disputeEvidenceHash: "dispute-evidence-hash",
  requiredBlobEndEpoch: "25",
  certifiedEpoch: "12",
  blobEndEpoch: "40",
  settlementProviderAmount: "5000000",
  attemptedAction: "64",
  breakerWindowMs: "60000",
  breakerAmount: "100000000",
  branchScopeHash: "branch-scope",
  subAgent: "0xSUB_AGENT_ADDRESS",
  childAmount: "1000000",
  childActions: "64",
  childExpiryMs: "1893456000000",
  childCap: "1000000",
  childMaxUses: "2",
  childDeadlineMs: "1893456000000",
  auctionTaskHash: "sealed-bid-child-task",
  auctionRevealDeadlineMs: "1893456000000",
  sealedBidHash: "sealed-bid-commitment",
  bidAmount: "900000",
  bidNonceHash: "bid-nonce",
  units: "2",
  unitPrice: "100000",
  usageProofHash: "usage-proof",
  serviceEndpointHash: "https-api-service",
  paymentIntentHash: "x402-payment-intent",
  serviceQuoteHash: "service-quote",
  serviceReceiptHash: "service-receipt",
  executionNullifierHash: "execution-nullifier",
  coverageCap: "1000000",
  premiumBps: "100",
  exposureAmount: "200000",
  backingMist: "1000000",
  validatorBondMist: "1000000",
  validationScoreBps: "9500",
  validationRoot: "validation-root",
  cosignStakeMist: "1000000",
  cosignDecayMs: "1893456000000",
  expectedOutputCommitment: "delivery-output-hash",
  proofChainRoot: "proof-chain-root",
  deliveryProofSigner: "0xcc62332e34bb2d5cd69f60efbb2a36cb916c7eb458301ea36636c4dbb012bd88",
  deliveryProofSignatureHex: "0x",
  privacyBudget: "50",
  privacyAllocation: "50",
  privacyContentScore: "1",
  privacyBehaviorScore: "2",
  privacyManifestHash: "privacy-manifest",
  privacyTraceCommitment: "privacy-trace-root",
  privacyEvidenceHash: "privacy-evidence",
  originManifestHash: "allowed-origins",
  toolManifestHash: "allowed-tools",
  criticPolicyHash: "critic-policy",
  criticRiskThreshold: "50",
  originRiskAllocation: "20",
  observedOriginHash: "allowed-origins",
  observedToolHash: "allowed-tools",
  userIntentHash: "user-intent",
  toolCallHash: "tool-call",
  criticRiskScore: "7",
  criticTraceRoot: "critic-trace-root",
  criticEvidenceHash: "critic-evidence",
  quarantineResolutionHash: "human-reviewed-origin-risk",
  attesterPubkeyHex: "0xcc62332e34bb2d5cd69f60efbb2a36cb916c7eb458301ea36636c4dbb012bd88",
  inputHash: "input-hash",
  outputHash: "delivery-output-hash",
  modelPcr: "pcr0",
  attestationFreshnessMs: "300000",
  attestedMs: "0",
  attestationSignatureHex: "0x"
};

const demoSteps = [
  "Create funded WorkOrder, AgentPolicy, and GenerationRegistry",
  "Spawn attenuated child WorkOrders and register generations",
  "Revoke subtree or freeze the fleet funding chokepoint",
  "Meter per-call settlement through an exposure aggregator",
  "Turn denial receipts into underwriting claims",
  "Submit bonded positive validations and slash on contradiction",
  "Auction child work, co-sign new agents, and release by delivery proof",
  "Track privacy leakage, bind one execution receipt, and quarantine origin/tool drift"
];

function App() {
  const account = useCurrentAccount();
  const signAndExecute = useSignAndExecuteTransaction();
  const [form, setForm] = useState<FormState>(defaultForm);
  const [lastDigest, setLastDigest] = useState("");
  const [status, setStatus] = useState("Ready for Sui Testnet package ID.");

  const packageReady = SUIFLOW_PACKAGE_ID.startsWith("0x") && !SUIFLOW_PACKAGE_ID.includes("PUBLISH");
  const connected = Boolean(account?.address);
  const canExecute = packageReady && connected && !signAndExecute.isPending;
  const txTarget = (fn: string) => `${SUIFLOW_PACKAGE_ID}::${MODULE}::${fn}`;

  const update = (key: keyof FormState) => (event: React.ChangeEvent<HTMLInputElement>) => {
    setForm((current) => ({ ...current, [key]: event.target.value }));
  };

  const connectedLabel = useMemo(() => {
    if (!account?.address) return "No wallet connected";
    return `${account.address.slice(0, 8)}...${account.address.slice(-6)}`;
  }, [account?.address]);

  async function run(label: string, build: () => Transaction) {
    if (!packageReady) {
      setStatus("Set VITE_SUIFLOW_PACKAGE_ID to the published Sui Testnet package ID.");
      return;
    }
    if (!connected) {
      setStatus("Connect a Sui wallet on Testnet first.");
      return;
    }

    try {
      setStatus(`${label}: waiting for wallet signature...`);
      const result = await signAndExecute.mutateAsync({ transaction: build() });
      const digest = "digest" in result ? result.digest : "";
      setLastDigest(digest);
      setStatus(`${label}: submitted${digest ? ` ${digest}` : ""}`);
    } catch (error) {
      setStatus(`${label}: ${(error as Error).message}`);
    }
  }

  const builders = {
    createWithPolicy: () => {
      const tx = new Transaction();
      tx.setGasBudget(60_000_000);
      const [payment] = tx.splitCoins(tx.gas, [tx.pure.u64(form.amountMist)]);
      tx.moveCall({
        target: txTarget("create_work_order_with_policy"),
        arguments: [
          tx.pure.address(form.provider),
          payment,
          pureBytes(tx, form.metadataHash),
          pureBytes(tx, form.mandateHash),
          pureBytes(tx, form.policyHash),
          pureBytes(tx, form.walrusBlobId),
          pureBytes(tx, form.sealPolicyId),
          tx.pure.u64(form.deadlineMs),
          tx.pure.address(form.agent),
          tx.pure.u64(
            ACTION_MARK_DELIVERED |
              ACTION_RELEASE |
              ACTION_REQUEST_REFUND |
              ACTION_PROPOSE_SETTLEMENT |
              ACTION_ACCEPT_SETTLEMENT |
              ACTION_READ_EVIDENCE |
              ACTION_METER_RELEASE |
              ACTION_REPORT_PRIVACY |
              ACTION_BIND_EXECUTION |
              ACTION_REPORT_ORIGIN_RISK
          ),
          tx.pure.u64(form.expiresMs),
          tx.pure.u64(form.maxUses),
          tx.pure.u64(form.maxProviderAmount),
          pureBytes(tx, form.agentPolicyHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    configureAttestation: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("configure_attestation"),
        arguments: [
          tx.object(form.workOrderId),
          pureBytes(tx, form.attesterPubkeyHex),
          pureBytes(tx, form.modelPcr),
          pureBytes(tx, form.inputHash),
          tx.pure.u64(form.attestationFreshnessMs)
        ]
      });
      return tx;
    },
    requireWalrus: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("require_walrus_availability_until"),
        arguments: [tx.object(form.workOrderId), tx.pure.u64(form.requiredBlobEndEpoch)]
      });
      return tx;
    },
    postBond: () => {
      const tx = new Transaction();
      const [bond] = tx.splitCoins(tx.gas, [tx.pure.u64(form.bondMist)]);
      tx.moveCall({
        target: txTarget("post_service_bond"),
        arguments: [tx.object(form.workOrderId), bond]
      });
      return tx;
    },
    createRegistry: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_generation_registry"),
        arguments: [tx.pure.u64(form.breakerWindowMs), tx.pure.u64(form.breakerAmount)]
      });
      return tx;
    },
    createExecutionRegistry: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_execution_binding_registry"),
        arguments: []
      });
      return tx;
    },
    configureExecutionContext: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("configure_execution_context"),
        arguments: [
          tx.object(form.workOrderId),
          pureBytes(tx, form.serviceEndpointHash),
          pureBytes(tx, form.paymentIntentHash),
          pureBytes(tx, form.serviceQuoteHash)
        ]
      });
      return tx;
    },
    registerGeneration: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("register_policy_generation"),
        arguments: [tx.object(form.registryId), tx.object(form.policyId)]
      });
      return tx;
    },
    revokeSubtree: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("revoke_subtree"),
        arguments: [tx.object(form.registryId), tx.pure.id(form.policyId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    pauseFleet: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("emergency_pause"),
        arguments: [tx.object(form.registryId), tx.object(form.killCapId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    unpauseFleet: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("emergency_unpause"),
        arguments: [tx.object(form.registryId), tx.object(form.killCapId)]
      });
      return tx;
    },
    createCaretaker: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_caretaker"),
        arguments: [pureBytes(tx, form.branchScopeHash)]
      });
      return tx;
    },
    revokeBranch: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("revoke_branch"),
        arguments: [tx.object(form.registryId), tx.object(form.caretakerId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    bindBranch: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("bind_policy_branch"),
        arguments: [tx.object(form.registryId), tx.object(form.policyId), tx.object(form.caretakerId)]
      });
      return tx;
    },
    spawnChild: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("spawn_child_work_order"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.pure.address(form.subAgent),
          tx.pure.address(form.provider),
          tx.pure.u64(form.childAmount),
          tx.pure.u64(form.childActions),
          tx.pure.u64(form.childExpiryMs),
          tx.pure.u64(form.childCap),
          tx.pure.u64(form.childMaxUses),
          pureBytes(tx, form.metadataHash),
          pureBytes(tx, form.mandateHash),
          pureBytes(tx, form.agentPolicyHash),
          pureBytes(tx, form.walrusBlobId),
          pureBytes(tx, form.sealPolicyId),
          tx.pure.u64(form.childDeadlineMs),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    createBidMarket: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_bid_market"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          pureBytes(tx, form.auctionTaskHash),
          tx.pure.u64(form.auctionRevealDeadlineMs)
        ]
      });
      return tx;
    },
    submitSealedBid: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("submit_sealed_bid"),
        arguments: [tx.object(form.bidMarketId), pureBytes(tx, form.sealedBidHash), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    openBid: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("open_bid"),
        arguments: [
          tx.object(form.bidMarketId),
          tx.pure.u64(form.bidAmount),
          pureBytes(tx, form.bidNonceHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    awardBidChild: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("award_bid_child_work_order"),
        arguments: [
          tx.object(form.bidMarketId),
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.pure.address(form.provider),
          tx.pure.u64(form.childActions),
          tx.pure.u64(form.childExpiryMs),
          tx.pure.u64(form.childCap),
          tx.pure.u64(form.childMaxUses),
          pureBytes(tx, form.metadataHash),
          pureBytes(tx, form.mandateHash),
          pureBytes(tx, form.agentPolicyHash),
          pureBytes(tx, form.walrusBlobId),
          pureBytes(tx, form.sealPolicyId),
          tx.pure.u64(form.childDeadlineMs),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    reapBranch: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("reap_abandoned_branch"),
        arguments: [tx.object(form.workOrderId), tx.object(form.policyId), tx.object(form.registryId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    meterRelease: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("meter_release"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.pure.u64(form.units),
          tx.pure.u64(form.unitPrice),
          pureBytes(tx, form.usageProofHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    meterReleaseExecution: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("meter_release_with_execution_binding"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.object(form.executionRegistryId),
          tx.pure.u64(form.units),
          tx.pure.u64(form.unitPrice),
          pureBytes(tx, form.usageProofHash),
          pureBytes(tx, form.serviceReceiptHash),
          pureBytes(tx, form.executionNullifierHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    createVault: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_underwriting_vault"),
        arguments: [tx.object(form.policyId), tx.pure.u64(form.coverageCap), tx.pure.u64(form.premiumBps)]
      });
      return tx;
    },
    stakeVault: () => {
      const tx = new Transaction();
      const [backing] = tx.splitCoins(tx.gas, [tx.pure.u64(form.backingMist)]);
      tx.moveCall({
        target: txTarget("stake_backing"),
        arguments: [tx.object(form.vaultId), backing]
      });
      return tx;
    },
    createAggregator: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("create_exposure_aggregator"),
        arguments: [tx.pure.id(form.controllerId || form.policyId), tx.pure.u64(form.premiumBps)]
      });
      return tx;
    },
    meteredVault: () => {
      const tx = new Transaction();
      const [ticket] = tx.moveCall({
        target: txTarget("record_exposure"),
        arguments: [
          tx.object(form.aggregatorId),
          tx.pure.id(form.controllerId || form.policyId),
          tx.pure.u64(form.exposureAmount)
        ]
      });
      tx.moveCall({
        target: txTarget("meter_release_with_vault"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.object(form.vaultId),
          ticket,
          tx.pure.u64(form.units),
          tx.pure.u64(form.unitPrice),
          pureBytes(tx, form.usageProofHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    policyDenialReceipt: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_policy_denial_receipt"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.pure.u64(form.attemptedAction),
          pureBytes(tx, "policy-denial-receipt"),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    fileClaim: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("file_claim"),
        arguments: [tx.object(form.vaultId), tx.object(form.workOrderId), tx.object(form.denialReceiptId)]
      });
      return tx;
    },
    configurePrivacyBudget: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("configure_privacy_budget"),
        arguments: [
          tx.object(form.workOrderId),
          tx.pure.u64(form.privacyBudget),
          pureBytes(tx, form.privacyManifestHash),
          pureBytes(tx, form.privacyTraceCommitment)
        ]
      });
      return tx;
    },
    allocatePrivacyBudget: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("allocate_policy_privacy_budget"),
        arguments: [tx.object(form.workOrderId), tx.object(form.policyId), tx.pure.u64(form.privacyAllocation)]
      });
      return tx;
    },
    recordPrivacyReceipt: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_privacy_receipt"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          tx.pure.u64(form.privacyContentScore),
          tx.pure.u64(form.privacyBehaviorScore),
          pureBytes(tx, form.privacyTraceCommitment),
          pureBytes(tx, form.walrusBlobId),
          pureBytes(tx, form.sealPolicyId),
          pureBytes(tx, form.privacyEvidenceHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    recordPrivacyBreach: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_privacy_breach_receipt"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.pure.u64(form.privacyContentScore),
          tx.pure.u64(form.privacyBehaviorScore),
          pureBytes(tx, form.privacyEvidenceHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    filePrivacyClaim: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("file_privacy_claim"),
        arguments: [tx.object(form.vaultId), tx.object(form.workOrderId), tx.object(form.privacyBreachReceiptId)]
      });
      return tx;
    },
    configureOriginFirewall: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("configure_origin_firewall"),
        arguments: [
          tx.object(form.workOrderId),
          pureBytes(tx, form.originManifestHash),
          pureBytes(tx, form.toolManifestHash),
          pureBytes(tx, form.criticPolicyHash),
          tx.pure.u64(form.criticRiskThreshold)
        ]
      });
      return tx;
    },
    allocateOriginRiskBudget: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("allocate_policy_origin_risk_budget"),
        arguments: [tx.object(form.workOrderId), tx.object(form.policyId), tx.pure.u64(form.originRiskAllocation)]
      });
      return tx;
    },
    recordOriginCriticReceipt: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_origin_critic_receipt"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          pureBytes(tx, form.observedOriginHash),
          pureBytes(tx, form.observedToolHash),
          pureBytes(tx, form.userIntentHash),
          pureBytes(tx, form.toolCallHash),
          tx.pure.u64(form.criticRiskScore),
          pureBytes(tx, form.criticTraceRoot),
          pureBytes(tx, form.criticEvidenceHash),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    clearOriginQuarantine: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("clear_origin_quarantine"),
        arguments: [tx.object(form.workOrderId), pureBytes(tx, form.quarantineResolutionHash)]
      });
      return tx;
    },
    createValidatorBond: () => {
      const tx = new Transaction();
      const [bond] = tx.splitCoins(tx.gas, [tx.pure.u64(form.validatorBondMist)]);
      tx.moveCall({
        target: txTarget("create_validator_bond"),
        arguments: [bond]
      });
      return tx;
    },
    bondedValidation: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("submit_bonded_validation"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.validatorBondCapId),
          tx.pure.address(form.agent),
          tx.pure.u64(form.validationScoreBps),
          pureBytes(tx, "bonded-validation"),
          pureBytes(tx, form.validationRoot)
        ]
      });
      return tx;
    },
    slashValidator: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("slash_validator_to_vault"),
        arguments: [tx.object(form.vaultId), tx.object(form.validatorBondCapId), tx.object(form.denialReceiptId)]
      });
      return tx;
    },
    cosignPolicy: () => {
      const tx = new Transaction();
      const [stake] = tx.splitCoins(tx.gas, [tx.pure.u64(form.cosignStakeMist)]);
      tx.moveCall({
        target: txTarget("cosign"),
        arguments: [
          tx.object(form.sponsorPolicyId || form.policyId),
          tx.object(form.sponsoreePolicyId || form.policyId),
          stake,
          tx.pure.u64(form.cosignDecayMs)
        ]
      });
      return tx;
    },
    slashCosign: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("slash_cosign_to_vault"),
        arguments: [tx.object(form.vaultId), tx.object(form.cosignBondId), tx.object(form.denialReceiptId)]
      });
      return tx;
    },
    releaseCosign: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("release_cosign_after_decay"),
        arguments: [tx.object(form.cosignBondId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    configureDeliveryConfirmation: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("configure_delivery_confirmation"),
        arguments: [tx.object(form.workOrderId), pureBytes(tx, form.expectedOutputCommitment)]
      });
      return tx;
    },
    verifyDeliveryProof: () => {
      const tx = new Transaction();
      const [proof] = tx.moveCall({
        target: txTarget("new_delivery_proof"),
        arguments: [
          tx.pure.id(form.workOrderId),
          pureBytes(tx, form.expectedOutputCommitment),
          pureBytes(tx, form.proofChainRoot),
          pureBytes(tx, form.deliveryProofSigner)
        ]
      });
      tx.moveCall({
        target: txTarget("verify_and_release_delivery_proof"),
        arguments: [tx.object(form.workOrderId), proof, pureBytes(tx, form.deliveryProofSignatureHex)]
      });
      return tx;
    },
    agentDeliverWithAvailability: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("agent_mark_delivered_with_availability_fields_live"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          pureBytes(tx, form.deliveryEvidenceHash),
          pureBytes(tx, form.walrusBlobId),
          tx.pure.u64(form.certifiedEpoch),
          tx.pure.u64(form.blobEndEpoch),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    requestRefund: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("request_refund"),
        arguments: [tx.object(form.workOrderId), pureBytes(tx, form.disputeEvidenceHash), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    },
    proposeSplit: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("propose_split_settlement"),
        arguments: [
          tx.object(form.workOrderId),
          tx.pure.u64(form.settlementProviderAmount),
          pureBytes(tx, form.disputeEvidenceHash)
        ]
      });
      return tx;
    },
    acceptSplit: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("accept_split_settlement"),
        arguments: [tx.object(form.workOrderId)]
      });
      return tx;
    },
    release: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("release"),
        arguments: [tx.object(form.workOrderId)]
      });
      return tx;
    },
    attestedRelease: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("release_with_attestation_fields_live"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.object(form.registryId),
          pureBytes(tx, form.inputHash),
          pureBytes(tx, form.outputHash),
          pureBytes(tx, form.modelPcr),
          tx.pure.u64(form.attestedMs),
          pureBytes(tx, form.attestationSignatureHex),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    policyDenial: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_policy_denial"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          tx.pure.u64(form.attemptedAction),
          pureBytes(tx, "policy-denial-attempt"),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    attestationDenial: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("record_attestation_denial_fields"),
        arguments: [
          tx.object(form.workOrderId),
          tx.object(form.policyId),
          pureBytes(tx, form.inputHash),
          pureBytes(tx, form.outputHash),
          pureBytes(tx, form.modelPcr),
          tx.pure.u64(form.attestedMs),
          pureBytes(tx, form.attestationSignatureHex),
          tx.object(CLOCK_OBJECT_ID)
        ]
      });
      return tx;
    },
    timeoutRefund: () => {
      const tx = new Transaction();
      tx.moveCall({
        target: txTarget("timeout_refund"),
        arguments: [tx.object(form.workOrderId), tx.object(CLOCK_OBJECT_ID)]
      });
      return tx;
    }
  };

  return (
    <main className="shell">
      <section className="topbar">
        <div>
          <p className="eyebrow">Sui Overflow 2026 · Agentic Web</p>
          <h1>SuiFlow Agentic Work Graph</h1>
        </div>
        <div className="walletBar">
          <span>{connectedLabel}</span>
          <ConnectButton connectText="Connect Sui Wallet" />
        </div>
      </section>

      <section className="hero">
        <div className="heroText">
          <h2>Bounded, revocable, insured authority for agent work graphs.</h2>
          <p>
            SuiFlow turns autonomous-agent work into a recursive Sui object graph: attenuated child
            capabilities, generation-counter subtree revocation, metered drawdowns, underwriting
            vaults, exposure aggregation, privacy-budgeted traces, execution-bound receipts, bonded
            validations, Seal/Walrus evidence, and signed receipts.
            Origin Critic Firewall adds a judge-visible prompt-injection defense by binding
            execution to approved origin/tool manifests and quarantining risky critic receipts.
          </p>
          <div className="actions">
            <button disabled={!canExecute} onClick={() => run("Create WorkOrder + AgentPolicy", builders.createWithPolicy)}>
              Create + Policy
            </button>
            <button className="secondary" disabled={!canExecute} onClick={() => run("Agent deliver with Walrus proof", builders.agentDeliverWithAvailability)}>
              Deliver
            </button>
            <button className="secondary" disabled={!canExecute} onClick={() => run("Attested release", builders.attestedRelease)}>
              Attested Release
            </button>
          </div>
        </div>
        <div className="terminal" aria-label="deployment status">
          <span>package</span>
          <strong>{SUIFLOW_PACKAGE_ID}</strong>
          <span>module</span>
          <strong>suiflow::{MODULE}</strong>
          <span>network</span>
          <strong>Sui Testnet</strong>
          {lastDigest && (
            <>
              <span>last tx</span>
              <a href={`${EXPLORER_TX}/${lastDigest}?network=testnet`} target="_blank" rel="noreferrer">
                {lastDigest}
              </a>
            </>
          )}
        </div>
      </section>

      <section className="grid">
        <Feature icon={<Boxes />} title="Recursive Work Graph" text="Parent WorkOrders can fund child WorkOrders while preserving root principal, depth, budget, and provenance." />
        <Feature icon={<Bot />} title="Attenuated Policies" text="Child AgentPolicies must be weaker than parents across action mask, expiry, budget, settlement cap, and depth." />
        <Feature icon={<ShieldCheck />} title="Revocation Lattice" text="GenerationRegistry supports subtree revocation, branch receipts, fleet pause, and velocity breaker funding freeze." />
        <Feature icon={<WalletCards />} title="Metered Settlement" text="Per-call drawdowns enforce remaining budget, usage caps, settlement caps, and optional insurance premium skim." />
        <Feature icon={<FileWarning />} title="Underwriting Claims" text="Policy denial receipts become oracle-free claim triggers against per-policy underwriting vaults." />
        <Feature icon={<Database />} title="Exposure Aggregation" text="Controller-scoped exposure tickets force sibling settlement through one shared risk counter." />
        <Feature icon={<Fingerprint />} title="TEE-Gated Release" text="TEE-required orders reject plain release and require a signed WorkReceipt over BCS-pinned fields." />
        <Feature icon={<LockKeyhole />} title="Seal Read Predicate" text="WorkOrder state and AgentPolicy read bits gate delivery, dispute, and timelock reveal identities." />
        <Feature icon={<Database />} title="Walrus Availability" text="Delivery can require certified blob epochs before settlement state moves to delivered." />
        <Feature icon={<ShieldCheck />} title="Provenance Receipts" text="Final receipts commit to policy, evidence, TEE, parent, depth, meter, premium, and release-condition fields." />
        <Feature icon={<WalletCards />} title="Agent Labor Auction" text="Parents can post sealed-bid child tasks, open bids after reveal, and award attenuated child policies to winners." />
        <Feature icon={<Fingerprint />} title="Delivery Oracle" text="On-chain delivery-confirmation release binds the expected output, proof-chain root, signer, and final receipt." />
        <Feature icon={<LockKeyhole />} title="SPILLGuard Privacy" text="Content and behavior leakage are scored against a WorkOrder privacy budget, with breach receipts claimable against vault backing." />
        <Feature icon={<Database />} title="Execution Binding" text="Metered payment can consume one service-execution receipt and nullifier, preventing replay across web/payment layers." />
        <Feature icon={<ShieldCheck />} title="Origin Critic Firewall" text="Tool calls are checked against origin and tool manifests; risky critic receipts quarantine release until payer review." />
      </section>

      <section className="workbench">
        <div className="panel formPanel">
          <h3>Transaction Inputs</h3>
          <div className="formGrid">
            <Field label="Provider" value={form.provider} onChange={update("provider")} />
            <Field label="Agent" value={form.agent} onChange={update("agent")} />
            <Field label="WorkOrder ID" value={form.workOrderId} onChange={update("workOrderId")} />
            <Field label="Policy ID" value={form.policyId} onChange={update("policyId")} />
            <Field label="Registry ID" value={form.registryId} onChange={update("registryId")} />
            <Field label="Execution registry" value={form.executionRegistryId} onChange={update("executionRegistryId")} />
            <Field label="KillCap ID" value={form.killCapId} onChange={update("killCapId")} />
            <Field label="Caretaker ID" value={form.caretakerId} onChange={update("caretakerId")} />
            <Field label="Vault ID" value={form.vaultId} onChange={update("vaultId")} />
            <Field label="Aggregator ID" value={form.aggregatorId} onChange={update("aggregatorId")} />
            <Field label="Controller ID" value={form.controllerId} onChange={update("controllerId")} />
            <Field label="DenialReceipt ID" value={form.denialReceiptId} onChange={update("denialReceiptId")} />
            <Field label="PrivacyBreach ID" value={form.privacyBreachReceiptId} onChange={update("privacyBreachReceiptId")} />
            <Field label="ValidatorBond ID" value={form.validatorBondCapId} onChange={update("validatorBondCapId")} />
            <Field label="BidMarket ID" value={form.bidMarketId} onChange={update("bidMarketId")} />
            <Field label="CoSignBond ID" value={form.cosignBondId} onChange={update("cosignBondId")} />
            <Field label="Sponsor policy" value={form.sponsorPolicyId} onChange={update("sponsorPolicyId")} />
            <Field label="Sponsoree policy" value={form.sponsoreePolicyId} onChange={update("sponsoreePolicyId")} />
            <Field label="Payment MIST" value={form.amountMist} onChange={update("amountMist")} />
            <Field label="Bond MIST" value={form.bondMist} onChange={update("bondMist")} />
            <Field label="Deadline ms" value={form.deadlineMs} onChange={update("deadlineMs")} />
            <Field label="Policy expiry ms" value={form.expiresMs} onChange={update("expiresMs")} />
            <Field label="Max uses" value={form.maxUses} onChange={update("maxUses")} />
            <Field label="Max provider amount" value={form.maxProviderAmount} onChange={update("maxProviderAmount")} />
            <Field label="Walrus blob" value={form.walrusBlobId} onChange={update("walrusBlobId")} />
            <Field label="Seal policy" value={form.sealPolicyId} onChange={update("sealPolicyId")} />
            <Field label="Delivery hash" value={form.deliveryEvidenceHash} onChange={update("deliveryEvidenceHash")} />
            <Field label="Dispute hash" value={form.disputeEvidenceHash} onChange={update("disputeEvidenceHash")} />
            <Field label="Required blob epoch" value={form.requiredBlobEndEpoch} onChange={update("requiredBlobEndEpoch")} />
            <Field label="Certified epoch" value={form.certifiedEpoch} onChange={update("certifiedEpoch")} />
            <Field label="Blob end epoch" value={form.blobEndEpoch} onChange={update("blobEndEpoch")} />
            <Field label="Split provider amount" value={form.settlementProviderAmount} onChange={update("settlementProviderAmount")} />
            <Field label="Denied action bit" value={form.attemptedAction} onChange={update("attemptedAction")} />
            <Field label="Breaker window ms" value={form.breakerWindowMs} onChange={update("breakerWindowMs")} />
            <Field label="Breaker amount" value={form.breakerAmount} onChange={update("breakerAmount")} />
            <Field label="Branch scope" value={form.branchScopeHash} onChange={update("branchScopeHash")} />
            <Field label="Sub-agent" value={form.subAgent} onChange={update("subAgent")} />
            <Field label="Child amount" value={form.childAmount} onChange={update("childAmount")} />
            <Field label="Child actions" value={form.childActions} onChange={update("childActions")} />
            <Field label="Child expiry" value={form.childExpiryMs} onChange={update("childExpiryMs")} />
            <Field label="Child cap" value={form.childCap} onChange={update("childCap")} />
            <Field label="Child max uses" value={form.childMaxUses} onChange={update("childMaxUses")} />
            <Field label="Child deadline" value={form.childDeadlineMs} onChange={update("childDeadlineMs")} />
            <Field label="Auction task" value={form.auctionTaskHash} onChange={update("auctionTaskHash")} />
            <Field label="Auction reveal ms" value={form.auctionRevealDeadlineMs} onChange={update("auctionRevealDeadlineMs")} />
            <Field label="Sealed bid hash" value={form.sealedBidHash} onChange={update("sealedBidHash")} />
            <Field label="Bid amount" value={form.bidAmount} onChange={update("bidAmount")} />
            <Field label="Bid nonce" value={form.bidNonceHash} onChange={update("bidNonceHash")} />
            <Field label="Meter units" value={form.units} onChange={update("units")} />
            <Field label="Unit price" value={form.unitPrice} onChange={update("unitPrice")} />
            <Field label="Usage proof" value={form.usageProofHash} onChange={update("usageProofHash")} />
            <Field label="Service endpoint" value={form.serviceEndpointHash} onChange={update("serviceEndpointHash")} />
            <Field label="Payment intent" value={form.paymentIntentHash} onChange={update("paymentIntentHash")} />
            <Field label="Service quote" value={form.serviceQuoteHash} onChange={update("serviceQuoteHash")} />
            <Field label="Service receipt" value={form.serviceReceiptHash} onChange={update("serviceReceiptHash")} />
            <Field label="Exec nullifier" value={form.executionNullifierHash} onChange={update("executionNullifierHash")} />
            <Field label="Coverage cap" value={form.coverageCap} onChange={update("coverageCap")} />
            <Field label="Premium bps" value={form.premiumBps} onChange={update("premiumBps")} />
            <Field label="Exposure amount" value={form.exposureAmount} onChange={update("exposureAmount")} />
            <Field label="Backing MIST" value={form.backingMist} onChange={update("backingMist")} />
            <Field label="Validator bond" value={form.validatorBondMist} onChange={update("validatorBondMist")} />
            <Field label="Validation score" value={form.validationScoreBps} onChange={update("validationScoreBps")} />
            <Field label="Validation root" value={form.validationRoot} onChange={update("validationRoot")} />
            <Field label="Cosign stake" value={form.cosignStakeMist} onChange={update("cosignStakeMist")} />
            <Field label="Cosign decay" value={form.cosignDecayMs} onChange={update("cosignDecayMs")} />
            <Field label="Expected output" value={form.expectedOutputCommitment} onChange={update("expectedOutputCommitment")} />
            <Field label="Proof chain root" value={form.proofChainRoot} onChange={update("proofChainRoot")} />
            <Field label="Proof signer" value={form.deliveryProofSigner} onChange={update("deliveryProofSigner")} />
            <Field label="Proof signature" value={form.deliveryProofSignatureHex} onChange={update("deliveryProofSignatureHex")} />
            <Field label="Privacy budget" value={form.privacyBudget} onChange={update("privacyBudget")} />
            <Field label="Privacy alloc" value={form.privacyAllocation} onChange={update("privacyAllocation")} />
            <Field label="Content leak" value={form.privacyContentScore} onChange={update("privacyContentScore")} />
            <Field label="Behavior leak" value={form.privacyBehaviorScore} onChange={update("privacyBehaviorScore")} />
            <Field label="Privacy manifest" value={form.privacyManifestHash} onChange={update("privacyManifestHash")} />
            <Field label="Privacy trace" value={form.privacyTraceCommitment} onChange={update("privacyTraceCommitment")} />
            <Field label="Privacy evidence" value={form.privacyEvidenceHash} onChange={update("privacyEvidenceHash")} />
            <Field label="Origin manifest" value={form.originManifestHash} onChange={update("originManifestHash")} />
            <Field label="Tool manifest" value={form.toolManifestHash} onChange={update("toolManifestHash")} />
            <Field label="Critic policy" value={form.criticPolicyHash} onChange={update("criticPolicyHash")} />
            <Field label="Critic threshold" value={form.criticRiskThreshold} onChange={update("criticRiskThreshold")} />
            <Field label="Origin risk alloc" value={form.originRiskAllocation} onChange={update("originRiskAllocation")} />
            <Field label="Observed origin" value={form.observedOriginHash} onChange={update("observedOriginHash")} />
            <Field label="Observed tool" value={form.observedToolHash} onChange={update("observedToolHash")} />
            <Field label="User intent" value={form.userIntentHash} onChange={update("userIntentHash")} />
            <Field label="Tool call" value={form.toolCallHash} onChange={update("toolCallHash")} />
            <Field label="Critic risk" value={form.criticRiskScore} onChange={update("criticRiskScore")} />
            <Field label="Critic trace" value={form.criticTraceRoot} onChange={update("criticTraceRoot")} />
            <Field label="Critic evidence" value={form.criticEvidenceHash} onChange={update("criticEvidenceHash")} />
            <Field label="Quarantine note" value={form.quarantineResolutionHash} onChange={update("quarantineResolutionHash")} />
            <Field label="Attester pubkey" value={form.attesterPubkeyHex} onChange={update("attesterPubkeyHex")} />
            <Field label="Input hash" value={form.inputHash} onChange={update("inputHash")} />
            <Field label="Output hash" value={form.outputHash} onChange={update("outputHash")} />
            <Field label="Model PCR" value={form.modelPcr} onChange={update("modelPcr")} />
            <Field label="Freshness ms" value={form.attestationFreshnessMs} onChange={update("attestationFreshnessMs")} />
            <Field label="Attested ms" value={form.attestedMs} onChange={update("attestedMs")} />
            <Field label="Signature" value={form.attestationSignatureHex} onChange={update("attestationSignatureHex")} />
          </div>
        </div>

        <div className="panel actionPanel">
          <h3>Lifecycle PTBs</h3>
          <div className="buttonGrid">
            <TxButton disabled={!canExecute} label="Create + Policy" onClick={() => run("Create WorkOrder + AgentPolicy", builders.createWithPolicy)} />
            <TxButton disabled={!canExecute} label="Create Registry" onClick={() => run("Create generation registry", builders.createRegistry)} />
            <TxButton disabled={!canExecute} label="Exec Registry" onClick={() => run("Create execution registry", builders.createExecutionRegistry)} />
            <TxButton disabled={!canExecute} label="Register Policy" onClick={() => run("Register policy generation", builders.registerGeneration)} />
            <TxButton disabled={!canExecute} label="Spawn Child" onClick={() => run("Spawn child WorkOrder", builders.spawnChild)} />
            <TxButton disabled={!canExecute} label="Revoke Subtree" onClick={() => run("Revoke subtree", builders.revokeSubtree)} />
            <TxButton disabled={!canExecute} label="Pause Fleet" onClick={() => run("Emergency pause", builders.pauseFleet)} />
            <TxButton disabled={!canExecute} label="Unpause Fleet" onClick={() => run("Emergency unpause", builders.unpauseFleet)} />
            <TxButton disabled={!canExecute} label="Create Branch" onClick={() => run("Create branch caretaker", builders.createCaretaker)} />
            <TxButton disabled={!canExecute} label="Bind Branch" onClick={() => run("Bind policy branch", builders.bindBranch)} />
            <TxButton disabled={!canExecute} label="Revoke Branch" onClick={() => run("Revoke branch", builders.revokeBranch)} />
            <TxButton disabled={!canExecute} label="Configure TEE" onClick={() => run("Configure attestation", builders.configureAttestation)} />
            <TxButton disabled={!canExecute} label="Require Walrus" onClick={() => run("Require Walrus availability", builders.requireWalrus)} />
            <TxButton disabled={!canExecute} label="Post Bond" onClick={() => run("Post service bond", builders.postBond)} />
            <TxButton disabled={!canExecute} label="Agent Deliver" onClick={() => run("Agent deliver with availability", builders.agentDeliverWithAvailability)} />
            <TxButton disabled={!canExecute} label="Delivery Gate" onClick={() => run("Configure delivery confirmation", builders.configureDeliveryConfirmation)} />
            <TxButton disabled={!canExecute} label="Proof Release" onClick={() => run("Verify delivery proof", builders.verifyDeliveryProof)} />
            <TxButton disabled={!canExecute} label="Bid Market" onClick={() => run("Create sealed-bid market", builders.createBidMarket)} />
            <TxButton disabled={!canExecute} label="Submit Bid" onClick={() => run("Submit sealed bid", builders.submitSealedBid)} />
            <TxButton disabled={!canExecute} label="Open Bid" onClick={() => run("Open bid", builders.openBid)} />
            <TxButton disabled={!canExecute} label="Award Bid" onClick={() => run("Award bid child", builders.awardBidChild)} />
            <TxButton disabled={!canExecute} label="Reap Branch" onClick={() => run("Reap abandoned branch", builders.reapBranch)} />
            <TxButton disabled={!canExecute} label="Meter Draw" onClick={() => run("Metered release", builders.meterRelease)} />
            <TxButton disabled={!canExecute} label="Bind Exec" onClick={() => run("Configure execution context", builders.configureExecutionContext)} />
            <TxButton disabled={!canExecute} label="Exec Meter" onClick={() => run("Execution-bound meter", builders.meterReleaseExecution)} />
            <TxButton disabled={!canExecute} label="Create Vault" onClick={() => run("Create underwriting vault", builders.createVault)} />
            <TxButton disabled={!canExecute} label="Stake Vault" onClick={() => run("Stake underwriting vault", builders.stakeVault)} />
            <TxButton disabled={!canExecute} label="Create Exposure" onClick={() => run("Create exposure aggregator", builders.createAggregator)} />
            <TxButton disabled={!canExecute} label="Vault Draw" onClick={() => run("Metered release with vault", builders.meteredVault)} />
            <TxButton disabled={!canExecute} label="Policy Denial" onClick={() => run("Record policy denial", builders.policyDenial)} />
            <TxButton disabled={!canExecute} label="Denial Receipt" onClick={() => run("Record denial receipt", builders.policyDenialReceipt)} />
            <TxButton disabled={!canExecute} label="File Claim" onClick={() => run("File insurance claim", builders.fileClaim)} />
            <TxButton disabled={!canExecute} label="Privacy Budget" onClick={() => run("Configure privacy budget", builders.configurePrivacyBudget)} />
            <TxButton disabled={!canExecute} label="Privacy Alloc" onClick={() => run("Allocate privacy budget", builders.allocatePrivacyBudget)} />
            <TxButton disabled={!canExecute} label="Privacy Receipt" onClick={() => run("Record privacy receipt", builders.recordPrivacyReceipt)} />
            <TxButton disabled={!canExecute} label="Privacy Breach" onClick={() => run("Record privacy breach", builders.recordPrivacyBreach)} />
            <TxButton disabled={!canExecute} label="Privacy Claim" onClick={() => run("File privacy claim", builders.filePrivacyClaim)} />
            <TxButton disabled={!canExecute} label="Origin Firewall" onClick={() => run("Configure origin firewall", builders.configureOriginFirewall)} />
            <TxButton disabled={!canExecute} label="Origin Budget" onClick={() => run("Allocate origin risk budget", builders.allocateOriginRiskBudget)} />
            <TxButton disabled={!canExecute} label="Critic Receipt" onClick={() => run("Record origin critic receipt", builders.recordOriginCriticReceipt)} />
            <TxButton disabled={!canExecute} label="Clear Quarantine" onClick={() => run("Clear origin quarantine", builders.clearOriginQuarantine)} />
            <TxButton disabled={!canExecute} label="Attest Denial" onClick={() => run("Record attestation denial", builders.attestationDenial)} />
            <TxButton disabled={!canExecute} label="Validator Bond" onClick={() => run("Create validator bond", builders.createValidatorBond)} />
            <TxButton disabled={!canExecute} label="Bonded Validate" onClick={() => run("Submit bonded validation", builders.bondedValidation)} />
            <TxButton disabled={!canExecute} label="Slash Validator" onClick={() => run("Slash validator", builders.slashValidator)} />
            <TxButton disabled={!canExecute} label="Co-sign" onClick={() => run("Co-sign policy", builders.cosignPolicy)} />
            <TxButton disabled={!canExecute} label="Slash Co-sign" onClick={() => run("Slash co-sign bond", builders.slashCosign)} />
            <TxButton disabled={!canExecute} label="Release Co-sign" onClick={() => run("Release co-sign bond", builders.releaseCosign)} />
            <TxButton disabled={!canExecute} label="Request Refund" onClick={() => run("Request refund", builders.requestRefund)} />
            <TxButton disabled={!canExecute} label="Timeout Refund" onClick={() => run("Timeout refund", builders.timeoutRefund)} />
            <TxButton disabled={!canExecute} label="Propose Split" onClick={() => run("Propose split", builders.proposeSplit)} />
            <TxButton disabled={!canExecute} label="Accept Split" onClick={() => run("Accept split", builders.acceptSplit)} />
            <TxButton disabled={!canExecute} label="Plain Release" onClick={() => run("Plain release", builders.release)} />
          </div>
          <div className="statusBox">
            <span>Status</span>
            <strong>{status}</strong>
          </div>
          <ol>
            {demoSteps.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
          <a className="ghost" href="https://overflow.sui.io/" target="_blank" rel="noreferrer">
            Hackathon <ArrowRight size={16} />
          </a>
        </div>
      </section>
    </main>
  );
}

function pureBytes(tx: Transaction, value: string) {
  return tx.pure.vector("u8", toBytes(value));
}

function toBytes(value: string) {
  const trimmed = value.trim();
  if (/^0x[0-9a-fA-F]*$/.test(trimmed) && trimmed.length % 2 === 0) {
    const hex = trimmed.slice(2);
    const bytes = [];
    for (let i = 0; i < hex.length; i += 2) {
      bytes.push(Number.parseInt(hex.slice(i, i + 2), 16));
    }
    return bytes;
  }
  return Array.from(encoder.encode(value));
}

function Field({
  label,
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (event: React.ChangeEvent<HTMLInputElement>) => void;
}) {
  return (
    <label>
      <span>{label}</span>
      <input value={value} onChange={onChange} spellCheck={false} />
    </label>
  );
}

function TxButton({ label, disabled, onClick }: { label: string; disabled: boolean; onClick: () => void }) {
  return (
    <button className="secondary" disabled={disabled} onClick={onClick}>
      {label}
    </button>
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

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networkConfig} defaultNetwork="testnet">
        <WalletProvider autoConnect>
          <App />
        </WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  </React.StrictMode>
);
