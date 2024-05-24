<script>
  import { t } from 'svelte-i18n';
  const currentYear = new Date().getFullYear();
</script>

<div class={$$props.class}>
  {$t('content.sections.footer.copyright', { values: { year: currentYear } })}
</div>
