export const truncateString = (str: string, maxLength: number = 10) => {
  if (!str) return "";
  return str.length > maxLength ? `${str.substring(0, maxLength)}` : str;
};
