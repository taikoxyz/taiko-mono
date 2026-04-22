export function truncateString(str: string, maxlength: number, strBoundary = '…') {
  if (!str) return;
  return str.length > maxlength ? `${str.substring(0, maxlength)}${strBoundary}` : str;
}
