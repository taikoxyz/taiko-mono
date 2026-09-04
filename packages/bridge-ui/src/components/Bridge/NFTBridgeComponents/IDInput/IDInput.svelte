<script lang="ts">
  import { createEventDispatcher, onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import InputBox from '$components/InputBox/InputBox.svelte';

  import { parseTokenIds } from './parseTokenIds';
  import { IDInputState as State } from './state';

  export let validIdNumbers: number[] = [];
  export let isDisabled = false;
  export let enteredIds: number[] = [];
  export let limit = 1;
  // export let state: State = State.DEFAULT;

  let typeClass = '';

  export const clearIds = () => {
    enteredIds = [];
    validIdNumbers = [];
    dispatch('inputValidation');
  };

  const dispatch = createEventDispatcher();

  let inputId = `input-${crypto.randomUUID()}`;

  function validateInput(idInput: EventTarget | number[] | null = null) {
    state = State.VALIDATING;

    let raw = '';
    if (idInput && idInput instanceof EventTarget) {
      raw = (idInput as HTMLInputElement).value;
    } else if (Array.isArray(idInput)) {
      raw = idInput.join(',');
    }

    const { ids, validIds, empty } = parseTokenIds(raw, limit);
    enteredIds = ids;
    validIdNumbers = validIds;

    // An empty field is neither valid nor an error: nothing has been entered yet
    if (empty) {
      state = State.DEFAULT;
      dispatch('inputValidation');
      return;
    }

    state = validIds.length > 0 ? State.VALID : State.INVALID;
    dispatch('inputValidation');
  }

  $: state = State.DEFAULT;

  $: typeClass = state === State.INVALID ? 'error' : '';

  onDestroy(() => {
    clearIds();
  });
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.token_id_input.label')}</label>
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder={$t('inputs.token_id_input.placeholder')}
      disabled={isDisabled}
      bind:value={enteredIds}
      on:input={(e) => validateInput(e.target)}
      class="withValidation w-full input-box py-6 pr-16 px-[26px] {typeClass} {$$props.class}" />
    {#if enteredIds && enteredIds.length > 0}
      <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clearIds}>
        <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
      </button>
    {/if}
  </div>
</div>
