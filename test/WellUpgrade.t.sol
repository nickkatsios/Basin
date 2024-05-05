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
import {MockWellUpgradeable} from "mocks/wells/MockWellUpgradeable.sol";


contract WellUpgradeTest is Test {

    IERC20 constant BEAN = IERC20(0xBEA0000029AD1c77D3d5D23Ba2D8893dB9d1Efab);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH9

    address proxyAddress;
    address aquifer;
    address initialOwner;

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
        aquifer = address(new Aquifer());
        address wellImplementation = address(new WellUpgradeable());
        initialOwner = makeAddr("owner");

        // Well
        WellUpgradeable well = encodeAndBoreWell(aquifer, wellImplementation, tokens, wellFunction, pumps, bytes32(0), initialOwner);

        console.log("Deployed CP2 at address: ", address(cp2));
        console.log("Deployed Pump at address: ", address(pumps[0].target));
        console.log("Well deployed at address: ", address(well));

        // Sum up of what is going on here
        // We encode and bore a well upgradeable from the aquifer
        // The well upgradeable additionally takes in an owner address so we modify the init function call
        // to include the owner address. 
        // When the new well is deployed, all init data are stored in the implementation storage 
        // including pump and well function data
        // Then we deploy a proxy for the well upgradeable and call the init function on the proxy
        // We have modified the deployUUPSProxy to remove deploying the implementation and only deploy the proxy
        // with the given well address and init data.
        // When we deploy the proxy, the init data is stored in the proxy storage and the well is initialized 
        // for the second time. We can now control the well via delegate calls to the proxy address.

        // NOTE: With this setup the well is initialized twice, once when we bore the well
        // ond once we deploy the proxy. This should not be possible but it is due
        // to the storage being used each time. The first time we init storage on the well implementation itself
        // and the second time we init storage on the proxy which is what we want.
        // So when calling various functions of the well from the proxy address, the init data such as the symbol
        // will be the data from the second call to init ie the one from deployUUPSProxy

        proxyAddress = Upgrades.deployUUPSProxy(
            "WellUpgradeable.sol", // name
            abi.encodeCall(WellUpgradeable.init, ("WELL", "WELL", initialOwner)), // init data (name, symbol, owner)
            address(well) // implementation address
        );
        console.logAddress(proxyAddress);
    }

    ///////////////////// Storage Tests /////////////////////

    function test_ProxyGetAquifer() public {
        assertEq(address(aquifer), WellUpgradeable(proxyAddress).aquifer());
    }

    function test_ProxyGetSymbolInStorage() public {
        assertEq("WELL", WellUpgradeable(proxyAddress).symbol());
    }

    function testProxyInitVersion() public {
        uint256 expectedVersion = 1;
        assertEq(expectedVersion, WellUpgradeable(proxyAddress).getVersion());
    }

    ////////////// Ownership Tests //////////////

    function test_ProxyOwner() public {
        assertEq(makeAddr("owner"), WellUpgradeable(proxyAddress).owner());
    }

    function test_ProxyTransferOwnership() public {
        vm.prank(initialOwner);
        address newOwner = makeAddr("newOwner");
        WellUpgradeable(proxyAddress).transferOwnership(newOwner);
        assertEq(newOwner, WellUpgradeable(proxyAddress).owner());
    }

    function test_RevertTransferOwnershipFromNotOnwer() public {
        vm.expectRevert();
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        WellUpgradeable(proxyAddress).transferOwnership(notOwner);
    }

    ////////////////////// Upgrade Tests //////////////////////

    function test_UpgradeToNewImplementation() public {
        Upgrades.upgradeProxy(
            proxyAddress,
            "MockWellUpgradeable.sol",
            ""
        );
        assertEq(2, MockWellUpgradeable(proxyAddress).getVersion());
    }
}
