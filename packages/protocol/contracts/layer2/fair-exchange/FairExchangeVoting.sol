// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/bridge/IBridge.sol";

contract FairExchangeVoting is EssentialContract {
    uint256 public constant MAX_WHITELISTED_ADDRESSES = 32;

    uint256 public immutable majorityPercentage;
    uint256 public immutable ringBufferSize;

    /// @dev Use one slot
    struct Voting {
        uint48 blockId;
        uint32 votingMap;
        uint8 voteCount;
        uint8 slashVotes;
    }

    event OverseerAdded(address indexed overseer);
    event OverseerRemoved(address indexed overseer);
    event VoteCasted(address indexed voter, uint64 indexed blockId, bool slash, uint32 reason);
    event SlashSignalSent(uint64 indexed blockId);

    error AddressAlreadyWhitelisted();
    error AddressNotWhitelisted();
    error AlreadyVotedForThisBlock();
    error BlockIdInTheFuture();
    error BlockIdTooOld();
    error ExceedsMaxWhitelistedAddresses();
    error InvalidMajorityPercentage();
    error SlashVoteRequiredForFirstVote();
    error NotAnOverseer();

    address[] public overseers;
    mapping(address overseer => uint256 idPlusOne) public isOverseer;
    mapping(uint256 blockId => Voting info) public blockVoting;

    uint256[47] private __gap;

    modifier onlyOverseer() {
        require(isOverseer[msg.sender] > 0, NotAnOverseer());
        _;
    }

    constructor(
        address _resolver,
        uint256 _majorityPercentage,
        uint256 _ringBufferSize,
        address _bridge
    )
        nonZeroValue(_majorityPercentage)
        nonZeroValue(_ringBufferSize)
        nonZeroAddr(_bridge)
        EssentialContract(_resolver)
    {
        require(_majorityPercentage <= 100, InvalidMajorityPercentage());
        majorityPercentage = _majorityPercentage;
        ringBufferSize = _ringBufferSize;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function addOverseer(address _address) external onlyOwner {
        require(isOverseer[_address] == 0, AddressAlreadyWhitelisted());
        require(overseers.length < MAX_WHITELISTED_ADDRESSES, ExceedsMaxWhitelistedAddresses());
        overseers.push(_address);
        isOverseer[_address] = overseers.length;
        emit OverseerAdded(_address);
    }

    function removeOverseer(address _address) external onlyOwner {
        unchecked {
            require(isOverseer[_address] != 0, AddressNotWhitelisted());
            uint256 lastIndex = overseers.length - 1;
            uint256 i = _getOverseerId(_address);
            if (i != lastIndex) {
                address lastOverseer = overseers[lastIndex];
                overseers[i] = lastOverseer;
                isOverseer[lastOverseer] = i + 1;
            }
            isOverseer[_address] = 0;
            overseers.pop();
        }
        emit OverseerRemoved(_address);
    }

    function vote(uint48 _blockId, bool _slash, uint32 _reason) external onlyOverseer {
        require(_blockId >= block.number - ringBufferSize, BlockIdTooOld());
        require(_blockId < block.number, BlockIdInTheFuture());

        uint256 overseerId = _getOverseerId(msg.sender);
        Voting memory info = _getVoting(_blockId);

        require(info.slashVotes != 0 || _slash, SlashVoteRequiredForFirstVote());
        require((info.votingMap & (1 << overseerId)) == 0, AlreadyVotedForThisBlock());

        info.votingMap |= uint32(1 << overseerId);
        info.voteCount += 1;

        if (_slash) {
            info.slashVotes += 1;
        }

        emit VoteCasted(msg.sender, _blockId, _slash, _reason);

        if (shouldSlash(_blockId)) {
            emit SlashSignalSent(_blockId);

            // TODO: send bridge message
        }
    }

    function getVoting(uint48 _blockId) public view returns (Voting memory info_) {
        info_ = _getVoting(_blockId);
        if (info_.blockId != _blockId) {
            info_ = Voting(_blockId, 0, 0, 0);
        }
    }

    function shouldSlash(uint48 _blockId) internal view returns (bool) {
        Voting memory info = getVoting(_blockId);
        return (info.slashVotes * 100) / info.voteCount >= majorityPercentage;
    }

    function _getOverseerId(address _address) private view returns (uint256) {
        uint256 index = isOverseer[_address];
        require(index > 0, AddressNotWhitelisted());
        unchecked {
            return index - 1;
        }
    }

    function _getVoting(uint48 _blockId) private view returns (Voting storage info_) {
        uint256 index = _blockId % ringBufferSize;
        info_ = blockVoting[index];
    }
}
