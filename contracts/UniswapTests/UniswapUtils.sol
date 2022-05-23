// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../OnlyOwner.sol";
import "../CoinflipView.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IWETH.sol";


contract Uniswap {

    address LINK_ADDRESS = 0xa36085F69e2889c224210F603D836748e7dC0088;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    function getAmountOutMin(uint _amountIn, address[] memory tokenPath) external view returns (uint) {
        uint[] memory amountOutMins = IUniswapV2Router(UNISWAP_V2_ROUTER).getAmountsOut(_amountIn, tokenPath);
        return amountOutMins[tokenPath.length - 1];
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
  
      function getReserves(address tokenA, address tokenB) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(0x459125C711A250084a986b9fc698159865f1805e).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * (997);
        uint numerator = amountInWithFee * (reserveOut);
        uint denominator = (reserveIn * (1000)) + (amountInWithFee);
        amountOut = numerator / denominator;
    }

     function getAmountsOut(address factory, uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        address _tokenIn = path[0];
        address _tokenOut = path[1];
        
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        return amounts;
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            //address to = i < path.length - 2 ? UniswapV2Library.pairFor(FACTORY, output, path[i + 2]) : _to;
            address to = _to;
            IUniswapV2Pair(0x5ae45101eB47752Ea0068F432735cF00F6C849bD).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
  
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to)
        external
        virtual
        payable
        returns (uint[] memory amounts){
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        amounts = getAmountsOut(FACTORY, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(0x5ae45101eB47752Ea0068F432735cF00F6C849bD, amounts[0]));
        _swap(amounts, path, to);
    }
}