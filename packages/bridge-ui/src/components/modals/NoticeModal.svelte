<script lang="ts">
  import { onMount } from 'svelte';
  import { localStoragePrefix } from '../../config';
  import Button from '../buttons/Button.svelte';
  import Modal from './Modal.svelte';

  export let show = false;
  export let name = 'NoticeModal';
  export let title = 'Notice';
  export let onConfirm: (noShowAgain: boolean) => void = null;

  let noShowAgainLocalStorageKey = `${localStoragePrefix}_${name}_noShowAgain`;
  let noShowAgainStorage = false;
  let noShowAgainCheckbox = false;

  onMount(() => {
    // Has the user opted out of seeing this message?
    noShowAgainStorage = Boolean(
      localStorage.getItem(noShowAgainLocalStorageKey),
    );
    noShowAgainCheckbox = noShowAgainStorage;
  });

  function onConfirmNotice() {
    if (noShowAgainCheckbox) {
      // If checkbox is checked, store it in localStorage so
      // the user doesn't see the message again.
      localStorage.setItem(noShowAgainLocalStorageKey, 'true');
      noShowAgainStorage = true;
    }

    show = false;

    onConfirm?.(noShowAgainCheckbox);
  }
</script>

<!-- 
  TODO: we might want noShowAgainStorage to be dynamic, otherwise
        the user will have to refresh the page to see the message again
        if they delete the localStorage entry.
-->
<Modal {title} isOpen={show && !noShowAgainStorage} showXButton={false}>
  <div
    class="
      flex
      w-full
      flex-col
      justify-between
      space-y-6
    ">
    <slot />

    <div class="text-left flex items-center">
      <input
        style:border-radius="0.5rem"
        type="checkbox"
        id="noShowAgain_{name}"
        bind:checked={noShowAgainCheckbox}
        class="checkbox checkbox-secundary mr-2" />
      <label for="noShowAgain_{name}">Do not show this message again</label>
    </div>

    <div class="flex justify-center">
      <Button type="accent" on:click={onConfirmNotice}>Confirm</Button>
    </div>
  </div>
</Modal>
