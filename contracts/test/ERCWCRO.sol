//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERCWCRO is ERC20 {
    constructor() ERC20("ERCWCRO", "ERCWCRO") {
        _mint(address(0x4E5D385E44DCD0b7adf5fBe03A6BB867A8A90E7B), uint256(50 * 1e6 * 1e18));
        _mint(address(0x86Fdd9980aCD3e2C8e7959Db344Ff6D5FD5743F5), uint256(50 * 1e6 * 1e18));
    }

	function decimals() public view override returns (uint8) {
		return 18;
	}
}