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

import {SARMHook} from "../src/hooks/SARMHook.sol";
import {SSAOracleAdapter} from "../src/oracles/SSAOracleAdapter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";

/**
 * @title SARMHookTest
 * @notice Comprehensive tests for SARM Protocol hook and oracle adapter.
 */
contract SARMHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Re-declare events for testing
    event RatingUpdated(address indexed token, uint8 oldRating, uint8 newRating);
    event FeedIdSet(address indexed token, bytes32 feedId);
    event RiskModeChanged(PoolId indexed poolId, SARMHook.RiskMode mode);
    event RiskCheck(PoolId indexed poolId, uint8 rating0, uint8 rating1, uint8 effectiveRating);
    event FeeOverrideApplied(PoolId indexed poolId, uint8 rating, uint24 fee);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    SSAOracleAdapter public oracle;
    SARMHook public hook;
    MockVerifier public mockVerifier;
    
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
        deployCodeTo("SARMHook.sol", abi.encode(manager, oracle), hookAddress);
        hook = SARMHook(hookAddress);

        // Initialize pool with hook
        poolKey = PoolKey({
            currency0: Currency.wrap(address(mockUSDC)),
            currency1: Currency.wrap(address(mockUSDT)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG, // Dynamic fees
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
        emit RatingUpdated(address(mockUSDC), 0, 1);
        
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
        vm.expectRevert(SSAOracleAdapter.TokenNotRated.selector);
        oracle.getRating(address(mockDAI));
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
        // Set high risk rating (5+)
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 5);

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
        emit RiskModeChanged(poolId, SARMHook.RiskMode.ELEVATED_RISK);
        
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
        oracle.setRatingManual(address(mockUSDT), 5);

        // Swap should be blocked because max(2, 5) = 5 >= frozenThreshold
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
        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.ELEVATED_RISK));

        // USDT depegs! Rating goes to 5
        console2.log("\nStage 3: USDT depeg - rating = 5");
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
        console2.log("\nStage 4: USDT recovers - rating = 2");
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

    /*//////////////////////////////////////////////////////////////
                        DYNAMIC FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DynamicFees_LowRiskFee() public {
        // Set low risk ratings (1-2) -> should get 0.005% fee (50)
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 2);

        // Expect FeeOverrideApplied event with 50 (0.005%)
        vm.expectEmit(true, true, true, true);
        emit FeeOverrideApplied(poolId, 2, 50);

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

        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.NORMAL));
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

        assertEq(uint8(hook.poolRiskMode(poolId)), uint8(SARMHook.RiskMode.ELEVATED_RISK));
    }

    function test_DynamicFees_FeeIncreasesWithRisk() public {
        console2.log("=== Testing Fee Progression with Risk ===");
        
        // Start with rating 1 (lowest risk)
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);

        console2.log("Rating 1: Fee should be 50 (0.005%)");
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 1, 50);
        
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

        console2.log("Rating 2: Fee should still be 50 (0.005%)");
        vm.expectEmit(true, false, false, true);
        emit FeeOverrideApplied(poolId, 2, 50);
        
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
        emit FeeOverrideApplied(poolId, 2, 50);
        
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
        emit FeeOverrideApplied(poolId, 2, 50);
        
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

    function test_DynamicFees_HighRiskNoFeeApplied() public {
        // Set high risk rating (5) - swap should be blocked before fee is applied
        oracle.setRatingManual(address(mockUSDC), 2);
        oracle.setRatingManual(address(mockUSDT), 5);

        // Swap should revert, so FeeOverrideApplied event should NOT be emitted
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

        // Expect RatingUpdated event
        vm.expectEmit(true, false, false, true);
        emit RatingUpdated(address(mockUSDC), 0, 3);

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
        // This test verifies end-to-end: DataLink updates rating, hook enforces it

        // Setup: Configure feed IDs for both tokens
        oracle.setFeedId(address(mockUSDC), bytes32(uint256(0x111)));
        oracle.setFeedId(address(mockUSDT), bytes32(uint256(0x222)));

        // Initially set low ratings manually
        oracle.setRatingManual(address(mockUSDC), 1);
        oracle.setRatingManual(address(mockUSDT), 1);

        // Verify swap works with low risk
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

        // DataLink update: USDT rating degraded to 5 (depeg)
        bytes32 usdtFeedId = bytes32(uint256(0x222));
        bytes memory verifiedData = abi.encode(
            usdtFeedId,
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint192(0),
            uint192(0),
            uint32(block.timestamp + 1 days),
            int192(int256(5e18)),  // rating 5 (depeg!)
            uint32(1)
        );
        mockVerifier.setResponse(verifiedData);
        
        bytes memory report = abi.encodePacked("depeg_alert");
        oracle.refreshRatingWithReport(address(mockUSDT), report);

        // Verify rating was updated
        (uint8 rating, ) = oracle.getRating(address(mockUSDT));
        assertEq(rating, 5);

        // Now swap should be blocked by circuit breaker
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
}
