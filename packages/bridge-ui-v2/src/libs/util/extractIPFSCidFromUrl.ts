export const extractIPFSCidFromUrl = (url: string): { cid: string | null; remainder: string | null } => {
  // Regular expression to match a typical IPFS CID v0 or v1
  // CID v0: QmP6oEEnsDr55gKqr1BQzjJwnsoscxFSksrsQ1YiMvG1Y91
  // CID v1: bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi
  const regex = /\/(Qm[a-zA-Z0-9]{44}|b[a-z]{8}[a-zA-Z0-9]{39})([^/]*)/;
  const match = url.match(regex);
  return match ? { cid: match[1], remainder: match[2] } : { cid: null, remainder: null };
};
