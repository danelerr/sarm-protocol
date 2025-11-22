# SARM Protocol

**Stablecoin Automated Risk Management Protocol**

A Uniswap v4 Hook that makes stablecoin liquidity "risk-aware" using institutional-grade ratings.

## Overview

SARM Protocol integrates S&P Global Stablecoin Stability Assessment (SSA) ratings into Uniswap v4 pools to:
- Adjust pool fees dynamically based on stablecoin risk
- Enforce risk modes and circuit breakers when ratings degrade
- Provide LPs with protection against depeg events

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

2. **SARMHook** (`src/hooks/SARMHook.sol`)
   - Uniswap v4 Hook implementing risk-aware swap logic
   - Reads ratings from SSAOracleAdapter
   - Applies dynamic fees and circuit breakers based on risk
   - Emits `RiskCheck` and `FeeOverrideApplied` events for analytics

3. **IDataLinkVerifier** (`src/interfaces/IDataLinkVerifier.sol`)
   - Interface for Chainlink DataLink verifier proxy
   - Validates signed reports from Chainlink DON before updating state

4. **MockERC20** / **MockVerifier** (`src/mocks/`)
   - Test contracts for development and testing

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
│   │   └── SARMHook.sol           # Main Uniswap v4 Hook
│   ├── oracles/
│   │   └── SSAOracleAdapter.sol   # Rating oracle adapter
│   └── mocks/
│       └── MockERC20.sol          # Test tokens
├── test/
│   └── SARMHook.t.sol             # Forge tests
├── script/
│   └── Deploy.s.sol               # Deployment scripts
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

### [x] Core Features (Complete)
- [x] **SSAOracleAdapter** with manual rating setter (for testing/demo)
- [x] **Chainlink DataLink integration** with pull-based verification
  - On-chain report verification via DataLink verifier proxy
  - `refreshRatingWithReport()` for automated rating updates
  - Staleness checks and rating normalization
- [x] **SARMHook** with beforeSwap logic
- [x] **Circuit breaker** for high-risk ratings (FROZEN mode)
- [x] **Risk mode transitions** (NORMAL → ELEVATED_RISK → FROZEN)
- [x] **Dynamic risk-adjusted fees** with override mechanism (0.05%/0.10%/0.30%)
- [x] **Event emission** for analytics (RiskCheck, RiskModeChanged, FeeOverrideApplied)
- [x] **Off-chain scripts** for fetching DataLink reports and submitting to oracle
- [x] **Comprehensive Forge tests** (25/25 passing, including DataLink integration)

### [WIP] Future Enhancements
- [ ] Chainlink Automation for periodic rating refreshes
- [ ] The Graph subgraph for event indexing and analytics
- [ ] Risk dashboard UI showing ratings and fee history
- [ ] LP analytics dashboard (fees earned by risk level)

## Chainlink DataLink Integration

SARM Protocol uses **Chainlink DataLink** to bring institutional-grade S&P Global SSA ratings on-chain with cryptographic verification.

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
│  SARMHook.beforeSwap()                                   │
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

**Manual refresh:**
```bash
pnpm refresh:usdc  # Refresh USDC rating
pnpm refresh:usdt  # Refresh USDT rating
pnpm refresh:all   # Refresh all tokens
```

**Production automation:**
- Deploy script to Chainlink Automation
- Or use cron job for periodic refreshes
- Monitor with alerting on rating changes

For detailed setup, see [`scripts/README.md`](scripts/README.md).

**Dynamic Risk-Adjusted Fees:**

SARM Protocol implements dynamic LP fees that adjust automatically based on the credit risk of the stablecoins in a pool. This ensures LPs are compensated appropriately for the risk they bear, while maintaining competitive fees for high-quality stablecoins.

**Fee Structure:**

| Credit Rating | Risk Level | LP Fee | Basis Points | Use Case |
|--------------|------------|--------|--------------|----------|
| 1-2 | NORMAL | 500 | 0.05% (5 bps) | High-quality stablecoins (USDC, USDT) |
| 3 | ELEVATED_RISK | 1000 | 0.10% (10 bps) | Stablecoins showing stress signals |
| 4-5 | FROZEN | 3000* | 0.30% (30 bps) | Depeg risk/Circuit breaker active |

*Note: Rating 4+ typically triggers the circuit breaker, blocking swaps entirely. The 0.30% fee would only apply if special exceptions are implemented.

**How It Works:**

1. **Before every swap**, the hook queries both token ratings from the oracle
2. The **effective rating** is calculated as `max(rating0, rating1)` (worst-case)
3. The hook maps the effective rating to the appropriate fee using `_feeForRating()`
4. The fee is returned with `LPFeeLibrary.OVERRIDE_FEE_FLAG` to apply for that specific swap
5. A `FeeOverrideApplied` event is emitted for analytics and indexing

**Benefits:**

- **Risk Compensation**: LPs earn higher fees when holding riskier assets
- **Market Signals**: Fee changes provide real-time risk signals to traders
- **Capital Efficiency**: Low fees on safe pairs maximize trading volume
- **Circuit Breaker Integration**: Seamlessly works with risk gating system

## Risk Rating Scale

S&P Global SSA ratings map to SARM risk modes:

| Rating | S&P Assessment | SARM Mode | Action |
|--------|---------------|-----------|--------|
| **1** | Excellent stability | NORMAL | 0.05% fee |
| **2** | Good stability | NORMAL | 0.05% fee |
| **3** | Moderate stability | ELEVATED_RISK | 0.10% fee |
| **4** | High depeg risk | FROZEN | Swaps blocked |
| **5** | Critical/Imminent depeg | FROZEN | Swaps blocked |

**Risk Modes:**

- **NORMAL**: Ratings 1-2, normal operation with competitive fees
- **ELEVATED_RISK**: Rating 3, higher fees to compensate for increased risk
- **FROZEN**: Ratings 4-5, circuit breaker activated, all swaps blocked

## Key Features

### [SECURITY] Circuit Breaker Protection
Automatically blocks swaps when stablecoin ratings indicate high depeg risk, protecting LPs from toxic flow.

### [FEES] Dynamic Risk-Adjusted Fees
LP fees adjust in real-time based on S&P Global credit ratings, ensuring proper risk compensation.

### [ANALYTICS] Full Transparency
All risk assessments and fee changes emit events for on-chain analytics and The Graph indexing.

### [INTEGRATION] Institutional Data
Integrates **S&P Global SSA ratings** via **Chainlink DataLink** with on-chain cryptographic verification, bringing institutional-grade risk assessment to DeFi.

## Chainlink Bounty Highlights

SARM Protocol demonstrates advanced Chainlink integration:

[x] **DataLink Pull-Based Architecture**: Fetches signed reports off-chain, verifies on-chain  
[x] **On-Chain Verification**: Uses DataLink verifier proxy for DON signature validation  
[x] **Smart Contract State Changes**: Ratings directly control Uniswap v4 Hook behavior  
[x] **S&P Global SSA Feeds**: Real institutional-grade credit ratings for stablecoins  
[x] **Production-Ready**: Complete off-chain scripts + staleness checks + error handling  
[x] **Fully Tested**: 25 comprehensive tests including DataLink integration scenarios  

**Key Innovation**: Hook logic (fees + circuit breaker) is **entirely driven by Chainlink-fed SSA ratings**. No external dependencies. True decentralized risk management.

## License

MIT

## Contact

For ETHGlobal Buenos Aires 2025 judging and questions:
- [Add your contact info]
