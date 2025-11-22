// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {SSAOracleAdapter} from "../oracles/SSAOracleAdapter.sol";

/**
 * @title SARMHook
 * @notice Stablecoin Automated Risk Management Hook for Uniswap v4.
 * @dev Makes stablecoin liquidity "risk-aware" by reading S&P Global SSA ratings
 *      and applying dynamic fees and circuit breakers based on risk levels.
 *
 * Risk Modes:
 *   - NORMAL: Low ratings (1-2), normal operation
 *   - ELEVATED_RISK: Medium ratings (3), higher fees
 *   - FROZEN: High ratings (4-5), swaps blocked or heavily restricted
 *
 * Part of SARM Protocol for ETHGlobal Buenos Aires 2025.
 */
contract SARMHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SwapBlocked_HighRisk();
    error TokenNotRated();

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
     * @param newMode New risk mode (NORMAL, ELEVATED_RISK, FROZEN).
     */
    event RiskModeChanged(PoolId indexed poolId, RiskMode newMode);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    enum RiskMode {
        NORMAL,         // Ratings 1-2: Normal operation
        ELEVATED_RISK,  // Rating 3: Higher fees
        FROZEN          // Ratings 4-5: Swaps blocked
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
        
        // Default thresholds
        riskConfig = RiskConfig({
            elevatedRiskThreshold: 3,
            frozenThreshold: 4
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the hook's permissions.
     * @dev We implement beforeSwap to check ratings before allowing swaps.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
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
     * @notice Called before a swap is executed.
     * @dev Reads ratings for both tokens, computes effective rating, and enforces risk policy.
     * @param key Pool key containing token addresses.
     * @return selector Function selector to confirm execution.
     * @return beforeSwapDelta No delta modification in Phase 1.
     * @return feeOverride No fee override in Phase 1 (Phase 2: dynamic fees).
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
        
        if (poolRiskMode[poolId] != currentMode) {
            poolRiskMode[poolId] = currentMode;
            emit RiskModeChanged(poolId, currentMode);
        }

        // Apply risk policy
        if (currentMode == RiskMode.FROZEN) {
            // Circuit breaker: block swaps when risk is too high
            revert SwapBlocked_HighRisk();
        }

        // Phase 1: Allow swap without fee modification
        // Phase 2: Return dynamic fee based on risk mode
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
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
     * @dev Determine risk mode based on effective rating.
     */
    function _determineRiskMode(uint8 effectiveRating) internal view returns (RiskMode) {
        if (effectiveRating >= riskConfig.frozenThreshold) {
            return RiskMode.FROZEN;
        } else if (effectiveRating >= riskConfig.elevatedRiskThreshold) {
            return RiskMode.ELEVATED_RISK;
        } else {
            return RiskMode.NORMAL;
        }
    }
}
