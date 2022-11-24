function remove0xPrefixIfPresent(s: string): string {
  if (!s.startsWith("0x")) {
    return s;
  }

  while (s.startsWith("0x")) {
    s = s.slice(2);
  }
  return s;
}

export { remove0xPrefixIfPresent };
