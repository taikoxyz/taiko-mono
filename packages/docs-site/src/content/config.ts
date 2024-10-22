import { z, defineCollection } from "astro:content";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";

export const collections = {
  docs: defineCollection({
    schema: docsSchema({
      extend: z.object({
        description: z
          .string()
          .max(160, { message: "Must be 160 characters or less." }).optional(),
      // banner: z.object({ content: z.string() }).default({
      //   content: '',
      //   }),
      }),
    }),
  }),
  i18n: defineCollection({ type: "data", schema: i18nSchema() }),
};
