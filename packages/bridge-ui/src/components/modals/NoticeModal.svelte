<script lang="ts" context="module">
  import { EventEmitter } from 'events';

  type OpenArgs = {
    name?: string;
    title?: string;
    onConfirm?: (noShowAgain: boolean) => void;
  };

  const emitter = new EventEmitter();

  // API
  export function noticeOpen(args: OpenArgs) {
    emitter.emit('open', args);
  }
</script>

<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
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

  /**
   * Checks if the user has opted out of seeing this message
   * based on a namespace, which by default is the name of the modal.
   */
  function checkLocalStorage(ns: string = name) {
    noShowAgainLocalStorageKey = `${localStoragePrefix}_${ns}_noShowAgain`;

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

  function onOpen({
    name: _name = name,
    title: _title = title,
    onConfirm: _onConfirm = onConfirm,
  }: OpenArgs) {
    // Sets dynamically modal's state
    name = _name;
    title = _title;
    onConfirm = _onConfirm;

    // Make sure the user hasn't opted out of seeing this message
    // based on the name passed in as argument (E.g. tx hash)
    checkLocalStorage(name);

    if (noShowAgainStorage) {
      // We don't show the modal, just to continue by running onConfirm.
      closeAndContinue();
    } else {
      // Show the modal
      show = true;
    }
  }

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
    emitter.on('open', onOpen);
    checkLocalStorage();
  });

  onDestroy(() => {
    emitter.off('open', onOpen);
  });

  // It could happen that the modal is being opened via prop, but the user
  // already opted out of seeing the message (we have localStorage set).
  // In that case, we still want to run the onConfirm callback, which contains
  // the next steps in the flow, also setting the prop back to false
  // (could be bound to the parent)
  // TODO: use promises here. API to open the modal should return a promise
  //       which resolves when the user clicks on confirm. If noShowAgain is set
  //       to true, the promise should resolve immediately.
  // $: if (show && noShowAgainStorage) {
  //   closeAndContinue();
  // }
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
