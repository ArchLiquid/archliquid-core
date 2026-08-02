// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity ^0.8.10;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title UniV3
/// @notice Uniswap V3 sqrt-price and full-range tick math, implemented with
///         OpenZeppelin's MIT Math (mulDiv/sqrt) and hardcoded tick constants,
///         so we depend on no BUSL-licensed Uniswap v3-core libraries.
library UniV3 {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;
    // TickMath bounds enforced by Uniswap V3 pools during initialize().
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function tickSpacing(uint24 fee) internal pure returns (int24) {
        if (fee == 100) return 1;
        if (fee == 500) return 10;
        if (fee == 3000) return 60;
        if (fee == 10000) return 200;
        revert("univ3: unsupported fee");
    }

    /// @notice The widest tick range aligned to the fee tier's spacing, i.e. a
    ///         full-range position equivalent to V2 liquidity.
    function fullRangeTicks(uint24 fee) internal pure returns (int24 tickLower, int24 tickUpper) {
        int24 s = tickSpacing(fee);
        // the divide-then-multiply is intentional: it snaps each bound to the
        // nearest valid multiple of the tick spacing (truncating toward zero
        // pulls both inside the usable range)
        // forge-lint: disable-next-line(divide-before-multiply)
        tickLower = (MIN_TICK / s) * s;
        // forge-lint: disable-next-line(divide-before-multiply)
        tickUpper = (MAX_TICK / s) * s;
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "univ3: identical tokens");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "univ3: zero token");
    }

    /// @notice sqrtPriceX96 for a pool seeded with `amount0` of token0 and
    ///         `amount1` of token1 (tokens already address-sorted). Equals
    ///         sqrt(amount1 / amount0) * 2**96, computed at full precision.
    function sqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
        require(amount0 > 0 && amount1 > 0, "univ3: zero amount");
        uint256 ratioX192 = Math.mulDiv(amount1, uint256(1) << 192, amount0);
        uint256 sp = Math.sqrt(ratioX192);
        require(sp >= MIN_SQRT_RATIO && sp < MAX_SQRT_RATIO, "univ3: price out of range");
        // safe: bounded by the require above
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(sp);
    }
}
