# SAGE Protocol

**Stablecoin Automated Risk Management Protocol**

A Uniswap v4 Hook that makes stablecoin liquidity "risk-aware" using institutional-grade ratings.

## Overview

SAGE Protocol integrates S&P Global Stablecoin Stability Assessment (SSA) ratings into Uniswap v4 pools to:
- **Reward high-quality stablecoins** with 30% fee discounts (ratings 1-2)
- Apply standard pricing to normal stablecoins (ratings 3-5)
- **No punitive measures** - swaps always allowed, only fee adjustments
- Provide transparent risk signals to LPs and traders

## Built For

- **ETHGlobal Buenos Aires 2025**
- **Uniswap v4 Stable-Asset Hooks Track**
- **Chainlink Bounty** (S&P Global SSA feeds)
- **The Graph Bounty** (Risk analytics & dashboards)

## Architecture

### Core Contracts

1. **SSAOracleAdapter** (`src/oracles/SSAOracleAdapter.sol`)
   - Single source of truth for stablecoin ratings on-chain
   - Integrates with **Chainlink DataLink** for S&P Global SSA ratings via pull-based verification
   - On-chain signature verification via DataLink verifier proxy
   - Emits `RatingUpdated` events for indexing

2. **SAGEHook** (`src/hooks/SAGEHook.sol`)
   - Uniswap v4 Hook implementing risk-aware swap logic
   - Reads ratings from SSAOracleAdapter
   - Applies dynamic fees and circuit breakers based on risk
   - Emits `RiskCheck` and `FeeOverrideApplied` events for analytics

3. **IDataLinkVerifier** (`src/interfaces/IDataLinkVerifier.sol`)
   - Interface for Chainlink DataLink verifier proxy
   - Validates signed reports from Chainlink DON before updating state

4. **MockERC20** / **MockVerifier** (`src/mocks/`)
   - Test contracts for development and testing

## Quick Start Deployment

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Private key with Base Sepolia ETH
- Uniswap v4 PoolManager address (from ETHGlobal resources)

### 1. Setup Environment

```bash
# Clone and setup
git clone https://github.com/yourusername/sarm-protocol.git
cd sarm-protocol

# Copy environment template
cp .env.example .env

# Edit .env and set:
# - PRIVATE_KEY (your deployer key)
# - POOL_MANAGER (Uniswap v4 on Base Sepolia)
# - Token addresses are pre-filled for Base Sepolia
```

### 2. Deploy Everything

```bash
# Option A: Using helper script
./script/deploy.sh sepolia

# Option B: Direct forge command
forge script script/DeploySARM.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

This single script will:
1. Deploy `SSAOracleAdapter` (with mocked ratings)
2. Set hardcoded ratings: USDC=1, USDT=1, DAI=3
3. Deploy `SAGEHook` with oracle integration
4. Initialize 3 pools with dynamic fees:
   - USDC/USDT (both rating 1 → 70 bps fee, 30% discount)
   - USDT/DAI (max rating 3 → 100 bps fee, normal)
   - DAI/USDC (max rating 3 → 100 bps fee, normal)

### 3. Verify Deployment

```bash
# Check oracle ratings
cast call <ORACLE_ADDRESS> "getRating(address)" <USDC_ADDRESS>

# Should return (1, <timestamp>) for USDC
```

📚 **Full deployment guide**: See [script/README.md](script/README.md) for:
- Hook address mining (CREATE2)
- Manual rating updates
- Troubleshooting
- Next steps (liquidity, swaps)

## Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/sarm-protocol.git
cd sarm-protocol

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v4-core
forge install Uniswap/v4-periphery
forge install foundry-rs/forge-std

# Build contracts
forge build

# Run tests
forge test

# Run tests with verbosity
forge test -vvv
```

## Project Structure

```
sarm-protocol/
├── src/
│   ├── hooks/
│   │   └── SAGEHook.sol           # Main Uniswap v4 Hook
│   ├── oracles/
│   │   └── SSAOracleAdapter.sol   # Rating oracle adapter
│   ├── interfaces/
│   │   └── IDataLinkVerifier.sol  # DataLink verifier interface
│   └── mocks/
│       └── MockERC20.sol          # Test tokens
├── test/
│   └── SAGEHook.t.sol             # Forge tests (26/26 passing)
├── script/
│   └── Deploy.s.sol               # Deployment scripts
├── cre/                           # Chainlink Runtime Environment
│   ├── workflows/
│   │   └── ssa-refresh.ts         # Automated rating updates
│   ├── cre.toml                   # CRE configuration
│   └── README.md                  # CRE setup guide
├── scripts/                       # Manual rating refresh scripts
│   ├── refresh-rating.ts          # Single token refresh
│   └── refresh-all.ts             # Batch refresh
├── lib/                           # Dependencies (gitignored)
├── foundry.toml                   # Foundry configuration
└── README.md
```

## Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testSwapWithLowRisk

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

## Implementation Status

### ✅ Core Features (Complete)
- [x] **SSAOracleAdapter** with manual rating setter (for testing/demo)
- [x] **Chainlink DataLink integration** with pull-based verification
  - On-chain report verification via DataLink verifier proxy
  - `refreshRatingWithReport()` for automated rating updates
  - Staleness checks and rating normalization
- [x] **Chainlink Runtime Environment (CRE) workflow**
  - Complete workflow logic designed and implemented
  - Demonstrates automated rating updates via cron trigger architecture
  - HTTP capability for DataLink API + EVM write capability for on-chain updates
  - Full documentation in `cre/README.md`
  - **Note**: Full deployment requires CRE Early Access (application pending)
- [x] **SAGEHook with REWARD-BASED MODEL** (NEW! 🎁)
  - **30% fee discount** for premium stablecoins (ratings 1-2)
  - **Standard pricing** for normal stablecoins (ratings 3-5)
  - **NO circuit breakers** - swaps always allowed
  - **NO punitive measures** - only rewards for quality
- [x] **Dynamic fee flag enforcement** (beforeInitialize)
- [x] **Dynamic risk-adjusted fees** (beforeSwap):
  - Ratings 1-2: 0.007% (70 bps) - 30% discount ✨
  - Ratings 3-5: 0.01% (100 bps) - Standard pricing
- [x] **Event emission** for analytics (RiskCheck, RiskModeChanged, FeeOverrideApplied)
- [x] **Off-chain scripts** for manual DataLink report fetching (fully functional for demo)
- [x] **Comprehensive Forge tests** (26/26 passing ✅)

### 🔄 Recent Updates
- **Nov 23, 2025**: Complete model transformation from punitive to reward-based
  - Eliminated FROZEN state and circuit breakers
  - Simplified to 2-tier fee structure (discount vs normal)
  - All 26 tests updated and passing
  - See [REWARD_MODEL.md](./REWARD_MODEL.md) for detailed explanation

### 🚀 Future Enhancements
- [ ] **CRE Early Access**: Deploy to production DON (requires approval at cre.chain.link)
- [ ] **The Graph subgraph** for event indexing and analytics
- [ ] **Risk dashboard UI** showing ratings and fee history
- [ ] **LP analytics dashboard** (fees earned by risk level)
- [ ] **Additional stablecoins** (FRAX, TUSD, etc.)

## Chainlink DataLink Integration

SAGE Protocol uses **Chainlink DataLink** to bring institutional-grade S&P Global SSA ratings on-chain with cryptographic verification.

### Architecture

**Pull-Based Verification Flow:**

```
┌──────────────┐     1. Fetch Report      ┌──────────────┐
│              │ ───────────────────────> │   DataLink   │
│  Off-Chain   │  (HTTP + credentials)    │   API        │
│  Script      │                          │              │
│              │ <─────────────────────── │ (Signed DON  │
└──────────────┘     2. Signed Report     │  Report)     │
       │                                   └──────────────┘
       │ 3. Submit Report
       ↓
┌──────────────────────────────────────────────────────────┐
│  SSAOracleAdapter.refreshRatingWithReport(token, report) │
│                                                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 4. Verify Signature via DataLink Verifier Proxy  │  │
│  │    ✓ Check DON signature                         │  │
│  │    ✓ Validate feed ID                            │  │
│  │    ✓ Check staleness                             │  │
│  └───────────────────────────────────────────────────┘  │
│                                                           │
│  5. Update On-Chain State: tokenRating[token] = X       │
│  6. Emit RatingUpdated(token, oldRating, newRating)     │
└──────────────────────────────────────────────────────────┘
       │
       │ 7. Hook reads rating on next swap
       ↓
┌──────────────────────────────────────────────────────────┐
│  SAGEHook.beforeSwap()                                   │
│  • Applies dynamic fees based on rating                  │
│  • Enforces circuit breaker if rating ≥ 4                │
└──────────────────────────────────────────────────────────┘
```

