<script>
  import TooltipModal from '../TooltipModal.svelte';

  export let show = false;
</script>

<TooltipModal title="Processing Fees" bind:isOpen={show}>
  <span slot="body">
    <div class="text-left">
      The amount you pay the relayer to process your bridge message on the
      destination chain.
      <br /><br />
      <ul class="list-disc ml-4">
        <li>
          <strong>Recommended</strong>: The recommended fee is the lowest fee
          that will get your transaction processed in a reasonable amount of
          time.
        </li>
        <li>
          <strong>Custom</strong>: You can set a custom fee for the relayer to
          incentivize them to prioritize your request. A lower fee may result in
          longer processing time.
        </li>
        <li>
          <strong>None</strong>: You can select no fee if you want to come back
          here and claim the bridged asset yourself.
        </li>
      </ul>
    </div>
  </span>
</TooltipModal>
