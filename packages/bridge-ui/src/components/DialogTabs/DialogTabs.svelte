<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import DialogTab from './DialogTab.svelte';

  export let tabs: { id: string; title: string }[];
  export let activeTab: string;
  const dispatch = createEventDispatcher();

  function setActiveTab(tabId: string) {
    if (activeTab !== tabId) {
      activeTab = tabId;
      dispatch('change', { tabId });
    }
  }
</script>

<div role="tablist" class="tabs">
  {#each tabs as tab}
    <DialogTab active={tab.id === activeTab} on:click={() => setActiveTab(tab.id)}>
      {tab.title}
    </DialogTab>
  {/each}
</div>
