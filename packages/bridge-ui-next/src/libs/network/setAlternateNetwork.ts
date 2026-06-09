import { destNetwork } from "$components/Bridge/state";
import { chainIdToChain } from "$libs/chain";
import { account } from "$stores/account";

import { getAlternateNetwork } from "./getAlternateNetwork";

export const setAlternateNetwork = () => {
  const currentAccount = account.getState();
  if (
    currentAccount &&
    (currentAccount.isConnected || currentAccount.isConnecting)
  ) {
    const alternateChainID = getAlternateNetwork();
    if (alternateChainID) {
      destNetwork.setState(chainIdToChain(alternateChainID));
    }
  } else {
    destNetwork.setState(null);
  }
};
