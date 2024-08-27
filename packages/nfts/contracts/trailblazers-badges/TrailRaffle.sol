// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TrailPass.sol";

// todo: integrate with trailPass

contract RaffleERC1155 is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    struct Prize {
        address tokenAddress;
        uint256 tokenId; // For ERC721 and ERC1155
        uint256 amount;  // For ERC20 and ERC1155
    }

    struct Raffle {
        uint256 trailPassTier;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice; // Price in ETH
        address[] prizeTokens;
        mapping(address => Prize[]) prizes;
        mapping(address => uint256) ticketsPurchased; // Track tickets purchased per participant
    }

    // Mapping from raffle ID to Raffle details
    mapping(uint256 => Raffle) public raffles;
    uint256 public raffleCount;

    event RaffleCreated(uint256 raffleId, uint256 startTime, uint256 endTime, uint256 ticketPrice, address[] prizeTokens);
    event PrizeAdded(uint256 raffleId, address tokenAddress, uint256 tokenId, uint256 amount);
    event RaffleEntered(uint256 raffleId, address participant, uint256 numberOfTickets);
    event TicketPriceUpdated(uint256 raffleId, uint256 newPrice);


    TrailPass public trailPass;
    function initialize( address _trailPass) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();
        trailPass = TrailPass(_trailPass);
    }

    function createRaffle(
        uint256 _tier,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _ticketPrice,
        address[] memory _prizeTokens
    ) external onlyOwner {
        if (_startTime >= _endTime) revert StartTimeMustBeBeforeEndTime();
        if (_ticketPrice == 0) revert TicketPriceMustBeGreaterThanZero();

        raffleCount++;
        Raffle storage newRaffle = raffles[raffleCount];

        newRaffle.trailPassTier = _tier;
        newRaffle.startTime = _startTime;
        newRaffle.endTime = _endTime;
        newRaffle.ticketPrice = _ticketPrice;
        newRaffle.prizeTokens = _prizeTokens;

        emit RaffleCreated(raffleCount, _startTime, _endTime, _ticketPrice, _prizeTokens);
    }

    function addPrize(
        uint256 raffleId,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external onlyOwner {
        if (raffleId == 0 || raffleId > raffleCount) revert InvalidRaffleId();
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        Raffle storage raffle = raffles[raffleId];

        raffle.prizes[tokenAddress].push(Prize({
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            amount: amount
        }));

        emit PrizeAdded(raffleId, tokenAddress, tokenId, amount);
    }

    function updateTicketPrice(uint256 raffleId, uint256 newPrice) external onlyOwner {
        if (raffleId == 0 || raffleId > raffleCount) revert InvalidRaffleId();
        if (newPrice == 0) revert TicketPriceMustBeGreaterThanZero();

        Raffle storage raffle = raffles[raffleId];
        raffle.ticketPrice = newPrice;

        emit TicketPriceUpdated(raffleId, newPrice);
    }

    function enterRaffle(uint256 raffleId, uint256 numberOfTickets) external payable {
        if (raffleId == 0 || raffleId > raffleCount) revert InvalidRaffleId();
        if (numberOfTickets == 0) revert NumberOfTicketsMustBeGreaterThanZero();
        if (msg.value != raffles[raffleId].ticketPrice * numberOfTickets) revert IncorrectETHAmount();

        Raffle storage raffle = raffles[raffleId];
        if (block.timestamp < raffle.startTime) revert RaffleNotStartedYet();
        if (block.timestamp > raffle.endTime) revert RaffleEnded();

        raffle.ticketsPurchased[msg.sender] += numberOfTickets;

        emit RaffleEntered(raffleId, msg.sender, numberOfTickets);
    }

    function distributePrizes(uint256 raffleId, address winner) external onlyOwner {
        if (raffleId == 0 || raffleId > raffleCount) revert InvalidRaffleId();
        if (block.timestamp <= raffles[raffleId].endTime) revert RaffleNotEnded();

        Raffle storage raffle = raffles[raffleId];
        for (uint i = 0; i < raffle.prizeTokens.length; i++) {
            address tokenAddress = raffle.prizeTokens[i];
            Prize[] storage prizes = raffle.prizes[tokenAddress];

            for (uint j = 0; j < prizes.length; j++) {
                Prize storage prize = prizes[j];
                if (prize.amount > 0) {
                    if (prize.tokenAddress == address(0)) {
                        // Handle ERC20 transfer
                        IERC20(tokenAddress).transfer(winner, prize.amount);
                    } else if (IERC721(tokenAddress).ownerOf(prize.tokenId) == address(this)) {
                        // Handle ERC721 transfer
                        IERC721(tokenAddress).safeTransferFrom(address(this), winner, prize.tokenId);
                    } else if (IERC1155(tokenAddress).balanceOf(address(this), prize.tokenId) > 0) {
                        // Handle ERC1155 transfer
                        IERC1155(tokenAddress).safeTransferFrom(address(this), winner, prize.tokenId, prize.amount, "");
                    }
                }
            }
        }
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Custom error definitions
    error StartTimeMustBeBeforeEndTime();
    error TicketPriceMustBeGreaterThanZero();
    error InvalidRaffleId();
    error AmountMustBeGreaterThanZero();
    error NumberOfTicketsMustBeGreaterThanZero();
    error IncorrectETHAmount();
    error RaffleNotStartedYet();
    error RaffleEnded();
    error RaffleNotEnded();
}
