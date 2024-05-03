// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WellUpgradeable} from "src/WellUpgradeable.sol";
import  {IERC20} from "test/TestHelper.sol";
import {Upgrades} from "ozuf/Upgrades.sol";

contract WellUpgradeTest is Test {

    IERC20 token;
    address proxyAddress;
    uint256 mainnetFork;

    function setUp() public {
        proxyAddress = Upgrades.deployUUPSProxy(
            "WellUpgradeable.sol",
            abi.encodeCall(WellUpgradeable.init, ("A", "B"))
        );
        console.logAddress(proxyAddress);
    }

    function testProxyInitVersion() public {
        uint256 expectedVersion = 1;
        assertEq(expectedVersion, WellUpgradeable(proxyAddress).getVersion());
    }

}
