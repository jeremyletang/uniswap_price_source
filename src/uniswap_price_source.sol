// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/libraries/TickMath.sol";
import "v3-core/contracts/libraries/FixedPoint96.sol";
import "v3-core/contracts/libraries/FullMath.sol";


interface IERC20 {
    function decimals() external view returns (uint256);
}

contract AUniswapPriceSource {
    // always needs the WETH, USDT, and USDT/WETH pool address
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IUniswapV3Pool constant usdtWethPool = IUniswapV3Pool(0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36);
    IUniswapV3Pool constant usdcWethPool = IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);

    function getPriceFromPool(IUniswapV3Pool pool, uint32 twapInterval, address quoteToken) public view returns (uint256) {
        uint256 decimals = getAdjustedDecimals(pool, quoteToken);
        return getActualPrice(getPriceX96FromSqrtPriceX96(getSqrtTwapX96(pool, twapInterval, quoteToken)), decimals);
    }

    /// @notice Get the price of a token in terms of USDT
    /// @param pool The Uniswap v3 pool to get the price of the token in terms of USDT
    /// @param twapInterval The time interval in seconds to get the twap over
    /// @return price The price of the token in terms of USDT with 18 decimals
    function priceFromEthPoolInUsdt(IUniswapV3Pool pool, uint32 twapInterval) public view returns (uint256) {
        // get the price from the eth pool first
        uint256 tokenEthPrice = priceFromWethPool(pool, twapInterval);
        return (ethPriceInUsdt() * tokenEthPrice) / 10 ** 18;
    }

    /// @notice Get the price of a token in terms of USDC
    /// @param pool The Uniswap v3 pool to get the price of the token in terms of USDC
    /// @param twapInterval The time interval in seconds to get the twap over
    /// @return price The price of the token in terms of USDC with 18 decimals
    function priceFromEthPoolInUsdc(IUniswapV3Pool pool, uint32 twapInterval) public view returns (uint256) {
        // get the price from the eth pool first
        uint256 tokenEthPrice = priceFromWethPool(pool, twapInterval);
        return (ethPriceInUsdc() * tokenEthPrice) / 10 ** 18;
    }

    /// @notice Get the price of ETH in terms of USDT
    /// @return price The price of ETH in terms of USDT with 18 decimals
    function ethPriceInUsdt() public view returns (uint256) {
        return getPriceFromPool(usdtWethPool, 30 minutes, USDT);
    }

    /// @notice Get the price of ETH in terms of USDC
    /// @return price The price of ETH in terms of USDC with 18 decimals
    function ethPriceInUsdc() public view returns (uint256) {
        return getPriceFromPool(usdcWethPool, 30 minutes, USDC);
   }

    /// @notice Get the price of a token from an USDC/TOKENX pool
    /// @return price The price of the token in terms of USDC with 18 decimals
    function priceFromUsdcPool(IUniswapV3Pool pool, uint32 twapInterval) public view returns (uint256) {
        require(pool.token0() == USDC || pool.token1() == USDC, "at least one token from the pool must be USDC");
        return getPriceFromPool(pool, twapInterval, USDC);
    }

    /// @notice Get the price of a token from an USDT/TOKENX pool
    /// @return price The price of the token in terms of USDT with 18 decimals
    function priceFromUsdtPool(IUniswapV3Pool pool, uint32 twapInterval) public view returns (uint256) {
        require(pool.token0() == USDT || pool.token1() == USDT, "at least one token from the pool must be USDT");
        return getPriceFromPool(pool, twapInterval, USDT);
    }

    /// @notice Get the price of a token in terms of WETH
    /// @param pool The Uniswap v3 pool to get the price of the token in terms of WETH
    /// @param twapInterval The time interval in seconds to get the twap over
    /// @return price The price of the token in terms of WETH with 18 decimals
    function priceFromWethPool(IUniswapV3Pool pool, uint32 twapInterval) public view returns (uint256) {
        require(pool.token0() == WETH || pool.token1() == WETH, "at least one token from the pool must be WETH");
        return getPriceFromPool(pool, twapInterval, WETH);
    }

    // helper functions

    /// @notice Get the current twap price of a pool
    /// @param pool The Uniswap v3 pool to get the twap price of
    /// @param twapInterval The time interval in seconds to get the twap over
    /// @param quoteToken The token to quote the price in terms of
    /// @return sqrtPriceX96 The time weighted average price
    function getSqrtTwapX96(IUniswapV3Pool pool, uint32 twapInterval, address quoteToken)
        public
        view
        returns (uint160 sqrtPriceX96)
    {
        require(
            pool.token0() == quoteToken || pool.token1() == quoteToken, "at least one token from the pool must be the quoted token"
        );
        require(twapInterval > 0, "twap interval must be > 0");
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval; // from (before)
        secondsAgos[1] = 0; // to (now)

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        (uint256 quoteTokenIdx, uint256 otherTokenIdx) = (0, 1);
        if (pool.token1() == quoteToken) {
            (quoteTokenIdx, otherTokenIdx) = (1, 0);
        }
        // tick(imprecise as it's an integer) to price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[quoteTokenIdx] - tickCumulatives[otherTokenIdx]) / twapInterval)
        );
    }

    /// @notice Convert sqrtPriceX96 to priceX96
    /// @param sqrtPriceX96 The sqrt price to convert
    /// @return priceX96 The price
    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns (uint256) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    /// @notice Convert priceX96 to price
    /// @param priceX96 The price to convert
    /// @param decimals The decimals of the price
    /// @return price The price
    function getActualPrice(uint256 priceX96, uint256 decimals) public pure returns (uint256) {
        return (priceX96 * (10 ** decimals)) / 2 ** 96;
    }

    /// @notice Get the adjusted decimals of a pool towards a quote token
    /// @param pool The Uniswap v3 pool to convert the decimals of
    /// @param quoteToken The token to quote the price in terms of
    /// @return decimals The adjusted decimals
    function getAdjustedDecimals(IUniswapV3Pool pool, address quoteToken) public view returns (uint256) {
        uint256 t0Decimals = IERC20(pool.token0()).decimals();
        uint256 t1Decimals = IERC20(pool.token1()).decimals();
        if (pool.token1() == quoteToken) {
            if (t1Decimals < t0Decimals) {
                return 18 + t0Decimals - t1Decimals;
            } else if (t1Decimals > t0Decimals) {
                return 18 - (t1Decimals - t0Decimals);
            }
        }
        if (pool.token0() == quoteToken) {
            if (t1Decimals < t0Decimals) {
                return 18 - (t0Decimals - t1Decimals);
            } else if (t1Decimals > t0Decimals) {
                return 18 + (t1Decimals - t0Decimals);
            }
        }
        return 18;
    }
}
