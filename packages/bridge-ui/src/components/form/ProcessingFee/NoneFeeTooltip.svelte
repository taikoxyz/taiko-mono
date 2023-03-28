<script>
  import { localStoragePrefix } from '../../../config';
  import TooltipModal from '../../modals/TooltipModal.svelte';

  export let show = false;

  let noShowAgainLocalStorageKey = `${localStoragePrefix}_NoneFeeTooltip_noShowAgain`;
  let noShowAgain = Boolean(localStorage.getItem(noShowAgainLocalStorageKey));

  function onConfirmNotice() {
    if (noShowAgain) {
      localStorage.setItem(noShowAgainLocalStorageKey, 'true');
    }
    show = false;
  }
</script>

<TooltipModal title="Notice" isOpen={show}>
  <div slot="body" class="space-y-6">
    <!-- TODO: translations? -->
    <div class="text-center">
      Selecting <strong>None</strong> means that you'll require ETH on the receiving
      chain in otder to claim the bridged token. Pleas, come back later to manually
      claim.
    </div>

    <div class="text-left flex items-center">
      <input
        style:border-radius="0.5rem"
        type="checkbox"
        id="noShowAgain"
        bind:checked={noShowAgain}
        class="checkbox checkbox-secundary mr-2" />
      <label for="noShowAgain">Do not show this message again</label>
    </div>

    <div class="flex justify-center">
      <button
        class="confirm btn btn-accent btn-md btn-wide"
        on:click={onConfirmNotice}>
        Confirm
      </button>
    </div>
  </div>
</TooltipModal>

<style>
  .confirm {
    /* TODO: design needed for buttons */
    height: 54px;
  }
</style>
