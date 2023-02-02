// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/**
 * @title Lib Last Reserve Bytes
 */
library LibLastReserveBytes {
    function readN(bytes32 slot) internal view returns (uint8 n) {
        assembly {
            n := shr(248, sload(slot))
        }
    }

    function storeLastReserves(bytes32 slot, uint40 lastTimestamp, bytes16[] memory reserves) internal {
        // require(reserves[0] <= type(uint104).max, "ByteStorage: too large");
        // TODO: Remove most significant bytes
        uint8 n = uint8(reserves.length);
        if (n == 1) {
            assembly {
                sstore(slot, 
                or(
                    or(shl(208, lastTimestamp), shl(248, n)),
                    shl(104, shr(152, mload(add(reserves, 32))))
                ))
            }
            return;
        }
        assembly {
            sstore(slot, 
            or(
                or(shl(208, lastTimestamp), shl(248, n)),
                or(
                    shl(104, shr(152, mload(add(reserves, 32)))), 
                    shr(152, mload(add(reserves, 64)))
                )
            ))
            // slot := add(slot, 32)
        }
        if (n > 2) {
            uint maxI = n / 2; // number of fully-packed slots
            uint iByte; // byte offset of the current reserve
            for (uint i = 1; i < maxI; ++i) {
                iByte = i * 64;
                assembly {
                    sstore(
                        add(slot, mul(i, 32)),
                        add(
                            mload(add(reserves, add(iByte, 32))),
                            shr(128, mload(add(reserves, add(iByte, 64))))
                        )
                    )
                }
            }
            // If there is an odd number of reserves, create a slot with the last reserve
            // Since `i < maxI` above, the next byte offset `maxI * 64`
            if (reserves.length % 2 == 1) {
                iByte = maxI * 64;
                assembly {
                    sstore(
                        add(slot, mul(maxI, 32)),
                        add(
                            mload(add(reserves, add(iByte, 32))),
                            shr(128, shl(128, sload(add(slot, maxI))))
                        )
                    )
                }
            }
        }
    }

    /**
     * @dev Read `n` packed bytes16 reserves at storage position `slot`.
     */
    function readLastReserves(bytes32 slot) internal view returns (uint8 n, uint40 lastTimestamp, bytes16[] memory reserves) {
        // Shortcut: two reserves can be quickly unpacked from one slot
        bytes32 temp;
        assembly {
            temp := sload(slot)
            n := shr(248, temp)
            lastTimestamp := shr(208, temp)
        }
        if (n == 0) return (n, lastTimestamp, reserves);
        // Initialize array with length `n`, fill it in via assembly
        reserves = new bytes16[](n);
        assembly { mstore(add(reserves, 32), shl(152, shr(104, temp))) }
        if (n == 1) return (n, lastTimestamp, reserves);
        assembly { mstore(add(reserves, 64), shl(152, temp)) }

        if (n > 2) {
            uint iByte;
            for (uint i = 3; i <= n; ++i) {
                // `iByte` is the byte position for the current slot:
                // i        3 4 5 6
                // iByte    1 1 2 2
                iByte = (i - 1) / 2 * 32;
                if (i % 2 == 1) {
                    assembly {
                        mstore(
                            // store at index i * 32; i = 0 is skipped by loop
                            add(reserves, mul(i, 32)),
                            sload(add(slot, iByte))
                        )
                    }
                } else {
                    assembly {
                        mstore(
                            add(reserves, mul(i, 32)),
                            sload(add(slot, iByte))
                        )
                    }
                }
            }
        }
    }

    function readBytes(bytes32 slot) internal view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }
}
