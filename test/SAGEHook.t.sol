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
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {SAGEHook} from "../src/hooks/SAGEHook.sol";
import {SSAOracleAdapter} from "../src/oracles/SSAOracleAdapter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";

/**
 * @title SAGEHookTest
 * @notice Comprehensive tests for SAGE Protocol hook and oracle adapter.
 */
contract SAGEHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Re-declare events for testing
    event RatingUpdated(address indexed token, uint8 oldRating, uint8 newRating);
    event FeedIdSet(address indexed token, bytes32 feedId);
    event RiskModeChanged(PoolId indexed poolId, SAGEHook.RiskMode mode);
    event RiskCheck(PoolId indexed poolId, uint8 rating0, uint8 rating1, uint8 effectiveRating);
    event FeeOverrideApplied(PoolId indexed poolId, uint8 rating, uint24 fee);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    SSAOracleAdapter public oracle;
    SAGEHook public hook;
    MockVerifier public mockVerifier;
    
    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC20 public mockDAI;

    // Three pools for comprehensive testing
    PoolKey public poolKeyUSDC_USDT;
    PoolKey public poolKeyUSDC_DAI;
    PoolKey public poolKeyUSDT_DAI;
    
    PoolId public poolIdUSDC_USDT;
    PoolId public poolIdUSDC_DAI;
    PoolId public poolIdUSDT_DAI;
    
    // Legacy single pool references (for backward compatibility with existing tests)
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

        // Deploy mock DataLink verifier
        mockVerifier = new MockVerifier();

        // Deploy oracle adapter with mock verifier
        oracle = new SSAOracleAdapter(address(mockVerifier));

        // Deploy SARM Hook
        // Note: Hook address must satisfy Uniswap v4 address requirements
        // For testing, we deploy directly; in production, CREATE2 is used
        // Hook requires both BEFORE_INITIALIZE_FLAG and BEFORE_SWAP_FLAG
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG);
        address hookAddress = address(flags);
        
        // Deploy hook at the expected address using vm.etch (for testing)
        deployCodeTo("SAGEHook.sol", abi.encode(manager, oracle), hookAddress);
        hook = SAGEHook(hookAddress);

        // Hardcode default ratings (simulates real-world scenario without CRE)
        // USDC and USDT: top tier (rating 1) -> 30% discount
        // DAI: less rated (rating 4) -> normal pricing
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);
        oracle.setRatingManual(address(mockDAI), 4);

        // Initialize three pools with the hook
        // Pool 1: USDC/USDT (both rating 1 -> discount)
        poolKeyUSDC_USDT = PoolKey({
            currency0: Currency.wrap(address(mockUSDC)),
            currency1: Currency.wrap(address(mockUSDT)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        poolIdUSDC_USDT = poolKeyUSDC_USDT.toId();
        manager.initialize(poolKeyUSDC_USDT, SQRT_PRICE_1_1);

        // Pool 2: USDC/DAI (USDC rating 1, DAI rating 4 -> normal fee)
        poolKeyUSDC_DAI = PoolKey({
            currency0: Currency.wrap(address(mockUSDC)),
            currency1: Currency.wrap(address(mockDAI)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        poolIdUSDC_DAI = poolKeyUSDC_DAI.toId();
        manager.initialize(poolKeyUSDC_DAI, SQRT_PRICE_1_1);

        // Pool 3: USDT/DAI (USDT rating 1, DAI rating 4 -> normal fee)
        poolKeyUSDT_DAI = PoolKey({
            currency0: Currency.wrap(address(mockUSDT)),
            currency1: Currency.wrap(address(mockDAI)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });
        poolIdUSDT_DAI = poolKeyUSDT_DAI.toId();
        manager.initialize(poolKeyUSDT_DAI, SQRT_PRICE_1_1);

        // Backward compatibility: default to USDC/USDT pool
        poolKey = poolKeyUSDC_USDT;
        poolId = poolIdUSDC_USDT;

        // Mint tokens to test users
        mockUSDC.mint(ALICE, 1_000_000e6);
        mockUSDT.mint(ALICE, 1_000_000e6);
        mockDAI.mint(ALICE, 1_000_000e18);
        mockUSDC.mint(BOB, 1_000_000e6);
        mockUSDT.mint(BOB, 1_000_000e6);
        mockDAI.mint(BOB, 1_000_000e18);

        // Approve tokens for pool manager
        vm.startPrank(ALICE);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        mockUSDT.approve(address(swapRouter), type(uint256).max);
        mockDAI.approve(address(swapRouter), type(uint256).max);
        mockUSDC.approve(address(modifyLiquidityRouter), type(uint256).max);
        mockUSDT.approve(address(modifyLiquidityRouter), type(uint256).max);
        mockDAI.approve(address(modifyLiquidityRouter), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        mockUSDT.approve(address(swapRouter), type(uint256).max);
        mockDAI.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();

        // Add initial liquidity to all three pools
        vm.startPrank(ALICE);
        
        // Pool 1: USDC/USDT
        modifyLiquidityRouter.modifyLiquidity(
            poolKeyUSDC_USDT,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000e6,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        // Pool 2: USDC/DAI
        modifyLiquidityRouter.modifyLiquidity(
            poolKeyUSDC_DAI,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000e6,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        // Pool 3: USDT/DAI
        modifyLiquidityRouter.modifyLiquidity(
            poolKeyUSDT_DAI,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000e6,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          ORACLE ADAPTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OracleAdapter_SetRatingManual() public {
        // USDC already rated 1 in setUp, so updating to 3
        vm.expectEmit(true, false, false, true);
        emit RatingUpdated(address(mockUSDC), 1, 3);
        
        oracle.setRatingManual(address(mockUSDC), 3);

        (uint8 rating, uint256 lastUpdated) = oracle.getRating(address(mockUSDC));
        assertEq(rating, 3);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_OracleAdapter_UpdateRating() public {
        // Set initial rating
        oracle.setRatingManual(address(mockUSDC), 1);

        // Update to higher rating
        vm.expectEmit(true, false, false, true);
        emit RatingUpdated(address(mockUSDC), 1, 4);
        
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
        // Use a new unrated token (mockDAI is now rated in setUp)
        MockERC20 unratedToken = new MockERC20("Unrated", "UNRATED", 18);
        vm.expectRevert(SSAOracleAdapter.TokenNotRated.selector);
        oracle.getRating(address(unratedToken));
    }

    /*//////////////////////////////////////////////////////////////
                           SARM HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BeforeInitialize_RevertIfNotDynamicFee() public {
        // Attempt to initialize a pool without DYNAMIC_FEE_FLAG
        PoolKey memory badKey = PoolKey({
            currency0: Currency.wrap(address(mockUSDC)),
            currency1: Currency.wrap(address(mockUSDT)),
            fee: uint24(500), // Static fee without DYNAMIC_FEE_FLAG
            tickSpacing: 60,
            hooks: hook
        });

        // Should revert (error is wrapped by Uniswap's PoolManager)
        vm.expectRevert();
        manager.initialize(badKey, SQRT_PRICE_1_1);
    }

    function test_SAGEHook_SwapWithLowRisk() public {
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));
    }

    function test_SAGEHook_SwapWithElevatedRisk() public {
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));
    }

    function test_DynamicFees_HighRatingPaysNormalFee() public {
        // Rating alto (5) -> fee normal = 100, sin revert
        oracle.setRatingManual(address(mockUSDC), 5);
        oracle.setRatingManual(address(mockUSDT), 5);

        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 5, 100);

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

        // Debe estar en modo ELEVATED_RISK (pero solo significa "sin descuento")
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));
    }

    function test_SAGEHook_RiskModeTransition() public {
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));

        // Degrade rating to elevated risk
        oracle.setRatingManual(address(mockUSDT), 3);

        // Second swap - should transition to ELEVATED_RISK
        vm.expectEmit(true, false, false, true);
        emit RiskModeChanged(poolId, SAGEHook.RiskMode.ELEVATED_RISK);
        
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        // Degrade rating to 5 - should still work (no blocking)
        oracle.setRatingManual(address(mockUSDT), 5);

        // Third swap - should succeed (no FROZEN state anymore)
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
        // Still in ELEVATED_RISK mode (5 is standard, not frozen)
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));
    }

    function test_SAGEHook_EffectiveRatingUsesMax() public {
        // Set different ratings - effective rating should be the maximum
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 5);

        // Swap should work because rating 5 no longer blocks (max(2, 5) = 5)
        // Should use ELEVATED_RISK mode with normal fee (100)
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 5, 100);
        
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        // Now set both to low ratings
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Swap should succeed with discount because max(1, 2) = 2
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 2, 70);
        
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));
    }

    function test_SAGEHook_EventsEmitted() public {
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Expect RiskCheck event
        vm.expectEmit(true, false, false, true);
        emit RiskCheck(poolId, 1, 2, 2);

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

    function test_SAGEHook_RevertTokenNotRated() public {
        // Create pool with unrated tokens (USDC/USDT are rated in setUp)
        MockERC20 unratedToken0 = new MockERC20("Unrated0", "UNRATED0", 6);
        MockERC20 unratedToken1 = new MockERC20("Unrated1", "UNRATED1", 6);

        // Ensure currency0 < currency1
        (address token0, address token1) = address(unratedToken0) < address(unratedToken1)
            ? (address(unratedToken0), address(unratedToken1))
            : (address(unratedToken1), address(unratedToken0));

        PoolKey memory newPoolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: hook
        });

        // Initialize pool
        manager.initialize(newPoolKey, SQRT_PRICE_1_1);

        // Swap should revert because tokens are not rated
        vm.prank(BOB);
        vm.expectRevert(); // Hook error wrapped by Uniswap
        swapRouter.swap(
            newPoolKey,
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
        console2.log("Stage 1: Healthy market");
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
        console2.log("\nStage 2: USDT rating degraded to 3");
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        // USDT rating degrades to 5 but swap still works
        console2.log("\nStage 3: USDT rating = 5 (high risk but not blocked)");
        oracle.setRatingManual(address(mockUSDT), 5);
        
        // Swap still works - just pays normal fee (no discount)
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
        console2.log("Swap 3: Success - Normal fee applied (no blocking)");
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        // USDT recovers
        console2.log("\nStage 4: USDT recovers - rating = 2");
        oracle.setRatingManual(address(mockUSDT), 2);
        
        // Normal operation resumes with discount
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false,  // Changed direction to avoid price limit issue
                amountSpecified: -200e6,
                sqrtPriceLimitX96: MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        console2.log("Swap 4: Success (NORMAL mode) - Market normalized");
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));
    }

    /*//////////////////////////////////////////////////////////////
                        DYNAMIC FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DynamicFees_LowRiskFee() public {
        // Set low risk ratings (1-2) -> should get 0.007% fee (70, 30% discount)
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Expect FeeOverrideApplied event with 70 (0.007%, 30% discount)
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 2, 70);

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

        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));
    }

    function test_DynamicFees_ModerateRiskFee() public {
        // Set moderate risk rating (3) -> should get 0.01% fee (100)
        oracle.setRatingManual(address(mockUSDC), 3);
        oracle.setRatingManual(address(mockUSDT), 3);

        // Expect FeeOverrideApplied event with 100 (0.01%)
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 3, 100);

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

        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));
    }

    function test_DynamicFees_FeeIncreasesWithRisk() public {
        console2.log("=== Testing Fee Progression with Risk ===");
        
        // Start with rating 1 (lowest risk)
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);

        console2.log("Rating 1: Fee should be 70 (0.007%, 30% discount)");
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 1, 70);
        
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

        // Increase to rating 2 (still low risk)
        oracle.setRatingManual(address(mockUSDT), 2);

        console2.log("Rating 2: Fee should still be 70 (0.007%, 30% discount)");
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 2, 70);
        
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

        // Increase to rating 3 (elevated risk)
        oracle.setRatingManual(address(mockUSDT), 3);

        console2.log("Rating 3: Fee should double to 100 (0.01%)");
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 3, 100);
        
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

        console2.log("All fee transitions successful!");
    }

    function test_DynamicFees_EventEmittedOnEverySwap() public {
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 2);

        // First swap
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 2, 70);
        
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

        // Second swap - event should be emitted again
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 2, 70);
        
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
    }

    function test_DynamicFees_DiscountForBestRatings() public {
        // Ratings top: 1 y 2 -> se espera 70 (0.007%) en lugar de 100
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 2);

        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 2, 70);

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

        // Debe estar en modo NORMAL (= par con descuento)
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));
    }

    /*//////////////////////////////////////////////////////////////
                    CHAINLINK DATALINK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DataLink_SetFeedId() public {
        bytes32 feedId = bytes32(uint256(0x123456789));
        
        vm.expectEmit(true, false, false, true);
        emit FeedIdSet(address(mockUSDC), feedId);
        
        oracle.setFeedId(address(mockUSDC), feedId);
        
        assertEq(oracle.tokenFeedId(address(mockUSDC)), feedId);
    }

    function test_DataLink_SetFeedId_RevertInvalidFeedId() public {
        vm.expectRevert(SSAOracleAdapter.InvalidFeedId.selector);
        oracle.setFeedId(address(mockUSDC), bytes32(0));
    }

    function test_DataLink_RefreshRatingWithReport_Success() public {
        // Setup: Configure feed ID
        bytes32 feedId = bytes32(uint256(0x123456789));
        oracle.setFeedId(address(mockUSDC), feedId);

        // Mock verifier response using DataLink v4 payload format
        // benchmarkPrice = 3e18 (rating 3), timestamp = now
        bytes memory verifiedData = abi.encode(
            feedId,                      // feedIdDecoded
            uint32(block.timestamp),     // validFromTimestamp
            uint32(block.timestamp),     // observationsTimestamp
            uint192(0),                  // nativeFee
            uint192(0),                  // linkFee
            uint32(block.timestamp + 1 days), // expiresAt
            int192(int256(3e18)),        // benchmarkPrice (rating 3 * 1e18)
            uint32(1)                    // marketStatus
        );
        mockVerifier.setResponse(verifiedData);

        // Create a fake report (content doesn't matter since verifier is mocked)
        bytes memory fakeReport = abi.encodePacked("fake_report_data");

        // Expect RatingUpdated event (USDC already rated 1 in setUp)
        vm.expectEmit(true, false, false, true);
        emit RatingUpdated(address(mockUSDC), 1, 3);

        // Call refreshRatingWithReport
        oracle.refreshRatingWithReport(address(mockUSDC), fakeReport);

        // Verify state was updated
        (uint8 rating, uint256 lastUpdated) = oracle.getRating(address(mockUSDC));
        assertEq(rating, 3);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_DataLink_RefreshRatingWithReport_RevertNoFeedId() public {
        // Don't set feed ID for token
        bytes memory fakeReport = abi.encodePacked("fake_report");

        vm.expectRevert(SSAOracleAdapter.InvalidFeedId.selector);
        oracle.refreshRatingWithReport(address(mockUSDC), fakeReport);
    }

    function test_DataLink_RefreshRatingWithReport_RevertStaleReport() public {
        // Setup: Configure feed ID
        bytes32 feedId = bytes32(uint256(0x123456789));
        oracle.setFeedId(address(mockUSDC), feedId);

        // Mock verifier response with current timestamp
        uint32 reportTimestamp = uint32(block.timestamp);
        bytes memory verifiedData = abi.encode(
            feedId,
            reportTimestamp,
            reportTimestamp,
            uint192(0),
            uint192(0),
            uint32(block.timestamp + 1 days),
            int192(int256(3e18)),  // rating 3
            uint32(1)
        );
        mockVerifier.setResponse(verifiedData);

        // Warp time forward 2 days to make report stale
        vm.warp(block.timestamp + 2 days);

        bytes memory fakeReport = abi.encodePacked("stale_report");

        vm.expectRevert(SSAOracleAdapter.StaleReport.selector);
        oracle.refreshRatingWithReport(address(mockUSDC), fakeReport);
    }

    function test_DataLink_RefreshRatingWithReport_RevertInvalidRating() public {
        // Setup: Configure feed ID
        bytes32 feedId = bytes32(uint256(0x123456789));
        oracle.setFeedId(address(mockUSDC), feedId);

        // Mock verifier response with invalid rating (0)
        bytes memory verifiedData = abi.encode(
            feedId,
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint192(0),
            uint192(0),
            uint32(block.timestamp + 1 days),
            int192(int256(0)),  // invalid: rating 0
            uint32(1)
        );
        mockVerifier.setResponse(verifiedData);

        bytes memory fakeReport = abi.encodePacked("invalid_rating_report");

        vm.expectRevert(SSAOracleAdapter.InvalidRating.selector);
        oracle.refreshRatingWithReport(address(mockUSDC), fakeReport);
    }

    function test_DataLink_RefreshRatingWithReport_UpdateExistingRating() public {
        // Setup: Set initial rating manually
        oracle.setRatingManual(address(mockUSDC), 1);

        // Configure feed ID
        bytes32 feedId = bytes32(uint256(0x123456789));
        oracle.setFeedId(address(mockUSDC), feedId);

        // Mock verifier response: upgrade rating to 4
        bytes memory verifiedData = abi.encode(
            feedId,
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint192(0),
            uint192(0),
            uint32(block.timestamp + 1 days),
            int192(int256(4e18)),  // rating 4
            uint32(1)
        );
        mockVerifier.setResponse(verifiedData);

        bytes memory fakeReport = abi.encodePacked("upgrade_report");

        // Expect RatingUpdated event with old rating = 1, new rating = 4
        vm.expectEmit(true, false, false, true);
        emit RatingUpdated(address(mockUSDC), 1, 4);

        oracle.refreshRatingWithReport(address(mockUSDC), fakeReport);

        // Verify rating was updated
        (uint8 rating, ) = oracle.getRating(address(mockUSDC));
        assertEq(rating, 4);
    }

    function test_DataLink_Integration_HookUsesDataLinkRating() public {
        // This test verifies end-to-end: DataLink updates rating, hook applies fees accordingly

        // Setup: Configure feed IDs for both tokens
        oracle.setFeedId(address(mockUSDC), bytes32(uint256(0x111)));
        oracle.setFeedId(address(mockUSDT), bytes32(uint256(0x222)));

        // Initially set low ratings manually
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);

        // Verify swap works with low risk (30% discount)
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 1, 70);
        
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.NORMAL));

        // DataLink update: USDT rating degraded to 5
        bytes32 usdtFeedId = bytes32(uint256(0x222));
        bytes memory verifiedData = abi.encode(
            usdtFeedId,
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint192(0),
            uint192(0),
            uint32(block.timestamp + 1 days),
            int192(int256(5e18)),  // rating 5
            uint32(1)
        );
        mockVerifier.setResponse(verifiedData);
        
        bytes memory report = abi.encodePacked("depeg_alert");
        oracle.refreshRatingWithReport(address(mockUSDT), report);

        // Verify rating was updated
        (uint8 rating, ) = oracle.getRating(address(mockUSDT));
        assertEq(rating, 5);

        // Swap is NOT blocked: pays normal fee (100) in ELEVATED_RISK mode
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 5, 100);
        
        vm.prank(BOB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false,  // Changed direction to avoid price limit
                amountSpecified: -100e6,
                sqrtPriceLimitX96: MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));
    }

    function test_ThreePools_DifferentFeesByRating() public {
        console2.log("=== Testing Three Pools with Different Rating Combinations ===");
        
        // Pool 1: USDC/USDT (both rating 1) -> should get discount (fee 70)
        console2.log("\nPool 1: USDC (rating 1) / USDT (rating 1)");
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolIdUSDC_USDT, 1, 70);
        
        vm.prank(BOB);
        swapRouter.swap(
            poolKeyUSDC_USDT,
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
        console2.log("Fee: 70 (0.007%, 30% discount) - NORMAL mode");
        assertEq(uint8(hook.poolRiskMode(poolIdUSDC_USDT)), uint8(SAGEHook.RiskMode.NORMAL));

        // Pool 2: USDC/DAI (USDC rating 1, DAI rating 4) -> normal fee (100)
        console2.log("\nPool 2: USDC (rating 1) / DAI (rating 4)");
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolIdUSDC_DAI, 4, 100);
        
        vm.prank(BOB);
        swapRouter.swap(
            poolKeyUSDC_DAI,
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
        console2.log("Fee: 100 (0.01%, normal) - ELEVATED_RISK mode");
        assertEq(uint8(hook.poolRiskMode(poolIdUSDC_DAI)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        // Pool 3: USDT/DAI (USDT rating 1, DAI rating 4) -> normal fee (100)
        console2.log("\nPool 3: USDT (rating 1) / DAI (rating 4)");
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolIdUSDT_DAI, 4, 100);
        
        vm.prank(BOB);
        swapRouter.swap(
            poolKeyUSDT_DAI,
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
        console2.log("Fee: 100 (0.01%, normal) - ELEVATED_RISK mode");
        assertEq(uint8(hook.poolRiskMode(poolIdUSDT_DAI)), uint8(SAGEHook.RiskMode.ELEVATED_RISK));

        console2.log("\n=== Summary ===");
        console2.log("Premium pairs (both rated 1-2): Get 30% discount");
        console2.log("Mixed pairs (one rated 3+): Pay normal fee");
    }
}
