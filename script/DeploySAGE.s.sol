// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {SAGEHook} from "../src/hooks/SAGEHook.sol";
import {SSAOracleAdapter} from "../src/oracles/SSAOracleAdapter.sol";

/**
 * @title DeploySAGE
 * @notice Deployment script for SAGE Protocol
 * @dev Deploys: Oracle + Hook + 3 Pools (USDC/USDT, USDC/DAI, USDT/DAI)
 */
contract DeploySAGE is Script {
    
    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    
    // Token addresses (Base Sepolia)
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
    address constant DAI = 0x174499EDe5E22a4A729e34e99fab4ec0bc7fA45e;
    
    // Fake ratings for testing dynamic fees
    uint8 constant USDC_RATING = 1;  // Premium -> 30% discount (fee 70)
    uint8 constant USDT_RATING = 1;  // Premium -> 30% discount (fee 70)
    uint8 constant DAI_RATING = 3;   // Standard -> normal fee (fee 100)

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== SAGE Protocol Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Pool Manager:", POOL_MANAGER);
        console2.log("");

        // 1. Deploy SSAOracleAdapter (with fake verifier)
        console2.log("1. Deploying SSAOracleAdapter...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        SSAOracleAdapter oracle = new SSAOracleAdapter(
            address(0) // Mock verifier address (not using CRE for now)
        );
        console2.log("   Oracle deployed at:", address(oracle));

        // 2. Set hardcoded ratings (simulating CRE data)
        console2.log("\n2. Setting hardcoded ratings...");
        console2.log("   USDC rating:", USDC_RATING, "-> Fee: 70 (0.007%, 30% discount)");
        oracle.setRatingManual(USDC, USDC_RATING);
        
        console2.log("   USDT rating:", USDT_RATING, "-> Fee: 70 (0.007%, 30% discount)");
        oracle.setRatingManual(USDT, USDT_RATING);
        
        console2.log("   DAI rating:", DAI_RATING, "-> Fee: 100 (0.01%, normal)");
        oracle.setRatingManual(DAI, DAI_RATING);

        // 3. Show hook deployment info
        console2.log("\n3. SAGEHook Deployment Info");
        console2.log("   Hook deployment requires CREATE2 with valid address");
        console2.log("   Required flags: BEFORE_INITIALIZE_FLAG | BEFORE_SWAP_FLAG");
        console2.log("   Use HookMiner (from Uniswap v4-periphery) to find valid salt");
        console2.log("   Example command:");
        console2.log("     forge script script/MineHookAddress.s.sol");

        vm.stopBroadcast();

        // 4. Deployment Summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("Oracle:", address(oracle));
        console2.log("Hook: NOT DEPLOYED (requires HookMiner)");
        console2.log("\nRatings configured:");
        console2.log("USDC: 1 (premium) -> Fee 70 (30% discount)");
        console2.log("USDT: 1 (premium) -> Fee 70 (30% discount)");
        console2.log("DAI:  3 (standard) -> Fee 100 (normal)");
        console2.log("\nOracle deployed successfully!");
        console2.log("\nNext steps:");
        console2.log("1. Use HookMiner to find valid CREATE2 salt for hook");
        console2.log("2. Deploy hook with: new SAGEHook{salt: minedSalt}(...)");
        console2.log("3. Initialize 3 pools: USDC/USDT, USDC/DAI, USDT/DAI");
        console2.log("4. Add liquidity and test dynamic fees");
        console2.log("\nFor testing without pools, you can:");
        console2.log("- Test oracle ratings: cast call", address(oracle), "\"getRating(address)\"");
        console2.log("- Update ratings: cast send", address(oracle), "\"setRatingManual(address,uint8)\"");
    }
}
