export default function CareerSection() {
  return (
    <div className="bg-white dark:bg-neutral-900">
      <div className="mx-auto max-w-7xl py-12 px-4 text-center sm:px-6 lg:py-16 lg:px-8">
        <h2 className="font-oxanium text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl dark:text-neutral-100">
          <span className="block">Join the community 💪</span>
        </h2>
        <section className="bg-white dark:bg-neutral-900 py-12">
          <div className="container mx-auto px-4">
            <div className="flex flex-wrap justify-center">
              <a
                href="https://github.com/taikoxyz/taiko-mono/blob/main/CONTRIBUTING.md"
                target={"_blank"}
                rel={"noreferrer"}
                className="inline-flex items-center justify-center w-64 md:w-72 px-4 md:px-6 py-2 md:py-3 mb-4 mx-2 text-base md:text-lg font-semibold text-white bg-neutral-800 hover:bg-neutral-900 dark:bg-neutral-700 dark:hover:bg-neutral-800 rounded-md shadow-md"
              >
                Contribute to Taiko &#8599;
              </a>
              <a
                href="https://discord.gg/taikoxyz"
                target={"_blank"}
                rel={"noreferrer"}
                className="inline-flex items-center justify-center w-64 md:w-72 px-4 md:px-6 py-2 md:py-3 mb-4 mx-2 text-base md:text-lg font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-md shadow-md"
              >
                Join the Discord &#8599;
              </a>
              <a
                href="https://taikoxyz.notion.site/Taiko-Jobs-828fd7232d2c4150a11e10c8baa910a2"
                target={"_blank"}
                rel={"noreferrer"}
                className="inline-flex items-center justify-center w-64 md:w-72 px-4 md:px-6 py-2 md:py-3 mb-4 mx-2 text-base md:text-lg font-semibold text-white bg-[#fc0fc0] hover:bg-[#e30ead] dark:hover:bg-[#e30ead] rounded-md shadow-md"
              >
                Explore open positions &#8599;
              </a>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
