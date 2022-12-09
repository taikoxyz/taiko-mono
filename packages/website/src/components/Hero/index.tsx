import React from "react";

export default function Hero() {
  return (
    <div className="relative bg-neutral-50 dark:bg-neutral-800">
      <main className="lg:relative">
        <div className="mx-auto w-full max-w-7xl pt-16 pb-20 text-left lg:py-48">
          <div className="px-4 sm:px-8 lg:w-1/2 xl:pr-16 ">
            <h1 className="font-oxanium text-4xl font-bold tracking-tight text-neutral-900 dark:text-neutral-100 sm:text-5xl md:text-6xl lg:text-5xl xl:text-6xl">
              A <span className="text-[#e30ead]">Type 1</span> ZK-EVM
            </h1>
            <p className="font-oxanium mx-auto mt-3 text-lg text-neutral-600 sm:text-xl md:mt-5 dark:text-neutral-100">
              Fully decentralized, Ethereum-equivalent ZK-Rollup.
            </p>
            <div className="mt-10">
              <div className="rounded-md shadow">
                <a
                  href="./docs/intro"
                  className=" rounded-md border border-transparent bg-[#e30ead] px-5 py-3 text-base font-semibold text-white dark:text-neutral-100 hover:bg-[#bd0b90] hover:no-underline hover:text-white"
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

