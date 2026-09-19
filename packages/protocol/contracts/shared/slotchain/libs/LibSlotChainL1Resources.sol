// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain L1 transaction resource policy
/// @dev Implements the checked EIP-7623 calldata-floor and EIP-7825 transaction-cap feasibility
/// arithmetic applied by profile decoders, descriptor validators, and release certificates. Every
/// result fits `uint64`; an intermediate that does not is rejected rather than truncated. The call
/// sequence bounds are necessary lower bounds on a compiled gas certificate, not measurements.
/// @custom:security-contact security@taiko.xyz
library LibSlotChainL1Resources {
    /// @dev Fixed by this normative profile revision under Ethereum's EIP-7825 policy. It is
    /// independent of the configurable L1 block gas limit and is not a caller or governance
    /// override; a different policy requires a reviewed normative revision.
    uint64 internal constant L1_TRANSACTION_GAS_LIMIT = 16_777_216;
    /// @dev Base intrinsic gas of every transaction.
    uint64 internal constant TRANSACTION_BASE_GAS = 21_000;
    /// @dev EIP-7623 tokens per nonzero calldata byte; a zero byte is one token.
    uint64 internal constant NONZERO_BYTE_TOKENS = 4;
    /// @dev Ordinary gas per calldata token.
    uint64 internal constant STANDARD_TOKEN_GAS = 4;
    /// @dev EIP-7623 floor gas per calldata token.
    uint64 internal constant FLOOR_TOKEN_GAS = 10;
    /// @dev Required complete-transaction margin as a percentage of the required gas.
    uint64 internal constant HEADROOM_PERCENT = 130;
    /// @dev EIP-150 forwarding denominator.
    uint64 internal constant EIP150_DENOMINATOR = 63;

    /// @dev Counts EIP-7623 calldata tokens.
    /// @param _zeroBytes The number of zero calldata bytes.
    /// @param _nonzeroBytes The number of nonzero calldata bytes.
    /// @return tokens_ The checked token count.
    function calldataTokens(
        uint64 _zeroBytes,
        uint64 _nonzeroBytes
    )
        internal
        pure
        returns (uint64 tokens_)
    {
        tokens_ = checkedGas(
            uint256(_zeroBytes) + uint256(NONZERO_BYTE_TOKENS) * uint256(_nonzeroBytes)
        );
    }

    /// @dev Computes the EIP-7623 non-creation budget: the larger of the ordinary intrinsic plus
    /// execution charge and the calldata floor. No refund is credited, and the floor is an
    /// alternative to the ordinary charge rather than a second charge added to execution.
    /// @param _zeroBytes The number of zero calldata bytes.
    /// @param _nonzeroBytes The number of nonzero calldata bytes.
    /// @param _executionGas The complete execution budget including every prefix and suffix.
    /// @return requiredGas_ The checked required transaction gas.
    function requiredTransactionGas(
        uint64 _zeroBytes,
        uint64 _nonzeroBytes,
        uint64 _executionGas
    )
        internal
        pure
        returns (uint64 requiredGas_)
    {
        uint256 tokens = calldataTokens(_zeroBytes, _nonzeroBytes);
        uint64 ordinary = checkedGas(
            uint256(TRANSACTION_BASE_GAS) + uint256(STANDARD_TOKEN_GAS) * tokens
                + uint256(_executionGas)
        );
        uint64 floor = checkedGas(uint256(TRANSACTION_BASE_GAS) + uint256(FLOOR_TOKEN_GAS) * tokens);
        return ordinary > floor ? ordinary : floor;
    }

    /// @dev Computes the checked `ceil(1.30 * requiredGas)`, including exact-boundary rounding.
    /// @param _requiredGas The required transaction gas.
    /// @return gasWithHeadroom_ The required gas plus the mandatory 30% margin.
    function gasWithHeadroom(uint64 _requiredGas) internal pure returns (uint64 gasWithHeadroom_) {
        return checkedGas(uint256(HEADROOM_PERCENT) * uint256(_requiredGas) + 99) / 100;
    }

    /// @dev Returns the smaller of the supported L1 block gas limit and the transaction cap.
    /// @param _supportedL1BlockGasLimit The profile's nonzero supported L1 block gas limit.
    /// @return cap_ The effective transaction cap.
    function transactionCap(uint64 _supportedL1BlockGasLimit) internal pure returns (uint64 cap_) {
        if (_supportedL1BlockGasLimit == 0) revert InvalidSupportedL1BlockGasLimit();
        return _supportedL1BlockGasLimit < L1_TRANSACTION_GAS_LIMIT
            ? _supportedL1BlockGasLimit
            : L1_TRANSACTION_GAS_LIMIT;
    }

    /// @dev Reports whether the required gas plus its 30% margin fits the transaction cap.
    /// @param _requiredGas The required transaction gas.
    /// @param _supportedL1BlockGasLimit The profile's nonzero supported L1 block gas limit.
    /// @return fits_ Whether the complete transaction budget fits.
    function fitsTransactionCap(
        uint64 _requiredGas,
        uint64 _supportedL1BlockGasLimit
    )
        internal
        pure
        returns (bool fits_)
    {
        return gasWithHeadroom(_requiredGas) <= transactionCap(_supportedL1BlockGasLimit);
    }

    /// @dev Reverts unless the required gas plus its 30% margin fits the transaction cap.
    /// @param _requiredGas The required transaction gas.
    /// @param _supportedL1BlockGasLimit The profile's nonzero supported L1 block gas limit.
    function requireTransactionFits(
        uint64 _requiredGas,
        uint64 _supportedL1BlockGasLimit
    )
        internal
        pure
    {
        uint64 withHeadroom = gasWithHeadroom(_requiredGas);
        uint64 cap = transactionCap(_supportedL1BlockGasLimit);
        if (withHeadroom > cap) revert L1TransactionBudgetExceeded(withHeadroom, cap);
    }

    /// @dev Computes the necessary full-stipend/EIP-150 bound of an ordered call sequence that must
    /// retain `_retainedReserve` after its final call. The reserve and the EIP-150 retention overlap
    /// at every call, so their maximum rather than their sum is retained. Unmeasured overhead is
    /// excluded, so the result is a lower bound on a compiled certificate, never a measurement.
    /// @param _stipends The ordered nonzero stipends forwarded to each call.
    /// @param _retainedReserve The gas retained after the final call.
    /// @return minimumGas_ The checked minimum gas at the first call.
    function callSequenceMinimumGas(
        uint64[] memory _stipends,
        uint64 _retainedReserve
    )
        internal
        pure
        returns (uint64 minimumGas_)
    {
        minimumGas_ = _retainedReserve;
        for (uint256 i = _stipends.length; i > 0; --i) {
            minimumGas_ = singleCallMinimumGas(_stipends[i - 1], minimumGas_);
        }
    }

    /// @dev Single-call form of `callSequenceMinimumGas`.
    /// @param _stipend The nonzero stipend forwarded to the call.
    /// @param _retainedReserve The gas retained after the call.
    /// @return minimumGas_ The checked minimum gas before the call.
    function singleCallMinimumGas(
        uint64 _stipend,
        uint64 _retainedReserve
    )
        internal
        pure
        returns (uint64 minimumGas_)
    {
        if (_stipend == 0) revert InvalidL1CallStipend();
        uint64 forwarding =
            checkedGas(uint256(_stipend) + EIP150_DENOMINATOR - 1) / EIP150_DENOMINATOR;
        uint64 retained = forwarding > _retainedReserve ? forwarding : _retainedReserve;
        minimumGas_ = checkedGas(uint256(_stipend) + uint256(retained));
    }

    /// @dev Narrows a checked gas quantity into the `uint64` resource model.
    /// @param _value The unchecked quantity.
    /// @return gas_ The same quantity when it fits `uint64`.
    function checkedGas(uint256 _value) internal pure returns (uint64 gas_) {
        if (_value > type(uint64).max) revert L1ResourceOverflow();
        return uint64(_value);
    }

    error InvalidL1CallStipend();
    error InvalidSupportedL1BlockGasLimit();
    error L1ResourceOverflow();
    error L1TransactionBudgetExceeded(uint64 gasWithHeadroom, uint64 transactionCap);
}
