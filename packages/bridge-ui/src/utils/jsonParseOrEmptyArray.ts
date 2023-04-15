export function jsonParseOrEmptyArray<T>(strJson: string | null): T[] {
  try {
    // Keep in mind that strJson could be null or empty string
    // JSON.parse would not throw an error in those cases
    return strJson ? JSON.parse(strJson) : [];
  } catch (e) {
    return [];
  }
}
