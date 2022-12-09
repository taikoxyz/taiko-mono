<script lang="ts">
  export let memo: string = "";
  let showMemo: boolean = true;

  function onChange(e: any) {
    showMemo = e.target.checked;
  }
</script>

<div class="form-control mb-2">
  <label class="label cursor-pointer">
    <span class="label-text">Memo</span>
    <input
      type="checkbox"
      class="toggle"
      on:change={onChange}
      bind:checked={showMemo}
    />
  </label>

  {#if showMemo}
    <input
      type="text"
      placeholder="Memo..."
      class="input input-primary bg-dark-4 input-sm md:input-md w-full"
      name="memo"
      bind:value={memo}
    />
  {/if}
</div>