**DataLink v4 Payload:**
```solidity
// Verified payload from verifier.verify() contains 8 fields:
(
    bytes32 feedId,              // Feed identifier  
    uint32 validFromTimestamp,   // Rating validity start
    uint32 observationsTimestamp, // Observation time
    uint192 nativeFee,           // Native token fee
    uint192 linkFee,             // LINK token fee
    uint32 expiresAt,            // Expiration time
    int192 benchmarkPrice,       // SSA rating * 1e18 (e.g., 3e18 = rating 3)
    uint32 marketStatus          // Market status flag
)

// Normalization: benchmarkPrice / 1e18 = rating (1-5)
```

See [`DATALINK_V4_FORMAT.md`](DATALINK_V4_FORMAT.md) for detailed technical documentation.

### Security & Permissions

**Oracle Updates:**
- `refreshRatingWithReport()` is **permissionless** - anyone can submit a DataLink report
- Security guaranteed by:
  - [x] DataLink verifier validates DON signatures on-chain
  - [x] Feed ID validation ensures correct data source
  - [x] Staleness checks reject old reports (24h MAX_STALENESS)
  - [x] Expiration validation via `expiresAt` field
  - [x] Rating normalization validates 1-5 range
- **Why permissionless?** Allows any party to pay gas for rating updates, increasing system liveness. Invalid reports are rejected by verifier.

**Admin Functions (owner-only):**
- `setRatingManual()` - Manual rating setter (for testing/demos)
- `setFeedId()` - Configure DataLink feed IDs per token

**Future Enhancements:**
- Consider using Chainlink Automation for periodic refreshes
- Add role-based access control for production environments
- Monitor `marketStatus` field for additional validation

### Setup Instructions

1. **Deploy Contracts**
```bash
forge script script/Deploy.s.sol --broadcast --verify
```

2. **Configure DataLink Feed IDs**
```bash
# Get feed IDs from https://data.chain.link
# Example: SSA-USDC, SSA-USDT, SSA-DAI

cast send $SSA_ORACLE_ADDRESS \
  "setFeedId(address,bytes32)" \
  $USDC_ADDRESS \
  0x... # Feed ID from data.chain.link
```

3. **Setup Off-Chain Scripts**
```bash
# Install dependencies
pnpm install

# Configure environment
cp .env.example .env
# Edit .env with your DataLink credentials

# Test refresh
pnpm refresh:usdc
```

### DataLink Credentials

