/* eslint-disable no-console */
import { promises as fs } from 'fs';
import path from 'path';
import * as prettier from "prettier";
import { Project, SourceFile, VariableDeclarationKind } from "ts-morph";
import type { Address } from 'viem';

import { Logger } from './utils/Logger';

const currentDir = path.resolve(new URL(import.meta.url).pathname);


// Todo: make paths and names configurable via .env?
const outputPath = path.join(path.join(path.dirname(currentDir)), '../src/generated/config.ts');

const configuredChainsConfigFile = path.join(path.dirname(currentDir), '../config', 'configuredChains.json');
const configuredBridgesConfigFile = path.join(path.dirname(currentDir), '../config', 'configuredBridges.json');


enum LayerType {
  L1 = "L1",
  L2 = "L2",
  L3 = "L3"
}

type Urls = {
  rpc: string;
  explorer: string;
};


type ChainConfig = {
  name: string;
  urls: Urls;
  type: LayerType;
}

type AddressConfig = {
  bridgeAddress: Address;
  erc20VaultAddress: Address;
  erc721VaultAddress: Address;
  erc1155VaultAddress: Address;
  crossChainSyncAddress: Address;
  signalServiceAddress: Address;
};

type BridgeConfig = {
  source: string;
  destination: string;
  addresses: AddressConfig;
}

type ChainConfigMap = Record<number, ChainConfig>;

type ConfiguredChains = {
  configuredChains: Array<Record<string, Omit<ChainConfig, 'chainId'>>>;
};


type RoutingMap = Record<string, Record<string, AddressConfig>>;

const pluginName = "generate-Chains-Config";
const logger = new Logger(pluginName);


export default function generateTsFromJsonPlugin() {
  return {
    pluginName,
    async buildStart() {
      logger.info("Plugin initialized.");
      const project = new Project();

      // Path to where you want to save the generated TypeScript file
      const tsFilePath = path.resolve(outputPath);

      // Create the TypeScript content

      let sourceFile = project.createSourceFile(tsFilePath, undefined, { overwrite: true });

      sourceFile.addImportDeclaration({
        namedImports: ["Address"],
        moduleSpecifier: "viem",
        isTypeOnly: true
      });

      sourceFile = await storeTypesAndEnums(sourceFile)
      sourceFile = await buildBridgeConfig(sourceFile);
      sourceFile = await buildChainConfig(sourceFile);

      // Save the file
      await sourceFile.saveSync();
      logger.info(`Generated config file`);

      const generatedCode = await fs.readFile(tsFilePath, "utf-8");

      logger.info(`Formatting...`);
      // Format the code using Prettier
      const formattedCode = await prettier.format(generatedCode, { parser: "typescript" });

      // Write the formatted code back to the file
      await fs.writeFile(tsFilePath, formattedCode);
      logger.info(`Formatted config file saved to ${tsFilePath}`);
    },
  };
}

async function storeTypesAndEnums(sourceFile: SourceFile) {
  logger.info(`Storing types and enums...`);
  // Urls
  sourceFile.addTypeAlias({
    name: "Urls",
    isExported: false,
    type: `{
      rpc: string;
      explorer: string;
    }`
  });

  // LayerType
  sourceFile.addEnum({
    name: "LayerType",
    isExported: false,
    members: [
      { name: "L1", value: "L1" },
      { name: "L2", value: "L2" },
      { name: "L3", value: "L3" }
    ]
  });

  // ChainConfig
  sourceFile.addTypeAlias({
    name: "ChainConfig",
    isExported: true,
    type: `{
      name: string;
      urls: Urls;
      type: LayerType;
    }`
  });

  // AddressConfig
  sourceFile.addTypeAlias({
    name: "AddressConfig",
    isExported: true,
    type: `{ 
      bridgeAddress: Address;
      erc20VaultAddress: Address;
      erc721VaultAddress: Address;
      erc1155VaultAddress: Address;
      crossChainSyncAddress: Address;
      signalServiceAddress: Address;
    }`
  });

  // RoutingMap
  sourceFile.addTypeAlias({
    name: "RoutingMap",
    isExported: true,
    type: `Record<string, Record<string, AddressConfig>>`
  });

  // ChainConfigMap
  sourceFile.addTypeAlias({
    name: "ChainConfigMap",
    isExported: true,
    type: `Record<number, ChainConfig>`
  });

  logger.info("Types and enums stored.")
  return sourceFile;
}


