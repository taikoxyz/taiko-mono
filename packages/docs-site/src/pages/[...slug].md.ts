import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export const prerender = true;

export async function getStaticPaths() {
  const entries = await getCollection("docs");

  return entries.map((entry) => ({
    params: { slug: entry.slug },
    props: { id: entry.id },
  }));
}

export const GET: APIRoute = async ({ props }) => {
  const { id } = props as { id: string };
  const sourcePath = join(process.cwd(), "src/content/docs", id);
  const markdown = await readFile(sourcePath, "utf-8");

  return new Response(markdown, {
    headers: {
      "Content-Type": "text/markdown; charset=utf-8",
      "Cache-Control": "public, max-age=0, must-revalidate",
    },
  });
};
