const posts = [
  {
    title: "Taiko Ambassador Program",
    href: "https://mirror.xyz/labs.taiko.eth/BvcEyYeVIiHnjc-i5qf3zR4s67Jc6nz_R6OSGj5rzOE",
    description:
      "Ethereum has come a long way in its seven-year life — changing the world, in our opinion — but it is only just getting started.",
    date: "Jan 04, 2023",
    datetime: "2023-01-04",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/5Ed-TXJIB3LTC2HJdPuEN.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "2 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?v=4",
    },
  },
  {
    title: "Taiko Alpha-1 Testnet is Live",
    href: "https://mirror.xyz/labs.taiko.eth/-lahy4KbGkeAcqhs0ETG3Up3oTVzZ0wLoE1eK_ao5h4",
    description:
      "Today, the Taiko Alpha-1 testnet (a1) is live - our first public testnet! We’ve codenamed this testnet, Snæfellsjökull.",
    date: "Dec 27, 2022",
    datetime: "2022-12-27",
    imageUrl:
      "https://mirror-media.imgix.net/publication-images/4qVW-dWhNmMQr61g91hGt.png?height=512&width=1024&h=512&w=1024&auto=compress",
    readingTime: "4 min",
    author: {
      name: "finestone",
      imageUrl: "https://avatars.githubusercontent.com/u/36642873?v=4",
    },
  },
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
