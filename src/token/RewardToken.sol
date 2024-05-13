// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {BaseToken} from "./BaseToken.sol";

contract RewardToken is BaseToken, ERC20Burnable {
    constructor() BaseToken("esRNT", "esRNT"){}

    function mint(address caller, uint256 amount) public{
        _mint(caller, amount * 10 ** decimals());
    }
}