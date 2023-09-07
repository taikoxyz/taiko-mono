# Bridge UI v2

This package contains the Bridge UI built with svelte and wagmi

- [Bridge UI v2](#bridge-ui-v2)
  - [Development setup](#development-setup)
    - [Set up environment variables](#set-up-environment-variables)
    - [Set up configurations](#set-up-configurations)
    - [Start a development server:](#start-a-development-server)
  - [Building](#building)

## Development setup

Install all dependencies with

```bash
pnpm install
```

### Set up environment variables

```bash
cp .env.example .env
```

Then update environment variables in .env

```bash
source .env
```

### Set up configurations

**High-level flow:**

1. Prepare .json config files
2. Export as base64 to .env
3. build/serve creates typescript configs for the app

<br/>

**Detailed process**

These are are the additional configuration files that have to be filled in:

| Name                                    | Description                                                                              |
| --------------------------------------- | ---------------------------------------------------------------------------------------- |
| **/config/configuredBridges.json**      | Defines the chains that are connected via taiko bridges and lists the contract addresses |
| **/config/configuredChains.json**       | Defines some metadata for the chains, such as name, icons, explorer URL, etc.            |
| **/config/configuredRelayer.json**      | If chains have a relayer, the URL and the chain IDs it covers are entered here           |
| **/config/configuredCustomTokens.json** | Defines a list of tokens that should be availabe in the token dropdowns                  |

---

<br>

To get started, open your terminal in `/packages/bridge-ui-v2/`

1. Copy the config examples
   ```bash
   cp config/sample/configuredBridges.example config/configuredBridges.json
   cp config/sample/configuredChains.example config/configuredChains.json
   cp config/sample/configuredRelayer.example config/configuredRelayer.json
   cp config/sample/configuredCustomTokens.example config/configuredCustomTokens.json
   ```
2. Change or fill in all the information that will be used by the bridge UI inside these files.

3. As the configurations are not committed directly, they will be loaded from the .env. <br>For that they need to be encoded and appended to the .env file:

   ```bash
   pnpm export:config
   ```

   This command exports the json as base64 string to your .env file

4. Now whenver a build is triggered it will generate the config files based on the .env file in `src/generated/`
   <br>**Note: In the** `config/schemas` **folder are schemas that will validate the correct json format and report any errors in your initial json configurations, so check the log output for any errors!**
   <br>

**Beware**, that if you make changes to the json files, you need to export them to the .env again via script.
<br>

### Start a development server:

```bash
pnpm dev

# or start the server and open the app in a new browser tab
pnpm dev -- --open
```

## Building

To create a production version of your app:

```bash
npm run build
```

You can preview the production build with `npm run preview`.

To deploy your app, you may need to install an [adapter](https://kit.svelte.dev/docs/adapters) for your target environment.
