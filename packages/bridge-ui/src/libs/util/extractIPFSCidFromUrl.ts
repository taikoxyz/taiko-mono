export const extractIPFSCidFromUrl = (url: string): { cid: string | null } => {
  // Adapting the provided regex to match the URL structure
  const regex =
    /\/(Qm[1-9A-HJ-NP-Za-km-z]{44,}|b[A-Za-z2-7]{58,}|B[A-Z2-7]{58,}|z[1-9A-HJ-NP-Za-km-z]{48,}|F[0-9A-F]{50,})(\/(\d|\w|\.)+)*/;
  const match = url.match(regex);
  return match ? { cid: match[1] } : { cid: null };
};
