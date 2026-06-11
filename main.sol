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

    function voteShard(bytes32 shardId, bool affirm) external whenLanesOpen {
        IxxShard storage s = shards[shardId];
        if (!s.live) revert IXx_ShardMissing();
        if (s.relay == msg.sender) revert IXx_VoteSelf();
        if (voteCast[shardId][msg.sender]) revert IXx_VoteCast();
        voteCast[shardId][msg.sender] = true;
        if (affirm) unchecked { s.yesVotes += 1; }
        else unchecked { s.noVotes += 1; }
        emit Voted(shardId, msg.sender, affirm, activeCycle);
    }

    function bondShard(bytes32 shardId) external payable nonReentrant whenLanesOpen {
        if (msg.value == 0) revert IXx_ZeroWei();
        IxxShard storage s = shards[shardId];
        if (!s.live) revert IXx_ShardMissing();
        s.bondWei += msg.value;
        totalBondWei += msg.value;
        _pushNative(s.relay, msg.value);
        emit Bonded(shardId, msg.sender, msg.value, activeCycle);
    }

    function joinRelay(bytes32 moniker) external payable nonReentrant whenLanesOpen {
        if (msg.value < IXX_RELAY_BOND) revert IXx_BondLow();
        if (relayDesks[msg.sender].enrolled) revert IXx_RelayKnown();
        relayDesks[msg.sender] = IxxRelayDesk({
            enrolled: true,
            moniker: moniker,
            enrolledAt: uint64(block.timestamp),
            shardTally: 0
        });
        totalBondWei += msg.value;
        emit RelayJoined(msg.sender, moniker, msg.value);
    }

    function routeBundle(bytes32 bundleId, uint256 corridorId, bytes32 intentTag)
        external
        payable
        nonReentrant
        whenLanesOpen
        onlyEnrolledRelay
    {
        if (bundleId == bytes32(0)) revert IXx_HashVoid();
        if (bundleIdUsed[bundleId]) revert IXx_BundleOpen();
        if (msg.value < IXX_SHARD_FEE) revert IXx_BondLow();
        if (openBundles >= IXX_OPEN_BUNDLE_CAP) revert IXx_QuotaFull();
        IxxCorridor storage c = corridors[corridorId];
        if (c.state != IxxCorridorState.Active) revert IXx_CorridorHalted();
        bundleIdUsed[bundleId] = true;
        bundles[bundleId] = IxxBundle({
            corridorId: corridorId,
            requester: msg.sender,
            intentTag: intentTag,
            phase: IxxBundlePhase.Waiting,
            resultHash: bytes32(0),
            trustScore: 0,
            queuedAt: uint64(block.timestamp)
        });
        unchecked {
            openBundles += 1;
            c.bundleTally += 1;
        }
        emit Routed(bundleId, corridorId, intentTag, block.timestamp);
    }

    function settleBundle(bytes32 bundleId, bytes32 payloadHash, uint16 trustScore) external onlyCurator {
        IxxBundle storage b = bundles[bundleId];
        if (b.phase != IxxBundlePhase.Waiting && b.phase != IxxBundlePhase.Running) revert IXx_BundleSealed();
        if (trustScore < IXX_TRUST_FLOOR) revert IXx_TrustLow();
        if (trustScore > IXX_TRUST_CEIL) revert IXx_TrustHigh();
        b.phase = IxxBundlePhase.Final;
        b.resultHash = payloadHash;
        b.trustScore = trustScore;
        if (openBundles > 0) unchecked { openBundles -= 1; }
        emit Settled(bundleId, payloadHash, trustScore, activeCycle);
    }

    function emitSignal(
        bytes32 signalId,
        uint256 corridorId,
        bytes32 signalTag,
        bytes32 rollupHash,
        uint16 signalBand
    ) external onlyCurator whenLanesOpen {
        if (signalIdUsed[signalId]) revert IXx_RelayStale();
        if (signalBand < IXX_SIGNAL_FLOOR) revert IXx_TrustLow();
        if (signalBand > IXX_SIGNAL_CEIL) revert IXx_TrustHigh();
        IxxCorridor storage c = corridors[corridorId];
        if (c.state != IxxCorridorState.Active) revert IXx_CorridorHalted();
        signalIdUsed[signalId] = true;
        signals[signalId] = IxxSignal({
            corridorId: corridorId,
            signalTag: signalTag,
            rollupHash: rollupHash,
            signalBand: signalBand,
            stampedAt: uint64(block.timestamp)
        });
        emit Signaled(signalId, corridorId, signalBand, block.timestamp);
    }

    function fundCorridor() external payable whenLanesOpen {
        if (msg.value == 0) revert IXx_ZeroWei();
        emit Trace_0(traceSerial, msg.sender, msg.value, activeCycle);
        unchecked { traceSerial += 1; }
    }

    function _pushNative(address to, uint256 amt) internal {
        (bool ok, ) = payable(to).call{value: amt}("");
        if (!ok) revert IXx_NativeFail();
    }

    function _openCycle(uint256 cycleId) internal {
        IxxCycleRing storage ring = cycleRings[cycleId];
        ring.openedAt = uint64(block.timestamp);
        ring.shardWeight = _cycleShardWeight();
        ring.bundleWeight = openBundles;
        (ring.mixHA, ring.mixHB) = _splitDigest(cycleId, ring.shardWeight, ring.bundleWeight);
    }

    function _splitDigest(uint256 cycleId, uint256 sw, uint256 bw)
        internal
        view
        returns (bytes32 hA, bytes32 hB)
    {
        hA = keccak256(abi.encode(IXX_DOMAIN, cycleId, sw, ADDRESS_A, _SALT_0));
        hB = keccak256(abi.encode(bw, cycleId, ADDRESS_B, _SALT_1, IXX_CYCLE_BLOCKS));
    }

    function shardDigest(bytes32 shardId) public view returns (bytes32) {
        IxxShard storage s = shards[shardId];
        (bytes32 hA, bytes32 hB) = _splitDigest(s.corridorId, uint256(uint160(s.relay)), s.bondWei);
        return keccak256(abi.encodePacked(hA, hB, s.intentFingerprint, ADDRESS_C, _SALT_2));
    }

    function _cycleShardWeight() internal view returns (uint256 w) {
        for (uint256 i = 1; i <= 27; ++i) {
            w += corridors[i].weightSum;
        }
    }

    function _bootstrapCorridors() internal {
        corridors[1] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(2),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 40,
            corridorKey: 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a
        });
        emit Opened(1, 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a, uint8(2), 40);
        corridors[2] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 69,
            corridorKey: 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb
        });
        emit Opened(2, 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb, uint8(4), 69);
        corridors[3] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 98,
            corridorKey: 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0
        });
        emit Opened(3, 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0, uint8(3), 98);
        corridors[4] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(5),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 127,
            corridorKey: 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887
        });
        emit Opened(4, 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887, uint8(5), 127);
        corridors[5] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(6),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 156,
            corridorKey: 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec
        });
        emit Opened(5, 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec, uint8(6), 156);
        corridors[6] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 185,
            corridorKey: 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef
        });
        emit Opened(6, 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef, uint8(4), 185);
        corridors[7] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 214,
            corridorKey: 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e
        });
        emit Opened(7, 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e, uint8(3), 214);
        corridors[8] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(7),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 243,
            corridorKey: 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344
        });
        emit Opened(8, 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344, uint8(7), 243);
        corridors[9] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(2),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 272,
            corridorKey: 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9
        });
        emit Opened(9, 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9, uint8(2), 272);
        corridors[10] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 301,
            corridorKey: 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a
        });
        emit Opened(10, 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a, uint8(4), 301);
        corridors[11] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 330,
            corridorKey: 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb
        });
        emit Opened(11, 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb, uint8(3), 330);
        corridors[12] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(5),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 359,
            corridorKey: 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0
        });
        emit Opened(12, 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0, uint8(5), 359);
        corridors[13] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(6),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 388,
            corridorKey: 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887
        });
        emit Opened(13, 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887, uint8(6), 388);
        corridors[14] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 417,
            corridorKey: 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec
        });
        emit Opened(14, 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec, uint8(4), 417);
        corridors[15] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 446,
            corridorKey: 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef
        });
        emit Opened(15, 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef, uint8(3), 446);
        corridors[16] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(7),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 475,
            corridorKey: 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e
        });
        emit Opened(16, 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e, uint8(7), 475);
        corridors[17] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(2),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 504,
            corridorKey: 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344
        });
        emit Opened(17, 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344, uint8(2), 504);
        corridors[18] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 533,
            corridorKey: 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9
        });
        emit Opened(18, 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9, uint8(4), 533);
        corridors[19] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 562,
            corridorKey: 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a
        });
        emit Opened(19, 0x7bf430f021139e0242bb4dded427a52bd94b8d85a638a4056614e7b38eaf773a, uint8(3), 562);
        corridors[20] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(5),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 591,
            corridorKey: 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb
        });
        emit Opened(20, 0x0df1467c35704813580f76d63c436554d7ce33b4782683c045a8281f5995cedb, uint8(5), 591);
        corridors[21] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(6),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 620,
            corridorKey: 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0
        });
        emit Opened(21, 0x690724ef277ba46331cfa3430b877836dc3bfd85d67eaa5dc342ddfd9a1f8fe0, uint8(6), 620);
        corridors[22] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 649,
            corridorKey: 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887
        });
        emit Opened(22, 0xd96f4463a6b544c4d17da0141fb0e4d49f11430e32a634f89b90e09b6c89e887, uint8(4), 649);
        corridors[23] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 678,
            corridorKey: 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec
        });
        emit Opened(23, 0x08afa6746972306897dd9120a6f77c709f128035381eae72d60bb90613c0f9ec, uint8(3), 678);
        corridors[24] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(7),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 707,
            corridorKey: 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef
        });
        emit Opened(24, 0x0f2866a8c85b0add4cd0445148a25df503daeec140bc1ea61a81ffe0b7e1f3ef, uint8(7), 707);
        corridors[25] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(2),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 736,
            corridorKey: 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e
        });
        emit Opened(25, 0xdc6f2691d3b518dfbdfe9df6f87cac57f2862add8d1b9f12cf4897daf931378e, uint8(2), 736);
        corridors[26] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(4),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 765,
            corridorKey: 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344
        });
        emit Opened(26, 0xdfb0d9ac75d94e0a3bef78477c9bf5315c23034345def4fe112fe119a026c344, uint8(4), 765);
        corridors[27] = IxxCorridor({
            state: IxxCorridorState.Active,
            intentTier: uint8(3),
            bornAt: uint64(block.timestamp),
            shardTally: 0,
            bundleTally: 0,
            weightSum: 794,
            corridorKey: 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9
        });
        emit Opened(27, 0x9b51b470d6eb225ff71353566f1cb4ef8e72246df224da5ba6f2f07c0e0c6ab9, uint8(3), 794);
    }

    // readers
    function readShard_0(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_0));
    }

    function readShard_1(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_1));
    }

    function readShard_2(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_2));
    }

    function readShard_3(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_3));
    }

    function readShard_4(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_4));
    }

    function readShard_5(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_5));
    }

    function readShard_6(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_6));
    }

    function readShard_7(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_7));
    }

    function readShard_8(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_8));
    }

    function readShard_9(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_0));
    }

    function readShard_10(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_1));
    }

    function readShard_11(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_2));
    }

    function readShard_12(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_3));
    }

    function readShard_13(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_4));
    }

    function readShard_14(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_5));
    }

    function readShard_15(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_6));
    }

    function readShard_16(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_7));
    }

    function readShard_17(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
    ) {
        IxxShard storage s = shards[shardId];
        corridorId = s.corridorId;
        relay = s.relay;
        tier = s.intentTier;
        bond = s.bondWei;
        digest = keccak256(abi.encode(shardId, bond, _SALT_8));
    }

    function readShard_18(bytes32 shardId) external view returns (
        uint256 corridorId,
        address relay,
        uint8 tier,
        uint256 bond,
        bytes32 digest
