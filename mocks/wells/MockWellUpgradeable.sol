// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {WellUpgradeable} from "src/WellUpgradeable.sol";

/// @custom:oz-upgrades-from WellUpgradeable
contract MockWellUpgradeable is WellUpgradeable {

    function getVersion() external override pure returns (uint256) {
        return 2;
    }

}