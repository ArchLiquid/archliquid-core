// SPDX-License-Identifier: LicenseRef-ArchLiquid-Proprietary
pragma solidity 0.8.30;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title ArchStockRegistry
/// @notice Allowlist of approved Robinhood Stock Tokens. Every ArchLiquid
///         distributor must pay holders in a registered stock token, so the
///         "get paid in stocks" guarantee cannot be subverted by pointing a
///         token at a worthless or creator-controlled asset. Owned by the
///         protocol multisig; the factory and launchpad consult it at deploy.
contract ArchStockRegistry is Ownable2Step {
    mapping(address => bool) public isApproved;
    address public stockSwapExecutor;

    event StockApproved(address indexed stock);
    event StockRevoked(address indexed stock);
    event StockSwapExecutorSet(address indexed executor);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setApproved(address stock, bool approved) external onlyOwner {
        require(stock != address(0), "registry: zero stock");
        isApproved[stock] = approved;
        if (approved) {
            emit StockApproved(stock);
        } else {
            emit StockRevoked(stock);
        }
    }

    /// @notice Select the reviewed executor snapshotted by future ArchTokens.
    ///         Existing tokens retain their immutable executor, so changing or
    ///         clearing this value cannot redirect their accumulated tax.
    function setStockSwapExecutor(address executor) external onlyOwner {
        require(executor == address(0) || executor.code.length > 0, "registry: invalid executor");
        stockSwapExecutor = executor;
        emit StockSwapExecutorSet(executor);
    }

    /// @notice Revert unless `stock` is currently approved.
    function requireApproved(address stock) external view {
        require(isApproved[stock], "registry: stock not approved");
    }
}
