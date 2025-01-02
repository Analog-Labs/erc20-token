// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AnlogToken} from "../src/AnlogToken.sol";

contract AnlogTokenTest is Test {
    AnlogToken public token;

    function setUp() public {
        token = new AnlogToken("Analog One", "ANLOG");
    }

    modifier preMint(address to, uint256 amount) {
        assertEq(token.totalSupply(), 0);
        token.mint(to, amount);
        assertEq(token.totalSupply(), amount);
        _;
    }

    function test_Mint() public preMint(address(1), 20_000) {
        assertEq(token.balanceOf(address(1)), 20_000);
    }

    function test_Transfer() public preMint(address(this), 20_000) {
        assertEq(token.balanceOf(address(2)), 0);
        token.transfer(address(2), 5_000);
        assertEq(token.balanceOf(address(2)), 5_000);
    }

    function test_Pause() public {
        assert(false);
    }
}
