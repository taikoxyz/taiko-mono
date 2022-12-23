import React from "react";

const posts = [
  {
    title: "Rollup Decentralization",
    href: "https://mirror.xyz/labs.taiko.eth/sxR3iKyD-GvTuyI9moCg4_ggDI4E4CqnvhdwRq5yL0A",
    description:
      "This post explores definitions and high-level ideas of rollup decentralization. It does not cover deep technical detail about decentralizing rollup implementations.",
    date: "Dec 20, 2022",
    datetime: "2022-12-20",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/NTeYUqYqHo4NqrRGJHvfO.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "9 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?v=4",
    },
  },
  {
    title: "Taiko Community Update #3",
    href: "https://mirror.xyz/labs.taiko.eth/8E_7fjFNFjY7dIGAppqaNyuM-1QXp78AekXMA9--q6o",
    description:
      "Taiko Community Update #3 has arrived 🥁 We do these to provide transparency into the progress we’ve made since our last community update.",
    date: "Dec 08, 2022",
    datetime: "2022-12-08",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/FaV63QrEdHnxGHdHMFw8p.png?height=960&width=1920&h=960&w=1920&auto=compress",
    readingTime: "2 min",
    author: {
      name: "d1onys1us",
      imageUrl: "https://avatars.githubusercontent.com/u/13951458?v=4",
    },
  },
  {
    title: "Taiko Is Fully Open Source",
    href: "https://mirror.xyz/labs.taiko.eth/31vzkwgNaKNrze0oIv_wTKCw6Tha8OYQ6ffrquS3XUg",
    description:
      'Taiko is fully open source -- you can view all the code on our GitHub. By "open source" we mean free to see the source and modify it.',
    date: "Dec 01, 2022",
    datetime: "2022-12-01",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/h-KI5JueXbaUalAJeiMvA.png?height=1024&width=2048&h=1024&w=2048&auto=compress",
    readingTime: "4 min",
    author: {
      name: "d1onys1us",
      imageUrl: "https://avatars.githubusercontent.com/u/13951458?v=4",
    },
  },
];
/**
 * @returns Blog section displaying latest Taiko blog posts from Mirror
 */
export default function BlogSection(): JSX.Element {
  return (
    <div className="relative bg-neutral-50 px-4 pt-16 pb-20 sm:px-6 lg:px-8 lg:pt-24 lg:pb-28 dark:bg-neutral-800">
      <div className="absolute inset-0">
        <div className="h-1/3 bg-white sm:h-2/3 dark:bg-[#1B1B1D]" />
      </div>
      <div className="relative mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="font-oxanium text-3xl font-bold tracking-tight text-neutral-900 sm:text-4xl dark:text-neutral-100">
            Latest Blog Posts
          </h2>
          <div className="mx-auto mt-3 max-w-2xl text-xl text-neutral-500 sm:mt-4 dark:text-neutral-300">
            Check out the full blog at{" "}
            <a href="https://mirror.xyz/labs.taiko.eth" target="_blank">
              mirror.xyz
            </a>
          </div>
        </div>
        <div className="mx-auto mt-12 grid max-w-lg gap-5 lg:max-w-none lg:grid-cols-3">
          {posts.map((post) => (
            <div
              key={post.title}
              className="flex flex-col overflow-hidden rounded-lg shadow-lg"
            >
              <div className="flex-shrink-0">
                <a href={post.href} target="_blank">
                  <img
                    className="h-54 w-full object-cover"
                    src={post.imageUrl}
                    alt=""
                  />
                </a>
              </div>
              <div className="flex flex-1 flex-col justify-between bg-white p-6 dark:bg-neutral-800">
                <div className="flex-1">
                  <a href={post.href} target="_blank" className="mt-2 block">
                    <div className="text-xl font-semibold text-neutral-900 dark:text-neutral-200">
                      {post.title}
                    </div>
                    <div className="mt-3 text-base text-neutral-500 dark:text-neutral-300">
                      {post.description}
                    </div>
                  </a>
                </div>
                <div className="mt-6 flex items-center">
                  <div className="flex-shrink-0">
                    <a>
                      <span className="sr-only">{post.author.name}</span>
                      <img
                        className="h-10 w-10 rounded-full"
                        src={post.author.imageUrl}
                        alt=""
                      />
                    </a>
                  </div>
                  <div className="ml-3">
                    <div className="text-sm font-medium text-neutral-900">
                      <a>{post.author.name}</a>
                    </div>
                    <div className="flex space-x-1 text-sm text-neutral-500 dark:text-neutral-400">
                      <time dateTime={post.datetime}>{post.date}</time>
                      <span aria-hidden="true">&middot;</span>
                      <span>{post.readingTime} read</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
