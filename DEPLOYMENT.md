# SAGE Protocol - Deployed Contracts

## Base Sepolia Testnet (Chain ID: 84532)

### Core Contracts
- **Oracle (SSAOracleAdapter)**: `0x444a4967487B655675c7F3EF0Ec68f93ae9f6866`
  - [View on Basescan](https://sepolia.basescan.org/address/0x444a4967487B655675c7F3EF0Ec68f93ae9f6866)
  - ✅ Verified on Sourcify
  
- **Hook (SAGEHook)**: `0x828e95D79fC2fD10882C13042edDe1071BB2E080`
  - [View on Basescan](https://sepolia.basescan.org/address/0x828e95D79fC2fD10882C13042edDe1071BB2E080)
  - ✅ Verified on Sourcify
  
- **PoolManager**: `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` (Uniswap v4)

### Token Addresses
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e` (Rating: 1)
- **USDT**: `0x7169D38820dfd117C3FA1f22a697dBA58d90BA06` (Rating: 1)
- **DAI**: `0x174499EDe5E22a4A729e34e99fab4ec0bc7fA45e` (Rating: 3)

### Pool Configurations
All pools initialized with:
- Fee tier: 3000 (0.30%)
- Tick spacing: 60
- Hook: SAGEHook with dynamic fees

**USDC/USDT Pool**
- Currency0: USDC
- Currency1: USDT
- Dynamic Fee: 70 bps (0.70%) - 30% discount due to rating 1

**USDC/DAI Pool**
- Currency0: USDC
- Currency1: DAI  
- Dynamic Fee: 70 bps for USDC side, 100 bps for DAI side

**DAI/USDT Pool**
- Currency0: DAI
- Currency1: USDT
- Dynamic Fee: 70 bps for USDT side, 100 bps for DAI side

### Dynamic Fee Structure
- **Rating 1-2**: 70 basis points (0.70%) - Premium tier with 30% discount
- **Rating 3-5**: 100 basis points (1.00%) - Standard tier

### Deployment Info
- Deployer Address: `0x2d48B0De46f72F79050ba9C4C8f97bF49e08Bd2d`
- Network: Base Sepolia
- RPC: https://sepolia.base.org
- Explorer: https://sepolia.basescan.org/

### Verification
To verify contracts on Basescan:
```bash
forge verify-contract <ADDRESS> <CONTRACT_PATH>:<CONTRACT_NAME> --chain-id 84532 --watch
```

Example:
```bash
forge verify-contract 0x0B65AAA64cB8f0225f02E17423f7f31BB8107c54 src/oracles/SSAOracleAdapter.sol:SSAOracleAdapter --chain-id 84532 --watch
```