Get your DataLink API credentials:
1. Visit [data.chain.link](https://data.chain.link)
2. Sign up / log in
3. Navigate to your dashboard
4. Copy your `username` and `secret`
5. Add to `.env`:
```bash
DATALINK_USER=your_username
DATALINK_SECRET=your_secret
```

### Usage

**Option 1: Chainlink Runtime Environment (CRE) - Recommended**

SAGE Protocol includes a CRE workflow for automated, decentralized rating updates:

```bash
cd cre

# Setup secrets
cre secrets set DATALINK_USER "your-username"
cre secrets set DATALINK_SECRET "your-secret"
cre secrets set PRIVATE_KEY "0x..."

# Configure cre.toml with contract addresses and feed IDs

# Test locally
npm run dev

# Deploy to production DON
npm run deploy
```

**Benefits:**
- Automated execution every 10 minutes via cron trigger
- Byzantine Fault Tolerant consensus across DON nodes
- No single point of failure
- Monitoring via CRE UI at [cre.chain.link](https://cre.chain.link)

See [`cre/README.md`](cre/README.md) for complete setup instructions.

**Option 2: Manual Scripts (Local/Testing)**

For local development and testing:

```bash
pnpm install

# Configure environment
cp .env.example .env
# Edit .env with your DataLink credentials

# Manual refresh
pnpm refresh:usdc  # Refresh USDC rating
pnpm refresh:usdt  # Refresh USDT rating
pnpm refresh:all   # Refresh all tokens
```

For detailed script setup, see [`scripts/README.md`](scripts/README.md).

**Dynamic Risk-Adjusted Fees:**

SAGE Protocol implements dynamic LP fees that **reward high-quality stablecoins** with discounts, while maintaining standard pricing for normal stablecoins. This incentivizes liquidity provision for safe assets without punitive measures for standard ones.

**Fee Structure (Reward-Based Model):**

| Credit Rating | Risk Level | LP Fee | Basis Points | Discount | Description |
|--------------|------------|--------|--------------|----------|-------------|
| 1-2 | NORMAL | 70 | 0.007% (0.7 bps) | **30% OFF** 🎁 | Premium stablecoins rewarded |
| 3-5 | ELEVATED_RISK | 100 | 0.01% (1 bps) | Standard | Normal pricing, no penalties |

**Philosophy:**
- ✅ **Reward quality** - Premium tokens get 30% fee discount
- ✅ **No punishment** - All ratings allow swaps with fair pricing
- ✅ **Simplicity** - Only 2 fee tiers, easy to understand
- ✅ **Predictability** - No surprises, no circuit breakers

**How It Works:**

1. **Before every swap**, the hook queries both token ratings from the oracle
2. The **effective rating** is calculated as `max(rating0, rating1)` (worst-case)
3. The hook maps the effective rating to the appropriate fee:
   - Ratings 1-2 → 70 bps (30% discount)
   - Ratings 3-5 → 100 bps (standard)
4. The fee is returned with `LPFeeLibrary.OVERRIDE_FEE_FLAG` to apply for that specific swap
5. A `FeeOverrideApplied` event is emitted for analytics and indexing

**Benefits:**

- **Incentivizes Quality**: LPs earn more competitive fees with premium stablecoins
- **Market Signals**: Fee differences provide transparent risk signals
- **Capital Efficiency**: Discounts maximize trading volume on safe pairs
- **No Disruption**: Trading always available, no sudden blocks

## Risk Rating Scale

S&P Global SSA ratings map to SARM risk modes:

| Rating | S&P Assessment | SARM Mode | Fee | Action |
|--------|---------------|-----------|-----|--------|
| **1** | Excellent stability | NORMAL | 0.007% (30% discount) | ✅ Reward |
| **2** | Good stability | NORMAL | 0.007% (30% discount) | ✅ Reward |
| **3** | Moderate stability | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |
| **4** | Higher risk | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |
| **5** | High risk | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |

**Risk Modes:**

- **NORMAL**: Ratings 1-2, premium tokens with 30% fee discount
- **ELEVATED_RISK**: Ratings 3-5, standard tokens with normal pricing
- ~~**FROZEN**~~: Removed - no circuit breakers or swap blocking

## Key Features

### [REWARDS] Discount for Quality
Automatically rewards high-quality stablecoins (ratings 1-2) with 30% fee discount, incentivizing liquidity for safe assets.

### [FEES] Two-Tier Pricing
Simple fee structure: discount (70 bps) for premium, standard (100 bps) for normal. No punitive measures.

### [ANALYTICS] Full Transparency
All risk assessments and fee changes emit events for on-chain analytics and The Graph indexing.

### [INTEGRATION] Institutional Data
Integrates **S&P Global SSA ratings** via **Chainlink DataLink** with on-chain cryptographic verification, bringing institutional-grade risk assessment to DeFi.

## Chainlink Bounty Highlights

SAGE Protocol demonstrates advanced Chainlink integration:

[x] **DataLink Pull-Based Architecture**: Fetches signed reports off-chain, verifies on-chain  
[x] **On-Chain Verification**: Uses DataLink verifier proxy for DON signature validation  
[x] **Smart Contract State Changes**: Ratings directly control Uniswap v4 Hook behavior  
[x] **S&P Global SSA Feeds**: Real institutional-grade credit ratings for stablecoins  
[x] **Chainlink Runtime Environment (CRE)**: Decentralized automated execution  
  - Cron-triggered workflows (every 10 minutes)
  - Byzantine Fault Tolerant consensus across DON nodes
  - HTTP capability for DataLink API integration
  - EVM write capability for on-chain oracle updates
  - Eliminates single points of failure
[x] **Production-Ready**: Complete CRE workflow + manual scripts + staleness checks + error handling  
[x] **Fully Tested**: 26 comprehensive tests including DataLink integration + beforeInitialize validation  

**Key Innovation**: Hook logic (fees + circuit breaker) is **entirely driven by Chainlink-fed SSA ratings**. No external dependencies. True decentralized risk management with automated updates via CRE.

## License

MIT

## Contact

For ETHGlobal Buenos Aires 2025 judging and questions:
- [Add your contact info]
