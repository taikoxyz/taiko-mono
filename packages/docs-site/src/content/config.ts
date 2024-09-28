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
        content: 'All Hekla Node Runners: Imminent Ontake fork Sep 30th, upgrade needed. Please update your provers to raiko 1.2.0! Click <a href="https://discord.com/channels/984015101017346058/984087180739768331/1284040980084817931">here</a> for more info',
        }),
      }),
    }),
  }),
  i18n: defineCollection({ type: "data", schema: i18nSchema() }),
};
