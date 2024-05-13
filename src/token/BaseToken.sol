// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BaseToken is ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol) ERC20Permit(_name) {}


    function mint(uint256 amount) public {
        _mint(msg.sender, amount * 10 ** decimals());
    }
}