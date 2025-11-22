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
   - Caches S&P Global SSA ratings (currently manual, Chainlink integration coming)
   - Emits `RatingUpdated` events for indexing

2. **SARMHook** (`src/hooks/SARMHook.sol`)
   - Uniswap v4 Hook implementing risk-aware swap logic
   - Reads ratings from SSAOracleAdapter
   - Applies dynamic fees and circuit breakers based on risk
   - Emits `RiskCheck` events for analytics

3. **MockERC20** (`src/mocks/MockERC20.sol`)
   - Test stablecoin tokens for development

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

## Implementation Phases

### Phase 1: Core Hook + Manual Ratings ✅
- [x] SSAOracleAdapter with manual rating setter
- [x] SARMHook with beforeSwap logic
- [x] Circuit breaker for high-risk ratings
- [x] Basic Forge tests

### Phase 2: Dynamic Fees (TODO)
- [ ] Fee tier calculation based on ratings
- [ ] Dynamic fee application in beforeSwap
- [ ] Tests for fee changes

### Phase 3: Chainlink Integration (TODO)
- [ ] Chainlink SSA feed interface
- [ ] refreshRating() implementation
- [ ] Mock Chainlink feed for tests

### Phase 4: Analytics + Frontend (TODO)
- [ ] The Graph subgraph
- [ ] Event indexing
- [ ] Risk dashboard UI

## Risk Rating Scale

- **1**: Minimal risk (e.g., well-collateralized, audited stablecoins)
- **2**: Low risk
- **3**: Medium risk
- **4**: Elevated risk (circuit breaker threshold)
- **5**: High risk (full freeze)

## License

MIT

## Contact

For ETHGlobal Buenos Aires 2025 judging and questions:
- [Add your contact info]
