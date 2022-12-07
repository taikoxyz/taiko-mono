import React from "react";
import {
  ArrowPathIcon,
  GlobeAltIcon,
  ScaleIcon,
} from "@heroicons/react/24/outline";

const features = [
  {
    name: "Type 1",
    description:
      "A Type 1 ZK-EVM (or Ethereum-equivalent) means we make no tradeoffs for compatibility. This means an equivalent DX to Ethereum.",
    icon: ArrowPathIcon,
  },
  {
    name: "Open Source",
    description:
      "All code at Taiko is open source. You can view the code on our GitHub. By “open source” we mean free to see the source and modify it.",
    icon: ScaleIcon,
  },
  {
    name: "Fully Decentralized",
    description:
      "The network is fully decentralized: Layer 2 nodes, proposers, and provers. This is because all of the Layer 2 data is stored on Layer 1.",
    icon: GlobeAltIcon,
  },
];

export default function Features() {
  return (
    <div className="mx-auto max-w-md px-6 text-center sm:max-w-3xl lg:max-w-7xl lg:px-8 dark:bg-[#1B1B1D]">
      <div className="mt-20">
        <div className="grid grid-cols-1 gap-12 sm:grid-cols-1 lg:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.name} className="pt-6">
              <div className="flow-root rounded-lg bg-neutral-50 px-6 pb-8 dark:bg-neutral-700">
                <div className="-mt-6">
                  <div>
                    <span className="inline-flex items-center justify-center rounded-xl bg-neutral-600 p-3 shadow-lg dark:bg-neutral-500">
                      <feature.icon
                        className="h-8 w-8 text-neutral-100"
                        aria-hidden="true"
                      />
                    </span>
                  </div>
                  <h3 className="mt-8 text-lg font-semibold leading-8 tracking-tight text-neutral-900 dark:text-neutral-100">
                    {feature.name}
                  </h3>
                  <p className="mt-5 text-base leading-7 text-neutral-600 dark:text-neutral-300">
                    {feature.description}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
