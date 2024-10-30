import { z, defineCollection } from "astro:content";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";

export const collections = {
  docs: defineCollection({
    schema: docsSchema({
      extend: z.object({
        description: z
          .string()
          .max(160, { message: "Must be 160 characters or less." }).optional(),
      banner: z.object({ content: z.string() }).default({
        content: 'All Mainnet Node Runners: Protocol upgrade on Oct 31st in preparation for Ontake fork, upgrade needed. Please ensure your nodes are using the software tags listed in the announcement! Click <a href="https://taiko.mirror.xyz/OJA4SwCqHjF32Zz0GkNJvnHWlsRYzdJ6hcO9FXVOpLs">here</a> for more info',
        }),
      }),
    }),
  }),
  i18n: defineCollection({ type: "data", schema: i18nSchema() }),
};
