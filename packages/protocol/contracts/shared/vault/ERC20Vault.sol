// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../bridge/IQuotaManager.sol";
import "../libs/LibAddress.sol";
import "../libs/LibNames.sol";
import "./BaseVault.sol";
import "./IBridgedERC20.sol";
import "./IPermit2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./ERC20Vault_Layout.sol"; // DO NOT DELETE

/// @title ERC20Vault
/// @notice This vault holds all ERC20 tokens (excluding Ether) that users have
/// deposited. It also manages the mapping between canonical ERC20 tokens and
/// their bridged tokens. This vault does not support rebase/elastic tokens.
/// @dev Labeled in address resolver as "erc20_vault".
/// @dev This is the original ERC20Vault contract without solver features as in ERC20Vault.sol
/// @custom:security-contact security@taiko.xyz
contract ERC20Vault is BaseVault {
    using Address for address;
    using LibAddress for address;
    using SafeERC20 for IERC20;

    uint256 public constant MIN_MIGRATION_DELAY = 90 days;

    /// @notice The canonical Uniswap Permit2 contract. Permit2 is deployed at this same address on
    /// every chain via the deterministic deployer, so it needs no per-chain configuration.
    /// @dev Bridging with a Permit2 signature is opt-in, so on a chain where Permit2 is not
    /// deployed only `sendTokenWithPermit2` is unavailable; every other entrypoint is unaffected.
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    IQuotaManager public immutable quotaManager;

    /// @dev Represents a canonical ERC20 token.
    struct CanonicalERC20 {
        uint64 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    /// @dev A Permit2 `SignatureTransfer` authorization, threaded from the entrypoint down to the
    /// pull. Named members rather than a hand-encoded tuple: `nonce` and `deadline` are both
    /// `uint256`, so transposing them is invisible to both the compiler and the function selector.
    struct Permit2Data {
        // The Permit2 unordered nonce.
        uint256 nonce;
        // The signature's expiry timestamp.
        uint256 deadline;
        // The owner's signature over the permit, passed to Permit2 verbatim.
        bytes signature;
    }

    /// @dev Represents an operation to send tokens to another chain.
    /// 4 slots
    struct BridgeTransferOp {
        // Destination chain ID.
        uint64 destChainId;
        // The owner of the bridge message on the destination chain.
        address destOwner;
        // Recipient address.
        address to;
        // Processing fee for the relayer.
        uint64 fee;
        // Address of the token.
        address token;
        // Gas limit for the operation.
        uint32 gasLimit;
        // Amount to be bridged.
        uint256 amount;
    }

    /// @notice Mappings from bridged tokens to their canonical tokens.
    mapping(address btoken => CanonicalERC20 canonical) public bridgedToCanonical;

    /// @notice Mappings from canonical tokens to their bridged tokens. Also storing
    /// the chainId for tokens across other chains aside from Ethereum.
    mapping(uint256 chainId => mapping(address ctoken => address btoken)) public canonicalToBridged;

    /// @notice Mappings from bridged tokens to their blacklist status.
    mapping(address btoken => bool denied) public btokenDenylist;

    /// @notice Mappings from ctoken to its last migration timestamp.
    mapping(uint256 chainId => mapping(address ctoken => uint256 timestamp)) public
        lastMigrationStart;

    uint256[46] private __gap;

    /// @notice Emitted when a new bridged token is deployed.
    /// @param srcChainId The chain ID of the canonical token.
    /// @param ctoken The address of the canonical token.
    /// @param btoken The address of the bridged token.
    /// @param ctokenSymbol The symbol of the canonical token.
    /// @param ctokenName The name of the canonical token.
    /// @param ctokenDecimal The decimal of the canonical token.
    event BridgedTokenDeployed(
        uint256 indexed srcChainId,
        address indexed ctoken,
        address indexed btoken,
        string ctokenSymbol,
        string ctokenName,
        uint8 ctokenDecimal
    );

    /// @notice Emitted when a bridged token is changed.
    /// @param srcChainId The chain ID of the canonical token.
    /// @param ctoken The address of the canonical token.
    /// @param btokenOld The address of the old bridged token.
    /// @param btokenNew The address of the new bridged token.
    /// @param ctokenSymbol The symbol of the canonical token.
    /// @param ctokenName The name of the canonical token.
    /// @param ctokenDecimal The decimal of the canonical token.
    event BridgedTokenChanged(
        uint256 indexed srcChainId,
        address indexed ctoken,
        address btokenOld,
        address btokenNew,
        string ctokenSymbol,
        string ctokenName,
        uint8 ctokenDecimal
    );

    /// @notice Emitted when a token is sent to another chain.
    /// @param msgHash The hash of the message.
    /// @param from The address of the sender.
    /// @param to The address of the recipient.
    /// @param canonicalChainId The chain ID of the canonical token.
    /// @param destChainId The chain ID of the destination chain.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param amount The amount of tokens sent.
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

    /// @notice Emitted when a token is released from a message.
    /// @param msgHash The hash of the message.
    /// @param from The address of the sender.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param amount The amount of tokens released.
    event TokenReleased(
        bytes32 indexed msgHash, address indexed from, address ctoken, address token, uint256 amount
    );

    /// @notice Emitted when a token is received from another chain.
    /// @param msgHash The hash of the message.
    /// @param from The address of the sender.
    /// @param to The address of the recipient.
    /// @param srcChainId The chain ID of the source chain.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param amount The amount of tokens received.
    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 srcChainId,
        address ctoken,
        address token,
        uint256 amount
    );

    error VAULT_BTOKEN_BLACKLISTED();
    error VAULT_CTOKEN_MISMATCH();
    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INVALID_CTOKEN();
    error VAULT_INVALID_NEW_BTOKEN();
    error VAULT_LAST_MIGRATION_TOO_CLOSE();
    error VAULT_PERMIT_NO_ALLOWANCE();

    constructor(address _resolver, address _quotaManager) BaseVault(_resolver) {
        quotaManager = IQuotaManager(_quotaManager);
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
    /// @notice Change bridged token.
    /// @param _ctoken The canonical token.
    /// @param _btokenNew The new bridged token address.
    /// @return btokenOld_ The old bridged token address.

    function changeBridgedToken(
        CanonicalERC20 calldata _ctoken,
        address _btokenNew
    )
        external
        onlyOwner
        nonReentrant
        returns (address btokenOld_)
    {
        if (
            _btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)
                || !_btokenNew.isContract()
        ) {
            revert VAULT_INVALID_NEW_BTOKEN();
        }

        if (_ctoken.addr == address(0) || _ctoken.chainId == block.chainid) {
            revert VAULT_INVALID_CTOKEN();
        }

        if (btokenDenylist[_btokenNew]) revert VAULT_BTOKEN_BLACKLISTED();

        uint256 _lastMigrationStart = lastMigrationStart[_ctoken.chainId][_ctoken.addr];
        if (block.timestamp < _lastMigrationStart + MIN_MIGRATION_DELAY) {
            revert VAULT_LAST_MIGRATION_TOO_CLOSE();
        }

        btokenOld_ = canonicalToBridged[_ctoken.chainId][_ctoken.addr];

        if (btokenOld_ != address(0)) {
            CanonicalERC20 memory ctoken = bridgedToCanonical[btokenOld_];

            // The ctoken must match the saved one.
            if (keccak256(abi.encode(_ctoken)) != keccak256(abi.encode(ctoken))) {
                revert VAULT_CTOKEN_MISMATCH();
            }

            delete bridgedToCanonical[btokenOld_];
            btokenDenylist[btokenOld_] = true;

            // Start the migration
            if (
                btokenOld_.supportsInterface(type(IBridgedERC20Migratable).interfaceId)
                    && _btokenNew.supportsInterface(type(IBridgedERC20Migratable).interfaceId)
            ) {
                IBridgedERC20Migratable(btokenOld_).changeMigrationStatus(_btokenNew, false);
                IBridgedERC20Migratable(_btokenNew).changeMigrationStatus(btokenOld_, true);
            }
        }

        bridgedToCanonical[_btokenNew] = _ctoken;
        canonicalToBridged[_ctoken.chainId][_ctoken.addr] = _btokenNew;
        lastMigrationStart[_ctoken.chainId][_ctoken.addr] = block.timestamp;

        emit BridgedTokenChanged({
            srcChainId: _ctoken.chainId,
            ctoken: _ctoken.addr,
            btokenOld: btokenOld_,
            btokenNew: _btokenNew,
            ctokenSymbol: _ctoken.symbol,
            ctokenName: _ctoken.name,
            ctokenDecimal: _ctoken.decimals
        });
    }

    /// @notice Transfers ERC20 tokens to this vault and sends a message to the
    /// destination chain so the user can receive the same amount of tokens by
    /// invoking the message call.
    /// @param _op Option for sending ERC20 tokens.
    /// @return message_ The constructed message.
    function sendToken(BridgeTransferOp calldata _op)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        Permit2Data memory noPermit2;
        message_ = _sendToken(_op, noPermit2, false);
    }

    /// @notice Same as `sendToken`, but consumes an EIP-2612 permit signature to set this vault's
    /// allowance first, so no separate `approve` transaction is needed.
    /// @dev Only usable with tokens that implement EIP-2612; use `sendTokenWithPermit2` otherwise.
    /// The caller must be the permit signer.
    /// @dev EIP-2612 `permit` *sets* the allowance rather than adding to it, so a caller who already
    /// holds a larger standing allowance for this vault will see it replaced by `_op.amount` and
    /// then spent down to zero. That is safe (it only ever reduces standing approval) but it is
    /// destructive, so callers that keep a long-lived allowance should use `sendToken` instead.
    /// @dev A failed permit is swallowed, so a caller who already holds a sufficient allowance
    /// bridges against it even when the signature is bad. That is the intended outcome -- the
    /// caller is the token owner and asked for exactly this transfer -- and it is also what makes
    /// the front-run case survivable, since a replayed signature leaves the allowance in place.
    /// Only the resulting allowance matters, which is what is checked; a signature that leaves no
    /// allowance behind reverts with `VAULT_PERMIT_NO_ALLOWANCE`.
    /// @param _op Option for sending ERC20 tokens.
    /// @param _deadline The permit signature's expiry timestamp.
    /// @param _v The permit signature's `v` value.
    /// @param _r The permit signature's `r` value.
    /// @param _s The permit signature's `s` value.
    /// @return message_ The constructed message.
    function sendTokenWithPermit(
        BridgeTransferOp calldata _op,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        // Validate before calling into `_op.token`. The permit is an external call to a
        // caller-chosen address, so it must not happen for an operation that cannot proceed
        // anyway. `_sendToken` runs the same `_checkOp` again, so no entrypoint can skip it.
        _checkOp(_op);

        // The permit is best-effort: anyone can front-run it by replaying the same signature
        // directly against the token, which consumes the nonce and would make an unguarded call
        // revert. Only the allowance it leaves behind matters, so a failed permit is swallowed and
        // the allowance is checked instead.
        try IERC20Permit(_op.token)
            .permit(msg.sender, address(this), _op.amount, _deadline, _v, _r, _s) { }
            catch { }

        // A `permit` call that neither reverts nor grants an allowance is not hypothetical: on a
        // token whose fallback silently accepts unknown selectors (WETH9 being the obvious one)
        // the `try` takes its success branch with the allowance still untouched. Checking the
        // allowance rather than the call's outcome covers that alongside the front-run case, and
        // fails here with a decodable error instead of deep inside `SafeERC20`.
        if (IERC20(_op.token).allowance(msg.sender, address(this)) < _op.amount) {
            revert VAULT_PERMIT_NO_ALLOWANCE();
        }

        Permit2Data memory noPermit2;
        message_ = _sendToken(_op, noPermit2, false);
    }

    /// @notice Same as `sendToken`, but pulls the tokens with a Permit2 `SignatureTransfer`, so no
    /// separate `approve` transaction is needed.
    /// @dev Works for every ERC20 regardless of EIP-2612 support, and requires the caller to have
    /// approved Permit2 once. The caller must be the permit signer. Reverts if Permit2 is not
    /// deployed on this chain.
    /// @param _op Option for sending ERC20 tokens.
    /// @param _nonce The Permit2 unordered nonce.
    /// @param _deadline The Permit2 signature's expiry timestamp.
    /// @param _signature The caller's Permit2 signature, which must authorize exactly `_op.amount`
    /// of `_op.token`. Passed to Permit2 verbatim as `bytes`, so a smart-contract wallet may
    /// authorize the transfer with an EIP-1271 signature: Permit2 routes a signer that has code to
    /// `isValidSignature` instead of `ecrecover`. Helpers that take a split `(v, r, s)` cannot
    /// express such a signature, which is why the raw bytes are threaded through here. No length is
    /// imposed on it for the same reason: Permit2 hands a contract signer whatever bytes it is
    /// given, and an EIP-1271 wallet that authorizes from stored state (a pre-approved hash, say)
    /// validates an empty signature. An EOA signature of the wrong length is rejected by Permit2
    /// itself.
    /// @return message_ The constructed message.
    function sendTokenWithPermit2(
        BridgeTransferOp calldata _op,
        uint256 _nonce,
        uint256 _deadline,
        bytes calldata _signature
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        Permit2Data memory permit2 =
            Permit2Data({ nonce: _nonce, deadline: _deadline, signature: _signature });
        message_ = _sendToken(_op, permit2, true);
    }

    /// @dev Validates a send operation. Every entrypoint reaches this through `_sendToken`, and
    /// `sendTokenWithPermit` additionally runs it up front so it never hands execution to a
    /// caller-chosen token for an operation that cannot proceed. Keeping the checks in one place is
    /// what stops those two lists from drifting apart.
    /// @param _op Option for sending ERC20 tokens.
    function _checkOp(BridgeTransferOp calldata _op) private view {
        if (_op.amount == 0) revert VAULT_INVALID_AMOUNT();
        if (_op.token == address(0)) revert VAULT_INVALID_TOKEN();
        if (btokenDenylist[_op.token]) revert VAULT_BTOKEN_BLACKLISTED();
        if (msg.value < _op.fee) revert VAULT_INSUFFICIENT_FEE();
        checkToAddressOnSrcChain(_op.to, _op.destChainId);
    }

    /// @dev Shared implementation behind `sendToken`, `sendTokenWithPermit` and
    /// `sendTokenWithPermit2`. The token pull is the only step that differs between them.
    /// @param _op Option for sending ERC20 tokens.
    /// @param _permit2 The Permit2 authorization; ignored unless `_usePermit2` is true.
    /// @param _usePermit2 Whether to pull via Permit2 rather than a plain `transferFrom`.
    /// @return message_ The constructed message.
    function _sendToken(
        BridgeTransferOp calldata _op,
        Permit2Data memory _permit2,
        bool _usePermit2
    )
        private
        returns (IBridge.Message memory message_)
    {
        _checkOp(_op);

        (bytes memory data, CanonicalERC20 memory ctoken, uint256 balanceChange) =
            _handleMessage(_op, _permit2, _usePermit2);

        IBridge.Message memory message = IBridge.Message({
            id: 0, // will receive a new value
            from: address(0), // will receive a new value
            srcChainId: 0, // will receive a new value
            destChainId: _op.destChainId,
            srcOwner: msg.sender,
            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,
            to: resolve(_op.destChainId, name(), false),
            value: msg.value - _op.fee,
            fee: _op.fee,
            gasLimit: _op.gasLimit,
            data: data
        });

        bytes32 msgHash;
        (msgHash, message_) =
            IBridge(resolve(LibNames.B_BRIDGE, false)).sendMessage{ value: msg.value }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message_.srcOwner,
            to: _op.to,
            canonicalChainId: ctoken.chainId,
            destChainId: _op.destChainId,
            ctoken: ctoken.addr,
            token: _op.token,
            amount: balanceChange
        });
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) public payable whenNotPaused nonReentrant {
        (CanonicalERC20 memory ctoken, address from, address to, uint256 amount) =
            abi.decode(_data, (CanonicalERC20, address, address, uint256));

        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        // Don't allow sending to disallowed addresses.
        // Don't send the tokens back to `from` because `from` is on the source chain.
        checkToAddressOnDestChain(to);

        // Transfer the ETH and the tokens to the `to` address
        address token = _transferTokens(ctoken, to, amount);
        to.sendEtherAndVerify(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            ctoken: ctoken.addr,
            token: token,
            amount: amount
        });
    }

    /// @inheritdoc IRecallableSender
    /// @dev The refund debits the withdrawal quota just like a cross-chain delivery does. A recall
    /// is reached through the same destination-chain failure proof that a delivery is, and on the
    /// bridged branch it mints supply bounded by no vault balance, so the quota is the only numeric
    /// ceiling on this path and is deliberately kept.
    /// @dev Consequence worth knowing: `QuotaManager` caps a token's refill at its configured
    /// quota, so a single recall larger than that cap can never be refunded in one call. An
    /// out-of-quota refund reverts atomically, leaving the message `NEW` and retryable once the
    /// quota refills; a recall above the cap stays blocked until the owner raises the token's quota
    /// via `QuotaManager.updateQuota`.
    function onMessageRecalled(
        IBridge.Message calldata _message,
        bytes32 _msgHash
    )
        external
        payable
        override
        onlyFromNamed(LibNames.B_BRIDGE)
        whenNotPaused
        nonReentrant
    {
        (bytes memory data) = abi.decode(_message.data[4:], (bytes));
        (CanonicalERC20 memory ctoken,,, uint256 amount) =
            abi.decode(data, (CanonicalERC20, address, address, uint256));

        // Transfer the ETH and tokens back to the owner.
        address token = _transferTokens(ctoken, _message.srcOwner, amount);
        _message.srcOwner.sendEtherAndVerify(_message.value);

        emit TokenReleased({
            msgHash: _msgHash,
            from: _message.srcOwner,
            ctoken: ctoken.addr,
            token: token,
            amount: amount
        });
    }

    /// @inheritdoc BaseVault
    function name() public pure override returns (bytes32) {
        return LibNames.B_ERC20_VAULT;
    }

    /// @dev Releases tokens to `_to`, either by transferring the canonical token this vault
    /// custodies or by minting the bridged representation.
    /// @dev Every release debits the withdrawal quota, whether it settles a delivery from another
    /// chain or refunds a recalled message. A recall is not itself a cross-chain inflow, but it is
    /// reached through the same failure-proof primitive as a delivery, and on the bridged branch it
    /// mints supply that no vault balance bounds -- so the quota is the only numeric ceiling on
    /// either path and is deliberately applied to both.
    /// @param _ctoken The canonical token.
    /// @param _to The recipient of the released tokens.
    /// @param _amount The amount to release.
    /// @return token_ The address of the token transferred or minted.
    function _transferTokens(
        CanonicalERC20 memory _ctoken,
        address _to,
        uint256 _amount
    )
        private
        returns (address token_)
    {
        if (_ctoken.chainId == block.chainid) {
            token_ = _ctoken.addr;
            IERC20(token_).safeTransfer(_to, _amount);
        } else {
            token_ = _getOrDeployBridgedToken(_ctoken);
            //For native bridged tokens (like USDC), the mint() signature is the same, so no need to
            // check.
            IBridgedERC20(token_).mint(_to, _amount);
        }
        _consumeTokenQuota(token_, _amount);
    }

    /// @dev Consumes a given amount of token quota from the quota manager; reverts if quota is
    /// insufficient. This is the final step of `_transferTokens`, so it runs only after the tokens
    /// have been transferred/minted — quota is debited exactly when tokens are actually released.
    /// Because it is the last step, a `QM_OUT_OF_QUOTA` revert rolls back the whole transaction
    /// atomically: the token transfer/mint is undone and no partial state remains. Integrators
    /// driving this flow externally (or via a custom vault) must expect the entire release to
    /// revert when quota is exhausted, never a partial release. Skips the external call when nothing
    /// is released (`_amount == 0`).
    /// @param _token The token address.
    /// @param _amount The amount of token quota to consume.
    function _consumeTokenQuota(address _token, uint256 _amount) private {
        if (_amount != 0 && address(quotaManager) != address(0)) {
            quotaManager.consumeQuota(_token, _amount);
        }
    }

    /// @dev Pulls `_amount` of `_token` from `msg.sender` into this vault. When `_usePermit2` is
    /// true the pull is authorized by a Permit2 `SignatureTransfer`, which works for every ERC20
    /// regardless of EIP-2612 support; otherwise a plain `transferFrom` against a pre-existing
    /// allowance is used. The Permit2 owner is always `msg.sender`, so the caller remains the token
    /// owner and `Message.srcOwner` keeps its meaning as the address a recall refunds.
    /// @param _token The token to pull.
    /// @param _amount The amount to pull.
    /// @param _permit2 The Permit2 authorization; ignored unless `_usePermit2` is true.
    /// @param _usePermit2 Whether to pull via Permit2 rather than a plain `transferFrom`.
    function _pullTokens(
        address _token,
        uint256 _amount,
        Permit2Data memory _permit2,
        bool _usePermit2
    )
        private
    {
        if (!_usePermit2) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            return;
        }

        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({ token: _token, amount: _amount }),
            nonce: _permit2.nonce,
            deadline: _permit2.deadline
        });
        IPermit2.SignatureTransferDetails memory details =
            IPermit2.SignatureTransferDetails({ to: address(this), requestedAmount: _amount });

        IPermit2(PERMIT2).permitTransferFrom(permit, details, msg.sender, _permit2.signature);
    }

    /// @dev Handles the message on the source chain and returns the encoded
    /// call on the destination call.
    /// @param _op The BridgeTransferOp object.
    /// @param _permit2 The Permit2 authorization; ignored unless `_usePermit2` is true.
    /// @param _usePermit2 Whether to pull via Permit2 rather than a plain `transferFrom`.
    /// @return msgData_ Encoded message data.
    /// @return ctoken_ The canonical token.
    /// @return balanceChange_ User token balance actual change after the token
    /// transfer. This value is calculated so we do not assume token balance
    /// change is the amount of token transferred away.
    function _handleMessage(
        BridgeTransferOp calldata _op,
        Permit2Data memory _permit2,
        bool _usePermit2
    )
        private
        returns (bytes memory msgData_, CanonicalERC20 memory ctoken_, uint256 balanceChange_)
    {
        // If it's a bridged token
        CanonicalERC20 storage _ctoken = bridgedToCanonical[_op.token];
        if (_ctoken.addr != address(0)) {
            ctoken_ = _ctoken;
            // Following the "transfer and burn" pattern, as used by USDC
            _pullTokens(_op.token, _op.amount, _permit2, _usePermit2);
            IBridgedERC20(_op.token).burn(_op.amount);
            balanceChange_ = _op.amount;
        } else {
            // If it's a canonical token
            ctoken_ = CanonicalERC20({
                chainId: uint64(block.chainid),
                addr: _op.token,
                decimals: _safeDecimals(_op.token),
                symbol: safeSymbol(_op.token),
                name: safeName(_op.token)
            });

            // Query the balance then query it again to get the actual amount of
            // token transferred into this address, this is more accurate than
            // simply using `amount` -- some contract may deduct a fee from the
            // transferred amount.
            IERC20 t = IERC20(_op.token);
            uint256 _balance = t.balanceOf(address(this));
            _pullTokens(_op.token, _op.amount, _permit2, _usePermit2);
            balanceChange_ = t.balanceOf(address(this)) - _balance;
        }

        msgData_ = abi.encodeCall(
            this.onMessageInvocation, abi.encode(ctoken_, msg.sender, _op.to, balanceChange_)
        );
    }

    /// @dev Retrieve or deploy a bridged ERC20 token contract.
    /// @param ctoken CanonicalERC20 data.
    /// @return btoken Address of the bridged token contract.
    function _getOrDeployBridgedToken(CanonicalERC20 memory ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /// @dev Deploy a new BridgedERC20 contract and initialize it.
    /// This must be called before the first time a bridged token is sent to
    /// this chain.
    /// @param ctoken CanonicalERC20 data.
    /// @return btoken Address of the deployed bridged token contract.
    function _deployBridgedToken(CanonicalERC20 memory ctoken) private returns (address btoken) {
        bytes memory data = abi.encodeCall(
            IBridgedERC20Initializable.init,
            (owner(), ctoken.addr, ctoken.chainId, ctoken.decimals, ctoken.symbol, ctoken.name)
        );

        btoken = address(new ERC1967Proxy(resolve(LibNames.B_BRIDGED_ERC20, false), data));
        bridgedToCanonical[btoken] = ctoken;
        canonicalToBridged[ctoken.chainId][ctoken.addr] = btoken;

        emit BridgedTokenDeployed({
            srcChainId: ctoken.chainId,
            ctoken: ctoken.addr,
            btoken: btoken,
            ctokenSymbol: ctoken.symbol,
            ctokenName: ctoken.name,
            ctokenDecimal: ctoken.decimals
        });
    }

    function _safeDecimals(address _token) private view returns (uint8) {
        (bool success, bytes memory data) =
            address(_token).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }
}
