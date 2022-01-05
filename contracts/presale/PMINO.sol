pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// PMINO
contract PMINO is ERC20('PMINO', 'PMINO') {
    constructor() {
        _mint(address(0x86Fdd9980aCD3e2C8e7959Db344Ff6D5FD5743F5), uint256(40 * 1e3 * 1e9));
    }

	function decimals() public view override returns (uint8) {
		return 9;
	}
}