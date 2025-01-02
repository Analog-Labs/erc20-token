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
        assertEq(token.totalSupply(), 0);

        token.mint(address(1), 20_000);

        assertEq(token.totalSupply(), 20_000);
        assertEq(token.balanceOf(address(1)), 20_000);

    }

    function test_Pause() public {
        assert(false);
    }
}
