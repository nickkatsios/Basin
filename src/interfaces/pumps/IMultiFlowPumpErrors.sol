// SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

/**
 * @title IMultiFlowPumpErrors defines the errors for the MultiFlowPump.
 * @dev The errors are separated into a different interface as not all Pump
 * implementations may share the same errors.
 */
interface IMultiFlowPumpErrors {
    error NotInitialized();

    error NoTimePassed();

    error InvalidMaxPercentDecreaseArgument(bytes16 maxPercentDecrease);

    error InvalidAArgument(bytes16 a);

    error InvalidCapIntervalArgument(uint256 capInterval);
}
