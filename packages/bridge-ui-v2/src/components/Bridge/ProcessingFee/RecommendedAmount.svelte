<script lang="ts">
  import { recommendProcessingFee } from '$libs/fee';
  import type { Token } from '$libs/token';
  import { network } from '$stores/network';

  import { destNetwork, selectedToken } from '../state';

  export let value: bigint;
  export let calculating = false;
  export let error = false;

  async function compute(token: Maybe<Token>, srcChainId?: number, destChainId?: number) {
    if (!token) return;

    calculating = true;
    error = false;

    try {
      value = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });
    } catch (err) {
      console.error(err);
      error = true;
    } finally {
      calculating = false;
    }
  }

  $: compute($selectedToken, $network?.id, $destNetwork?.id);
</script>
