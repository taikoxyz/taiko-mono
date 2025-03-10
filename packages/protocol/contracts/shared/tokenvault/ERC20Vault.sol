// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../shared/based/ITaiko.sol";
import "../../layer1/based/ITaikoInbox.sol";
import "../bridge/IQuotaManager.sol";
import "../libs/LibStrings.sol";
import "../libs/LibAddress.sol";
import "./IBridgedERC20.sol";
import "./BaseVault.sol";

/// @title ERC20Vault
/// @notice This vault holds all ERC20 tokens (excluding Ether) that users have
/// deposited. It also manages the mapping between canonical ERC20 tokens and
/// their bridged tokens. This vault does not support rebase/elastic tokens.
/// @dev Labeled in address resolver as "erc20_vault".
/// @custom:security-contact security@taiko.xyz
contract ERC20Vault is BaseVault {
    using Address for address;
    using LibAddress for address;
    using SafeERC20 for IERC20;

    uint256 public constant MIN_MIGRATION_DELAY = 90 days;

    /// @dev Represents a canonical ERC20 token.
    struct CanonicalERC20 {
        uint64 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    /// @dev Represents an operation to send tokens to another chain.
    /// 5 slots
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
        // Fee paid to the solver in the same ERC20 token. A value of zero means this operation is
        // not solvable.
        uint256 solverFee;
    }

    /// @dev Represents an operation to solve an ERC20 bridging intent on destination chain
    struct SolverOp {
        // Nonce for the solver condition
        uint256 nonce;
        // ERC20 token address on destination chain
        address token;
        // Recipient of the tokens
        address to;
        // Amount of tokens to be transferred to the recipient
        uint256 amount;
        // Fields below are used to constrain a solve operation to only pass if an L2 batch
        // containing the initial "intent" transaction is included.
        uint64 l2BatchId;
        bytes32 l2BatchMetaHash;
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

    /// @notice Mapping from solver condition to the address of solver
    mapping(bytes32 solverCondition => address solver) public solverConditionToSolver;

    uint256[45] private __gap;

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
    /// @param solverFee Fee to be paid to the solver on the destination chain
    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 canonicalChainId,
        uint64 destChainId,
        address ctoken,
        address token,
        uint256 amount,
        uint256 solverFee
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
    /// @param solver The solver for the bridging intent on destination chain.
    /// @param srcChainId The chain ID of the source chain.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param amount The amount of tokens received.
    /// @param solverFee Fee paid to the solver on destination chain
    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        address solver,
        uint64 srcChainId,
        address ctoken,
        address token,
        uint256 amount,
        uint256 solverFee
    );

    /// @notice Emitted when a bridging intent is solved
    /// @param solverCondition The solver condition hash
    /// @param solver The address of the solver
    event ERC20Solved(bytes32 indexed solverCondition, address solver);

    error VAULT_INSUFFICIENT_ETHER();
    error VAULT_ALREADY_SOLVED();
    error VAULT_BTOKEN_BLACKLISTED();
    error VAULT_CTOKEN_MISMATCH();
    error VAULT_ETHER_TRANSFER_FAILED();
    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INVALID_CTOKEN();
    error VAULT_INVALID_NEW_BTOKEN();
    error VAULT_LAST_MIGRATION_TOO_CLOSE();
    error VAULT_METAHASH_MISMATCH();
    error VAULT_NOT_ON_L1();

    constructor(address _resolver) BaseVault(_resolver) { }

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

    /// @notice Transfers ERC20 tokens or Ether to this vault and sends a message to the
    /// destination chain so the user can receive the same amount by invoking the message call.
    /// @param _op Option for sending tokens/ether.
    /// @return message_ The constructed message.
    function sendToken(BridgeTransferOp calldata _op)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        {
            if (_op.amount == 0) revert VAULT_INVALID_AMOUNT();

            uint256 etherToBridge = (_op.token == address(0) ? _op.amount + _op.solverFee : 0);
            if (msg.value < _op.fee + etherToBridge) {
                revert VAULT_INSUFFICIENT_ETHER();
            }

            if (_op.token != address(0) && btokenDenylist[_op.token]) {
                revert VAULT_BTOKEN_BLACKLISTED();
            }
            checkToAddressOnSrcChain(_op.to, _op.destChainId);
        }

        address bridge = resolve(LibStrings.B_BRIDGE, false);

        (
            bytes memory data,
            CanonicalERC20 memory ctoken,
            uint256 balanceChangeAmount,
            uint256 balanceChangeSolverFee
        ) = _handleMessage(bridge, _op);

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
        (msgHash, message_) = IBridge(bridge).sendMessage{ value: msg.value }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message_.srcOwner,
            to: _op.to,
            canonicalChainId: ctoken.chainId,
            destChainId: _op.destChainId,
            ctoken: ctoken.addr,
            token: _op.token,
            amount: balanceChangeAmount,
            solverFee: balanceChangeSolverFee
        });
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) public payable whenNotPaused nonReentrant {
        (
            CanonicalERC20 memory ctoken,
            address from,
            address to,
            uint256 amount,
            uint256 solverFee,
            bytes32 solverCondition
        ) = abi.decode(_data, (CanonicalERC20, address, address, uint256, uint256, bytes32));

        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        // Don't allow sending to disallowed addresses.
        // Don't send the tokens back to `from` because `from` is on the source chain.
        checkToAddressOnDestChain(to);

        address tokenRecipient = to;

        // If the bridging intent is solvable and has been solved, the solver becomes the token
        // recipient
        address solver;
        if (solverFee != 0) {
            solver = solverConditionToSolver[solverCondition];
            if (solver != address(0)) {
                tokenRecipient = solver;
                delete solverConditionToSolver[solverCondition];
            }
        }

        address token;
        {
            uint256 amountToTransfer = amount + solverFee;
            token = _transferTokensOrEther(ctoken, tokenRecipient, amountToTransfer);

            bool succeeded = to.sendEther(
                ctoken.addr == address(0) ? msg.value - amountToTransfer : msg.value, gasleft(), ""
            );

            // Only require Ether transfer to succeed if the bridging intent is not solved by a
            // solver.  The bridging intent owner must ensure that the recipient address can
            // successfully receive Ether.
            if (solver == address(0)) {
                require(succeeded, VAULT_ETHER_TRANSFER_FAILED());
            } else {
                // Do not check Ether transfer success. If we did, the bridging intent owner could
                // intentionally cause the Ether transfer to fail on the destination chain, then
                // falsely claim the transaction failed and reclaim the Ether on the source chain.
            }
        }

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            solver: solver,
            srcChainId: ctx.srcChainId,
            ctoken: ctoken.addr,
            token: token,
            amount: amount,
            solverFee: solverFee
        });
    }

    /// @inheritdoc IRecallableSender
    function onMessageRecalled(
        IBridge.Message calldata _message,
        bytes32 _msgHash
    )
        external
        payable
        override
        whenNotPaused
        nonReentrant
    {
        // `onlyFromBridge` checked in checkRecallMessageContext
        checkRecallMessageContext();

        (bytes memory data) = abi.decode(_message.data[4:], (bytes));
        (CanonicalERC20 memory ctoken,,, uint256 amount, uint256 solverFee,) =
            abi.decode(data, (CanonicalERC20, address, address, uint256, uint256, bytes32));

        // Transfer the ETH and tokens back to the owner
        uint256 amountToReturn = amount + solverFee;
        address token = _transferTokensOrEther(ctoken, _message.srcOwner, amountToReturn);
        _message.srcOwner.sendEtherAndVerify(
            ctoken.addr == address(0) ? _message.value - amountToReturn : _message.value
        );

        emit TokenReleased({
            msgHash: _msgHash,
            from: _message.srcOwner,
            ctoken: ctoken.addr,
            token: token,
            amount: amount
        });
    }

    /// @notice Lets a solver fulfil a bridging intent by transferring tokens/ether to the
    /// recipient.
    /// @param _op Parameters for the solve operation
    function solve(SolverOp memory _op) external payable nonReentrant whenNotPaused {
        if (_op.l2BatchMetaHash != 0) {
            // Verify that the required L2 batch containing the intent transaction has been proposed
            address taiko = resolve(LibStrings.B_TAIKO, false);
            if (!ITaiko(taiko).isOnL1()) revert VAULT_NOT_ON_L1();

            bytes32 l2BatchMetaHash = ITaikoInbox(taiko).getBatch(_op.l2BatchId).metaHash;
            if (l2BatchMetaHash != _op.l2BatchMetaHash) revert VAULT_METAHASH_MISMATCH();
        }

        // Record the solver's address
        bytes32 solverCondition = getSolverCondition(_op.nonce, _op.token, _op.to, _op.amount);
        if (solverConditionToSolver[solverCondition] != address(0)) revert VAULT_ALREADY_SOLVED();
        solverConditionToSolver[solverCondition] = msg.sender;

        // Handle transfer based on token type
        if (_op.token == address(0)) {
            // For Ether transfers
            if (msg.value != _op.amount) revert VAULT_INVALID_AMOUNT();
            _op.to.sendEtherAndVerify(_op.amount);
        } else {
            // For ERC20 tokens
            IERC20(_op.token).safeTransferFrom(msg.sender, _op.to, _op.amount);
        }

        emit ERC20Solved(solverCondition, msg.sender);
    }

    /// @notice Returns the solver condition for a bridging intent
    /// @param _nonce Unique numeric value to prevent nonce collision
    /// @param _token Token address (address(0) for Ether)
    /// @param _to Recipient on destination chain
    /// @param _amount Amount of tokens/ether expected by the recipient
    /// @return solver condition
    function getSolverCondition(
        uint256 _nonce,
        address _token,
        address _to,
        uint256 _amount
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _token, _to, _amount));
    }

    /// @inheritdoc BaseVault
    function name() public pure override returns (bytes32) {
        return LibStrings.B_ERC20_VAULT;
    }

    function _transferTokensOrEther(
        CanonicalERC20 memory _ctoken,
        address _to,
        uint256 _amount
    )
        private
        returns (address token_)
    {
        if (_ctoken.addr == address(0)) {
            // Handle Ether transfer
            _to.sendEtherAndVerify(_amount);
        } else if (_ctoken.chainId == block.chainid) {
            token_ = _ctoken.addr;
            IERC20(token_).safeTransfer(_to, _amount);
        } else {
            token_ = _getOrDeployBridgedToken(_ctoken);
            IBridgedERC20(token_).mint(_to, _amount);
        }
    }

    /// @dev Handles the message on the source chain and returns the encoded
    /// call on the destination call.
    /// @param _bridge Address of the message passing bridge
    /// @param _op The BridgeTransferOp object.
    /// @return msgData_ Encoded message data.
    /// @return ctoken_ The canonical token.
    /// @return balanceChangeAmount_ User token balance actual change after the token
    /// transfer for `amount`. This value is calculated so we do not assume token balance
    /// change is the amount of token transferred away.
    /// @return balanceChangeSolverFee_ User token balance actual change after the token
    /// transfer for `solverFee`. This value is calculated so we do not assume token balance
    /// change is the amount of token transferred away.
    function _handleMessage(
        address _bridge,
        BridgeTransferOp calldata _op
    )
        private
        returns (
            bytes memory msgData_,
            CanonicalERC20 memory ctoken_,
            uint256 balanceChangeAmount_,
            uint256 balanceChangeSolverFee_
        )
    {
        bytes32 solverCondition;

        if (_op.token == address(0)) {
            balanceChangeAmount_ = _op.amount;
            balanceChangeSolverFee_ = _op.solverFee;
        } else if (bridgedToCanonical[_op.token].addr != address(0)) {
            // Handle bridged token
            ctoken_ = bridgedToCanonical[_op.token];
            uint256 amount = _op.amount + _op.solverFee;
            IERC20(_op.token).safeTransferFrom(msg.sender, address(this), amount);
            IBridgedERC20(_op.token).burn(amount);

            balanceChangeAmount_ = _op.amount;
            balanceChangeSolverFee_ = _op.solverFee;
        } else {
            // Handle canonical token
            ctoken_ = CanonicalERC20({
                chainId: uint64(block.chainid),
                addr: _op.token,
                decimals: _safeDecimals(_op.token),
                symbol: safeSymbol(_op.token),
                name: safeName(_op.token)
            });

            balanceChangeAmount_ = _transferTokenAndReturnBalanceDiff(_op.token, _op.amount);
            balanceChangeSolverFee_ = _transferTokenAndReturnBalanceDiff(_op.token, _op.solverFee);
        }

        // Prepare solver condition
        if (_op.solverFee > 0) {
            uint256 _nonce = IBridge(_bridge).nextMessageId();
            solverCondition = getSolverCondition(_nonce, ctoken_.addr, _op.to, balanceChangeAmount_);
        }

        msgData_ = abi.encodeCall(
            this.onMessageInvocation,
            abi.encode(
                ctoken_,
                msg.sender,
                _op.to,
                balanceChangeAmount_,
                balanceChangeSolverFee_,
                solverCondition
            )
        );
    }

    /// @dev Transfers tokens from the sender to this contract and returns the difference in
    /// balance.
    /// @param _erc20Token The ERC20 token to transfer.
    /// @param _amount The amount of tokens to transfer.
    /// @return The difference in balance after the transfer.
    function _transferTokenAndReturnBalanceDiff(
        address _erc20Token,
        uint256 _amount
    )
        private
        returns (uint256)
    {
        if (_amount == 0) return 0;

        IERC20 erc20 = IERC20(_erc20Token);
        uint256 balance = erc20.balanceOf(address(this));
        erc20.safeTransferFrom(msg.sender, address(this), _amount);
        return erc20.balanceOf(address(this)) - balance;
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

        btoken = address(new ERC1967Proxy(resolve(LibStrings.B_BRIDGED_ERC20, false), data));
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

    function _consumeTokenQuota(address _token, uint256 _amount) private {
        address quotaManager = resolve(LibStrings.B_QUOTA_MANAGER, true);
        if (quotaManager != address(0)) {
            IQuotaManager(quotaManager).consumeQuota(_token, _amount);
        }
    }

    function _safeDecimals(address _token) private view returns (uint8) {
        (bool success, bytes memory data) =
            address(_token).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }
}
