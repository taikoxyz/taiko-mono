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
        content: 'All Taiko Alethia Node Runners: Protocol upgrade on Feb 13th, upgrade needed. Please ensure your nodes are using the software tags listed in the announcement! Click <a href="https://discord.com/channels/984015101017346058/984087180739768331/1336962654425714688">here</a> for more info',
        }),
      }),
    }),
  }),
  i18n: defineCollection({ type: "data", schema: i18nSchema() }),
};
