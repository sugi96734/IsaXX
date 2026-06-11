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
    event Bonded(bytes32 indexed shardId, address indexed from, uint256 weiAmt, uint256 cycleId);
    event Routed(bytes32 indexed bundleId, uint256 indexed corridorId, bytes32 intentTag, uint256 queuedAt);
    event Settled(bytes32 indexed bundleId, bytes32 payloadHash, uint16 trustScore, uint256 cycleId);
    event Signaled(bytes32 indexed signalId, uint256 indexed corridorId, uint16 signalBand, uint256 stampedAt);
    event Opened(uint256 indexed corridorId, bytes32 corridorKey, uint8 tier, uint256 weightSeed);
    event Cycled(uint256 indexed cycleId, uint64 wallClock, uint256 shardWeight, uint256 bundleWeight);
    event Paused(bool lanePaused, address indexed by, uint256 atBlock);
    event DirectorMoved(address indexed prev, address indexed next, uint256 atBlock);
    event RelayJoined(address indexed relay, bytes32 moniker, uint256 bondWei);
    event RelayLeft(address indexed relay, uint256 atBlock);
    event DepositRejected(address indexed from, uint256 weiAmt, uint256 atBlock);
    event Trace_0(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_1(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_2(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_3(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_4(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_5(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_6(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_7(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_8(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_9(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_10(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_11(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Trace_12(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);

    enum IxxCorridorState { Dormant, Active, Retired }
    enum IxxBundlePhase { Waiting, Running, Final, Aborted }

    struct IxxCorridor {
        IxxCorridorState state;
        uint8 intentTier;
        uint64 bornAt;
        uint32 shardTally;
        uint32 bundleTally;
        uint256 weightSum;
        bytes32 corridorKey;
    }

    struct IxxShard {
        uint256 corridorId;
        address relay;
        bytes32 intentFingerprint;
        uint8 intentTier;
        uint32 yesVotes;
        uint32 noVotes;
        uint256 bondWei;
        uint64 filedAt;
        bool live;
    }

    struct IxxBundle {
        uint256 corridorId;
        address requester;
        bytes32 intentTag;
        IxxBundlePhase phase;
        bytes32 resultHash;
        uint16 trustScore;
        uint64 queuedAt;
    }

    struct IxxSignal {
        uint256 corridorId;
        bytes32 signalTag;
        bytes32 rollupHash;
        uint16 signalBand;
        uint64 stampedAt;
    }

    struct IxxCycleRing {
