<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { ImportStep, ReviewStep } from '$components/Bridge/FungibleBridgeComponents';
  import { ConfirmationStep } from '$components/Bridge/SharedBridgeComponents';
  import { BridgeSteps, BridgingStatus } from '$components/Bridge/types';
  import WidgetNavigation from '$components/Bridge/WidgetBridge/WidgetNavigation.svelte';
  import WidgetStep from '$components/Bridge/WidgetBridge/WidgetStep.svelte';
  import WidgetStepper from '$components/Bridge/WidgetBridge/WidgetStepper.svelte';
  import { ConnectButton } from '$components/ConnectButton';
  import { account } from '$stores/account';

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  let stepTitle: string;
  let stepDescription: string;
  let hasEnoughEth: boolean = false;
  let hasEnoughFundsToContinue: boolean = false;
  let exceedsQuota: boolean = false;
  let bridgingStatus: BridgingStatus;
  let needsManualReviewConfirmation: boolean;

  // Get padding from URL query parameter (defaults to 0)
  $: padding = $page.url.searchParams.get('padding') || '0';
  $: paddingStyle = `${padding}px`;

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
    <div class="w-full">
      {#if activeStep === BridgeSteps.IMPORT}
        <ImportStep bind:hasEnoughEth bind:exceedsQuota />
      {:else if activeStep === BridgeSteps.REVIEW}
        <ReviewStep
          on:goBack={() => (activeStep = BridgeSteps.IMPORT)}
          bind:needsManualReviewConfirmation
          bind:hasEnoughEth
          bind:hasEnoughFundsToContinue />
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
      bind:needsManualReviewConfirmation />
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
