# Sui Overflow Submission Draft

## BUIDL Name

SuiFlow Agentic Work Graph

## Primary Track

Agentic Web

## Short Description

SuiFlow is object-capability settlement for autonomous agents on Sui: funded work-order objects, bounded agent-policy objects, Walrus/Seal evidence pointers, service bonds, refunds, split settlement, receipt events, and validator attestations.

## Vision

AI agents need more than payment triggers. They need enforceable work settlement: bounded authority, delivery evidence, disputes, refunds, receipts, and reputation. SuiFlow uses Sui shared objects and owned agent-policy objects to make that safe and auditable.

## What Was Built

- Sui Move package for funded work orders and agent policy objects.
- SUI escrow, service bond, release, refund, and split-settlement paths.
- Walrus blob ID and Seal policy ID fields for evidence.
- Receipt and validator-attestation events.
- Frontend shell for Sui wallet/PTB demo.
- Agent interface for non-custodial action planning.

## Why It Is Novel

The agent does not receive broad wallet authority. It receives a Sui object capability scoped to one work order, one set of actions, and one expiry. The capability is checked on-chain before delegated actions execute.

## Links

- GitHub: fill after push
- Package ID: fill after Sui testnet publish
- Demo site: fill after frontend run/host
- Video: fill after recording
