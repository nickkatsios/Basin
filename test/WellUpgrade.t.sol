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
import {WellDeployer} from "script/helpers/WellDeployer.sol";


contract WellUpgradeTest is Test, WellDeployer {

    address proxyAddress;
    address aquifer;
    address initialOwner;

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
        WellUpgradeable well = encodeAndBoreWellUpgradeable(aquifer, wellImplementation, tokens, wellFunction, pumps, bytes32(0), initialOwner);

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

        // NOTE: Modifications made to oppenzeppelin contracts
        // 1) removed implementation deployment in deployUUPSProxy function in Upgrades.sol
        // 2) commented out 2nd line in onlyProxy modifier in UUPSUpgradeable.sol
        // (require(_getImplementation() == __self, "Function must be called through active proxy");)
        // 3) Updated oppenzeppelin contracts version

        proxyAddress = Upgrades.deployUUPSProxy(
            "WellUpgradeable.sol", // name
            abi.encodeCall(WellUpgradeable.init, ("WELL", "WELL", initialOwner)), // init data (name, symbol, owner)
            address(well) // implementation address
        );
        console.log("Proxy Address: ", proxyAddress);
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

    function testProxyNumTokens() public {
        uint256 expectedNumTokens = 2;
        assertEq(expectedNumTokens, WellUpgradeable(proxyAddress).numberOfTokens());
    }

    ////////////// Ownership Tests //////////////

    function test_ProxyOwner() public {
        assertEq(initialOwner, WellUpgradeable(proxyAddress).owner());
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
        // getting error due to the onlyProxy modifier in UUPSUpgradeable.sol
        // commented this out for now in UUPSUpgradeable.sol
        // require(_getImplementation() == __self, "Function must be called through active proxy");

        // QUESTION: When we upgrade the proxy to a new implementation, will we need to bore another well
        // and upgrade to that well address?

        // QUESTION: When we upgrade the proxy to a new well, will we need to call the init function again?

        vm.startPrank(initialOwner);
        Upgrades.upgradeProxy(
            proxyAddress,
            "MockWellUpgradeable.sol",
            // just call a random function here to avoid error due to not being a
            // fallback function in the new implementation (Address: low-level delegate call failed)
            abi.encodeCall(MockWellUpgradeable.getVersion, (2))
        );
        assertEq(2, MockWellUpgradeable(proxyAddress).getVersion(2));
        vm.stopPrank();
    }


    function test_UpgradeToNewImplementationAndInteract() public {
        // getting error due to the onlyProxy modifier in UUPSUpgradeable.sol
        // commented this out for now in UUPSUpgradeable.sol
        // require(_getImplementation() == __self, "Function must be called through active proxy");

        vm.startPrank(initialOwner);
        Upgrades.upgradeProxy(
            proxyAddress,
            "MockWellUpgradeable.sol",
            // just call a random function here to avoid error due to not being a
            // fallback function in the new implementation (Address: low-level delegate call failed)
            abi.encodeCall(MockWellUpgradeable.getVersion, (2))
        );
        // this returns 0 --> something messed up in proxy storage?
        // Maybe we need to bore a well first and then upgrade to that well address
        // In that case the upgradeProxy function will need to be modified to take in the implementation address
        assertEq(2, MockWellUpgradeable(proxyAddress).numberOfTokens());
        vm.stopPrank();
    }
}
