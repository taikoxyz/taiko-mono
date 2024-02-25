# Bridge UI

This package contains the Bridge UI built with svelte and wagmi

- [Bridge UI](#bridge-ui)
  - [Development setup](#development-setup)
    - [Set up environment variables](#set-up-environment-variables)
    - [Set up configurations](#set-up-configurations)
      - [Optional flags](#optional-flags)
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

These are the additional configuration files that have to be filled in:

| Name                                    | Description                                                                              |
| --------------------------------------- | ---------------------------------------------------------------------------------------- |
| **/config/configuredBridges.json**      | Defines the chains that are connected via taiko bridges and lists the contract addresses |
| **/config/configuredChains.json**       | Defines some metadata for the chains, such as name, icons, explorer URL, etc.            |
| **/config/configuredRelayer.json**      | If chains have a relayer, the URL and the chain IDs it covers are entered here           |
| **/config/configuredEventIndexer.json** | NFT Indexer we can query to help with importing NFTs                                     |
| **/config/configuredCustomTokens.json** | Defines a list of tokens that should be available in the token dropdowns                 |

---

<br>

To get started, open your terminal in `/packages/bridge-ui/`

1. Copy the config examples
   ```bash
   cp config/sample/configuredBridges.example config/configuredBridges.json
   cp config/sample/configuredChains.example config/configuredChains.json
   cp config/sample/configuredRelayer.example config/configuredRelayer.json
   cp config/sample/configuredCustomTokens.example config/configuredCustomTokens.json
   cp config/sample/configuredEventIndexer.example config/configuredEventIndexer.json
   ```
2. Change or fill in all the information that will be used by the bridge UI inside these files.

3. As the configurations are not committed directly, they will be loaded from the .env. <br>For that they need to be encoded and appended to the .env file:

   ```bash
   pnpm export:config
   ```

   This command exports the json as base64 string to your .env file

4. Now whenever a build is triggered it will generate the config files based on the .env file in `src/generated/`
   <br>**Note: In the** `config/schemas` **folder are schemas that will validate the correct json format and report any errors in your initial json configurations, so check the log output for any errors!**
   <br>

**Beware**, that if you make changes to the json files, you need to export them to the .env again via script.
<br>

#### Optional flags

```bash
pnpm export:config --<env> --<version>
```

You can store multiple configs in subfolders, currently the script accepts:
`--a5`, `--a6` for version and `--dev`, `--prod` for env

The folder structure should look like this then:

```
config/
|-- dev/
|   |-- a5/
|   |-- a6/
|-- prod/
|   |-- a5/
|   |-- a6/
```

More could be configured manually in `scripts/exportJsonToEnv.js`
<br>

### Start a development server:

```bash
pnpm dev

# or start the server and open the app in a new browser tab
pnpm dev -- --open

# if you want to expose the IP to your network you can use this flag
pnpm dev --host

```

## Building

To create a production version of your app:

```bash
pnpm run build
```

You can preview the production build with `pnpm run preview`.

To deploy your app, you may need to install an [adapter](https://kit.svelte.dev/docs/adapters) for your target environment.
