# Uniswap Price Source Contract

This Solidity smart contract provides a set of functions to retrieve prices from Uniswap V3 pools, specifically targeting prices in terms of USDT, USDC, and WETH. The contract is designed to handle various scenarios, including getting prices from different pools and applying multipliers.

## Prerequisites

- Solidity version 0.7.6
- Ethereum network supporting Uniswap V3 contracts
- External dependencies: `v3-core` contracts (imported in the code)

## Contract Overview

The contract includes the following key functions:

- `getPriceFromPool`: Get the price of a token in terms of a specified quote token.
- `priceFromEthPoolInUsdt` and `priceFromEthPoolInUsdc`: Get the price of a token in terms of USDT or USDC, with an optional multiplier.
- `ethPriceInUsdt` and `ethPriceInUsdc`: Get the price of ETH in terms of USDT or USDC.
- `priceFromUsdcPool` and `priceFromUsdtPool`: Get the price of a token from an USDC or USDT pool, respectively.
- `priceFromWethPool`: Get the price of a token in terms of WETH.
- `priceFromUsdtPoolInUsdc` and `priceFromUsdcPoolInUsdt`: Get the price of a token in terms of USDC or USDT from a USDT or USDC pool, respectively.
- `usdtPriceInUsdc` and `usdcPriceInUsdt`: Get the price of USDT in terms of USDC or vice versa.

## Usage

1. Deploy the contract on an Ethereum network.
2. Call the desired functions based on your price calculation needs.

Note: Ensure the contract has sufficient permissions and funds to interact with the Uniswap V3 pools.

## License

This contract is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Disclaimer

This contract is provided as-is without any warranties. Use it at your own risk
