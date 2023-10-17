export class NotConnectedError extends Error {
  name = 'NotConnectedError';
}

export class TokenMintedError extends Error {
  name = 'TokenMintedError';
}

export class InsufficientBalanceError extends Error {
  name = 'InsufficientBalanceError';
}

export class InsufficientAllowanceError extends Error {
  name = 'InsufficientAllowanceError';
}

export class NotApprovedError extends Error {
  name = 'NotApprovedError';
}

export class NoAllowanceRequiredError extends Error {
  name = 'NoAllowanceRequiredError';
}

export class NoTokenAddressError extends Error {
  name = 'NoTokenAddressError';
}

export class FailedTransactionError extends Error {
  name = 'FailedTransactionError';
}

export class SendMessageError extends Error {
  name = 'SendMessageError';
}

export class SendERC20Error extends Error {
  name = 'SendERC20Error';
}

export class SendERC721Error extends Error {
  name = 'SendERC721Error';
}

export class SendERC1155Error extends Error {
  name = 'SendERC1155Error';
}

export class ApproveError extends Error {
  name = 'ApproveError';
}

export class RevertedWithFailedError extends Error {
  name = 'RevertedWithFailedError';
}

export class MintError extends Error {
  name = 'MintError';
}

export class PendingBlockError extends Error {
  name = 'PendingBlockError';
}

export class InvalidProofError extends Error {
  name = 'InvalidProofError';
}

export class MessageStatusError extends Error {
  name = 'MessageStatusError';
}

export class WrongOwnerError extends Error {
  name = 'WrongOwnerError';
}

export class WrongChainError extends Error {
  name = 'WrongChainError';
}

export class BridgeTxPollingError extends Error {
  name = 'BridgeTxPollingError';
}

export class ProcessMessageError extends Error {
  name = 'ProcessMessageError';
}

export class RetryError extends Error {
  name = 'RetryError';
}

export class ReleaseError extends Error {
  name = 'ReleaseError';
}

export class UnknownTokenTypeError extends Error {
  name = 'UnknownTokenTypeError';
}
