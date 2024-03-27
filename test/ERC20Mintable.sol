// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "solmate/tokens/ERC20.sol";

contract ERC20Mintable is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimal
    ) ERC20(name, symbol, decimal) {}

    // only used for test
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}