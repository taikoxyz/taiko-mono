<script lang="ts">
  import { t } from 'svelte-i18n';

  import IconFlipper from '$components/Icon/IconFlipper.svelte';
  import { MessageStatus } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { classNames } from '$libs/util/classNames';
  import { uid } from '$libs/util/uid';

  export let selectedStatus: MessageStatus | null = null;

  let flipped = false;
  let menuOpen = false;
  let uuid = `dropdown-${uid()}`;

  let iconFlipperComponent: IconFlipper;

  const closeMenu = () => {
    menuOpen = false;
    flipped = false;
  };

  const options = [
    { value: null, label: $t('transactions.filter.all') },
    { value: MessageStatus.NEW, label: $t('transactions.filter.processing') },
    { value: MessageStatus.RETRIABLE, label: $t('transactions.filter.retry') },
    { value: MessageStatus.DONE, label: $t('transactions.filter.claimed') },
    { value: MessageStatus.FAILED, label: $t('transactions.filter.failed') },
  ];

  const toggleMenu = () => {
    menuOpen = !menuOpen;
    flipped = !flipped;
  };

  const select = (option: (typeof options)[0]) => {
    selectedStatus = option.value;
    closeMenu();
  };

  $: menuClasses = classNames(
    'menu absolute right-0 w-[210px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10  box-shadow-small',
    menuOpen ? 'visible opacity-100' : 'invisible opacity-0',
  );
</script>

<div class="relative">
  <button
    aria-haspopup="listbox"
    aria-expanded={menuOpen}
    class="f-between-center w-[210px] min-h-[36px] max-h-[36px] px-6 bg-neutral border-0 shadow-none outline-none rounded-[6px]"
    on:click|stopPropagation={toggleMenu}>
    <span class="text-primary-content font-bold">
      {selectedStatus !== null
        ? options.find((option) => option.value === selectedStatus)?.label
        : $t('transactions.filter.all')}
    </span>
    <IconFlipper
      bind:flipped
      bind:this={iconFlipperComponent}
      iconType1="chevron-left"
      iconType2="chevron-down"
      selectedDefault="chevron-left"
      size={15}
      noEvent />
  </button>
  {#if menuOpen}
    <ul
      role="listbox"
      class={menuClasses}
      use:closeOnEscapeOrOutsideClick={{ enabled: menuOpen, callback: () => closeMenu, uuid: uuid }}>
      {#each options as option (option.value)}
        <li
          role="option"
          aria-selected={option.value === selectedStatus}
          tabindex="0"
          class="flex items-center h-[56px] px-3 cursor-pointer rounded-[6px]"
          on:click={() => select(option)}
          on:keydown={() => select(option)}>
          <span class="flex w-full h-[56px] text-primary-content font-bold">{option.label}</span>
        </li>
      {/each}
    </ul>
  {/if}
</div>
