<script lang="ts">
  import Modal from "./modals/Modal.svelte";
  import getConfirmations from "../utils/getConfirmations";
  import logger from "../utils/logger";
  import { signer } from "../store/signer";

  export let isOpen: boolean = false;
  export let hash: string = "0x";

  let confirmations: number = 0;
  let wantConfirmations: number = 5;
  let interval: ReturnType<typeof setInterval>;
  let intervalTime: number = 5 * 1000;

  const onCloseClicked = () => {
    isOpen = false;
  };

  $: confs(isOpen).catch((e) => logger.error(e));

  async function confs(open: boolean) {
    confirmations = await getConfirmations($signer.provider, hash);
    if (confirmations < wantConfirmations) {
      interval = setInterval(() => {
        getConfirmations($signer.provider, hash).then((c) => {
          confirmations = c;
          if (confirmations >= wantConfirmations) {
            clearInterval(interval);
          }
        });
      }, intervalTime);
    }
  }
</script>

<Modal title="Waiting for Confirmations" bind:isOpen onClose={onCloseClicked}>
  {#if confirmations < wantConfirmations}
    {confirmations} of {wantConfirmations}
  {:else}
    Transaction confirmed!
  {/if}
</Modal>
