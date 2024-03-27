pragma solidity ^0.8.14;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint128 liquidityDelta
    ) internal returns(bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 luquidityBefore = info.liquidity;
        uint128 liquidityAfter = luquidityBefore + liquidityDelta;

        flipped = (liquidityAfter == 0) != (luquidityBefore == 0);
        
        if(luquidityBefore == 0) {
            info.initialized = true;
        }

        info.liquidity = liquidityAfter;
    }
}