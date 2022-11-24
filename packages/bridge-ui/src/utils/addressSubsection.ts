export const addressSubsection = (address: string) => {
  if (!address) return "0x";
  return `${address.substring(0, 6)}...${address.substring(38, 42)}`;
};
