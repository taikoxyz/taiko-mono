export function jsonParseWithDefault<T>(strJson: Maybe<string>, defaultValue: T): T {
  try {
    // Keep in mind that strJson could be null or empty string
    // JSON.parse would not throw an error in those cases
    return strJson ? JSON.parse(strJson) : defaultValue;
  } catch (e) {
    return defaultValue;
  }
}
