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

contract DeploySAGE is Script {
    
    address constant POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
    address constant DAI = 0x174499EDe5E22a4A729e34e99fab4ec0bc7fA45e;
    
    uint8 constant USDC_RATING = 1;
    uint8 constant USDT_RATING = 1;
    uint8 constant DAI_RATING = 3;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        SSAOracleAdapter oracle = new SSAOracleAdapter(address(0));
        console2.log("Oracle:", address(oracle));

        oracle.setRatingManual(USDC, USDC_RATING);
        oracle.setRatingManual(USDT, USDT_RATING);
        oracle.setRatingManual(DAI, DAI_RATING);

        console2.log("Ratings: USDC=1, USDT=1, DAI=3");
        console2.log("Hook deployment requires CREATE2 with valid address");

        vm.stopBroadcast();
    }
}
