<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { classNames } from '$lib/util/classNames';

  const dispatch = createEventDispatcher();

  type IStep = 'eligible' | 'non-eligible' | 'success';
  export let step: IStep = 'non-eligible';
  export let disabled = true;

  $: wrapperClasses = classNames(
    'flex',
    'flex-col',
    'items-center',
    'justify-center',
    'w-full',
    'h-full',
    'text-center',
  );

  $: iconClasses = classNames();
  $: titleClasses = classNames('text-[45px]/[52px]', 'font-clash-grotesk', 'font-[500]', 'my-6');
  $: textClasses = classNames('text-[16px]/[24px]', 'text-content-secondary');

  const icons: Record<IStep, string> = {
    eligible: '/img/eligible.svg',
    'non-eligible': '/img/non-eligible.svg',
    success: '/img/success.svg',
  };

  const titles: Record<IStep, string> = {
    eligible: "Congratulations, you're eligible!",
    'non-eligible': "Sorry, you're not eligible",
    success: 'You got it!',
  };

  const texts: Record<IStep, string> = {
    eligible: 'You are eligible to mint Snaefell NFT',
    'non-eligible': 'Unfortunately, you were not an Alpha-1 testnet contributors.',
    success: 'You’ve successfully minted your Snaefell NFT. Thank you for being here from the start!',
  };

  const buttonClasses = classNames('mt-6 max-h-[56px]');
</script>

<div class={wrapperClasses}>
  <div class={iconClasses}>
    <img src={icons[step]} alt={step} />
  </div>

  <div class={titleClasses}>
    {titles[step]}
  </div>

  <div class={textClasses}>
    {texts[step]}
  </div>

  <ActionButton
    on:click={async () => {
      dispatch('click');
    }}
    priority="primary"
    {disabled}
    class={buttonClasses}
    onPopup>
    {#if step === 'success'}
      {$t('buttons.view')}
    {:else}
      {$t('buttons.proceedToMint')}
    {/if}
  </ActionButton>
</div>
