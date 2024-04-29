export class NotConnectedError extends Error {
  name = 'NotConnectedError';
}

export class FailedTransactionError extends Error {
  name = 'FailedTransactionError';
}

export class MintError extends Error {
  name = 'MintError';
}

export class FilterLogsError extends Error {
  name = 'FilterLogsError';
}

export class ConfigError extends Error {
  name = 'ConfigError';
}

export class IpfsError extends Error {
  name = 'IpfsError';
}
