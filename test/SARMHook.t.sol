// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {SARMHook} from "../src/hooks/SARMHook.sol";
import {SSAOracleAdapter} from "../src/oracles/SSAOracleAdapter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title SARMHookTest
 * @notice Comprehensive tests for SARM Protocol hook and oracle adapter.
 */
contract SARMHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    SSAOracleAdapter public oracle;
    SARMHook public hook;
    
    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC20 public mockDAI;

    PoolKey public poolKey;
    PoolId public poolId;

    address public constant ALICE = address(0xABCD);
    address public constant BOB = address(0xBEEF);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Deploy Uniswap v4 core contracts using Deployers helper
        deployFreshManagerAndRouters();

        // Deploy mock stablecoins
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        mockUSDT = new MockERC20("Mock USDT", "USDT", 6);
        mockDAI = new MockERC20("Mock DAI", "DAI", 18);

        // Deploy oracle adapter
        oracle = new SSAOracleAdapter();

        // Deploy SARM Hook
        // Note: Hook address must satisfy Uniswap v4 address requirements
        // For testing, we deploy directly; in production, CREATE2 is used
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        address hookAddress = address(flags);
        
        // Deploy hook at the expected address using vm.etch (for testing)
        deployCodeTo("SARMHook.sol", abi.encode(manager, oracle), hookAddress);
        hook = SARMHook(hookAddress);

        // Initialize pool with hook
        poolKey = PoolKey({
            currency0: Currency.wrap(address(mockUSDC)),
            currency1: Currency.wrap(address(mockUSDT)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG, // Dynamic fees (Phase 2)
            tickSpacing: 60,
            hooks: hook
        });
        poolId = poolKey.toId();

        // Initialize the pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);

        // Mint tokens to test users
        mockUSDC.mint(ALICE, 1_000_000e6);
        mockUSDT.mint(ALICE, 1_000_000e6);
        mockUSDC.mint(BOB, 1_000_000e6);
        mockUSDT.mint(BOB, 1_000_000e6);

        // Approve tokens for pool manager
        vm.startPrank(ALICE);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        mockUSDT.approve(address(swapRouter), type(uint256).max);
        mockUSDC.approve(address(modifyLiquidityRouter), type(uint256).max);
        mockUSDT.approve(address(modifyLiquidityRouter), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        mockUSDT.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();

        // Add initial liquidity
        vm.prank(ALICE);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000e6, // 1000 USDC worth of liquidity
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ORACLE ADAPTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OracleAdapter_SetRatingManual() public {
        // Set rating for USDC
        vm.expectEmit(true, false, false, true);
        emit SSAOracleAdapter.RatingUpdated(address(mockUSDC), 0, 1);
        
        oracle.setRatingManual(address(mockUSDC), 1);

        (uint8 rating, uint256 lastUpdated) = oracle.getRating(address(mockUSDC));
        assertEq(rating, 1);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_OracleAdapter_UpdateRating() public {
        // Set initial rating
        oracle.setRatingManual(address(mockUSDC), 1);

        // Update to higher rating
        vm.expectEmit(true, false, false, true);
        emit SSAOracleAdapter.RatingUpdated(address(mockUSDC), 1, 4);
        
        oracle.setRatingManual(address(mockUSDC), 4);

        (uint8 rating, ) = oracle.getRating(address(mockUSDC));
        assertEq(rating, 4);
    }

    function test_OracleAdapter_RevertInvalidRating() public {
        vm.expectRevert(SSAOracleAdapter.InvalidRating.selector);
        oracle.setRatingManual(address(mockUSDC), 0);

        vm.expectRevert(SSAOracleAdapter.InvalidRating.selector);
        oracle.setRatingManual(address(mockUSDC), 6);
    }

    function test_OracleAdapter_RevertTokenNotRated() public {
        vm.expectRevert(SSAOracleAdapter.TokenNotRated.selector);
        oracle.getRating(address(mockDAI));
    }

    /*//////////////////////////////////////////////////////////////
                           SARM HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SARMHook_SwapWithLowRisk() public {
        // Set low risk ratings (1-2)
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Perform swap - should succeed
        vm.prank(BOB);
        bool zeroForOne = true;
        int256 amountSpecified = 1000e6; // Swap 1000 USDC
        
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        // Check that pool is in NORMAL mode
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.NORMAL));
    }

    function test_SARMHook_SwapWithElevatedRisk() public {
        // Set medium risk rating (3)
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 3);

        // Perform swap - should succeed but in ELEVATED_RISK mode
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1000e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );

        // Check that pool is in ELEVATED_RISK mode
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.ELEVATED_RISK));
    }

    function test_SARMHook_SwapBlockedHighRisk() public {
        // Set high risk rating (4+)
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 4);

        // Attempt swap - should revert
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1000e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

    function test_SARMHook_RiskModeTransition() public {
        // Start with low risk
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);

        // First swap - NORMAL mode
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.NORMAL));

        // Degrade rating to elevated risk
        oracle.setRatingManual(address(mockUSDT), 3);

        // Second swap - should transition to ELEVATED_RISK
        vm.expectEmit(true, false, false, true);
        emit SARMHook.RiskModeChanged(poolId, SARMHook.RiskMode.ELEVATED_RISK);
        
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.ELEVATED_RISK));

        // Degrade rating to frozen
        oracle.setRatingManual(address(mockUSDT), 5);

        // Third swap - should revert (FROZEN)
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

    function test_SARMHook_EffectiveRatingUsesMax() public {
        // Set different ratings - effective rating should be the maximum
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 4);

        // Swap should be blocked because max(2, 4) = 4 >= frozenThreshold
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );

        // Now set both to low ratings
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Swap should succeed because max(1, 2) = 2 < frozenThreshold
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

    function test_SARMHook_EventsEmitted() public {
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Expect RiskCheck event
        vm.expectEmit(true, false, false, true);
        emit SARMHook.RiskCheck(poolId, 1, 2, 2);

        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

    function test_SARMHook_RevertTokenNotRated() public {
        // Set rating only for one token
        oracle.setRatingManual(address(mockUSDC), 1);
        // mockUSDT is not rated

        // Swap should revert because USDT is not rated
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_SimulateDepegScenario() public {
        console2.log("=== Simulating Depeg Scenario ===");
        
        // Initial state: both stablecoins are healthy
        console2.log("Phase 1: Healthy market");
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);
        
        // Swaps work normally
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1000e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        console2.log("Swap 1: Success (NORMAL mode)");

        // USDT starts showing signs of stress
        console2.log("\nPhase 2: USDT rating degraded to 3");
        oracle.setRatingManual(address(mockUSDT), 3);
        
        // Swaps still work but in elevated risk mode
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -500e6,
                sqrtPriceLimitX96: MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        console2.log("Swap 2: Success (ELEVATED_RISK mode)");
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.ELEVATED_RISK));

        // USDT depegs! Rating goes to 5
        console2.log("\nPhase 3: USDT depeg - rating = 5");
        oracle.setRatingManual(address(mockUSDT), 5);
        
        // Circuit breaker activates
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        console2.log("Swap 3: BLOCKED - Circuit breaker activated!");

        // USDT recovers
        console2.log("\nPhase 4: USDT recovers - rating = 2");
        oracle.setRatingManual(address(mockUSDT), 2);
        
        // Normal operation resumes
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -200e6,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        console2.log("Swap 4: Success (NORMAL mode) - Market normalized");
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.NORMAL));
    }
}
