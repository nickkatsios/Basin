// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20, Balances, Call, MockToken, Well, console} from "test/TestHelper.sol";
import {SwapHelper, SwapAction, Snapshot} from "test/SwapHelper.sol";
import {MockFunctionBad} from "mocks/functions/MockFunctionBad.sol";
import {IWellFunction} from "src/interfaces/IWellFunction.sol";
import {IWell} from "src/interfaces/IWell.sol";
import {IWellErrors} from "src/interfaces/IWellErrors.sol";


contract WellSwapFromStableSwapTest is SwapHelper {
    function setUp() public {
        setupStableSwapWell(10);
    }

    function test_getSwapOut() public {
        uint amountIn = 10 * 1e18;
        uint amountOut = well.getSwapOut(tokens[0], tokens[1], amountIn);

        assertEq(amountOut, 9_995_239_930_393_036_263); // ~0.05% slippage
    }

    function testFuzz_getSwapOut_revertIf_insufficientWellBalance(uint amountIn, uint i) public prank(user) {
        // Swap token `i` -> all other tokens
        vm.assume(i < tokens.length);

        // Find an input amount that produces an output amount higher than what the Well has.
        // When the Well is deployed it has zero reserves, so any nonzero value should revert.
        amountIn = bound(amountIn, 1, type(uint128).max);

        // Deploy a new Well with a poorly engineered pricing function.
        // Its `getBalance` function can return an amount greater than the Well holds.
        IWellFunction badFunction = new MockFunctionBad();
        Well badWell = encodeAndBoreWell(
            address(aquifer), wellImplementation, tokens, Call(address(badFunction), ""), pumps, bytes32(0)
        );

        // Check assumption that reserves are empty
        Balances memory wellBalances = getBalances(address(badWell), badWell);
        assertEq(wellBalances.tokens[0], 0, "bad assumption: wellBalances.tokens[0] != 0");
        assertEq(wellBalances.tokens[1], 0, "bad assumption: wellBalances.tokens[1] != 0");

        for (uint j = 0; j < tokens.length; ++j) {
            if (j != i) {
                vm.expectRevert(); // underflow
                badWell.getSwapOut(tokens[i], tokens[j], amountIn);
            }
        }
    }

    /// @dev Swaps should always revert if `fromToken` = `toToken`.
    function test_swapFrom_revertIf_sameToken() public prank(user) {
        vm.expectRevert(IWellErrors.InvalidTokens.selector);
        well.swapFrom(tokens[0], tokens[0], 100 * 1e18, 0, user, type(uint).max);
    }

    /// @dev Slippage revert if minAmountOut is too high
    function test_swapFrom_revertIf_minAmountOutTooHigh() public prank(user) {
        uint amountIn = 10 * 1e18;
        uint amountOut = well.getSwapOut(tokens[0], tokens[1], amountIn);
        uint minAmountOut = amountOut + 1e18;

        vm.expectRevert(abi.encodeWithSelector(IWellErrors.SlippageOut.selector, amountOut, minAmountOut));
        well.swapFrom(tokens[0], tokens[1], amountIn, minAmountOut, user, type(uint).max);
    }

    function test_swapFrom_revertIf_expired() public {
        vm.expectRevert(IWellErrors.Expired.selector);
        well.swapFrom(tokens[0], tokens[1], 0, 0, user, block.timestamp - 1);
    }

    function testFuzz_swapFrom(uint amountIn) public prank(user) {
        amountIn = bound(amountIn, 0, tokens[0].balanceOf(user));

        (Snapshot memory bef, SwapAction memory act) = beforeSwapFrom(0, 1, amountIn);
        act.wellSends = well.swapFrom(tokens[0], tokens[1], amountIn, 0, user, type(uint).max);
        afterSwapFrom(bef, act);
        checkStableSwapInvariant(address(well));
    }

    function testFuzz_swapAndRemoveAllLiq(uint amountIn) public {
        amountIn = bound(amountIn, 0, tokens[0].balanceOf(user));
        vm.prank(user); 
        well.swapFrom(tokens[0], tokens[1], amountIn, 0, user, type(uint).max);

        vm.prank(address(this));
        well.removeLiquidityImbalanced(
            type(uint).max,
            IWell(address(well)).getReserves(),
            address(this),
            type(uint).max
        );
        assertEq(IERC20(address(well)).totalSupply(),0);
    }

    /// @dev Zero hysteresis: token0 -> token1 -> token0 gives the same result
    function testFuzz_swapFrom_equalSwap(uint token0AmtIn) public prank(user) {
        vm.assume(token0AmtIn < tokens[0].balanceOf(user));
        uint token1Out = well.swapFrom(tokens[0], tokens[1], token0AmtIn, 0, user, type(uint).max);
        uint token0Out = well.swapFrom(tokens[1], tokens[0], token1Out, 0, user, type(uint).max);
        assertEq(token0Out, token0AmtIn);
        checkInvariant(address(well));
    }
}