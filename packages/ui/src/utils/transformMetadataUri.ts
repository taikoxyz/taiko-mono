import { IPFS_GATEWAY_PREFIX } from "../constants/IPFS_GATEWAY_PREFIX";

export const transformMetadataUri = (
  metadataUri: string,
  id: string
): string => {
  if (!metadataUri) return "";
  if (metadataUri.includes("Unable")) return "";
  if (!metadataUri.includes("ipfs")) {
    metadataUri = metadataUri.replace("0x{id}", id);
    metadataUri = metadataUri.replace("{id}", id);
    return metadataUri;
  }

  if (metadataUri.includes("mypinata.cloud")) {
    metadataUri = metadataUri.split("/ipfs/")[1];
  }

  //metadataUri = metadataUri.replace("/metadata.json", "");

  metadataUri = metadataUri.replace("https://ipfs.io/ipfs/", "");
  metadataUri = metadataUri.replace("https://ipfs.io/", "");
  metadataUri = metadataUri.replace("ipfs/", "");
  metadataUri = metadataUri.replace("ipfs://", "");
  metadataUri = metadataUri.replace("0x{id}", id);
  metadataUri = metadataUri.replace("{id}", id);
  metadataUri = IPFS_GATEWAY_PREFIX + "ipfs/" + metadataUri;

  return metadataUri;
};
