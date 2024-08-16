export function getFileExtension(filename: string): string {
  const parts: string[] = filename.split('.');
  return parts.length > 1 ? parts[parts.length - 1] : '';
}
