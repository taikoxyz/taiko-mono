const posts = [
  {
    title: "ZK-Roller-Coaster #3",
    href: "https://taiko.mirror.xyz/tg6eYqbf2qL_QVX9NXhBB4nduOir-3RGkS4M_obYrRI",
    description:
      "This is the 3rd edition of ZK-Roller-Coaster where we track and investigate the most exciting, meaningful, and crazy ZK-stuff of the prior two weeks.",
    date: "Apr 22, 2023",
    datetime: "2023-04-22",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/UA6Tx4uMB6qMYU3p38Dpt.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "4 min",
    author: {
      name: "Lisa A.",
      imageUrl: "https://avatars.githubusercontent.com/u/106527861?v=4",
    },
  },
  {
    title: "What are ZK-SNARKs and how they work",
    href: "https://taiko.mirror.xyz/9kGUby8h_dyu-t8jcPkDADfbWUMJw3mlGxvZAZk9sV0",
    description:
      "An exploration into ZK-SNARKs with a focus on the PLONKish variety: commitment schemes, interactive oracle proofs, Fiat-Shamir, and how it all ties together.",
    date: "Apr 10, 2023",
    datetime: "2023-04-10",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/RdnOgFVFENnLwFYAb26FD.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "16 min",
    author: {
      name: "Aleksei Vambol",
      imageUrl: "https://avatars.githubusercontent.com/u/77882392?v=4",
    },
  },
  {
    title: "Alpha-2 Testnet Update",
    href: "https://taiko.mirror.xyz/EM1IEpF_Pd9_WuPxw3EQPHNHmaXzh7kljMSolP754AI",
    description:
      "We launched our alpha-2 testnet a bit over two weeks ago, and it has been a very useful one in terms of testing, finding issues, and other takeaways.",
    date: "Apr 6, 2023",
    datetime: "2023-04-06",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/MkuJ4w2BaFA9_qMDhBA2P.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "4 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?v=4",
    },
  },
];

export default function BlogSection() {
  return (
    <div className="relative bg-neutral-50 px-4 pt-16 pb-20 sm:px-6 lg:px-8 lg:pt-24 lg:pb-28 dark:bg-neutral-900">
      <div className="absolute inset-0">
        <div className="h-1/3 bg-white sm:h-2/3 dark:bg-neutral-900" />
      </div>
      <div className="relative mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="font-oxanium text-3xl font-bold tracking-tight text-neutral-900 sm:text-4xl dark:text-neutral-100">
            Latest blog posts
          </h2>
          <div className="mx-auto mt-3 max-w-2xl text-xl text-neutral-500 sm:mt-4 dark:text-neutral-300">
            Check out the full blog at{" "}
            <a href="https://mirror.xyz/labs.taiko.eth" target="_blank">
              mirror.xyz ↗
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
                    <span className="sr-only">{post.author.name}</span>
                    <img
                      className="h-10 w-10 rounded-full"
                      src={post.author.imageUrl}
                      alt=""
                    />
                  </div>
                  <div className="ml-3">
                    <div className="text-sm font-medium text-[#fc0fc0]">
                      {post.author.name}
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
