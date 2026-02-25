# ₿ Bitcoin-Conditional NFT Vesting

> Lock NFTs on Stacks and unlock them only when a target **Bitcoin block height** is reached — trustlessly enforced on-chain via a trusted oracle.

---

## 📖 Overview

`btc-nft-vesting.clar` is a Clarity smart contract that implements **Bitcoin-height-gated NFT vesting**. An owner mints a vesting entry (backed by an NFT), targeting a specific Bitcoin block height as the unlock condition. Until that BTC height is confirmed by the oracle, the NFT stays locked in the contract. Once confirmed, the designated recipient can claim it.

This enables:
- 🎁 **Time-locked NFT gifts** tied to real Bitcoin milestones
- 🔐 **Vesting schedules** for teams or investors using BTC as the clock
- 🏦 **Conditional NFT escrow** without a centralized custodian

---

## 🏗️ Architecture

| Component | Description |
|-----------|-------------|
| `vested-nft` | SIP-009-style NFT trait, one token per vesting schedule |
| `vesting-schedules` | Stores owner, recipient, BTC unlock height, metadata URI, and claim status |
| `oracle-principal` | Trusted address that reports confirmed BTC block heights |
| `confirmed-btc-height` | Latest BTC height accepted from the oracle |

---

## ⚙️ Core Functions

### 🔒 Admin & Oracle

| Function | Who | Description |
|----------|-----|-------------|
| `set-oracle(new-oracle)` | Contract owner | Update the oracle principal |
| `set-paused(paused)` | Contract owner | Pause/unpause the contract |
| `update-btc-height(new-height)` | Oracle | Push a new confirmed BTC block height |

### 📝 Vesting Lifecycle

| Function | Who | Description |
|----------|-----|-------------|
| `create-vesting(recipient, btc-unlock-height, metadata-uri, token-amount)` | Anyone | Create a new vesting schedule and mint an NFT into escrow |
| `claim-vested-nft(token-id)` | Recipient | Claim the NFT once BTC height condition is met |
| `revoke-vesting(token-id)` | Owner | Revoke unclaimed vesting before unlock height is reached |
| `update-metadata-uri(token-id, new-uri)` | Owner | Update the NFT metadata URI before it is claimed |

### 🔍 Read-Only

| Function | Description |
|----------|-------------|
| `get-vesting-schedule(token-id)` | Fetch all details for a vesting entry |
| `is-claimable(token-id)` | Check if a token is currently claimable |
| `get-recipient-tokens(recipient)` | List all token IDs for a recipient |
| `get-owner-tokens(owner)` | List all token IDs created by an owner |
| `get-confirmed-btc-height` | Current oracle-confirmed BTC height |
| `get-total-vested` | Total vesting schedules ever created |
| `get-total-claimed` | Total NFTs successfully claimed |

---

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed

### Clone & Setup

```bash
git clone <your-repo-url>
cd Bitcoin-conditional-NFT-vesting
clarinet check
```

### Run Console

```bash
clarinet console
```

### Example Flow

```clarity
;; 1. Oracle updates BTC height (oracle wallet)
(contract-call? .btc-nft-vesting update-btc-height u880000)

;; 2. Owner creates a vesting schedule, targeting BTC block 900000
(contract-call? .btc-nft-vesting create-vesting
    'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
    u900000
    "ipfs://QmExampleHash"
    u1
)

;; 3. Check if claimable
(contract-call? .btc-nft-vesting is-claimable u1)

;; 4. Once BTC height >= 900000, recipient claims
(contract-call? .btc-nft-vesting claim-vested-nft u1)
```

---

## 🛡️ Security Model

- 🔑 Only the **oracle** can advance the BTC height, and only **forward** (no rollbacks)
- ⏸️ Owner can **pause** the contract to halt new vesting and claims in an emergency
- 🔄 Owners can **revoke** only before the BTC unlock height is reached and the NFT is unclaimed
- ✅ All user inputs are validated with descriptive error codes

### Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| `u100` | `ERR-NOT-OWNER` | Caller is not the contract owner |
| `u101` | `ERR-NOT-FOUND` | Token ID does not exist |
| `u102` | `ERR-ALREADY-CLAIMED` | NFT has already been claimed |
| `u103` | `ERR-VESTING-NOT-MET` | BTC height condition not yet reached |
| `u104` | `ERR-INVALID-PARAMS` | Invalid input parameters |
| `u105` | `ERR-NOT-AUTHORIZED` | Caller is not the designated recipient |
| `u106` | `ERR-ALREADY-EXISTS` | Token already exists |
| `u107` | `ERR-ORACLE-ONLY` | Caller is not the oracle |
| `u108` | `ERR-PAUSED` | Contract is currently paused |

---

## 📂 Project Structure

```
.
├── contracts/
│   └── btc-nft-vesting.clar   # Core vesting contract
├── tests/                      # Vitest test files
├── settings/                   # Clarinet network configs
├── Clarinet.toml               # Project configuration
└── README.md
```

---

## 📜 License

MIT
