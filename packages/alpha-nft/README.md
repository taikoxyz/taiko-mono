# Taikoon MFT

## Setup

To run in localhost, first, start an Anvil node:

```shell
$ pnpm node
```

Copy the default `.env.example` file to `.env`, and fill in the required values

Then, deploy the contracts:

```shell
$ pnpm install # installs the workspace's dependencies
```

---

## Deploying the Taikoons

In order to deploy the token, the images for the NFTs must be placed under `data/original/`. The following script will re-size them and upload them to IPFS:

```shell
$ pnpm deploy:ipfs
```

After a lot of information about the resize and upload process, the `/data/metadata` folder will be populated with the metadata files. Upload the folder to IPFS.

4EverLand's web panel works just fine.

Copy over the root CID to the `.env` file.

```shell
$ pnpm deploy:localhost # For the local Anvil node
$ pnpm deploy:holesky # For Holesky's Devnet
$ pnpm deploy:devnet # For Taiko's Devnet
```

## Minters

Used to add minters to the whitelist. The source addresses and amounts must be added under the corresponding network CSV file in `data/whitelist/`

As with the Fetch script, there's a version available for each network:

```shell
$ pnpm minters:localhost
$ pnpm minters:holesky
$ pnpm minters:devnet
```
