export { default as BllIcon } from "./BLL";
export { default as EthIcon } from "./ETH";
export { default as HorseIcon } from "./HORSE";
export { default as Icon, type IconType } from "./Icon";
export { default as IconFlipper } from "./IconFlipper";
export { default as TTKOIcon } from "./TTKO";

// The original SvelteKit barrel only exposed named exports (e.g. `import { Icon }`).
// `Icon` is the namesake export of this directory, so we additionally surface it as
// the default export — this keeps `import { Icon }` working (matching the original)
// while also supporting `import Icon from '@/components/Icon'`.
export { default } from "./Icon";
