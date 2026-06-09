import { Bridge } from "@/components/Bridge";
import { Page } from "@/components/Page";

/**
 * Root route — mirrors src/routes/+page.svelte:
 *   <svelte:head><title>Taiko Bridge</title></svelte:head>
 *   <Page><Bridge /></Page>
 *
 * The "Taiko Bridge" title is the layout's default `metadata.title`, so this
 * route needs no per-page metadata override. Server component that renders the
 * client <Bridge /> feature inside the presentational <Page /> wrapper.
 */
export default function BridgePage() {
  return (
    <Page>
      <Bridge />
    </Page>
  );
}
