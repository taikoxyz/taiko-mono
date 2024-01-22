<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import CombinedChainSelector from '$components/ChainSelectors/CombinedChainSelector.svelte';
  import { Step, Stepper } from '$components/Stepper';

  import ImportStep from './BridgeSteps/ImportStep/ImportStep.svelte';
  import StepNavigation from './BridgeSteps/StepNavigation/StepNavigation.svelte';
  import { BridgeSteps } from './types';

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;

  // $: displayL1Warning =
  //   slowL1Warning && $destinationChain?.id && chainConfig[$destinationChain.id].type === LayerType.L1;
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

  <Card
    class="md:mt-[32px] w-full md:w-[524px]"
    title={$t('bridge.title.default')}
    text={$t('bridge.description.default')}>
    <div class="space-y-[30px] mt-[30px]">
      <CombinedChainSelector />
      <div class="space-y-[30px]">
        {#if activeStep === BridgeSteps.IMPORT}
          <ImportStep />
        {/if}
        <!-- {#if displayL1Warning}
        <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
      {/if} -->
      </div>

      <StepNavigation bind:activeStep />
    </div>
  </Card>
</div>
