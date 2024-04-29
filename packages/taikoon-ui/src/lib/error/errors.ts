export class NotConnectedError extends Error {
  name = 'NotConnectedError';
}

export class TokenMintedError extends Error {
  name = 'TokenMintedError';
}

export class InsufficientBalanceError extends Error {
  name = 'InsufficientBalanceError';
}

export class NoTokenAddressError extends Error {
  name = 'NoTokenAddressError';
}

export class NoTokenError extends Error {
  name = 'NoTokenError';
}

export class FailedTransactionError extends Error {
  name = 'FailedTransactionError';
}

export class RevertedWithoutMessageError extends Error {
  name = 'RevertedWithoutMessageError';
}

export class RevertedWithFailedError extends Error {
  name = 'RevertedWithFailedError';
}

export class MintError extends Error {
  name = 'MintError';
}

export class WrongOwnerError extends Error {
  name = 'WrongOwnerError';
}

export class WrongChainError extends Error {
  name = 'WrongChainError';
}

export class FilterLogsError extends Error {
  name = 'FilterLogsError';
}

export class NoTokenInfoFoundError extends Error {
  name = 'NoTokenInfoFoundError';
}

export class NoMetadataFoundError extends Error {
  name = 'NoMetadataFoundError';
}

export class InternalError extends Error {
  name = 'InternalError';
}

export class ConfigError extends Error {
  name = 'ConfigError';
}

export class IpfsError extends Error {
  name = 'IpfsError';
}
