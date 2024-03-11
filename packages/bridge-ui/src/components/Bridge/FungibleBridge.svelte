<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { Step, Stepper } from '$components/Stepper';

  import { ImportStep, ReviewStep, StepNavigation } from './FungibleBridgeComponents';
  import { ConfirmationStep, RecipientStep } from './SharedBridgeComponents';
  import { BridgeSteps, BridgingStatus } from './types';

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  let recipientStepComponent: RecipientStep;

  let stepTitle: string;
  let stepDescription: string;
  let hasEnoughEth: boolean = false;
  let bridgingStatus: BridgingStatus;

  const handleTransactionDetailsClick = () => (activeStep = BridgeSteps.RECIPIENT);
  const handleBackClick = () => (activeStep = BridgeSteps.IMPORT);

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

<div class=" gap-0 w-full md:w-[524px]">
  <Stepper {activeStep}>
    <Step stepIndex={BridgeSteps.IMPORT} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.IMPORT}
      >{$t('bridge.step.import.title')}</Step>
    <Step stepIndex={BridgeSteps.REVIEW} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.REVIEW}
      >{$t('bridge.step.review.title')}</Step>
    <Step stepIndex={BridgeSteps.CONFIRM} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.CONFIRM}
      >{$t('bridge.step.confirm.title')}</Step>
  </Stepper>

  <Card class="md:mt-[32px] w-full md:w-[524px]" title={stepTitle} text={stepDescription}>
    <div class="space-y-[30px] mt-[30px]">
      {#if activeStep === BridgeSteps.IMPORT}
        <!-- IMPORT STEP -->
        <ImportStep bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.REVIEW}
        <!-- REVIEW STEP -->
        <ReviewStep
          on:editTransactionDetails={handleTransactionDetailsClick}
          on:goBack={handleBackClick}
          bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.RECIPIENT}
        <!-- RECIPIENT STEP -->
        <RecipientStep bind:this={recipientStepComponent} bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.CONFIRM}
        <!-- CONFIRM STEP -->
        <ConfirmationStep bind:bridgingStatus />
      {/if}
      <!-- NAVIGATION -->
      <StepNavigation bind:activeStep {bridgingStatus} />
    </div>
  </Card>
</div>