async function buildChainConfig(sourceFile: SourceFile) {
  const chainConfig: ChainConfigMap = {};

  const chainsJsonContent = await fs.readFile(configuredChainsConfigFile, 'utf-8');
  const chains: ConfiguredChains = JSON.parse(chainsJsonContent);

  if (!chains.configuredChains || !Array.isArray(chains.configuredChains)) {
    console.error('configuredChains is not an array. Please check the content of the configuredChainsConfigFile.');
    throw new Error();
  }

  chains.configuredChains.forEach((item: Record<string, ChainConfig>) => {
    for (const [chainIdStr, config] of Object.entries(item)) {
      const chainId = Number(chainIdStr);
      const type = config.type as LayerType;

      // Check for duplicates
      if (Object.prototype.hasOwnProperty.call(chainConfig, chainId)) {
        logger.error(`Duplicate chainId ${chainId} found in configuredChains.json`);
        throw new Error();
      }

      // Validate LayerType
      if (!Object.values(LayerType).includes(config.type)) {
        logger.error(`Invalid LayerType ${config.type} found for chainId ${chainId}`);
        throw new Error();
      }

      chainConfig[chainId] = { ...config, type };

    }
  });


  // Add chainConfig variable to sourceFile
  sourceFile.addVariableStatement({
    declarationKind: VariableDeclarationKind.Const,
    declarations: [{
      name: 'chainConfig',
      type: 'ChainConfigMap',
      initializer: _formatObjectToTsLiteral(chainConfig)
    }],
    isExported: true
  });

  logger.info(`Configured ${Object.keys(chainConfig).length} chains.`);
  return sourceFile;
}



async function buildBridgeConfig(sourceFile: SourceFile) {
  logger.info("Building bridge config...");
  const routingContractsMap: RoutingMap = {};

  const bridgesJsonContent = await fs.readFile(configuredBridgesConfigFile, 'utf-8');

  const bridges = JSON.parse(bridgesJsonContent);
  if (!bridges.configuredBridges || !Array.isArray(bridges.configuredBridges)) {
    logger.error('configuredBridges is not an array. Please check the content of the configuredBridgesConfigFile.');
    throw new Error();
  }

  bridges.configuredBridges.forEach((item: BridgeConfig) => {
    if (!routingContractsMap[item.source]) {
      routingContractsMap[item.source] = {};
    }
    routingContractsMap[item.source][item.destination] = item.addresses;
  });


  // Add routingContractsMap variable
  sourceFile.addVariableStatement({
    declarationKind: VariableDeclarationKind.Const,
    declarations: [{
      name: 'routingContractsMap',
      type: "RoutingMap",
      initializer: _formatObjectToTsLiteral(routingContractsMap)
    }],
    isExported: true
  });

  logger.info(`Configured ${bridges.configuredBridges.length} bridges.`);
  return sourceFile;
}


const _formatObjectToTsLiteral = (obj: RoutingMap | ChainConfigMap): string => {
  const formatValue = (value: any): string => {
    if (typeof value === 'string') {
      if (Object.values(LayerType).includes(value as LayerType)) {
        return `LayerType.${value}`;
      }
      return `"${value}"`;
    }
    if (typeof value === 'number' || typeof value === 'boolean' || value === null) {
      return String(value);
    }
    if (Array.isArray(value)) {
      return `[${value.map(formatValue).join(", ")}]`;
    }
    if (typeof value === 'object') {
      return _formatObjectToTsLiteral(value);
    }
    return 'undefined';
  };

  if (Array.isArray(obj)) {
    return `[${obj.map(formatValue).join(", ")}]`;
  }

  const entries = Object.entries(obj);
  const formattedEntries = entries.map(
    ([key, value]) => `${key}: ${formatValue(value)}`
  );

  return `{${formattedEntries.join(", ")}}`;
};