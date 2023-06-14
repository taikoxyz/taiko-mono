const posts = [
  {
    title: "L2 MEV wat",
    href: "https://taiko.mirror.xyz/VjNjFws6OOVez5YCDMwjy4BUiDqZBHYDvcW4-JZGDkc",
    description:
      "In this article, we “map” the current landscape of L2 MEV, thinking about different MEV consequences for different L2 designs. We also briefly overview different ways of L2s decentralization and how it might impact L2 MEV.",
    date: "Jun 13, 2023",
    datetime: "2023-06-13",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/Qgm0gbwbCQnU8bm5Y1dGB.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "15 min",
    author: {
      name: "Lisa A.",
      imageUrl: "https://avatars.githubusercontent.com/u/106527861?v=4",
    },
  },
  {
    title:
      "Taiko Labs raises $22 million in funding to build an Ethereum-equivalent (Type 1) ZK-EVM",
    href: "https://taiko.mirror.xyz/THTEOFtqE6pjDre5_Tzn04S0mjr7vCoMt5Y-uozfNv8",
    description:
      "We are thrilled to announce that we have raised $22 million across two funding rounds and launched our latest testnet (Alpha-3) in our mission to build a decentralized and Ethereum-equivalent (Type 1) ZK-EVM.",
    date: "Jun 08, 2023",
    datetime: "2023-06-08",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/N0UlPJZrY7oBrK3d4XovR.png?height=1600&width=3200&h=1600&w=3200&auto=compress",
    readingTime: "3 min",
    author: {
      name: "Lisa A.",
      imageUrl: "https://avatars.githubusercontent.com/u/106527861?v=4",
    },
  },
  {
    title: "Taiko Alpha-3 Testnet is Live",
    href: "https://taiko.mirror.xyz/wD7yN8Y5RttbP7kzdtX22GbMg6i18a-Xwet2sshpt48",
    description:
      "Today we’re excited to share that the Taiko alpha-3 testnet, Grímsvötn, is live! This is the next step on the road to a decentralized, Ethereum-equivalent ZK-EVM.",
    date: "Jun 07, 2023",
    datetime: "2023-06-07",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/LtyEm5huf-mf9854QWh3o.jpeg?height=800&width=1600&h=800&w=1600&auto=compress",
    readingTime: "9 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?s=96&v=4",
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
          <h2 className="font-grotesk text-3xl tracking-tight text-neutral-900 sm:text-4xl dark:text-neutral-100">
            Latest blog posts
          </h2>
          <div className="mx-auto mt-3 max-w-2xl text-xl text-neutral-500 sm:mt-4 dark:text-neutral-300">
            Check out the full blog at{" "}
            <a
              className="underline"
              href="https://taiko.mirror.xyz"
              target="_blank"
              rel="noopener noreferrer"
            >
              taiko.mirror.xyz
            </a>
          </div>
        </div>
        <div className="mx-auto mt-12 grid max-w-lg gap-5 lg:max-w-none lg:grid-cols-3">
          {posts.map((post) => (
            <a
              key={post.title}
              href={post.href}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:shadow-lg transition duration-300"
            >
              <div className="flex flex-col h-full overflow-hidden rounded-lg shadow-lg">
                <div className="flex-shrink-0">
                  <img
                    className="h-54 w-full object-cover"
                    src={post.imageUrl}
                    alt=""
                  />
                </div>
                <div className="flex flex-1 flex-col justify-between bg-white p-6 dark:bg-neutral-800 dark:hover:bg-neutral-700">
                  <div className="flex-1">
                    <div className="mt-2 block">
                      <div className="text-xl font-semibold text-neutral-900 dark:text-neutral-200 line-clamp-1">
                        {post.title}
                      </div>
                      <div className="mt-3 text-base text-neutral-500 dark:text-neutral-300 line-clamp-3">
                        {post.description}
                      </div>
                    </div>
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
                      <div className="text-sm font-medium text-[#e81899]">
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
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
