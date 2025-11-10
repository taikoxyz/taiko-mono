<script lang="ts">
  import { t } from 'svelte-i18n';

  import { ImportStep, ReviewStep } from '../FungibleBridgeComponents';
  import { ConfirmationStep } from '../SharedBridgeComponents';
  import { BridgeSteps, BridgingStatus } from '../types';
  import WidgetNavigation from './WidgetNavigation.svelte';
  import WidgetStep from './WidgetStep.svelte';
  import WidgetStepper from './WidgetStepper.svelte';

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;

  let stepTitle: string;
  let stepDescription: string;

  let hasEnoughEth: boolean = false;
  let hasEnoughFundsToContinue: boolean = false;
  let exceedsQuota: boolean = false;
  let bridgingStatus: BridgingStatus;
  let needsManualReviewConfirmation: boolean;

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

<div class="gap-0 w-full">
  <!-- Widget Stepper without glow effects -->
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

  <!-- No Card wrapper, just content with padding -->
  <div class="mt-[32px] w-full">
    {#if stepTitle}
      <div class="mb-[16px] text-center">
        <h2 class="text-xl font-bold">{stepTitle}</h2>
        {#if stepDescription}
          <p class="text-secondary-content mt-2">{stepDescription}</p>
        {/if}
      </div>
    {/if}

    <div class="space-y-[30px]">
      {#if activeStep === BridgeSteps.IMPORT}
        <!-- IMPORT STEP -->
        <ImportStep bind:hasEnoughEth bind:exceedsQuota />
      {:else if activeStep === BridgeSteps.REVIEW}
        <!-- REVIEW STEP -->
        <ReviewStep
          on:goBack={() => (activeStep = BridgeSteps.IMPORT)}
          bind:needsManualReviewConfirmation
          bind:hasEnoughEth
          bind:hasEnoughFundsToContinue />
      {:else if activeStep === BridgeSteps.CONFIRM}
        <!-- CONFIRM STEP -->
        <ConfirmationStep bind:bridgingStatus />
      {/if}
      <!-- NAVIGATION -->
      <WidgetNavigation
        bind:activeStep
        bind:exceedsQuota
        bind:hasEnoughFundsToContinue
        {bridgingStatus}
        bind:needsManualReviewConfirmation />
    </div>
  </div>
</div>
