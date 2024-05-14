<script lang="ts">
  import { json } from 'svelte-i18n';

  import { default as CollapsibleSection } from './Collapsible.section.svelte';

  $: faqOptions = $json('content.sections.faq.entries') as {
    title: string;
    text: string;
  }[];
</script>

<CollapsibleSection options={faqOptions.map((o) => ({ ...o, visible: false }))} />
