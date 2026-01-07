<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { ImportStep, ReviewStep } from '$components/Bridge/FungibleBridgeComponents';
  import { ConfirmationStep, RecipientStep } from '$components/Bridge/SharedBridgeComponents';
  import { BridgeSteps, BridgingStatus } from '$components/Bridge/types';
  import WidgetNavigation from '$components/Bridge/WidgetBridge/WidgetNavigation.svelte';
  import WidgetStep from '$components/Bridge/WidgetBridge/WidgetStep.svelte';
  import WidgetStepper from '$components/Bridge/WidgetBridge/WidgetStepper.svelte';
  import { ConnectButton } from '$components/ConnectButton';
  import { account, connectedSmartContractWallet } from '$stores/account';

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  let recipientStepComponent: RecipientStep;
  let stepTitle: string;
  let stepDescription: string;
  let hasEnoughEth: boolean = false;
  let hasEnoughFundsToContinue: boolean = false;
  let exceedsQuota: boolean = false;
  let bridgingStatus: BridgingStatus;
  let needsManualReviewConfirmation: boolean;
  let needsManualRecipientConfirmation: boolean;

  $: needsManualRecipientConfirmation = $connectedSmartContractWallet;

  // Get padding from URL query parameter (defaults to 0, max 100)
  $: {
    const paddingParam = $page.url.searchParams.get('padding');
    const paddingNum = parseInt(paddingParam || '0', 10);
    padding = isNaN(paddingNum) ? 0 : Math.min(Math.max(paddingNum, 0), 100);
  }
  $: paddingStyle = `${padding}px`;

  let padding: number = 0;

  $: {
    const stepKey = BridgeSteps[activeStep].toLowerCase();
    if (activeStep === BridgeSteps.CONFIRM) {
      stepTitle = '';
      stepDescription = '';
    } else {
      stepTitle = $t(`bridge.title.fungible.${stepKey}`);
      stepDescription = $t(`bridge.description.fungible.${stepKey}`);
    }
  }
</script>

<svelte:head>
  <title>Taiko Bridge Widget</title>
</svelte:head>

{#if $account?.isConnected}
  <div class="flex flex-col justify-between w-full h-full" style="padding: {paddingStyle}">
    <!-- Connect button at the top -->
    <div class="flex justify-center">
      <ConnectButton connected={$account?.isConnected} />
    </div>

    <!-- Title and Description -->
    {#if stepTitle}
      <div class="text-center">
        <h2 class="text-xl font-bold">{stepTitle}</h2>
        {#if stepDescription}
          <p class="text-secondary-content mt-2">{stepDescription}</p>
        {/if}
      </div>
    {/if}

    <!-- Widget Stepper -->
    <WidgetStepper {activeStep}>
      <WidgetStep
        stepIndex={BridgeSteps.IMPORT}
        currentStepIndex={activeStep}
        isActive={activeStep === BridgeSteps.IMPORT}>{$t('bridge.step.import.title')}</WidgetStep>
      <WidgetStep
        stepIndex={BridgeSteps.REVIEW}
        currentStepIndex={activeStep}
        isActive={activeStep === BridgeSteps.REVIEW}>{$t('bridge.step.review.title')}</WidgetStep>
      <WidgetStep
        stepIndex={BridgeSteps.CONFIRM}
        currentStepIndex={activeStep}
        isActive={activeStep === BridgeSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</WidgetStep>
    </WidgetStepper>

    <!-- Bridge Step Content -->
    <div class="w-full px-4 overflow-hidden">
      {#if activeStep === BridgeSteps.IMPORT}
        <ImportStep bind:hasEnoughEth bind:exceedsQuota />
      {:else if activeStep === BridgeSteps.REVIEW}
        <ReviewStep
          on:editTransactionDetails={() => (activeStep = BridgeSteps.RECIPIENT)}
          on:goBack={() => (activeStep = BridgeSteps.IMPORT)}
          bind:needsManualReviewConfirmation
          bind:hasEnoughEth
          bind:hasEnoughFundsToContinue />
      {:else if activeStep === BridgeSteps.RECIPIENT}
        <RecipientStep bind:this={recipientStepComponent} bind:hasEnoughEth bind:needsManualRecipientConfirmation />
      {:else if activeStep === BridgeSteps.CONFIRM}
        <ConfirmationStep bind:bridgingStatus />
      {/if}
    </div>

    <!-- Navigation -->
    <WidgetNavigation
      bind:activeStep
      bind:exceedsQuota
      bind:hasEnoughFundsToContinue
      {bridgingStatus}
      bind:needsManualReviewConfirmation
      bind:needsManualRecipientConfirmation />
  </div>
{:else}
  <div class="flex flex-col justify-center items-center w-full h-full gap-6" style="padding: {paddingStyle}">
    <!-- Title and Description -->
    {#if stepTitle}
      <div class="text-center">
        <h2 class="text-xl font-bold">{stepTitle}</h2>
        {#if stepDescription}
          <p class="text-secondary-content mt-2">{stepDescription}</p>
        {/if}
      </div>
    {/if}

    <!-- Connect button -->
    <div class="flex justify-center">
      <ConnectButton connected={$account?.isConnected} />
    </div>
  </div>
{/if}
