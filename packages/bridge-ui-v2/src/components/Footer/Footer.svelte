<script lang="ts">
  import { Footer, P } from 'flowbite-svelte'

  const year = new Date().getFullYear()
</script>

<Footer>
  <P size="base">
    Made with ❤️ by
    <a href="https://taiko.xyz/" target="_blank" rel="noopener noreferrer">Taiko</a>,
    {year}
  </P>
</Footer>
