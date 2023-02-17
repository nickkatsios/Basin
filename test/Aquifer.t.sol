// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {TestHelper, Well, IERC20, console} from "test/TestHelper.sol";
import {IWell, Call} from "src/interfaces/IWell.sol";
import {ConstantProduct} from "src/functions/ConstantProduct.sol";
import {LibClone} from "src/libraries/LibClone.sol";
import {Aquifer} from "src/Aquifer.sol";

contract AquiferTest is TestHelper {
    address[] wells;

    event BoreWell(
        address well,
        address implementation,
        IERC20[] tokens,
        Call wellFunction,
        Call[] pumps,
        bytes wellData
    );

    function setUp() public {
        initUser();
        deployMockTokens(10);

        //    
        deployWellImplementation();
        aquifer = new Aquifer();

        // Prep Wells
        wellFunction = Call(address(new ConstantProduct()), new bytes(0));

        // See {WellDeployer}
        well = boreWell(
            address(aquifer),
            wellImplementation,
            getTokens(2),
            wellFunction,
            pumps,
            bytes32(0) // salt
        );
    }

    /// @dev well function
    function test_aquifer_wellFunction() public {
        check_wellFunction(well.wellFunction());
    }

    function check_wellFunction(Call memory _wellFunction) private {
        assertEq(_wellFunction.target, wellFunction.target);
        assertEq(_wellFunction.data, wellFunction.data);
    }

    //////////// DEPLOYMENT ////////////

    /// @dev events cannot be checked as the address is not known
    // prior to deployment
    // FIXME: should we add a salt when deploying a well so that this can be tested?
    function test_boreEvent() external {
        IERC20[] memory _tokens = getTokens(2);
        bytes32 salt = bytes32(uint(1));

        address a = LibClone.predictDeterministicAddress(
            address(wellImplementation),
            encodeWellImmutableData(address(aquifer), _tokens, wellFunction, pumps),
            salt,
            address(aquifer)
        );

        vm.expectEmit(true, true, true, true, address(aquifer));
        emit BoreWell(
            a,
            address(wellImplementation),
            _tokens,
            wellFunction,
            pumps,
            new bytes(0) // well data
        );

        well = boreWell(
            address(aquifer),
            wellImplementation,
            _tokens,
            wellFunction,
            pumps,
            salt
        );

        console.log("Well address", address(well));
    }
}