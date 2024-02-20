<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';

  let modalOpen: boolean;

  function closeModal() {
    modalOpen = false;
  }

  function confirmModal() {
    localStorage.setItem('accepted-modal', 'true');

    closeModal();
  }

  onMount(() => {
    modalOpen = localStorage.getItem('accepted-modal') !== 'true';
  });
</script>

<dialog class="modal modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative md:rounded-[20px] bg-white space-y-[25px] md:w-[435px] m-auto">
    <div class="w-full space-y-[30px]">
      <Icon type="welcome-icon" class="w-[100px] h-[100px] mx-auto" />
      <h1 class="!text-black text-4xl font-bold">{$t('bridge.welcome_modal.title')}</h1>
      <p class="body-regular text-black text-center mb-3">
        <!-- eslint-disable-next-line svelte/no-at-html-tags -->
        {@html $t('bridge.welcome_modal.body')}
      </p>

      <div class="f-row w-full space-x-[25px]">
        <ActionButton priority="primary" class="w-full" on:click={confirmModal}>
          {$t('bridge.welcome_modal.confirm')}
        </ActionButton>
      </div>
      <div class="w-full text-center">
        <a href="https://www.taiko.xyz" target="_blank" class="link">{$t('bridge.welcome_modal.link')} </a>
      </div>
    </div>
  </div>
</dialog>
