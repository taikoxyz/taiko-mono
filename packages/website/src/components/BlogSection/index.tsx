import React from "react";

const posts = [
  {
    title: "Taiko Is Fully Open Source",
    href: "https://mirror.xyz/labs.taiko.eth/31vzkwgNaKNrze0oIv_wTKCw6Tha8OYQ6ffrquS3XUg",
    category: { name: "Article" },
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
  {
    title: "Community Update #2",
    href: "https://mirror.xyz/labs.taiko.eth/JdMMaBLOtK3Hk_SGZy_c9WFEnn1jDtOpfeXVHxJAtMU",
    category: { name: "Community Update" },
    description:
      "Hey everyone 👋, we want to update you on the progress we’ve made since our last community update.",
    date: "Nov 24, 2022",
    datetime: "2022-11-24",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/hcstqDARznViEZh0CXJ-T.png?height=960&width=1920&h=960&w=1920&auto=compress",
    readingTime: "2 min",
    author: {
      name: "Taiko Labs",
      imageUrl: "./img/Taiko_Logo_Fluo-on-Black.svg",
    },
  },
  {
    title: "The Type 1 ZK-EVM",
    href: "https://mirror.xyz/labs.taiko.eth/w7NSKDeKfJoEy0p89I9feixKfdK-20JgWF9HZzxfeBo",
    category: { name: "Article" },
    description:
      "Taiko is building a Type 1 (Ethereum-equivalent) ZK-EVM. What benefits come from using a Type 1 ZK-EVM? Let’s learn together in this post.",
    date: "Nov 15, 2022",
    datetime: "2022-11-15",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/3Dn5g9BMMfwPnMOi-IIEK.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "6 min",
    author: {
      name: "Taiko Labs",
      imageUrl: "./img/Taiko_Logo_Fluo-on-Black.svg",
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
          <h2 className="text-3xl font-bold tracking-tight text-neutral-900 sm:text-4xl dark:text-neutral-100">
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
              <div className="flex flex-1 flex-col justify-between bg-white p-6 dark:bg-neutral-700">
                <div className="flex-1">
                  <div className="text-sm font-medium">
                    <a>{post.category.name}</a>
                  </div>
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
