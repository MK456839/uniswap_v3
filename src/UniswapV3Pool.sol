// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {Tick} from "helpers/Tick.sol";
import {Position} from "helpers/Position.sol";
import {TickBitmap} from "helpers/TickBitmap.sol";

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(uint256, uint256) external;
    function uniswapV3SwapCallback(int256, int256) external;
}

interface IERC20 {
    function balanceOf(address account) external returns(uint256);
    function transfer(address to, uint256 amount) external returns(bool);
}

contract UnisawpV3Pool {
    using TickBitmap for mapping(int16 => uint256);
    mapping(int16 => uint256) public tickBitmap;
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal immutable MIN_TICK = -887272;
    int24 internal immutable MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    // Amount of liquidity
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    event Mint(address indexed sender, address indexed owner, int24 lowerTick, int24 upperTick, uint256 amount, uint256 amount0, uint256 amount1);
    event Swap(address indexed caller, address indexed recipient, int256 amount0, int256 amount1, uint160 price, uint128 liquidity, int24 tick);

    constructor(
        address _token0,
        address _token1,
        uint160 _sqrtPriceX96,
        int24 _tick
    ) {
        token0 = _token0;
        token1 = _token1;
        slot0 = Slot0({
            sqrtPriceX96 : _sqrtPriceX96,
            tick : _tick
        });
    }

    // 在区间[lowerTick, upperTick]中提供流动性，流动性数量为amount
    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) public returns(uint256 amount0, uint256 amount1) {
        require(lowerTick < upperTick && lowerTick > MIN_TICK && upperTick < MAX_TICK, "invalid tick range");
        require(amount > 0, "invalid amount input");

        liquidity = amount;

        bool flippedLower = ticks.update(lowerTick, amount); // 更新 lowerTick 位置上的流动性
        bool flippedUpper = ticks.update(upperTick, amount); // 更新 upperTick 位置上的流动性

        if(flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        if(flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick 
        );
        position.update(amount); // 通过 owner、lowerTick、upperTick 唯一生成 id 更新 position 的流动性

        // amount0 = 0.998976618347425408 ether; // 实际添加的 ETH 数量
        // amount1 = 5000 ether;                 // 实际添加的 USDC 的数量
        
        Slot0 memory slot0_ = slot0;
        
        amount0 = Math.calcAmount0Delta(
            slot0_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(upperTick),
            amount
        );

        amount1 = Math.calcAmount1Delta(
            slot0_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(lowerTick),
            amount
        );

        uint256 balance0Before;
        uint256 balance1Before;
        if(amount0 > 0) balance0Before = balance0();
        if(amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback( // 通过回调函数来收取用户添加流动性的代币
            amount0,
            amount1
        );
        if(amount0 > 0) require(balance0() >= balance0Before + amount0, "token0 add failed"); 
        if(amount1 > 0) require(balance1() >= balance1Before + amount1, "token1 add failed");

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    function balance0() internal returns(uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns(uint256) {
        return IERC20(token1).balanceOf(address(this));
    }

    // State 2
    function swap(address recipient) public returns(int256 amount0, int256 amount1) {
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        IERC20(token0).transfer(recipient, uint256(-amount0));

        uint256 balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3SwapCallback( // 通过回调函数来收取用户添加流动性的代币
            amount0,
            amount1
        );
        require(balance1() >= balance1Before + uint256(amount1), "token1 add failed");
        
        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            nextPrice,
            liquidity,
            nextTick
        );
    }
}