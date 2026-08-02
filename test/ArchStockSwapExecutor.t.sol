// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArchStockSwapExecutor} from "../src/ArchStockSwapExecutor.sol";
import {ISwapRouter} from "../src/interfaces/IUniswapV3.sol";
import {MockERC20, MockV3Router, MockWETH} from "./mocks/Mocks.sol";

contract PartialFillAggregator {
    function swap(IERC20 weth, MockERC20 stock, uint256 spend, uint256 output) external {
        require(weth.transferFrom(msg.sender, address(this), spend), "test aggregator: transfer failed");
        stock.mint(msg.sender, output);
    }
}

contract ArchStockSwapExecutorTest is Test {
    MockWETH internal weth;
    MockERC20 internal stock;
    MockV3Router internal aggregator;
    ArchStockSwapExecutor internal executor;

    function setUp() public {
        weth = new MockWETH();
        stock = new MockERC20("Stock", "STOCK");
        aggregator = new MockV3Router();
        executor = new ArchStockSwapExecutor(IERC20(address(weth)), address(aggregator));
        weth.mint(address(this), 10 ether);
        weth.approve(address(executor), type(uint256).max);
    }

    function _swapData(address recipient, uint256 amountIn, uint256 quotedOut) internal returns (bytes memory data) {
        aggregator.setNextOut(address(stock), quotedOut);
        data = abi.encodeCall(
            ISwapRouter.exactInputSingle,
            (ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(weth),
                    tokenOut: address(stock),
                    fee: 3000,
                    recipient: recipient,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                }))
        );
    }

    function test_exactInputIsSpentAndMeasuredStockReturned() public {
        bytes memory data = _swapData(address(executor), 2 ether, 25e18);
        uint256 amountOut = executor.swapExactWethForStock(address(stock), 2 ether, 24e18, data);

        assertEq(amountOut, 25e18);
        assertEq(stock.balanceOf(address(this)), 25e18);
        assertEq(weth.balanceOf(address(aggregator)), 2 ether);
        assertEq(weth.allowance(address(executor), address(aggregator)), 0);
    }

    function test_outputSentElsewhereCannotSatisfyExecutor() public {
        bytes memory data = _swapData(makeAddr("attacker"), 2 ether, 25e18);
        vm.expectRevert("executor: insufficient output");
        executor.swapExactWethForStock(address(stock), 2 ether, 1, data);
    }

    function test_outerMinimumCannotBeBypassedByAggregatorCalldata() public {
        bytes memory data = _swapData(address(executor), 2 ether, 25e18);
        vm.expectRevert("executor: insufficient output");
        executor.swapExactWethForStock(address(stock), 2 ether, 26e18, data);
    }

    function test_partialInputIsRefundedAndPreexistingWethIsPreserved() public {
        PartialFillAggregator partialAggregator = new PartialFillAggregator();
        ArchStockSwapExecutor partialExecutor =
            new ArchStockSwapExecutor(IERC20(address(weth)), address(partialAggregator));
        weth.mint(address(partialExecutor), 3 ether); // unrelated balance cannot be spent
        weth.approve(address(partialExecutor), 5 ether);

        bytes memory data = abi.encodeCall(partialAggregator.swap, (IERC20(address(weth)), stock, 2 ether, 40e18));
        uint256 callerWethBefore = weth.balanceOf(address(this));
        partialExecutor.swapExactWethForStock(address(stock), 5 ether, 40e18, data);

        assertEq(weth.balanceOf(address(this)), callerWethBefore - 2 ether);
        assertEq(weth.balanceOf(address(partialExecutor)), 3 ether);
        assertEq(weth.allowance(address(partialExecutor), address(partialAggregator)), 0);
        assertEq(stock.balanceOf(address(this)), 40e18);
    }
}
