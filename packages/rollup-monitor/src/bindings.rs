use alloy::sol;

sol! {
    struct BlobSlice {
        bytes32[] blobHashes;
        uint24 offset;
        uint48 timestamp;
    }

    struct DerivationSource {
        bool isForcedInclusion;
        BlobSlice blobSlice;
    }

    event Proposed(
        uint48 indexed id,
        address indexed proposer,
        bytes32 parentProposalHash,
        uint48 endOfSubmissionWindowTimestamp,
        uint8 basefeeSharingPctg,
        DerivationSource[] sources
    );

    event Proved(
        uint48 firstProposalId,
        uint48 firstNewProposalId,
        uint48 lastProposalId,
        address indexed actualProver
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 canonicalChainId,
        uint64 destChainId,
        address ctoken,
        address token,
        uint256 amount
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address ctoken,
        address token,
        uint256 amount
    );

    event Upgraded(address indexed implementation);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Paused(address account);
    event Unpaused(address account);
    event ExecutionSuccess(bytes32 txHash, uint256 payment);
    event ExecutionFailure(bytes32 txHash, uint256 payment);
    event ImageTrusted(bytes32 imageId, bool trusted);
    event ProgramTrusted(bytes32 programVKey, bool trusted);
    event InstanceAdded(
        uint256 indexed id,
        address indexed instance,
        address indexed replaced,
        uint256 validSince
    );
    event InstanceDeleted(uint256 indexed id, address indexed instance);
}
