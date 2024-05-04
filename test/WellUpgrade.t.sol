// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WellUpgradeable} from "src/WellUpgradeable.sol";
import {IERC20} from "test/TestHelper.sol";
import {Upgrades} from "ozuf/Upgrades.sol";
import {Script} from "forge-std/Script.sol";
import {WellDeployer} from "script/helpers/WellDeployer.sol";
import {MockPump} from "mocks/pumps/MockPump.sol";
import {Well, Call, IWellFunction, IPump, IERC20} from "src/Well.sol";
import {ConstantProduct2} from "src/functions/ConstantProduct2.sol";
import {Aquifer} from "src/Aquifer.sol";
import {WellDeployer} from "script/helpers/WellDeployer.sol";
import {LibWellUpgradeableConstructor} from "src/libraries/LibWellUpgradeableConstructor.sol";
import {LibContractInfo} from "src/libraries/LibContractInfo.sol";
import {MockToken} from "mocks/tokens/MockToken.sol";


contract WellUpgradeTest is Test {

    IERC20 constant BEAN = IERC20(0xBEA0000029AD1c77D3d5D23Ba2D8893dB9d1Efab);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH9

    address proxyAddress;
    uint256 mainnetFork;

    function encodeAndBoreWell(
        address _aquifer,
        address _wellImplementation,
        IERC20[] memory _tokens,
        Call memory _wellFunction,
        Call[] memory _pumps,
        bytes32 _salt,
        address owner
    ) internal returns (WellUpgradeable _well) {
        (bytes memory immutableData, bytes memory initData) =
            LibWellUpgradeableConstructor.encodeWellDeploymentData(_aquifer, _tokens, _wellFunction, _pumps, owner);
        _well = WellUpgradeable(Aquifer(_aquifer).boreWell(_wellImplementation, immutableData, initData, _salt));
    }

    function setUp() public {

        // Tokens
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = new MockToken("BEAN", "BEAN", 6);
        tokens[1] = new MockToken("WETH", "WETH", 18);


        // Well Function
        IWellFunction cp2 = new ConstantProduct2();
        Call memory wellFunction = Call(address(cp2), new bytes(0));

        // Pump
        IPump mockPump = new MockPump();
        Call[] memory pumps = new Call[](1);
        pumps[0] = Call(address(mockPump), new bytes(0));
        address aquifer = address(new Aquifer());
        address wellImplementation = address(new WellUpgradeable());
        address owner = address(this);

        // Well
        WellUpgradeable well = encodeAndBoreWell(aquifer, wellImplementation, tokens, wellFunction, pumps, bytes32(0), owner);

        console.log("Deployed CP2 at address: ", address(cp2));
        console.log("Deployed Pump at address: ", address(pumps[0].target));
        console.log("Well deployed at address: ", address(well));

        proxyAddress = Upgrades.deployUUPSProxy(
            "WellUpgradeable.sol", // name
            abi.encodeCall(WellUpgradeable.init, ("A", "B", owner)), // init data (name, symbol, owner)
            address(well) // implementation address
        );
        console.logAddress(proxyAddress);
    }

    // deploy well upgradeable just the implementation without proxy 
    // call borewell with that implementation and figure out ownership parameters
    function testProxyInitVersion() public {
        uint256 expectedVersion = 1;
        assertEq(expectedVersion, WellUpgradeable(proxyAddress).getVersion());
    }

}
