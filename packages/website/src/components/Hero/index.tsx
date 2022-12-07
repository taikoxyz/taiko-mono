import React from "react";

export default function Hero() {
  return (
    <div className="relative bg-neutral-50 dark:bg-neutral-800">
      <main className="lg:relative">
        <div className="mx-auto w-full max-w-7xl pt-16 pb-20 text-center lg:py-48 lg:text-left">
          <div className="px-4 sm:px-8 lg:w-1/2 xl:pr-16">
            <h1 className="text-4xl font-bold tracking-tight text-neutral-900 sm:text-5xl md:text-6xl lg:text-5xl xl:text-6xl">
              <span className="block xl:inline">
                <span className="font-oxanium block text-[#e30ead] xl:inline">
                  Type 1{" "}
                </span>
                <span className="dark:text-neutral-100">ZK-EVM</span>
              </span>{" "}
            </h1>
            <p className="font-oxanium mx-auto mt-3 max-w-md text-lg text-neutral-600 sm:text-xl md:mt-5 md:max-w-3xl dark:text-neutral-100">
              A fully decentralized, Ethereum-equivalent ZK-Rollup.
            </p>
            <div className="mt-10 sm:flex sm:justify-center lg:justify-start">
              <div className="inline-flex rounded-md shadow">
                <a
                  href="./docs/intro"
                  className="inline-flex items-center justify-center rounded-md border border-transparent bg-[#e30ead] px-5 py-3 text-base font-medium text-white hover:bg-[#bd0b90] hover:no-underline hover:text-white"
                >
                  Get started
                </a>
              </div>
            </div>
          </div>
        </div>
        <div className="relative h-64 w-full sm:h-72 md:h-96 lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-1/2">
          <img
            className="absolute inset-0 h-full w-full object-cover"
            src="./img/Taiko_GEOM_1_Fluo_Sliced.svg"
            alt=""
          />
        </div>
      </main>
    </div>
  );
}
