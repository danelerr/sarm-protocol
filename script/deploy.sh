#!/bin/bash

# SAGE Protocol Deployment Script
# Usage: ./deploy.sh [network]
# Networks: sepolia (Base Sepolia testnet), mainnet (Base mainnet)

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SAGE Protocol Deployment ===${NC}\n"

# Check network argument
NETWORK=${1:-dry-run}

if [ "$NETWORK" != "sepolia" ] && [ "$NETWORK" != "mainnet" ] && [ "$NETWORK" != "dry-run" ]; then
    echo -e "${RED}Error: Invalid network '$NETWORK'${NC}"
    echo "Usage: ./deploy.sh [sepolia|mainnet|dry-run]"
    exit 1
fi

# Validate environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set${NC}"
    echo "Set it with: export PRIVATE_KEY=0x..."
    exit 1
fi

echo -e "${YELLOW}Network: $NETWORK${NC}"
echo -e "${YELLOW}Deploying:${NC}"
echo "  1. SSAOracleAdapter (with hardcoded ratings)"
echo "  2. SAGEHook"
echo "  3. Pool: USDC/USDT (rating 1/1 -> fee 70)"
echo "  4. Pool: USDC/DAI (rating 1/3 -> fee 100)"
echo "  5. Pool: USDT/DAI (rating 1/3 -> fee 100)"
echo ""

# Dry run
if [ "$NETWORK" == "dry-run" ]; then
    echo -e "${YELLOW}Running dry-run (simulation only)...${NC}\n"
    forge script script/DeploySAGE.s.sol:DeploySAGE \
        --rpc-url https://sepolia.base.org \
        -vvv
    exit 0
fi

# Real deployment
if [ "$NETWORK" == "sepolia" ]; then
    RPC_URL="https://sepolia.base.org"
    EXPLORER="https://sepolia.basescan.org"
elif [ "$NETWORK" == "mainnet" ]; then
    RPC_URL="https://mainnet.base.org"
    EXPLORER="https://basescan.org"
    
    echo -e "${RED}WARNING: Deploying to MAINNET!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

echo -e "${GREEN}Deploying to $NETWORK...${NC}\n"

forge script script/DeploySAGE.s.sol:DeploySAGE \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    -vvv

echo -e "\n${GREEN}✓ Deployment complete!${NC}"
echo -e "View transactions at: ${EXPLORER}"
