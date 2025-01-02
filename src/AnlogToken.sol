// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/// @notice for starter, this is just pure OZ preset as it is.
contract AnlogToken is ERC20PresetMinterPauser {
    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {}
}
