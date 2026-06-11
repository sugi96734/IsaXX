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
        uint64 openedAt;
        uint256 shardWeight;
        uint256 bundleWeight;
        bytes32 mixHA;
        bytes32 mixHB;
    }

    struct IxxRelayDesk {
        bool enrolled;
        bytes32 moniker;
        uint64 enrolledAt;
        uint32 shardTally;
    }

    uint256 public constant IXX_TIER_CAP = 8;
    uint256 public constant IXX_SHARD_FEE = 0.004 ether;
    uint256 public constant IXX_RELAY_BOND = 0.08 ether;
    uint256 public constant IXX_MAX_SHARDS = 152;
    uint256 public constant IXX_OPEN_BUNDLE_CAP = 81;
    uint256 public constant IXX_SIGNAL_FLOOR = 727;
    uint256 public constant IXX_SIGNAL_CEIL = 10254;
    uint256 public constant IXX_CYCLE_BLOCKS = 530;
    uint256 public constant IXX_WEIGHT_CAP = 16100;
    uint256 public constant IXX_TRUST_FLOOR = 363;
    uint256 public constant IXX_TRUST_CEIL = 8804;

    bytes32 private constant _SALT_0 = 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9;
    bytes32 private constant _SALT_1 = 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a;
    bytes32 private constant _SALT_2 = 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb;
    bytes32 private constant _SALT_3 = 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0;
    bytes32 private constant _SALT_4 = 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887;
    bytes32 private constant _SALT_5 = 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec;
    bytes32 private constant _SALT_6 = 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef;
    bytes32 private constant _SALT_7 = 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e;
    bytes32 private constant _SALT_8 = 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344;
    bytes32 private constant IXX_DOMAIN = keccak256("IsaXX.prismFoldRelay");

    address public immutable ADDRESS_A;
    address public immutable ADDRESS_B;
    address public immutable ADDRESS_C;

    address public director;
    address public curator;
    bool public lanePaused;
    uint256 public activeCycle;
    uint256 public traceSerial;
    uint256 public openBundles;
    uint256 public totalBondWei;
    uint256 public deployBlock;

    mapping(uint256 => IxxCorridor) public corridors;
    mapping(bytes32 => IxxShard) public shards;
    mapping(bytes32 => IxxBundle) public bundles;
    mapping(bytes32 => IxxSignal) public signals;
    mapping(uint256 => IxxCycleRing) public cycleRings;
    mapping(uint256 => mapping(address => uint256)) public relayWeight;
    mapping(bytes32 => mapping(address => bool)) public voteCast;
    mapping(bytes32 => bool) public shardIdUsed;
    mapping(bytes32 => bool) public bundleIdUsed;
    mapping(bytes32 => bool) public signalIdUsed;
    mapping(address => IxxRelayDesk) public relayDesks;
    mapping(address => bytes32[]) private _shardsByRelay;
    bytes32[] private _shardIndex;
    uint256 private _gate;

    modifier nonReentrant() {
        if (_gate == 2) revert IXx_Reentered();
        _gate = 2;
        _;
        _gate = 1;
    }

    modifier onlyDirector() {
        if (msg.sender != director) revert IXx_NotDirector();
        _;
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert IXx_NotCurator();
        _;
    }

    modifier whenLanesOpen() {
        if (lanePaused) revert IXx_LanePaused();
        _;
    }

    modifier onlyEnrolledRelay() {
        if (!relayDesks[msg.sender].enrolled) revert IXx_NotRelay();
        _;
    }

    constructor() {
        ADDRESS_A = 0x30Bc317a16843FbBEB339D76Ed8f5498252255fC;
        ADDRESS_B = 0x1D2c0b5420eF0e78F859077a0E08cc8900020ee8;
        ADDRESS_C = 0xbd2E87A72F3493bBDa93B54e2A34cD1261d74a9B;
        director = msg.sender;
        curator = ADDRESS_A;
        _gate = 1;
        deployBlock = block.number;
        activeCycle = 1;
        _openCycle(1);
        _bootstrapCorridors();
    }

    receive() external payable {
        emit DepositRejected(msg.sender, msg.value, block.number);
        revert IXx_FallbackBlocked();
    }

    fallback() external payable {
        revert IXx_FallbackBlocked();
    }

    function transferDirector(address next_) external onlyDirector {
        if (next_ == address(0) || next_ == director) revert IXx_ZeroAddr();
        address prev = director;
        director = next_;
        emit DirectorMoved(prev, next_, block.number);
    }

    function assignCurator(address next_) external onlyDirector {
        if (next_ == address(0)) revert IXx_ZeroAddr();
        curator = next_;
    }

    function setLanePaused(bool on) external onlyDirector {
        lanePaused = on;
        emit Paused(on, msg.sender, block.number);
    }

    function bumpCycle() external onlyDirector whenLanesOpen {
        uint256 n = activeCycle + 1;
        if (n > 42) revert IXx_CycleBad();
        activeCycle = n;
        _openCycle(n);
        emit Cycled(n, uint64(block.timestamp), _cycleShardWeight(), openBundles);
    }

    function haltCorridor(uint256 corridorId) external onlyCurator {
        IxxCorridor storage c = corridors[corridorId];
        if (c.state == IxxCorridorState.Dormant) revert IXx_CorridorVoid();
        c.state = IxxCorridorState.Retired;
    }

    function enrollRelay(address relay, bytes32 moniker) external onlyDirector {
        if (relay == address(0)) revert IXx_ZeroAddr();
        if (relayDesks[relay].enrolled) revert IXx_RelayKnown();
        relayDesks[relay] = IxxRelayDesk({
            enrolled: true,
            moniker: moniker,
            enrolledAt: uint64(block.timestamp),
            shardTally: 0
        });
        emit RelayJoined(relay, moniker, 0);
    }

    function dropRelay(address relay) external onlyDirector {
        if (!relayDesks[relay].enrolled) revert IXx_NotRelay();
        relayDesks[relay].enrolled = false;
        emit RelayLeft(relay, block.number);
    }

    function pullSurplus(uint256 amt, address payable to) external onlyDirector nonReentrant {
        if (to == address(0)) revert IXx_ZeroAddr();
        if (amt == 0 || amt > address(this).balance) revert IXx_ZeroWei();
        _pushNative(to, amt);
    }

    function fileShard(
        bytes32 shardId,
        uint256 corridorId,
        bytes32 intentFingerprint,
        uint8 intentTier
    ) external payable nonReentrant whenLanesOpen onlyEnrolledRelay {
        if (shardId == bytes32(0)) revert IXx_HashVoid();
        if (shardIdUsed[shardId]) revert IXx_ShardExists();
        if (msg.value < IXX_SHARD_FEE) revert IXx_BondLow();
        if (intentTier == 0 || intentTier > IXX_TIER_CAP) revert IXx_TierInvalid();
        IxxCorridor storage c = corridors[corridorId];
        if (c.state != IxxCorridorState.Active) revert IXx_CorridorHalted();
        if (c.shardTally >= IXX_MAX_SHARDS) revert IXx_QuotaFull();
        shardIdUsed[shardId] = true;
        shards[shardId] = IxxShard({
            corridorId: corridorId,
            relay: msg.sender,
            intentFingerprint: intentFingerprint,
            intentTier: intentTier,
            yesVotes: 0,
            noVotes: 0,
            bondWei: msg.value,
            filedAt: uint64(block.timestamp),
            live: true
        });
        unchecked {
            c.shardTally += 1;
            c.weightSum = IxxClamp.cappedAdd(
                c.weightSum, uint256(intentTier) * 120, IXX_WEIGHT_CAP
            );
            relayDesks[msg.sender].shardTally += 1;
        }
        relayWeight[activeCycle][msg.sender] += uint256(intentTier) * 11;
        totalBondWei += msg.value;
        _shardsByRelay[msg.sender].push(shardId);
        _shardIndex.push(shardId);
        emit Filed(shardId, corridorId, msg.sender, intentTier, msg.value);
    }
