// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IArchStockSwapExecutor} from "./interfaces/IArchStockSwapExecutor.sol";

/// @title ArchStockSwapExecutor
/// @notice Constrains off-chain-generated aggregator calldata to an immutable
///         target, an exact WETH input allowance, and a measured stock output.
///         The caller always receives both the stock and any unspent WETH.
contract ArchStockSwapExecutor is IArchStockSwapExecutor, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable WETH;
    address public immutable AGGREGATOR;

    event StockSwapExecuted(
        address indexed caller, address indexed stock, uint256 wethSpent, uint256 stockReceived, uint256 wethRefunded
    );

    constructor(IERC20 weth, address aggregator) {
        require(address(weth) != address(0), "executor: zero weth");
        require(aggregator.code.length > 0, "executor: invalid aggregator");
        WETH = weth;
        AGGREGATOR = aggregator;
    }

    function swapExactWethForStock(address stock, uint256 amountIn, uint256 minAmountOut, bytes calldata swapData)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(stock != address(0) && stock != address(WETH), "executor: invalid stock");
        require(amountIn > 0, "executor: zero input");
        require(swapData.length >= 4, "executor: missing calldata");

        IERC20 stockToken = IERC20(stock);
        uint256 wethBefore = WETH.balanceOf(address(this));
        uint256 stockBefore = stockToken.balanceOf(address(this));

        WETH.safeTransferFrom(msg.sender, address(this), amountIn);
        require(WETH.balanceOf(address(this)) == wethBefore + amountIn, "executor: input mismatch");

        WETH.forceApprove(AGGREGATOR, amountIn);
        (bool ok, bytes memory result) = AGGREGATOR.call(swapData);
        WETH.forceApprove(AGGREGATOR, 0);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        uint256 stockAfter = stockToken.balanceOf(address(this));
        amountOut = stockAfter - stockBefore;
        require(amountOut >= minAmountOut && amountOut > 0, "executor: insufficient output");

        uint256 wethAfter = WETH.balanceOf(address(this));
        require(wethAfter >= wethBefore, "executor: preexisting weth spent");
        uint256 wethRefund = wethAfter - wethBefore;
        uint256 wethSpent = amountIn - wethRefund;

        stockToken.safeTransfer(msg.sender, amountOut);
        if (wethRefund > 0) WETH.safeTransfer(msg.sender, wethRefund);

        emit StockSwapExecuted(msg.sender, stock, wethSpent, amountOut, wethRefund);
    }
}
