// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice IsaXX — prism-fold intent shard exchange for rollup corridors.

library IxxClamp {
    error IXX_ClampFault();
    uint256 internal constant BPS = 10_000;
    function boundU24(uint256 v, uint24 lo, uint24 hi) internal pure returns (uint24) {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return uint24(v);
    }
    function feeSlice(uint256 gross, uint256 bps) internal pure returns (uint256) {
        unchecked { return (gross * bps) / BPS; }
    }
    function cappedAdd(uint256 a, uint256 b, uint256 cap) internal pure returns (uint256) {
        unchecked {
            uint256 s = a + b;
            if (s < a || s > cap) revert IXX_ClampFault();
            return s;
        }
    }
}

contract IsaXX {
    error IXx_NotDirector();
    error IXx_NotCurator();
    error IXx_LanePaused();
    error IXx_ZeroAddr();
    error IXx_ZeroWei();
    error IXx_Reentered();
    error IXx_CorridorVoid();
    error IXx_CorridorHalted();
    error IXx_ShardExists();
    error IXx_ShardMissing();
    error IXx_TierInvalid();
    error IXx_QuotaFull();
    error IXx_CycleBad();
    error IXx_BundleOpen();
    error IXx_BundleMissing();
    error IXx_BundleSealed();
    error IXx_RelayStale();
    error IXx_TrustLow();
    error IXx_TrustHigh();
    error IXx_HandoffSelf();
    error IXx_HashVoid();
    error IXx_VoteCast();
    error IXx_VoteSelf();
    error IXx_BondLow();
    error IXx_NativeFail();
    error IXx_BatchWide();
    error IXx_LengthMismatch();
    error IXx_NotRelay();
    error IXx_RelayKnown();
    error IXx_FallbackBlocked();
    error IXx_FaultLine_30();
    error IXx_FaultLine_31();
    error IXx_FaultLine_32();
    error IXx_FaultLine_33();
    error IXx_FaultLine_34();
    error IXx_FaultLine_35();
    error IXx_FaultLine_36();
    error IXx_FaultLine_37();
    error IXx_FaultLine_38();
    error IXx_FaultLine_39();

    event Filed(bytes32 indexed shardId, uint256 indexed corridorId, address indexed relay, uint8 tier, uint256 weiBond);
    event Voted(bytes32 indexed shardId, address indexed voter, bool affirm, uint256 cycleId);
