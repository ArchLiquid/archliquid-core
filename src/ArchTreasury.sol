// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity 0.8.30;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ArchTreasury
/// @notice Terminal sink for every protocol fee: flat creation fees, raise
///         fees, curve trade fees, the 10% share of distribution taxes,
///         staking skims and lending reserves. Holds ETH and any ERC20
///         (including stock tokens). Withdrawals are owner-only; ownership is
///         intended for the protocol multisig.
contract ArchTreasury is Ownable2Step {
    using SafeERC20 for IERC20;

    event EthReceived(address indexed from, uint256 amount);
    event EthWithdrawn(address indexed to, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "treasury: zero to");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "treasury: eth send failed");
        emit EthWithdrawn(to, amount);
    }

    function withdrawToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "treasury: zero to");
        token.safeTransfer(to, amount);
        emit TokenWithdrawn(address(token), to, amount);
    }
}
