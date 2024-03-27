// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UnisawpV3Pool pool;

    bool shouldTransferInCallback;

    struct TestCaseParams { // 测试用参数
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 sqrtPriceX96;
        bool shouldTransferInCallback;  // 是否需要在回调函数中转账
        bool mintLiquidity;             // 是否需要添加流动性
    }

    function setUp() public {
        token0 = new ERC20Mintable("ETH", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance : 1 ether,
            usdcBalance : 5000 ether,
            currentTick : 85176,
            lowerTick : 84222,
            upperTick : 86129,
            liquidity : 1517882343751509868544,
            sqrtPriceX96 : 5602277097478614198912276234240,
            shouldTransferInCallback : true,
            mintLiquidity : true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);
        uint256 expectedAmount0 = 0.998976618347425408 ether;
        uint256 expectedAmount1 = 5000 ether;
        
        // 调用 mint 函数的返回值，等于期望值
        require(poolBalance0 == expectedAmount0, "invalid token0 deposit amount");
        require(poolBalance1 == expectedAmount1, "invalid token1 deposit amount");
        // 池子中实际添加的 token 数量，等于期望值
        require(token0.balanceOf(address(pool)) == expectedAmount0, "invalid token0 deposit in pool");
        require(token1.balanceOf(address(pool)) == expectedAmount1, "invalid token1 deposit in pool");
        // positions 更新的流动性等于传入参数
        bytes32 positionKey = keccak256(abi.encodePacked(
            address(this),
            params.lowerTick,
            params.upperTick
        ));
        uint128 poolLiquidity = pool.positions(positionKey);
        require(poolLiquidity == params.liquidity, "invalid liquidity add in pool");
        // lowerTick 更新成功，并且流动性等于传入参数
        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
        require(tickInitialized, "tick update failed");
        require(tickLiquidity == params.liquidity, "invalid tick liquidity");
        // upperTick 更新成功，并且流动性等于传入参数
        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        require(tickInitialized, "tick update failed");
        require(tickLiquidity == params.liquidity, "invalid tick liquidity");
        // 池子中记录的价格和 tick 等于传入参数
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        require(sqrtPriceX96 == params.sqrtPriceX96, "invalid price in pool");
        require(tick == params.currentTick, "invalid tick in pool");
        // 池子中记录的流动性等于传入参数
        require(pool.liquidity() == params.liquidity, "invalid liquidity in pool");
    }

    function setUpTestCase(TestCaseParams memory params) internal returns(uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5000 ether);

        pool = new UnisawpV3Pool(
            address(token0),
            address(token1),
            params.sqrtPriceX96,
            params.currentTick
        );

        shouldTransferInCallback = params.shouldTransferInCallback;

        if(params.mintLiquidity) {
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity
            );
        }
    }

    // mint 回调函数，向 pool 转账
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) external {
        if(shouldTransferInCallback) {
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
        }
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance : 1 ether,
            usdcBalance : 5000 ether,
            currentTick : 85176,
            lowerTick : 84222,
            upperTick : 86129,
            liquidity : 1517882343751509868544,
            sqrtPriceX96 : 5602277097478614198912276234240,
            shouldTransferInCallback : true,
            mintLiquidity : true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        uint256 userBalance0Before = token0.balanceOf(address(this));

        token1.mint(address(this), 42 ether);

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this));
        // swap 函数返回的 token 变化量等于期望值
        require(amount0Delta == -0.008396714242162444 ether, "invalid ETH out");
        require(amount1Delta == 42 ether, "invalid USDC in");
        // 用户 swap 之后 token 数量正确
        require(token0.balanceOf(address(this)) == uint256(int256(userBalance0Before) - amount0Delta), "invalid user ETH balance");
        require(token1.balanceOf(address(this)) == 0, "invalid user USDC balance");
        // 池子 swap 之后 token 数量正确
        require(token0.balanceOf(address(pool)) == uint256(int256(poolBalance0) + amount0Delta), "invalid pool ETH balance");
        require(token1.balanceOf(address(pool)) == uint256(int256(poolBalance1) + amount1Delta), "invalid pool USDC balance");
        // 池子状态正确
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        require(sqrtPriceX96 == 5604469350942327889444743441197, "invalid current sqrtP");
        require(tick == 85184, "invalid current tick");
        require(pool.liquidity() == 1517882343751509868544, "invalid current liquidity");
    }

    // swap 回调函数，向 pool 转账
    function uniswapV3SwapCallback(int256 amount0, int256 amount1) public {
        if(amount0 > 0) {
            token0.transfer(msg.sender, uint256(amount0));
        } 

        if(amount1 > 0) {
            token1.transfer(msg.sender, uint256(amount1));
        }
    }
}