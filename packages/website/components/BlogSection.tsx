const posts = [
  {
    title: "Taiko Community Update — Q1/2023",
    href: "https://taiko.mirror.xyz/IoEGEzlf0aJAtF31YgHHLOa5dSoetLfpIfb7lRaRiCE",
    description:
      "Below is a summary of Taiko’s Q1 2023. Consider this Q1.5 as we’ll include updates that happened post-Q1 but before this update.",
    date: "May 19, 2023",
    datetime: "2023-05-19",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/TOXeVr7_rtitwDoja4vFR.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "6 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?v=4",
    },
  },
  {
    title: "ZK-Roller-Coaster #4",
    href: "https://taiko.mirror.xyz/OCkE3gMDKixWYC-mlX7wAqDNJaUEpm3yeDAYJygyxkg",
    description:
      "This is the 4th edition of ZK-Roller-Coaster where we track and investigate the most exciting, meaningful, and crazy ZK-stuff of the prior two weeks.",
    date: "May 06, 2023",
    datetime: "2023-05-06",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/Myf4VHMd1ACmqL0jmYHWe.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "4 min",
    author: {
      name: "Lisa A.",
      imageUrl: "https://avatars.githubusercontent.com/u/106527861?v=4",
    },
  },
  {
    title: "Taiko Protocol Overview",
    href: "https://taiko.mirror.xyz/y_47kIOL5kavvBmG0zVujD2TRztMZt-xgM5d4oqp4_Y",
    description:
      "Taiko follows the “decentralized from day 1” approach. Below is the protocol description. Taiko protocol consists of three stages: block proposal, validation, and proving.",
    date: "May 02, 2023",
    datetime: "2023-05-02",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/o_qvD7XIAPSjiqlvvodoj.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "6 min",
    author: {
      name: "Lisa A.",
      imageUrl: "https://avatars.githubusercontent.com/u/106527861?v=4",
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
                      <div className="text-xl font-semibold text-neutral-900 dark:text-neutral-200">
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
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
