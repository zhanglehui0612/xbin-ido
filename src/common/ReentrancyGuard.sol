// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

abstract contract ReentrancyGuard {
    bool internal locked;

    modifier noReentrancy() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }
}