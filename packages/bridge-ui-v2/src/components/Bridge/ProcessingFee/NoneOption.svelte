<script lang="ts">
  import type { Address } from 'viem';

  import { recommendProcessingFee } from '$libs/fee';
  import { getBalance, type Token } from '$libs/token';
  import { account, network } from '$stores';

  import { destNetwork, selectedToken } from '../state';

  export let enoughEth: boolean;
  export let calculating = false;
  export let error = false;

  async function compute(token: Maybe<Token>, userAddress?: Address, srcChain?: number, destChain?: number) {
    if (!token || !userAddress || !srcChain || !destChain) {
      enoughEth = false;
      return;
    }

    calculating = true;
    error = false;

    try {
      let destBalance;
      // Get the balance of the user on the destination chain
      destBalance = await getBalance({
        userAddress,
        srcChainId: destChain,
      });

      // Calculate the recommended amount of ETH needed for processMessage call
      const recommendedAmount = await recommendProcessingFee({
        token,
        destChainId: destChain,
        srcChainId: srcChain,
      });

      // Does the user have enough ETH to claim manually on the destination chain?
      enoughEth = destBalance ? destBalance?.value >= recommendedAmount : false;
    } catch (err) {
      console.error(err);

      error = true;
      enoughEth = false;
    } finally {
      calculating = false;
    }
  }

  $: compute($selectedToken, $account?.address, $network?.id, $destNetwork?.id);
</script>
