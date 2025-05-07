// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/token/TaikoTokenBase.sol";

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of precision.
/// @dev Labeled in address resolver as "taiko_token"
/// @dev On Ethereum, this contract is deployed behind a proxy at
/// 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 (token.taiko.eth)
/// @custom:security-contact security@taiko.xyz
contract TaikoToken is TaikoTokenBase {
    error TT_NON_VOTING_ACCOUNT();

    // Bond tokens deposited to Taiko Inbox are not eligible for voting
    address private constant _TAIKO_INBOX = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;

    // Tokens bridged to Taiko mainnet are not eligible for voting
    address private constant _ERC20_VAULT = 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;

    // Tokens deposited to Taiko Treasury Vault are not eligible for voting
    address private constant _TAIKO_FOUNDATION_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da;

    // Tokens managed by the Taiko DAO are not eligible for voting
    address private constant _TAIKO_DAO = 0x9CDf589C941ee81D75F34d3755671d614f7cf261;

    // This is a Taiko TokenLocker contract to force DAO owne'd TAIKO token to be released linearly.
    address private constant _TAIKO_DAO_TOKEN_LOCKER = 0x0000000000000000000000000000000000000000;

    // This is a TaikoTreasuryVault contract to manage the DAO's ERC20 tokens, including some TAIKO
    // tokens.
    address private constant _TAIKO_DAO_VAULT = 0x0000000000000000000000000000000000000000;

    error TT_INVALID_PARAM();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _recipient The address to receive initial token minting.
    function init(address _owner, address _recipient) public initializer {
        __Essential_init(_owner);
        __ERC20_init("Taiko Token", "TAIKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }

    /// @notice Batch transfers tokens
    /// @param recipients The list of addresses to transfer tokens to.
    /// @param amounts The list of amounts for transfer.
    /// @return true if the transfer is successful.
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    )
        external
        returns (bool)
    {
        uint256 size = recipients.length;
        if (size != amounts.length) revert TT_INVALID_PARAM();
        for (uint256 i; i < size; ++i) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }

    function delegate(address account) public override {
        address[] memory nonVotingAccounts = getNonVotingAccounts();
        // Special checks to avoid reading from storage slots
        for (uint256 i; i < nonVotingAccounts.length; ++i) {
            if (msg.sender == nonVotingAccounts[i]) revert TT_NON_VOTING_ACCOUNT();
        }
        super.delegate(account);
    }

    function getPastTotalSupply(uint256 timepoint) public view override returns (uint256) {
        address[] memory nonVotingAccounts = getNonVotingAccounts();
        uint256 nonVotingSupply;
        for (uint256 i; i < nonVotingAccounts.length; ++i) {
            nonVotingSupply += balanceOf(nonVotingAccounts[i]);
        }
        return super.getPastTotalSupply(timepoint) - nonVotingSupply;
    }

    function getNonVotingAccounts() public pure virtual returns (address[] memory accounts_) {
        accounts_ = new address[](6);
        accounts_[0] = _TAIKO_INBOX;
        accounts_[1] = _ERC20_VAULT;
        accounts_[2] = _TAIKO_FOUNDATION_TREASURY;
        accounts_[3] = _TAIKO_DAO;
        accounts_[4] = _TAIKO_DAO_TOKEN_LOCKER;
        accounts_[5] = _TAIKO_DAO_VAULT;
    }
}
