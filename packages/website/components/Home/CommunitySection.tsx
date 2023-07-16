export function CommunitySection() {
  // Button base class
  const buttonClass =
    "inline-flex items-center justify-center float w-64 px-4 md:px-6 py-2 md:py-3 mb-4 mx-2 text-base md:text-lg font-semibold text-white rounded-md shadow-md";

  return (
    <div className="bg-white dark:bg-neutral-900">
      <div className="mx-auto max-w-7xl py-12 px-4 text-center sm:px-6 lg:py-16 lg:px-8">
        <h2 className="font-grotesk text-3xl tracking-tight text-gray-900 sm:text-4xl dark:text-neutral-100">
          <span className="block">Join the community 🥁</span>
        </h2>
        <section className="bg-white dark:bg-neutral-900 py-12">
          <div className="container mx-auto px-4">
            <div className="flex flex-wrap justify-center">
              <a
                href="https://github.com/taikoxyz/taiko-mono/blob/main/CONTRIBUTING.md"
                target="_blank"
                rel="noreferrer"
                className={`${buttonClass} bg-[#404040] hover:bg-[#3a3a3a]`}
              >
                Contribute to Taiko
              </a>
              <a
                href="https://discord.gg/taikoxyz"
                target="_blank"
                rel="noreferrer"
                className={`${buttonClass} bg-[#5865f2] hover:bg-[#4f5bda]`}
              >
                Join the Discord
              </a>
              <a
                href="https://twitter.com/taikoxyz"
                target="_blank"
                rel="noreferrer"
                className={`${buttonClass} bg-[#00acee] hover:bg-[#009bd6]`}
              >
                Follow on Twitter
              </a>
              <a
                href="https://taikoxyz.notion.site/Taiko-Jobs-828fd7232d2c4150a11e10c8baa910a2"
                target="_blank"
                rel="noreferrer"
                className={`${buttonClass} bg-[#e81899] hover:bg-[#d1168a]`}
              >
                Explore open positions
              </a>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
