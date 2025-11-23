// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {SSAOracleAdapter} from "../oracles/SSAOracleAdapter.sol";

/**
 * @title SAGEHook
 * @notice Uniswap v4 Hook implementing a reward-based, non-punitive risk model for stablecoins.
 * @dev Risk-aware swap logic:
 *   - NORMAL: Premium ratings (1-2), 30% fee discount (0.007%)
 *   - ELEVATED_RISK: Standard ratings (3-5), normal fees (0.01%)
 *   - No swap blocking - all swaps allowed, only fee adjustments
 *
 * Part of SAGE Protocol for ETHGlobal Buenos Aires 2025.
 */
contract SAGEHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenNotRated();
    error DynamicFeeRequired();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted on every swap to log the risk check.
     * @param poolId ID of the pool.
     * @param rating0 Rating of token0.
     * @param rating1 Rating of token1.
     * @param effectiveRating Maximum rating of the pair (determines risk mode).
     */
    event RiskCheck(PoolId indexed poolId, uint8 rating0, uint8 rating1, uint8 effectiveRating);

    /**
     * @notice Emitted when a pool transitions risk modes.
     * @param poolId ID of the pool.
     * @param newMode New risk mode (NORMAL or ELEVATED_RISK).
     */
    event RiskModeChanged(PoolId indexed poolId, RiskMode newMode);

    /**
     * @notice Emitted when a dynamic fee is applied to a swap.
     * @param poolId ID of the pool.
     * @param effectiveRating The rating used to determine the fee.
     * @param fee The LP fee applied (in hundredths of a bip).
     */
    event FeeOverrideApplied(PoolId indexed poolId, uint8 effectiveRating, uint24 fee);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    enum RiskMode {
        NORMAL,         // Ratings 1-2: 0.007% (30% discount)
        ELEVATED_RISK   // Ratings 3-5: 0.01% (normal fee)
    }

    struct RiskConfig {
        uint8 elevatedRiskThreshold;  // Rating >= this = ELEVATED_RISK
        uint8 frozenThreshold;         // Rating >= this = FROZEN
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the SSA Oracle Adapter.
    SSAOracleAdapter public immutable oracle;

    /// @notice Risk configuration thresholds.
    RiskConfig public riskConfig;

    /// @notice Current risk mode per pool.
    mapping(PoolId => RiskMode) public poolRiskMode;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _poolManager Address of the Uniswap v4 PoolManager.
     * @param _oracle Address of the SSAOracleAdapter.
     */
    constructor(IPoolManager _poolManager, SSAOracleAdapter _oracle) BaseHook(_poolManager) {
        oracle = _oracle;
        
        // Config with thresholds that match S&P SSA rating scale (1-5):
        // - Rating 1: NORMAL (Low risk)
        // - Rating 2: NORMAL (Low-to-Moderate risk) 
        // - Rating 3-5: ELEVATED_RISK (Standard risk, no discount)
        riskConfig = RiskConfig({
            elevatedRiskThreshold: 3,
            frozenThreshold: 5  // legacy, no longer used for blocking
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the hook's permissions.
     * @dev We implement beforeInitialize to enforce dynamic fees and beforeSwap for risk checks.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Called before a pool is initialized.
     * @dev Enforces that the pool is configured with DYNAMIC_FEE_FLAG.
     *      This is critical because SAGE needs to override fees based on risk ratings.
     */
    function _beforeInitialize(
        address,              /* sender */
        PoolKey calldata key,
        uint160               /* sqrtPriceX96 */
    ) internal override returns (bytes4) {
        // Require that the pool uses DYNAMIC_FEE_FLAG
        if ((key.fee & LPFeeLibrary.DYNAMIC_FEE_FLAG) == 0) {
            revert DynamicFeeRequired();
        }

        return BaseHook.beforeInitialize.selector;
    }

    /**
     * @notice Called before a swap is executed.
     * @dev Reads ratings for both tokens, computes effective rating, and enforces risk policy.
     * @param key Pool key containing token addresses.
     * @return selector Function selector to confirm execution.
     * @return beforeSwapDelta No delta modification.
     * @return feeOverride Dynamic LP fee for this swap, encoded with OVERRIDE_FEE_FLAG.
     */
    function _beforeSwap(
        address, /* sender */
        PoolKey calldata key,
        IPoolManager.SwapParams calldata, /* params */
        bytes calldata /* hookData */
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // Get token addresses from pool key
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        // Read ratings from oracle
        (uint8 rating0, ) = _getRating(token0);
        (uint8 rating1, ) = _getRating(token1);

        // Compute effective rating (worst-case risk)
        uint8 effectiveRating = rating0 > rating1 ? rating0 : rating1;

        // Get pool ID
        PoolId poolId = key.toId();

        // Emit risk check event for analytics
        emit RiskCheck(poolId, rating0, rating1, effectiveRating);

        // Determine and apply risk mode
        RiskMode currentMode = _determineRiskMode(effectiveRating);
        
        // Update pool risk mode if changed
        RiskMode previousMode = poolRiskMode[poolId];
        if (currentMode != previousMode) {
            poolRiskMode[poolId] = currentMode;
            emit RiskModeChanged(poolId, currentMode);
        }

        // Calculate dynamic fee (no blocking, only fee adjustments)
        uint24 baseFee = _feeForRating(effectiveRating);

        // Emit event for analytics and monitoring
        emit FeeOverrideApplied(poolId, effectiveRating, baseFee);

        // Set override flag so Uniswap v4 uses this fee for this swap
        uint24 feeOverride = baseFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, feeOverride);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Get rating from oracle with error handling.
     */
    function _getRating(address token) internal view returns (uint8 rating, uint256 lastUpdated) {
        try oracle.getRating(token) returns (uint8 r, uint256 lu) {
            return (r, lu);
        } catch {
            revert TokenNotRated();
        }
    }

    /**
     * @notice Determines risk mode: NORMAL for ratings 1-2, ELEVATED_RISK for 3-5
     */
    function _determineRiskMode(uint8 effectiveRating) internal pure returns (RiskMode) {
        if (effectiveRating <= 2) {
            return RiskMode.NORMAL;
        } else {
            return RiskMode.ELEVATED_RISK;
        }
    }

    /**
     * @notice Reward-based fee schedule: 30% discount for premium stablecoins
     * @dev Fee schedule:
     *  - Rating 1-2: 0.007% (70 bps) - 30% discount
     *  - Rating 3-5: 0.01% (100 bps) - normal fee
     */
    function _feeForRating(uint8 effectiveRating) internal pure returns (uint24) {
        uint24 baseFee = 100; // 0.01% normal fee
        
        if (effectiveRating <= 2) {
            // 30% discount → 70% of base = 0.007%
            return uint24((uint256(baseFee) * 70) / 100); // 70
        } else {
            return baseFee; // 100
        }
    }
}
