<script lang="ts">
  import { onMount } from 'svelte';

  import type { NoticeModalOpenMethod } from '../domain/modal';
  import Button from './Button.svelte';
  import Modal from './Modal.svelte';

  const STORAGE_PREFIX = 'notice-modal';

  export let show = false;
  export let name = 'NoticeModal';
  export let title = 'Notice';
  export let onConfirm: (noShowAgain: boolean) => void = null;

  let noShowAgainLocalStorageKey = `${STORAGE_PREFIX}-${name}-noShowAgain`;
  let noShowAgainStorage = false;
  let noShowAgainCheckbox = false;

  /**
   * Checks if the user has opted out of seeing this message
   * based on a namespace, which by default is the name of the modal.
   */
  function checkLocalStorage(ns: string = name) {
    noShowAgainLocalStorageKey = `${STORAGE_PREFIX}-${ns}-noShowAgain`;

    noShowAgainStorage = Boolean(
      localStorage.getItem(noShowAgainLocalStorageKey),
    );

    // Check the checkbox control if the user has opted out.
    noShowAgainCheckbox = noShowAgainStorage;
  }

  function closeAndContinue() {
    show = false;
    onConfirm?.(noShowAgainCheckbox);
  }

  /**
   * Expose this method in case we want to open the modal
   * via API:
   *    <NoticeModal bind:this={noticeModal} />
   *    noticeModal.open({ name, title, onConfirm })
   */
  export const open: NoticeModalOpenMethod = ({
    name: _name = name,
    title: _title = title,
    onConfirm: _onConfirm = onConfirm,
  }) => {
    // Sets dynamically modal's state
    name = _name;
    title = _title;
    onConfirm = _onConfirm;

    // Make sure the user hasn't opted out of seeing this message
    // based on the name passed in as argument (E.g. tx hash)
    checkLocalStorage(name);

    if (noShowAgainStorage) {
      // We don't show the modal, just continue by running onConfirm.
      closeAndContinue();
    } else {
      // Show the modal
      show = true;
    }
  };

  function onConfirmNotice() {
    if (noShowAgainCheckbox) {
      // If checkbox is checked, store it in localStorage so
      // the user doesn't see the message again.
      localStorage.setItem(noShowAgainLocalStorageKey, 'true');
      noShowAgainStorage = true;
    }

    closeAndContinue();
  }

  onMount(() => {
    checkLocalStorage();
  });
</script>

<Modal {title} isOpen={show && !noShowAgainStorage} showXButton={false}>
  <div
    class="
      flex
      w-full
      flex-col
      justify-between
      space-y-6
    ">
    <slot {open} />

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
