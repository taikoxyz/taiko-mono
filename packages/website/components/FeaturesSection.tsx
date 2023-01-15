import {
  ArrowPathIcon,
  GlobeAltIcon,
  ScaleIcon,
} from "@heroicons/react/24/outline";

const features = [
  {
    name: "Type 1",
    description:
      "A Type 1 (Ethereum-equivalent) ZK-EVM aims for maximum compatibility. This results in a seamless developer experience.",
    icon: ArrowPathIcon,
  },
  {
    name: "Open Source",
    description:
      "Taiko's code is open source and available on GitHub. “Open source” means free to view and modify the source code.",
    icon: ScaleIcon,
  },
  {
    name: "Decentralized",
    description:
      "Fully decentralized and permissionless nodes, proposers, and provers. Anyone can participate in Taiko.",
    icon: GlobeAltIcon,
  },
];

export default function FeaturesSection() {
  return (
    <div className="mx-auto max-w-md px-6 text-center sm:max-w-2xl lg:max-w-7xl lg:px-8 dark:bg-neutral-950">
      <div className="my-20">
        <div className="grid grid-cols-1 gap-12 sm:grid-cols-1 lg:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.name} className="pt-6">
              <div className="flow-root rounded-lg bg-neutral-50 px-6 pb-8 dark:bg-neutral-800">
                <div className="-mt-6">
                  <div>
                    <span className="inline-flex items-center justify-center rounded-xl bg-neutral-600 p-3 shadow-lg dark:bg-neutral-500">
                      <feature.icon
                        className="h-8 w-8 text-neutral-100"
                        aria-hidden="true"
                      />
                    </span>
                  </div>
                  <h3 className="font-oxanium mt-8 text-lg font-semibold leading-8 tracking-tight text-neutral-900 dark:text-neutral-100">
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
