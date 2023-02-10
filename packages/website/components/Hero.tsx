import { useLayoutEffect } from "react";
import { gsap } from "gsap/dist/gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";

export default function Hero() {
  useLayoutEffect(() => {
    gsap.registerPlugin(ScrollTrigger);

    // Enlarge the TaikoGeom
    gsap.to(".taikoGeom", {
      width: 5000,
      scrollTrigger: {
        trigger: ".taikoGeom",
        start: "top 100",
        end: "+=800",
        scrub: true,
      },
    });

    // Lower the TaikoGeom opacity to 0 with an exponential function
    gsap.to(".taikoGeom", {
      opacity: 0,
      ease: "expo.out",
      scrollTrigger: {
        trigger: ".taikoGeom",
        start: "top 100",
        end: "+=800",
        scrub: true,
      },
    });

    // Enlarge the TaikoGeomParent on scrolling to show the full TaikoGeom
    gsap.to(".taikoGeomParent", {
      width: 5000,
      scrollTrigger: {
        trigger: ".taikoGeom",
        start: "top 100",
        end: "+=800",
        scrub: true,
      },
    });
  });

  return (
    <div className="mx-auto max-w-[90rem]">
      <div className="relative bg-neutral-50 dark:bg-neutral-900 mt-3">
        <main className="lg:relative">
          <div className="relative z-10 w-3/4 pt-16 pb-20 text-left lg:py-48">
            <div className="pl-[max(env(safe-area-inset-left),1.5rem)]">
              <h1 className="font-oxanium text-4xl md:text-5xl font-bold tracking-tight text-neutral-900 dark:text-neutral-100">
                A <span className="text-[#e30ead]">Type 1</span> ZK-EVM
              </h1>
              <p className="font-oxanium mt-3 text-lg text-neutral-600 sm:text-xl md:mt-5 dark:text-neutral-100">
                Fully decentralized, Ethereum-equivalent ZK-Rollup.
              </p>
              <div className="mt-10 flex md:justify-left">
                <div className="inline-flex rounded-md shadow">
                  <a
                    href="/docs/"
                    className="inline-flex items-center rounded-md border border-transparent bg-[#e30ead] px-5 py-3 text-base font-semibold text-white dark:text-neutral-100 hover:bg-[#bd0b90] hover:no-underline hover:text-white"
                  >
                    Get started
                  </a>
                </div>
              </div>
            </div>
          </div>

          <div
            id="taikoGeomParent"
            className="absolute inset-y-0 right-0 overflow-hidden h-full w-11/12 lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-1/2 taikoGeomParent"
          >
            <img
              id="taikoGeom"
              className="absolute z-0 -right-6 overflow-visible h-full w-full object-cover max-w-none taikoGeom"
              src="/images/Taiko_GEOM_1_Fluo_Sliced.svg"
              alt=""
            />
          </div>
        </main>
      </div>
    </div>
  );
}
