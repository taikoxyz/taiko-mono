import type { Metadata } from "next";

import { Page } from "@/components/Page";
import { Relayer } from "@/components/Relayer";

/**
 * /relayer route — "Manual Claim". Mirrors src/routes/relayer/+page.svelte:
 *   <svelte:head><title>Taiko Bridge | Manual Claim</title></svelte:head>
 *   <Page><Relayer /></Page>
 */
export const metadata: Metadata = {
  title: "Taiko Bridge | Manual Claim",
};

export default function RelayerPage() {
  return (
    <Page>
      <Relayer />
    </Page>
  );
}
