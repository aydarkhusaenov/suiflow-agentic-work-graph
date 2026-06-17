# Sui Testnet Proof

## Published Package

```text
Package ID:
0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d

Publisher:
0xa4921a5ec7d3ab185fd0caf6f2e5df3b78c513c32d2685e59fc97ad67a412138

Publish tx:
3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn

UpgradeCap:
0xf2e25d20bf6ce419d87de719b6aa2f38b8c68511b157506ba49681f888ee2b3f
```

- Package Explorer: https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet
- Publish Explorer: https://suiexplorer.com/txblock/3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn?network=testnet

## Live Demo Objects

```text
GenerationRegistry object:
0x13430af00d9313e07d5af28d79fe576994c6f5856e5d05ed67e6f0d4a9c48d37

ExecutionBindingRegistry object:
0xa053491cd30ee6b5e86a766ab19990cdb0854bf5ea92e35fdb5a5ec2ff217014

KillCap object:
0xe332ab7e920dfc7111ff48d81acd9945a19ff71bde72aed464f02d4dec048d4d

WorkOrder object:
0x5ae3b9662947ba0f2a8493858d724c4bdf3cd64190fb9022c24b057c1d90876a

AgentPolicy object:
0x2e6fb9f5d621d25ca92f8d6acf72a52dfc370dcc1b91adad82e72b73ba24272a

PrivacyReceipt object:
0xd22d4a0be6185497240b39e87c6937ec7592f746f45bc33075ad5192dd1ba9aa

OriginCriticReceipt object:
0x2cf07bb7d94b47099b815452751a7e44e285016c35f34f81001c527b0647f095
```

## Live Demo Transactions

```text
Split escrow coin tx:
C6vs8qABiQmikopYextgntX6pf3Aj1KKAfahPubucpMc

Create registry tx:
E4NspSFu7JktrDFoz3WuGW1218st3Ehw99EjDV1NLWJb

Create execution registry tx:
EZV4bbXM9bZPNgYJF1mEH3gorMvVPqBCaAQw2mcyuMTv

Create WorkOrder + AgentPolicy tx:
5m1SUijSep6pMRyJ44KyJqyxvL6e549RRyHZaAbDYjbP

Register policy generation tx:
5LtasfCqMKLFArid9g7Vr4CojEMsTupUAUhc6ab27vtH

Configure execution context tx:
99PDhvNKrmH3CVYTAztafqdWwNrvERovrwwZDfbEcYne

Configure privacy budget tx:
5nQnw1YguFC5WuVE6PkPgEzoKr9V2hYAMEFmakTGLfZg

Allocate privacy budget tx:
4oBiDt9vU7jkPv5oJppmJjNp9RV3ci6xYEFvNQG7VbTe

Configure origin firewall tx:
DAQMbCxBjsT4rncco2dLMJLaLJrxutXFFbUS3GxFGvCr

Allocate origin risk budget tx:
8vWxtHiH9YMVUPhho34kHj2HFsHmdA5vQ7jGBYkbd1HT

Origin critic safe receipt tx:
8f3oC9gNwsTXzuuujnuXwkYgKKwhVZKo73dpZfEybtJn

Privacy receipt tx:
8tWpyk9H2z3w1BRkwB2mab7nPX4zKctwxNTjNChq4v4Z

Execution-bound metered release tx:
ED8JSH5t12LXESyEh7WAvUts6cExjmoWL2nr5Y9dtCKf

Require Walrus availability tx:
HqahiMs6v5SbdJge8BEm6EjpApWfoKQaSksFZMWUuDnM

Agent delivery with availability tx:
GxugZzfoAkCrTmwFKcW1493s8i6Wn285HYQgos1aGH6e

Final release tx:
F5iPLTz3tH3j26YuQg9GqiLZLTyYL4tRdQnmSLEVoKe3
```

## Explorer Links

- Create WorkOrder + AgentPolicy: https://suiexplorer.com/txblock/5m1SUijSep6pMRyJ44KyJqyxvL6e549RRyHZaAbDYjbP?network=testnet
- Origin critic receipt: https://suiexplorer.com/txblock/8f3oC9gNwsTXzuuujnuXwkYgKKwhVZKo73dpZfEybtJn?network=testnet
- Privacy receipt: https://suiexplorer.com/txblock/8tWpyk9H2z3w1BRkwB2mab7nPX4zKctwxNTjNChq4v4Z?network=testnet
- Execution-bound metered release: https://suiexplorer.com/txblock/ED8JSH5t12LXESyEh7WAvUts6cExjmoWL2nr5Y9dtCKf?network=testnet
- Agent delivery with availability: https://suiexplorer.com/txblock/GxugZzfoAkCrTmwFKcW1493s8i6Wn285HYQgos1aGH6e?network=testnet
- Final release: https://suiexplorer.com/txblock/F5iPLTz3tH3j26YuQg9GqiLZLTyYL4tRdQnmSLEVoKe3?network=testnet

## Demo Coverage

This live testnet trail proves:

- Published Move package on Sui Testnet.
- Shared `GenerationRegistry` and `ExecutionBindingRegistry`.
- Funded `WorkOrder` and owned `AgentPolicy`.
- Registered policy generation.
- Execution context binding.
- Privacy budget allocation and `PrivacyReceipt`.
- Origin Critic Firewall configuration, risk budget allocation, and `OriginCriticReceipt`.
- Execution-bound metered settlement with one service receipt/nullifier.
- Walrus availability adapter path.
- Agent delivery through live policy/registry checks.
- Final release and final receipt path.

## Runbook-Only Until Installed

- Sui Prover: no machine-checked proof output claimed.
- Walrus: adapter fields are live; no real `walrus::blob::Blob` object is claimed.
- Seal: predicate surfaces are implemented; no live encrypt/decrypt proof is claimed.
- Nautilus/off-chain signer: no successful live attested release is claimed.
- Isolated critic service: on-chain critic receipt/quarantine surface is live; no live external critic service is claimed.
