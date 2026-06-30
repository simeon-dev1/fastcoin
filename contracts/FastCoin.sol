// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Fastcoin {
	string public name = "FastCoin";
	string public symbol = "FST";
	uint8 public decimals = 18;
	uint256 public totalSupply;
	mapping(address => uint256) public balanceOf;

	constructor(uint256 _initialSupply) {
		totalSupply = _initialSupply * 10 ** decimals;
		balanceOf[msg.sender] = totalSupply;
	}
}
