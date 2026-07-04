import { z, defineCollection } from "astro:content";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";

export const collections = {
  docs: defineCollection({
    schema: docsSchema({
      extend: z.object({
        description: z
          .string()
          .max(160, { message: "Must be 160 characters or less." })
          .optional(),
        banner: z.object({ content: z.string() }).default({
          content: 'Taiko Hekla will be sunsetting with the deprecation of the Holesky Testnet on September 30th, 2025. In it\'s place, we are deploying the Taiko Hoodi testnet with Ethereum Hoodi as L1. Please find network details <a href="https://taiko.mirror.xyz/bmdcp5YfzInHvZonNp7WmVmiMqIJOCtVkmHdC8aANP0">here</a>.',
          }),
      }),
    }),
  }),
  i18n: defineCollection({ type: "data", schema: i18nSchema() }),
};
