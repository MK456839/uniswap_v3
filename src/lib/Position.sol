pragma solidity ^0.8.14;

library Position {
    struct Info {
        uint128 liquidity;
    }

    function update(
        Info storage info,
        uint128 liquidityDelta
    ) internal {
        uint128 liquidityBefore = info.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        info.liquidity = liquidityAfter;
    }

    function get(
        mapping(bytes32 => Position.Info) storage self,
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) internal view returns(Position.Info storage position){
        position = self[
            keccak256(abi.encodePacked(owner, lowerTick, upperTick))
        ];
    }
}