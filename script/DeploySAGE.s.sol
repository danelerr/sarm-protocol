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
    
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
    address constant DAI = 0x174499EDe5E22a4A729e34e99fab4ec0bc7fA45e;
    
    uint8 constant USDC_RATING = 1;
    uint8 constant USDT_RATING = 1;
    uint8 constant DAI_RATING = 3;
    
    function mineSalt(SSAOracleAdapter oracle) internal view returns (address, bytes32) {
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG);
        uint160 FLAG_MASK = 0x3FFF;
        flags = flags & FLAG_MASK;
        
        bytes memory constructorArgs = abi.encode(IPoolManager(POOL_MANAGER), oracle);
        bytes memory creationCodeWithArgs = abi.encodePacked(
            type(SAGEHook).creationCode,
            constructorArgs
        );
        
        address hookAddress;
        for (uint256 salt = 0; salt < 100000; salt++) {
            hookAddress = computeAddress(CREATE2_DEPLOYER, salt, creationCodeWithArgs);
            
            if ((uint160(hookAddress) & FLAG_MASK) == flags && hookAddress.code.length == 0) {
                return (hookAddress, bytes32(salt));
            }
        }
        
        revert("HookMiner: could not find salt");
    }
    
    function computeAddress(address deployer, uint256 salt, bytes memory creationCodeWithArgs)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xFF), deployer, salt, keccak256(creationCodeWithArgs)))))
        );
    }
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        SSAOracleAdapter oracle = new SSAOracleAdapter(address(0));
        console2.log("Oracle:", address(oracle));

        oracle.setRatingManual(USDC, USDC_RATING);
        oracle.setRatingManual(USDT, USDT_RATING);
        oracle.setRatingManual(DAI, DAI_RATING);
        console2.log("Ratings configured");

        vm.stopBroadcast();
        
        console2.log("Mining salt for hook...");
        (address predictedHook, bytes32 salt) = mineSalt(oracle);
        console2.log("Predicted hook:", predictedHook);
        console2.log("Salt:", uint256(salt));
        
        vm.startBroadcast(deployerPrivateKey);
        
        SAGEHook hook = new SAGEHook{salt: salt}(IPoolManager(POOL_MANAGER), oracle);
        require(address(hook) == predictedHook, "Hook address mismatch");
        console2.log("Hook deployed:", address(hook));
        
        IPoolManager manager = IPoolManager(POOL_MANAGER);
        
        PoolKey memory poolKeyUSDC_USDT = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        manager.initialize(poolKeyUSDC_USDT, 79228162514264337593543950336);
        console2.log("Pool USDC/USDT initialized");
        
        PoolKey memory poolKeyUSDC_DAI = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(DAI),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        manager.initialize(poolKeyUSDC_DAI, 79228162514264337593543950336);
        console2.log("Pool USDC/DAI initialized");
        
        PoolKey memory poolKeyUSDT_DAI = PoolKey({
            currency0: Currency.wrap(DAI),
            currency1: Currency.wrap(USDT),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        manager.initialize(poolKeyUSDT_DAI, 79228162514264337593543950336);
        console2.log("Pool DAI/USDT initialized");

        vm.stopBroadcast();
        console2.log("DEPLOYMENT COMPLETE!");
    }
}
