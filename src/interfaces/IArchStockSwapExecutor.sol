// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity ^0.8.10;

interface IArchStockSwapExecutor {
    function swapExactWethForStock(address stock, uint256 amountIn, uint256 minAmountOut, bytes calldata swapData)
        external
        returns (uint256 amountOut);
}
