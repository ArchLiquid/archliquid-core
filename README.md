# ArchLiquid Core

Shared protocol contracts, exchange interfaces, and Uniswap V3 math used by
the ArchLiquid contract suite.

> **Status:** Testnet preview. These contracts have not been audited by an
> external security firm. Review the source and run the test suite before
> interacting with a deployment.

## What is included

| Contract | Purpose |
|---|---|
| [`ArchTreasury`](src/ArchTreasury.sol) | Receives ETH and ERC-20 protocol fees and permits owner-only withdrawals. |
| [`ArchStockRegistry`](src/ArchStockRegistry.sol) | Maintains the owner-controlled allowlist of stock tokens and the executor selected for future tokens. |
| [`ArchStockSwapExecutor`](src/ArchStockSwapExecutor.sol) | Constrains aggregator calls to an immutable target, exact WETH allowance, measured stock output, and caller refunds. |
| [`IArchStockSwapExecutor`](src/interfaces/IArchStockSwapExecutor.sol) | Stable interface consumed by token and launch contracts. |
| [`IUniswapV2`](src/interfaces/IUniswapV2.sol) | Minimal Uniswap V2-compatible interfaces. |
| [`IUniswapV3`](src/interfaces/IUniswapV3.sol) | Minimal V3 factory, pool, router, WETH, and position-manager interfaces. |
| [`UniV3`](src/lib/UniV3.sol) | Fee-tier validation, token ordering, full-range ticks, and square-root price calculation. |

## Architecture

```text
approved stock tokens ──> ArchStockRegistry
                                │ snapshots executor
                                v
WETH ──> ArchStockSwapExecutor ──> immutable aggregator ──> stock token
                    │
                    └── measures output and returns stock + unused WETH

protocol fees ──> ArchTreasury ──> owner-authorized withdrawals
```

The registry affects new token deployments. Changing or clearing its executor
does not redirect the executor already stored by an existing `ArchToken`.

## Install and build

Foundry is required. Clone recursively so the pinned dependencies are checked
out at their recorded commits.

```bash
git clone --recurse-submodules https://github.com/ArchLiquid/archliquid-core.git
cd archliquid-core
forge build
forge test
forge build --sizes
```

Compiler settings are fixed in [`foundry.toml`](foundry.toml): Solidity 0.8.30,
Paris EVM, optimizer enabled with 200 runs, and IR compilation.

## Configure the registry and executor

The snippet below assumes the transaction sender is the registry owner. The
aggregator address must contain contract code.

```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArchTreasury} from "@archliquid/core/ArchTreasury.sol";
import {ArchStockRegistry} from "@archliquid/core/ArchStockRegistry.sol";
import {ArchStockSwapExecutor} from "@archliquid/core/ArchStockSwapExecutor.sol";

ArchTreasury treasury = new ArchTreasury(protocolMultisig);
ArchStockRegistry registry = new ArchStockRegistry(protocolMultisig);
ArchStockSwapExecutor executor =
    new ArchStockSwapExecutor(IERC20(weth), aggregator);

registry.setApproved(stockToken, true);
registry.setStockSwapExecutor(address(executor));
```

`setApproved` and `setStockSwapExecutor` are protected by OpenZeppelin
`Ownable2Step`. Ownership should be accepted by the intended controller before
the contracts are used by factories.

## Execute a constrained stock swap

```solidity
IERC20(weth).approve(address(executor), amountIn);

uint256 amountOut = executor.swapExactWethForStock(
    stockToken,
    amountIn,
    minStockOut,
    aggregatorCalldata
);
```

The executor provides these call-level guarantees:

- `WETH` and the aggregator target are immutable.
- The aggregator receives an allowance for exactly `amountIn`; the allowance is
  cleared after the call.
- Success is measured from this contract's stock-token balance, rather than
  trusting aggregator return data.
- `minStockOut` is enforced by the executor.
- Pre-existing WETH cannot be spent, and any unused input is returned to the
  caller.
- The purchased stock is always returned to the caller.

Aggregator calldata still determines the route. Generate and validate it for
the configured aggregator, chain, tokens, exact input, and recipient before
submitting the transaction.

## Treasury operations

The treasury accepts ETH through `receive()` and any ERC-20 through a normal
token transfer. Only its owner can withdraw:

```solidity
treasury.withdrawETH(payable(recipient), 1 ether);
treasury.withdrawToken(IERC20(token), recipient, amount);
```

Both withdrawal methods reject the zero recipient. The contract does not
schedule, price, or automatically distribute treasury assets.

## Dependency pins

| Dependency | Commit |
|---|---|
| Foundry standard library | `c179529c064588ede54a0661ec3cc98219460d07` |
| OpenZeppelin Contracts | `5fd1781b1454fd1ef8e722282f86f9293cacf256` |

Consumers should pin an immutable ArchLiquid commit and map
`@archliquid/core/` to this repository's `src/` directory.

## Tests

The current suite covers constrained stock execution, outer slippage
enforcement, recipient validation, partial-input refunds, and preservation of
pre-existing WETH.

```bash
forge fmt --check
forge test -vv
forge build --sizes
```

## Related repositories

- [Lockers](https://github.com/ArchLiquid/archliquid-lockers)
- [Token](https://github.com/ArchLiquid/archliquid-token)
- [Launchpad](https://github.com/ArchLiquid/archliquid-launchpad)
- [Integration contracts](https://github.com/ArchLiquid/archliquid-contracts)

## Security

Read [SECURITY.md](SECURITY.md) before reporting a vulnerability. Use GitHub's
private vulnerability reporting flow; do not publish exploit details in an
issue.

## License

Copyright (c) 2026 ArchLiquid. This repository is public source, not open
source. No permission to use, copy, modify, compile, deploy, or distribute the
materials is granted without prior written approval. See [LICENSE](LICENSE).
Files marked `LicenseRef-ArchLiquid-Proprietary` are governed by that license.
