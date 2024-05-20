# Taiko UI Library

## Components

- [x] Footer
- [ ] Icons
- [ ] Button
- [ ] ResponsiveController

## Exported values

- [x] UI Kit colors
- [x] Dark Theme colors
- [x] Light Theme colors
- [ ] Typography

## Contributing

### Development

The library includes [Storybook](https://storybook.js.org/) for development. To start the Storybook server, run:

```bash
$ pnpm storybook
```

### Build

The library builds and packs as a [Svelte library] with the following command:

```bash
$ pnpm build
```

### Adding components

In order to add new components into the library to be used outside:

1. Create a new component under `src/lib/components/` directory.
2. Export the component on `src/lib/index.ts`:

```typescript
import { NewComponent } from './components/NewComponent';

export {
    Footer,
    ...
    NewComponent
};

```

3. Now you can import it and use it in another project:

```typescript
import { NewComponent } from '@taiko/ui-lib';

...

<NewComponent />
```

### Exported values

Besides from the components, the library exports the configurations for TailwindCSS in `src/theme/`:

- `colors.js`: [Taiko's UI Kit](https://www.figma.com/design/3zuVeAbGDICzyhVvSI15nG/Taiko---UI-Kit-%26-Components?node-id=26-122&t=R6fMNiuhGixl6nxX-0) core colors
- `dark-mode.js`: TailwindCSS/DaisyUI dark mode configuration
- `light-mode.js`: TailwindCSS/DaisyUI light mode configuration

All exported values from the `src/theme` directory are prefixed with `tko-` to avoid conflicts with other libraries and local definitions.
