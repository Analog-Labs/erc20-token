// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AnlogToken} from "../src/AnlogToken.sol";

contract AnlogTokenTest is Test {
    AnlogToken public token;

    function setUp() public {
        token = new AnlogToken("Analog One", "ANLOG");
    }

    function test_Mint() public {
        assert(false);
    }

    function test_Pause() public {
        assert(false);
    }
}
