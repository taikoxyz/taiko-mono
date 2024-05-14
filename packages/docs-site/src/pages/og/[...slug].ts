import { getCollection } from "astro:content";
import { OGImageRoute } from "astro-og-canvas";

const entries = await getCollection("docs");
const pages = Object.fromEntries(entries.map(({ data, id }) => [id, { data }]));

// See https://github.com/delucis/astro-og-canvas for the full API
export const { getStaticPaths, GET } = OGImageRoute({
  pages,
  param: "slug",
  getImageOptions: (_path, page: (typeof pages)[number]) => {
    return {
      title: page.data.title,
      description: page.data.description ?? "",
      logo: {
        path: "./src/assets/taiko-og-logo.png",
      },
      bgGradient: [
        [15, 2, 15],
        [58, 12, 36],
        [132, 24, 75],
      ],
      border: {
        width: 30,
        color: [232, 24, 153],
      },
      fonts: [
        "./src/fonts/ClashGrotesk-Medium.ttf",
        "./src/fonts/PublicSans-Light.ttf",
      ],
      font: {
        title: {
          families: ["Clash Grotesk"],
        },
        description: {
          families: ["Public Sans"],
        },
      },
    };
  },
});
