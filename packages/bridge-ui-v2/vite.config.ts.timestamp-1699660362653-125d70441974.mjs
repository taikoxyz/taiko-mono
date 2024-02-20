// vite.config.ts
import { sveltekit } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/@sveltejs+kit@1.22.3_svelte@4.1.0_vite@4.4.9/node_modules/@sveltejs/kit/src/exports/vite/index.js";
import tsconfigPaths from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/vite-tsconfig-paths@4.2.1_typescript@5.2.2_vite@4.4.9/node_modules/vite-tsconfig-paths/dist/index.mjs";
import { defineConfig } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/vitest@0.32.2_jsdom@22.1.0/node_modules/vitest/dist/config.js";

// scripts/vite-plugins/generateBridgeConfig.ts
import dotenv from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/dotenv@16.3.1/node_modules/dotenv/lib/main.js";
import { promises as fs2 } from "fs";
import path from "path";
import { Project, VariableDeclarationKind } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ts-morph@19.0.0/node_modules/ts-morph/dist/ts-morph.js";

// config/schemas/configuredBridges.schema.json
var configuredBridges_schema_default = {
  $id: "configuredBridges.json",
  type: "object",
  properties: {
    configuredBridges: {
      type: "array",
      items: {
        type: "object",
        properties: {
          source: {
            type: "string"
          },
          destination: {
            type: "string"
          },
          addresses: {
            type: "object",
            properties: {
              bridgeAddress: {
                type: "string"
              },
              erc20VaultAddress: {
                type: "string"
              },
              etherVaultAddress: {
                type: "string"
              },
              erc721VaultAddress: {
                type: "string"
              },
              erc1155VaultAddress: {
                type: "string"
              },
              crossChainSyncAddress: {
                type: "string"
              },
              signalServiceAddress: {
                type: "string"
              }
            },
            required: [
              "bridgeAddress",
              "erc20VaultAddress",
              "erc721VaultAddress",
              "erc1155VaultAddress",
              "crossChainSyncAddress",
              "signalServiceAddress"
            ],
            additionalProperties: false
          }
        },
        required: ["source", "destination", "addresses"],
        additionalProperties: false
      }
    }
  },
  required: ["configuredBridges"],
  additionalProperties: false
};

// scripts/utils/decodeBase64ToJson.ts
import { Buffer } from "buffer";
var decodeBase64ToJson = (base64) => {
  return JSON.parse(Buffer.from(base64, "base64").toString("utf-8"));
};

// scripts/utils/formatSourceFile.ts
import { promises as fs } from "fs";
import * as prettier from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/prettier@3.0.3/node_modules/prettier/index.mjs";
async function formatSourceFile(tsFilePath) {
  const generatedCode = await fs.readFile(tsFilePath, "utf-8");
  return await prettier.format(generatedCode, { parser: "typescript" });
}

// scripts/utils/PluginLogger.js
var FgMagenta = "\x1B[35m";
var FgYellow = "\x1B[33m";
var FgRed = "\x1B[31m";
var Bright = "\x1B[1m";
var Reset = "\x1B[0m";
var timestamp = () => (/* @__PURE__ */ new Date()).toLocaleTimeString();
var PluginLogger = class {
  /**
   * @param {string} pluginName
   */
  constructor(pluginName6) {
    this.pluginName = pluginName6;
  }
  /**
   * @param {string} message
   */
  info(message) {
    this._logWithColor(FgMagenta, message);
  }
  /**
   * @param {any} message
   */
  warn(message) {
    this._logWithColor(FgYellow, message);
  }
  /**
   * @param {string} message
   */
  error(message) {
    this._logWithColor(FgRed, message, true);
  }
  /**
   * @param {string} color
   * @param {any} message
   */
  _logWithColor(color, message, isError = false) {
    console.log(
      `${color}${timestamp()}${Bright} [${this.pluginName}]${Reset}${isError ? color : ""} ${message} ${isError ? Reset : ""} `
    );
  }
};

// scripts/utils/validateJson.ts
import Ajv from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ajv@8.7.0/node_modules/ajv/dist/ajv.js";
var ajv = new Ajv({ strict: false });
var logger = new PluginLogger("json-validator");
var validateJsonAgainstSchema = (json, schema) => {
  logger.info(`Validating ${schema.$id}`);
  const validate = ajv.compile(schema);
  const valid = validate(json);
  if (!valid) {
    logger.error("Validation failed.");
    console.error("Error details:", ajv.errors);
    return false;
  }
  logger.info(`Validation of ${schema.$id} succeeded.`);
  return true;
};

// scripts/vite-plugins/generateBridgeConfig.ts
var __vite_injected_original_import_meta_url = "file:///home/jeff/code/taikochain/taiko-mono/packages/bridge-ui-v2/scripts/vite-plugins/generateBridgeConfig.ts";
dotenv.config();
var pluginName = "generateBridgeConfig";
var logger2 = new PluginLogger(pluginName);
var skip = process.env.SKIP_ENV_VALDIATION || false;
var currentDir = path.resolve(new URL(__vite_injected_original_import_meta_url).pathname);
var outputPath = path.join(path.dirname(currentDir), "../../src/generated/bridgeConfig.ts");
function generateBridgeConfig() {
  return {
    name: pluginName,
    async buildStart() {
      logger2.info("Plugin initialized.");
      let configuredBridgesConfigFile;
      if (!skip) {
        if (!process.env.CONFIGURED_BRIDGES) {
          throw new Error(
            "CONFIGURED_BRIDGES is not defined in environment. Make sure to run the export step in the documentation."
          );
        }
        configuredBridgesConfigFile = decodeBase64ToJson(process.env.CONFIGURED_BRIDGES || "");
        const isValid = validateJsonAgainstSchema(configuredBridgesConfigFile, configuredBridges_schema_default);
        if (!isValid) {
          throw new Error("encoded configuredBridges.json is not valid.");
        }
      } else {
        configuredBridgesConfigFile = "";
      }
      const tsFilePath = path.resolve(outputPath);
      const project = new Project();
      const notification = `// Generated by ${pluginName} on ${(/* @__PURE__ */ new Date()).toLocaleString()}`;
      const warning = `// WARNING: Do not change this file manually as it will be overwritten`;
      let sourceFile = project.createSourceFile(tsFilePath, `${notification}
${warning}
`, { overwrite: true });
      sourceFile = await storeTypes(sourceFile);
      sourceFile = await buildBridgeConfig(sourceFile, configuredBridgesConfigFile);
      await sourceFile.saveSync();
      logger2.info(`Generated config file`);
      await sourceFile.saveSync();
      const formatted = await formatSourceFile(tsFilePath);
      await fs2.writeFile(tsFilePath, formatted);
      logger2.info(`Formatted config file saved to ${tsFilePath}`);
    }
  };
}
async function storeTypes(sourceFile) {
  logger2.info(`Storing types...`);
  sourceFile.addImportDeclaration({
    namedImports: ["RoutingMap"],
    moduleSpecifier: "$libs/bridge",
    isTypeOnly: true
  });
  logger2.info("Type stored.");
  return sourceFile;
}
async function buildBridgeConfig(sourceFile, configuredBridgesConfigFile) {
  logger2.info("Building bridge config...");
  const routingContractsMap = {};
  const bridges = configuredBridgesConfigFile;
  if (!skip) {
    if (!bridges.configuredBridges || !Array.isArray(bridges.configuredBridges)) {
      logger2.error("configuredBridges is not an array. Please check the content of the configuredBridgesConfigFile.");
      throw new Error();
    }
    bridges.configuredBridges.forEach((item) => {
      if (!routingContractsMap[item.source]) {
        routingContractsMap[item.source] = {};
      }
      routingContractsMap[item.source][item.destination] = item.addresses;
    });
  }
  if (skip) {
    sourceFile.addVariableStatement({
      declarationKind: VariableDeclarationKind.Const,
      declarations: [
        {
          name: "routingContractsMap",
          type: "RoutingMap",
          initializer: "{}"
        }
      ],
      isExported: true
    });
    logger2.info(`Skipped bridge.`);
  } else {
    sourceFile.addVariableStatement({
      declarationKind: VariableDeclarationKind.Const,
      declarations: [
        {
          name: "routingContractsMap",
          type: "RoutingMap",
          initializer: _formatObjectToTsLiteral(routingContractsMap)
        }
      ],
      isExported: true
    });
    logger2.info(`Configured ${bridges.configuredBridges.length} bridges.`);
  }
  return sourceFile;
}
var _formatObjectToTsLiteral = (obj) => {
  const formatValue = (value) => {
    if (typeof value === "string") {
      return `"${value}"`;
    }
    return String(value);
  };
  const entries = Object.entries(obj);
  const formattedEntries = entries.map(([key, value]) => {
    const innerEntries = Object.entries(value);
    const innerFormattedEntries = innerEntries.map(([innerKey, innerValue]) => {
      const innerInnerEntries = Object.entries(innerValue);
      const innerInnerFormattedEntries = innerInnerEntries.map(
        ([innerInnerKey, innerInnerValue]) => `${innerInnerKey}: ${formatValue(innerInnerValue)}`
      );
      return `${innerKey}: {${innerInnerFormattedEntries.join(", ")}}`;
    });
    return `${key}: {${innerFormattedEntries.join(", ")}}`;
  });
  return `{${formattedEntries.join(", ")}}`;
};

// scripts/vite-plugins/generateChainConfig.ts
import dotenv2 from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/dotenv@16.3.1/node_modules/dotenv/lib/main.js";
import { promises as fs3 } from "fs";
import path2 from "path";
import { Project as Project2, VariableDeclarationKind as VariableDeclarationKind2 } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ts-morph@19.0.0/node_modules/ts-morph/dist/ts-morph.js";

// config/schemas/configuredChains.schema.json
var configuredChains_schema_default = {
  $id: "configuredChains.json",
  properties: {
    configuredChains: {
      type: "array",
      items: {
        type: "object",
        propertyNames: {
          pattern: "^[0-9]+$"
        },
        additionalProperties: {
          type: "object",
          properties: {
            name: {
              type: "string"
            },
            icon: {
              type: "string"
            },
            type: {
              type: "string"
            },
            urls: {
              type: "object",
              properties: {
                rpc: {
                  type: "string"
                },
                explorer: {
                  type: "string"
                }
              },
              required: ["rpc", "explorer"]
            }
          },
          required: ["name", "icon", "type", "urls"]
        }
      }
    }
  },
  required: ["configuredChains"]
};

// scripts/vite-plugins/generateChainConfig.ts
var __vite_injected_original_import_meta_url2 = "file:///home/jeff/code/taikochain/taiko-mono/packages/bridge-ui-v2/scripts/vite-plugins/generateChainConfig.ts";
dotenv2.config();
var pluginName2 = "generateChainConfig";
var logger3 = new PluginLogger(pluginName2);
var skip2 = process.env.SKIP_ENV_VALDIATION || false;
var currentDir2 = path2.resolve(new URL(__vite_injected_original_import_meta_url2).pathname);
var outputPath2 = path2.join(path2.dirname(currentDir2), "../../src/generated/chainConfig.ts");
function generateChainConfig() {
  return {
    name: pluginName2,
    async buildStart() {
      logger3.info("Plugin initialized.");
      let configuredChainsConfigFile;
      if (!skip2) {
        if (!process.env.CONFIGURED_CHAINS) {
          throw new Error(
            "CONFIGURED_CHAINS is not defined in environment. Make sure to run the export step in the documentation."
          );
        }
        configuredChainsConfigFile = decodeBase64ToJson(process.env.CONFIGURED_CHAINS || "");
        const isValid = validateJsonAgainstSchema(configuredChainsConfigFile, configuredChains_schema_default);
        if (!isValid) {
          throw new Error("encoded configuredBridges.json is not valid.");
        }
      } else {
        configuredChainsConfigFile = "";
      }
      const tsFilePath = path2.resolve(outputPath2);
      const project = new Project2();
      const notification = `// Generated by ${pluginName2} on ${(/* @__PURE__ */ new Date()).toLocaleString()}`;
      const warning = `// WARNING: Do not change this file manually as it will be overwritten`;
      let sourceFile = project.createSourceFile(tsFilePath, `${notification}
${warning}
`, { overwrite: true });
      sourceFile = await storeTypes2(sourceFile);
      sourceFile = await buildChainConfig(sourceFile, configuredChainsConfigFile);
      await sourceFile.saveSync();
      const formatted = await formatSourceFile(tsFilePath);
      await fs3.writeFile(tsFilePath, formatted);
      logger3.info(`Formatted config file saved to ${tsFilePath}`);
    }
  };
}
async function storeTypes2(sourceFile) {
  logger3.info(`Storing types...`);
  sourceFile.addImportDeclaration({
    namedImports: ["ChainConfigMap"],
    moduleSpecifier: "$libs/chain",
    isTypeOnly: true
  });
  sourceFile.addEnum({
    name: "LayerType",
    isExported: false,
    members: [
      { name: "L1", value: "L1" },
      { name: "L2", value: "L2" },
      { name: "L3", value: "L3" }
    ]
  });
  logger3.info("Types stored.");
  return sourceFile;
}
async function buildChainConfig(sourceFile, configuredChainsConfigFile) {
  const chainConfig = {};
  const chains = configuredChainsConfigFile;
  if (!skip2) {
    if (!chains.configuredChains || !Array.isArray(chains.configuredChains)) {
      console.error("configuredChains is not an array. Please check the content of the configuredChainsConfigFile.");
      throw new Error();
    }
    chains.configuredChains.forEach((item) => {
      for (const [chainIdStr, config] of Object.entries(item)) {
        const chainId = Number(chainIdStr);
        const type = config.type;
        if (Object.prototype.hasOwnProperty.call(chainConfig, chainId)) {
          logger3.error(`Duplicate chainId ${chainId} found in configuredChains.json`);
          throw new Error();
        }
        if (!Object.values(LayerType).includes(config.type)) {
          logger3.error(`Invalid LayerType ${config.type} found for chainId ${chainId}`);
          throw new Error();
        }
        chainConfig[chainId] = { ...config, type };
      }
    });
  }
  sourceFile.addVariableStatement({
    declarationKind: VariableDeclarationKind2.Const,
    declarations: [
      {
        name: "chainConfig",
        type: "ChainConfigMap",
        initializer: _formatObjectToTsLiteral2(chainConfig)
      }
    ],
    isExported: true
  });
  if (skip2) {
    logger3.info(`Skipped chains.`);
  } else {
    logger3.info(`Configured ${Object.keys(chainConfig).length} chains.`);
  }
  return sourceFile;
}
var LayerType = /* @__PURE__ */ ((LayerType2) => {
  LayerType2["L1"] = "L1";
  LayerType2["L2"] = "L2";
  LayerType2["L3"] = "L3";
  return LayerType2;
})(LayerType || {});
var _formatObjectToTsLiteral2 = (obj) => {
  const formatValue = (value) => {
    if (typeof value === "string") {
      if (typeof value === "string") {
        if (Object.values(LayerType).includes(value)) {
          return `LayerType.${value}`;
        }
        return `"${value}"`;
      }
      return `"${value}"`;
    }
    if (typeof value === "number" || typeof value === "boolean" || value === null) {
      return String(value);
    }
    if (Array.isArray(value)) {
      return `[${value.map(formatValue).join(", ")}]`;
    }
    if (typeof value === "object") {
      return _formatObjectToTsLiteral2(value);
    }
    return "undefined";
  };
  if (Array.isArray(obj)) {
    return `[${obj.map(formatValue).join(", ")}]`;
  }
  const entries = Object.entries(obj);
  const formattedEntries = entries.map(([key, value]) => `${key}: ${formatValue(value)}`);
  return `{${formattedEntries.join(", ")}}`;
};

// scripts/vite-plugins/generateCustomTokenConfig.ts
import dotenv3 from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/dotenv@16.3.1/node_modules/dotenv/lib/main.js";
import { promises as fs4 } from "fs";
import path3 from "path";
import { Project as Project3, VariableDeclarationKind as VariableDeclarationKind3 } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ts-morph@19.0.0/node_modules/ts-morph/dist/ts-morph.js";
var __vite_injected_original_import_meta_url3 = "file:///home/jeff/code/taikochain/taiko-mono/packages/bridge-ui-v2/scripts/vite-plugins/generateCustomTokenConfig.ts";
dotenv3.config();
var pluginName3 = "generateTokens";
var logger4 = new PluginLogger(pluginName3);
var skip3 = process.env.SKIP_ENV_VALDIATION || false;
var currentDir3 = path3.resolve(new URL(__vite_injected_original_import_meta_url3).pathname);
var outputPath3 = path3.join(path3.dirname(currentDir3), "../../src/generated/customTokenConfig.ts");
function generateCustomTokenConfig() {
  return {
    name: pluginName3,
    async buildStart() {
      logger4.info("Plugin initialized.");
      let configuredTokenConfigFile;
      if (!skip3) {
        if (!process.env.CONFIGURED_CUSTOM_TOKEN) {
          throw new Error(
            "CONFIGURED_CUSTOM_TOKEN is not defined in environment. Make sure to run the export step in the documentation."
          );
        }
        configuredTokenConfigFile = decodeBase64ToJson(process.env.CONFIGURED_CUSTOM_TOKEN || "");
        const isValid = validateJsonAgainstSchema(configuredTokenConfigFile, configuredChains_schema_default);
        if (!isValid) {
          throw new Error("encoded configuredBridges.json is not valid.");
        }
      } else {
        configuredTokenConfigFile = "";
      }
      const tsFilePath = path3.resolve(outputPath3);
      const project = new Project3();
      const notification = `// Generated by ${pluginName3} on ${(/* @__PURE__ */ new Date()).toLocaleString()}`;
      const warning = `// WARNING: Do not change this file manually as it will be overwritten`;
      let sourceFile = project.createSourceFile(tsFilePath, `${notification}
${warning}
`, { overwrite: true });
      sourceFile = await storeTypes3(sourceFile);
      sourceFile = await buildCustomTokenConfig(sourceFile, configuredTokenConfigFile);
      await sourceFile.save();
      const formatted = await formatSourceFile(tsFilePath);
      await fs4.writeFile(tsFilePath, formatted);
      logger4.info(`Formatted config file saved to ${tsFilePath}`);
    }
  };
}
async function storeTypes3(sourceFile) {
  logger4.info(`Storing types...`);
  sourceFile.addImportDeclaration({
    namedImports: ["Token"],
    moduleSpecifier: "$libs/token",
    isTypeOnly: true
  });
  sourceFile.addImportDeclaration({
    namedImports: ["TokenType"],
    moduleSpecifier: "$libs/token"
  });
  logger4.info("Type stored.");
  return sourceFile;
}
async function buildCustomTokenConfig(sourceFile, configuredTokenConfigFile) {
  logger4.info("Building custom token config...");
  if (skip3) {
    sourceFile.addVariableStatement({
      declarationKind: VariableDeclarationKind3.Const,
      declarations: [
        {
          name: "customToken",
          initializer: "[]",
          type: "Token[]"
        }
      ],
      isExported: true
    });
    logger4.info(`Skipped token.`);
  } else {
    const tokens = configuredTokenConfigFile;
    sourceFile.addVariableStatement({
      declarationKind: VariableDeclarationKind3.Const,
      declarations: [
        {
          name: "customToken",
          initializer: _formatObjectToTsLiteral3(tokens),
          type: "Token[]"
        }
      ],
      isExported: true
    });
    logger4.info(`Configured ${tokens.length} tokens.`);
  }
  return sourceFile;
}
var _formatObjectToTsLiteral3 = (tokens) => {
  const formatToken = (token) => {
    const entries = Object.entries(token);
    const formattedEntries = entries.map(([key, value]) => {
      if (key === "type" && typeof value === "string") {
        return `${key}: TokenType.${value}`;
      }
      if (typeof value === "object") {
        return `${key}: ${JSON.stringify(value)}`;
      }
      return `${key}: ${JSON.stringify(value)}`;
    });
    return `{${formattedEntries.join(", ")}}`;
  };
  return `[${tokens.map(formatToken).join(", ")}]`;
};

// scripts/vite-plugins/generateEventIndexerConfig.ts
import dotenv4 from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/dotenv@16.3.1/node_modules/dotenv/lib/main.js";
import { promises as fs5 } from "fs";
import path4 from "path";
import { Project as Project4, VariableDeclarationKind as VariableDeclarationKind4 } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ts-morph@19.0.0/node_modules/ts-morph/dist/ts-morph.js";

// config/schemas/configuredEventIndexer.schema.json
var configuredEventIndexer_schema_default = {
  $id: "configuredEventIndexer.json",
  type: "object",
  properties: {
    configuredEventIndexer: {
      type: "array",
      items: {
        type: "object",
        properties: {
          chainIds: {
            type: "array",
            items: {
              type: "integer"
            }
          },
          url: {
            type: "string"
          }
        },
        required: ["chainIds", "url"]
      }
    }
  },
  required: ["configuredEventIndexer"]
};

// scripts/vite-plugins/generateEventIndexerConfig.ts
var __vite_injected_original_import_meta_url4 = "file:///home/jeff/code/taikochain/taiko-mono/packages/bridge-ui-v2/scripts/vite-plugins/generateEventIndexerConfig.ts";
dotenv4.config();
var pluginName4 = "generateEventIndexerConfig";
var logger5 = new PluginLogger(pluginName4);
var skip4 = process.env.SKIP_ENV_VALDIATION || false;
var currentDir4 = path4.resolve(new URL(__vite_injected_original_import_meta_url4).pathname);
var outputPath4 = path4.join(path4.dirname(currentDir4), "../../src/generated/eventIndexerConfig.ts");
function generateEventIndexerConfig() {
  return {
    name: pluginName4,
    async buildStart() {
      logger5.info("Plugin initialized.");
      let configuredEventIndexerConfigFile;
      if (!skip4) {
        if (!process.env.CONFIGURED_EVENT_INDEXER) {
          throw new Error(
            "CONFIGURED_EVENT_INDEXER is not defined in environment. Make sure to run the export step in the documentation."
          );
        }
        configuredEventIndexerConfigFile = decodeBase64ToJson(process.env.CONFIGURED_EVENT_INDEXER || "");
        const isValid = validateJsonAgainstSchema(configuredEventIndexerConfigFile, configuredEventIndexer_schema_default);
        if (!isValid) {
          throw new Error("encoded configuredBridges.json is not valid.");
        }
      } else {
        configuredEventIndexerConfigFile = "";
      }
      const tsFilePath = path4.resolve(outputPath4);
      const project = new Project4();
      const notification = `// Generated by ${pluginName4} on ${(/* @__PURE__ */ new Date()).toLocaleString()}`;
      const warning = `// WARNING: Do not change this file manually as it will be overwritten`;
      let sourceFile = project.createSourceFile(tsFilePath, `${notification}
${warning}
`, { overwrite: true });
      sourceFile = await storeTypesAndEnums(sourceFile);
      sourceFile = await buildEventIndexerConfig(sourceFile, configuredEventIndexerConfigFile);
      await sourceFile.save();
      const formatted = await formatSourceFile(tsFilePath);
      console.log("formatted", tsFilePath);
      await fs5.writeFile(tsFilePath, formatted);
      logger5.info(`Formatted config file saved to ${tsFilePath}`);
    }
  };
}
async function storeTypesAndEnums(sourceFile) {
  logger5.info(`Storing types...`);
  sourceFile.addImportDeclaration({
    namedImports: ["EventIndexerConfig"],
    moduleSpecifier: "$libs/eventIndexer",
    isTypeOnly: true
  });
  logger5.info("Types stored.");
  return sourceFile;
}
async function buildEventIndexerConfig(sourceFile, configuredEventIndexerConfigFile) {
  logger5.info("Building event indexer config...");
  const indexer = configuredEventIndexerConfigFile;
  if (!skip4) {
    if (!indexer.configuredEventIndexer || !Array.isArray(indexer.configuredEventIndexer)) {
      console.error(
        "configuredEventIndexer is not an array. Please check the content of the configuredEventIndexerConfigFile."
      );
      throw new Error();
    }
    const eventIndexerConfigVariable = {
      declarationKind: VariableDeclarationKind4.Const,
      declarations: [
        {
          name: "configuredEventIndexer",
          initializer: _formatObjectToTsLiteral4(indexer.configuredEventIndexer),
          type: "EventIndexerConfig[]"
        }
      ],
      isExported: true
    };
    sourceFile.addVariableStatement(eventIndexerConfigVariable);
  } else {
    const emptyEventIndexerConfigVariable = {
      declarationKind: VariableDeclarationKind4.Const,
      declarations: [
        {
          name: "configuredEventIndexer",
          initializer: "[]",
          type: "EventIndexerConfig[]"
        }
      ],
      isExported: true
    };
    sourceFile.addVariableStatement(emptyEventIndexerConfigVariable);
  }
  logger5.info("EventIndexer config built.");
  return sourceFile;
}
var _formatEventIndexerConfigToTsLiteral = (config) => {
  return `{chainIds: [${config.chainIds ? config.chainIds.join(", ") : ""}], url: "${config.url}"}`;
};
var _formatObjectToTsLiteral4 = (indexer) => {
  return `[${indexer.map(_formatEventIndexerConfigToTsLiteral).join(", ")}]`;
};

// scripts/vite-plugins/generateRelayerConfig.ts
import dotenv5 from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/dotenv@16.3.1/node_modules/dotenv/lib/main.js";
import { promises as fs6 } from "fs";
import path5 from "path";
import { Project as Project5, VariableDeclarationKind as VariableDeclarationKind5 } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/ts-morph@19.0.0/node_modules/ts-morph/dist/ts-morph.js";

// config/schemas/configuredRelayer.schema.json
var configuredRelayer_schema_default = {
  $id: "configuredRelayer.json",
  type: "object",
  properties: {
    configuredRelayer: {
      type: "array",
      items: {
        type: "object",
        properties: {
          chainIds: {
            type: "array",
            items: {
              type: "integer"
            }
          },
          url: {
            type: "string"
          }
        },
        required: ["chainIds", "url"]
      }
    }
  },
  required: ["configuredRelayer"]
};

// scripts/vite-plugins/generateRelayerConfig.ts
var __vite_injected_original_import_meta_url5 = "file:///home/jeff/code/taikochain/taiko-mono/packages/bridge-ui-v2/scripts/vite-plugins/generateRelayerConfig.ts";
dotenv5.config();
var pluginName5 = "generateRelayerConfig";
var logger6 = new PluginLogger(pluginName5);
var skip5 = process.env.SKIP_ENV_VALDIATION || false;
var currentDir5 = path5.resolve(new URL(__vite_injected_original_import_meta_url5).pathname);
var outputPath5 = path5.join(path5.dirname(currentDir5), "../../src/generated/relayerConfig.ts");
function generateRelayerConfig() {
  return {
    name: pluginName5,
    async buildStart() {
      logger6.info("Plugin initialized.");
      let configuredRelayerConfigFile;
      if (!skip5) {
        if (!process.env.CONFIGURED_RELAYER) {
          throw new Error(
            "CONFIGURED_RELAYER is not defined in environment. Make sure to run the export step in the documentation."
          );
        }
        configuredRelayerConfigFile = decodeBase64ToJson(process.env.CONFIGURED_RELAYER || "");
        const isValid = validateJsonAgainstSchema(configuredRelayerConfigFile, configuredRelayer_schema_default);
        if (!isValid) {
          throw new Error("encoded configuredBridges.json is not valid.");
        }
      } else {
        configuredRelayerConfigFile = "";
      }
      const tsFilePath = path5.resolve(outputPath5);
      const project = new Project5();
      const notification = `// Generated by ${pluginName5} on ${(/* @__PURE__ */ new Date()).toLocaleString()}`;
      const warning = `// WARNING: Do not change this file manually as it will be overwritten`;
      let sourceFile = project.createSourceFile(tsFilePath, `${notification}
${warning}
`, { overwrite: true });
      sourceFile = await storeTypesAndEnums2(sourceFile);
      sourceFile = await buildRelayerConfig(sourceFile, configuredRelayerConfigFile);
      await sourceFile.save();
      const formatted = await formatSourceFile(tsFilePath);
      console.log("formatted", tsFilePath);
      await fs6.writeFile(tsFilePath, formatted);
      logger6.info(`Formatted config file saved to ${tsFilePath}`);
    }
  };
}
async function storeTypesAndEnums2(sourceFile) {
  logger6.info(`Storing types...`);
  sourceFile.addImportDeclaration({
    namedImports: ["RelayerConfig"],
    moduleSpecifier: "$libs/relayer",
    isTypeOnly: true
  });
  logger6.info("Types stored.");
  return sourceFile;
}
async function buildRelayerConfig(sourceFile, configuredRelayerConfigFile) {
  logger6.info("Building relayer config...");
  const relayer = configuredRelayerConfigFile;
  if (!skip5) {
    if (!relayer.configuredRelayer || !Array.isArray(relayer.configuredRelayer)) {
      console.error("configuredRelayer is not an array. Please check the content of the configuredRelayerConfigFile.");
      throw new Error();
    }
    const relayerConfigVariable = {
      declarationKind: VariableDeclarationKind5.Const,
      declarations: [
        {
          name: "configuredRelayer",
          initializer: _formatObjectToTsLiteral5(relayer.configuredRelayer),
          type: "RelayerConfig[]"
        }
      ],
      isExported: true
    };
    sourceFile.addVariableStatement(relayerConfigVariable);
  } else {
    const emptyRelayerConfigVariable = {
      declarationKind: VariableDeclarationKind5.Const,
      declarations: [
        {
          name: "configuredRelayer",
          initializer: "[]",
          type: "RelayerConfig[]"
        }
      ],
      isExported: true
    };
    sourceFile.addVariableStatement(emptyRelayerConfigVariable);
  }
  logger6.info("Relayer config built.");
  return sourceFile;
}
var _formatRelayerConfigToTsLiteral = (config) => {
  return `{chainIds: [${config.chainIds ? config.chainIds.join(", ") : ""}], url: "${config.url}"}`;
};
var _formatObjectToTsLiteral5 = (relayers) => {
  return `[${relayers.map(_formatRelayerConfigToTsLiteral).join(", ")}]`;
};

// vite.config.ts
var vite_config_default = defineConfig({
  build: {
    sourcemap: true
  },
  plugins: [
    sveltekit(),
    // This plugin gives vite the ability to resolve imports using TypeScript's path mapping.
    // https://www.npmjs.com/package/vite-tsconfig-paths
    tsconfigPaths(),
    generateBridgeConfig(),
    generateChainConfig(),
    generateRelayerConfig(),
    generateCustomTokenConfig(),
    generateEventIndexerConfig()
  ],
  test: {
    environment: "jsdom",
    globals: true,
    include: ["src/**/*.{test,spec}.{js,ts}"]
  }
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiLCAic2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVCcmlkZ2VDb25maWcudHMiLCAiY29uZmlnL3NjaGVtYXMvY29uZmlndXJlZEJyaWRnZXMuc2NoZW1hLmpzb24iLCAic2NyaXB0cy91dGlscy9kZWNvZGVCYXNlNjRUb0pzb24udHMiLCAic2NyaXB0cy91dGlscy9mb3JtYXRTb3VyY2VGaWxlLnRzIiwgInNjcmlwdHMvdXRpbHMvUGx1Z2luTG9nZ2VyLmpzIiwgInNjcmlwdHMvdXRpbHMvdmFsaWRhdGVKc29uLnRzIiwgInNjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQ2hhaW5Db25maWcudHMiLCAiY29uZmlnL3NjaGVtYXMvY29uZmlndXJlZENoYWlucy5zY2hlbWEuanNvbiIsICJzY3JpcHRzL3ZpdGUtcGx1Z2lucy9nZW5lcmF0ZUN1c3RvbVRva2VuQ29uZmlnLnRzIiwgInNjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlRXZlbnRJbmRleGVyQ29uZmlnLnRzIiwgImNvbmZpZy9zY2hlbWFzL2NvbmZpZ3VyZWRFdmVudEluZGV4ZXIuc2NoZW1hLmpzb24iLCAic2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVSZWxheWVyQ29uZmlnLnRzIiwgImNvbmZpZy9zY2hlbWFzL2NvbmZpZ3VyZWRSZWxheWVyLnNjaGVtYS5qc29uIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjJcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3ZpdGUuY29uZmlnLnRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3ZpdGUuY29uZmlnLnRzXCI7aW1wb3J0IHsgc3ZlbHRla2l0IH0gZnJvbSAnQHN2ZWx0ZWpzL2tpdC92aXRlJztcbmltcG9ydCB0c2NvbmZpZ1BhdGhzIGZyb20gJ3ZpdGUtdHNjb25maWctcGF0aHMnO1xuaW1wb3J0IHsgZGVmaW5lQ29uZmlnIH0gZnJvbSAndml0ZXN0L2Rpc3QvY29uZmlnJztcblxuaW1wb3J0IHsgZ2VuZXJhdGVCcmlkZ2VDb25maWcgfSBmcm9tICcuL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQnJpZGdlQ29uZmlnJztcbmltcG9ydCB7IGdlbmVyYXRlQ2hhaW5Db25maWcgfSBmcm9tICcuL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQ2hhaW5Db25maWcnO1xuaW1wb3J0IHsgZ2VuZXJhdGVDdXN0b21Ub2tlbkNvbmZpZyB9IGZyb20gJy4vc2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVDdXN0b21Ub2tlbkNvbmZpZyc7XG5pbXBvcnQgeyBnZW5lcmF0ZUV2ZW50SW5kZXhlckNvbmZpZyB9IGZyb20gJy4vc2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVFdmVudEluZGV4ZXJDb25maWcnO1xuaW1wb3J0IHsgZ2VuZXJhdGVSZWxheWVyQ29uZmlnIH0gZnJvbSAnLi9zY3JpcHRzL3ZpdGUtcGx1Z2lucy9nZW5lcmF0ZVJlbGF5ZXJDb25maWcnO1xuXG5leHBvcnQgZGVmYXVsdCBkZWZpbmVDb25maWcoe1xuICBidWlsZDoge1xuICAgIHNvdXJjZW1hcDogdHJ1ZSxcbiAgfSxcbiAgcGx1Z2luczogW1xuICAgIHN2ZWx0ZWtpdCgpLFxuICAgIC8vIFRoaXMgcGx1Z2luIGdpdmVzIHZpdGUgdGhlIGFiaWxpdHkgdG8gcmVzb2x2ZSBpbXBvcnRzIHVzaW5nIFR5cGVTY3JpcHQncyBwYXRoIG1hcHBpbmcuXG4gICAgLy8gaHR0cHM6Ly93d3cubnBtanMuY29tL3BhY2thZ2Uvdml0ZS10c2NvbmZpZy1wYXRoc1xuICAgIHRzY29uZmlnUGF0aHMoKSxcbiAgICBnZW5lcmF0ZUJyaWRnZUNvbmZpZygpLFxuICAgIGdlbmVyYXRlQ2hhaW5Db25maWcoKSxcbiAgICBnZW5lcmF0ZVJlbGF5ZXJDb25maWcoKSxcbiAgICBnZW5lcmF0ZUN1c3RvbVRva2VuQ29uZmlnKCksXG4gICAgZ2VuZXJhdGVFdmVudEluZGV4ZXJDb25maWcoKSxcbiAgXSxcbiAgdGVzdDoge1xuICAgIGVudmlyb25tZW50OiAnanNkb20nLFxuICAgIGdsb2JhbHM6IHRydWUsXG4gICAgaW5jbHVkZTogWydzcmMvKiovKi57dGVzdCxzcGVjfS57anMsdHN9J10sXG4gIH0sXG59KTtcbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQnJpZGdlQ29uZmlnLnRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQnJpZGdlQ29uZmlnLnRzXCI7aW1wb3J0IGRvdGVudiBmcm9tICdkb3RlbnYnO1xuaW1wb3J0IHsgcHJvbWlzZXMgYXMgZnMgfSBmcm9tICdmcyc7XG5pbXBvcnQgcGF0aCBmcm9tICdwYXRoJztcbmltcG9ydCB7IFByb2plY3QsIFNvdXJjZUZpbGUsIFZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIH0gZnJvbSAndHMtbW9ycGgnO1xuXG5pbXBvcnQgY29uZmlndXJlZEJyaWRnZXNTY2hlbWEgZnJvbSAnLi4vLi4vY29uZmlnL3NjaGVtYXMvY29uZmlndXJlZEJyaWRnZXMuc2NoZW1hLmpzb24nO1xuaW1wb3J0IHR5cGUgeyBCcmlkZ2VDb25maWcsIENvbmZpZ3VyZWRCcmlkZ2VzVHlwZSwgUm91dGluZ01hcCB9IGZyb20gJy4uLy4uL3NyYy9saWJzL2JyaWRnZS90eXBlcyc7XG5pbXBvcnQgeyBkZWNvZGVCYXNlNjRUb0pzb24gfSBmcm9tICcuLi91dGlscy9kZWNvZGVCYXNlNjRUb0pzb24nO1xuaW1wb3J0IHsgZm9ybWF0U291cmNlRmlsZSB9IGZyb20gJy4uL3V0aWxzL2Zvcm1hdFNvdXJjZUZpbGUnO1xuaW1wb3J0IHsgUGx1Z2luTG9nZ2VyIH0gZnJvbSAnLi4vdXRpbHMvUGx1Z2luTG9nZ2VyJztcbmltcG9ydCB7IHZhbGlkYXRlSnNvbkFnYWluc3RTY2hlbWEgfSBmcm9tICcuLi91dGlscy92YWxpZGF0ZUpzb24nO1xuXG5kb3RlbnYuY29uZmlnKCk7XG5jb25zdCBwbHVnaW5OYW1lID0gJ2dlbmVyYXRlQnJpZGdlQ29uZmlnJztcbmNvbnN0IGxvZ2dlciA9IG5ldyBQbHVnaW5Mb2dnZXIocGx1Z2luTmFtZSk7XG5cbmNvbnN0IHNraXAgPSBwcm9jZXNzLmVudi5TS0lQX0VOVl9WQUxESUFUSU9OIHx8IGZhbHNlO1xuXG5jb25zdCBjdXJyZW50RGlyID0gcGF0aC5yZXNvbHZlKG5ldyBVUkwoaW1wb3J0Lm1ldGEudXJsKS5wYXRobmFtZSk7XG5cbmNvbnN0IG91dHB1dFBhdGggPSBwYXRoLmpvaW4ocGF0aC5kaXJuYW1lKGN1cnJlbnREaXIpLCAnLi4vLi4vc3JjL2dlbmVyYXRlZC9icmlkZ2VDb25maWcudHMnKTtcblxuZXhwb3J0IGZ1bmN0aW9uIGdlbmVyYXRlQnJpZGdlQ29uZmlnKCkge1xuICByZXR1cm4ge1xuICAgIG5hbWU6IHBsdWdpbk5hbWUsXG4gICAgYXN5bmMgYnVpbGRTdGFydCgpIHtcbiAgICAgIGxvZ2dlci5pbmZvKCdQbHVnaW4gaW5pdGlhbGl6ZWQuJyk7XG4gICAgICBsZXQgY29uZmlndXJlZEJyaWRnZXNDb25maWdGaWxlO1xuICAgICAgaWYgKCFza2lwKSB7XG4gICAgICAgIGlmICghcHJvY2Vzcy5lbnYuQ09ORklHVVJFRF9CUklER0VTKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKFxuICAgICAgICAgICAgJ0NPTkZJR1VSRURfQlJJREdFUyBpcyBub3QgZGVmaW5lZCBpbiBlbnZpcm9ubWVudC4gTWFrZSBzdXJlIHRvIHJ1biB0aGUgZXhwb3J0IHN0ZXAgaW4gdGhlIGRvY3VtZW50YXRpb24uJyxcbiAgICAgICAgICApO1xuICAgICAgICB9XG5cbiAgICAgICAgLy8gRGVjb2RlIGJhc2U2NCBlbmNvZGVkIEpTT04gc3RyaW5nXG4gICAgICAgIGNvbmZpZ3VyZWRCcmlkZ2VzQ29uZmlnRmlsZSA9IGRlY29kZUJhc2U2NFRvSnNvbihwcm9jZXNzLmVudi5DT05GSUdVUkVEX0JSSURHRVMgfHwgJycpO1xuXG4gICAgICAgIC8vIFZhbGlkZSBKU09OIGFnYWluc3Qgc2NoZW1hXG4gICAgICAgIGNvbnN0IGlzVmFsaWQgPSB2YWxpZGF0ZUpzb25BZ2FpbnN0U2NoZW1hKGNvbmZpZ3VyZWRCcmlkZ2VzQ29uZmlnRmlsZSwgY29uZmlndXJlZEJyaWRnZXNTY2hlbWEpO1xuXG4gICAgICAgIGlmICghaXNWYWxpZCkge1xuICAgICAgICAgIHRocm93IG5ldyBFcnJvcignZW5jb2RlZCBjb25maWd1cmVkQnJpZGdlcy5qc29uIGlzIG5vdCB2YWxpZC4nKTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAgY29uZmlndXJlZEJyaWRnZXNDb25maWdGaWxlID0gJyc7XG4gICAgICB9XG5cbiAgICAgIGNvbnN0IHRzRmlsZVBhdGggPSBwYXRoLnJlc29sdmUob3V0cHV0UGF0aCk7XG5cbiAgICAgIGNvbnN0IHByb2plY3QgPSBuZXcgUHJvamVjdCgpO1xuICAgICAgY29uc3Qgbm90aWZpY2F0aW9uID0gYC8vIEdlbmVyYXRlZCBieSAke3BsdWdpbk5hbWV9IG9uICR7bmV3IERhdGUoKS50b0xvY2FsZVN0cmluZygpfWA7XG4gICAgICBjb25zdCB3YXJuaW5nID0gYC8vIFdBUk5JTkc6IERvIG5vdCBjaGFuZ2UgdGhpcyBmaWxlIG1hbnVhbGx5IGFzIGl0IHdpbGwgYmUgb3ZlcndyaXR0ZW5gO1xuXG4gICAgICBsZXQgc291cmNlRmlsZSA9IHByb2plY3QuY3JlYXRlU291cmNlRmlsZSh0c0ZpbGVQYXRoLCBgJHtub3RpZmljYXRpb259XFxuJHt3YXJuaW5nfVxcbmAsIHsgb3ZlcndyaXRlOiB0cnVlIH0pO1xuXG4gICAgICAvLyBDcmVhdGUgdGhlIFR5cGVTY3JpcHQgY29udGVudFxuICAgICAgc291cmNlRmlsZSA9IGF3YWl0IHN0b3JlVHlwZXMoc291cmNlRmlsZSk7XG4gICAgICBzb3VyY2VGaWxlID0gYXdhaXQgYnVpbGRCcmlkZ2VDb25maWcoc291cmNlRmlsZSwgY29uZmlndXJlZEJyaWRnZXNDb25maWdGaWxlKTtcblxuICAgICAgLy8gU2F2ZSB0aGUgZmlsZVxuICAgICAgYXdhaXQgc291cmNlRmlsZS5zYXZlU3luYygpO1xuICAgICAgbG9nZ2VyLmluZm8oYEdlbmVyYXRlZCBjb25maWcgZmlsZWApO1xuXG4gICAgICBhd2FpdCBzb3VyY2VGaWxlLnNhdmVTeW5jKCk7XG5cbiAgICAgIGNvbnN0IGZvcm1hdHRlZCA9IGF3YWl0IGZvcm1hdFNvdXJjZUZpbGUodHNGaWxlUGF0aCk7XG5cbiAgICAgIC8vIFdyaXRlIHRoZSBmb3JtYXR0ZWQgY29kZSBiYWNrIHRvIHRoZSBmaWxlXG4gICAgICBhd2FpdCBmcy53cml0ZUZpbGUodHNGaWxlUGF0aCwgZm9ybWF0dGVkKTtcbiAgICAgIGxvZ2dlci5pbmZvKGBGb3JtYXR0ZWQgY29uZmlnIGZpbGUgc2F2ZWQgdG8gJHt0c0ZpbGVQYXRofWApO1xuICAgIH0sXG4gIH07XG59XG5cbmFzeW5jIGZ1bmN0aW9uIHN0b3JlVHlwZXMoc291cmNlRmlsZTogU291cmNlRmlsZSkge1xuICBsb2dnZXIuaW5mbyhgU3RvcmluZyB0eXBlcy4uLmApO1xuXG4gIC8vIFJvdXRpbmdNYXBcbiAgc291cmNlRmlsZS5hZGRJbXBvcnREZWNsYXJhdGlvbih7XG4gICAgbmFtZWRJbXBvcnRzOiBbJ1JvdXRpbmdNYXAnXSxcbiAgICBtb2R1bGVTcGVjaWZpZXI6ICckbGlicy9icmlkZ2UnLFxuICAgIGlzVHlwZU9ubHk6IHRydWUsXG4gIH0pO1xuXG4gIGxvZ2dlci5pbmZvKCdUeXBlIHN0b3JlZC4nKTtcbiAgcmV0dXJuIHNvdXJjZUZpbGU7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIGJ1aWxkQnJpZGdlQ29uZmlnKHNvdXJjZUZpbGU6IFNvdXJjZUZpbGUsIGNvbmZpZ3VyZWRCcmlkZ2VzQ29uZmlnRmlsZTogQ29uZmlndXJlZEJyaWRnZXNUeXBlKSB7XG4gIGxvZ2dlci5pbmZvKCdCdWlsZGluZyBicmlkZ2UgY29uZmlnLi4uJyk7XG4gIGNvbnN0IHJvdXRpbmdDb250cmFjdHNNYXA6IFJvdXRpbmdNYXAgPSB7fTtcblxuICBjb25zdCBicmlkZ2VzOiBDb25maWd1cmVkQnJpZGdlc1R5cGUgPSBjb25maWd1cmVkQnJpZGdlc0NvbmZpZ0ZpbGU7XG5cbiAgaWYgKCFza2lwKSB7XG4gICAgaWYgKCFicmlkZ2VzLmNvbmZpZ3VyZWRCcmlkZ2VzIHx8ICFBcnJheS5pc0FycmF5KGJyaWRnZXMuY29uZmlndXJlZEJyaWRnZXMpKSB7XG4gICAgICBsb2dnZXIuZXJyb3IoJ2NvbmZpZ3VyZWRCcmlkZ2VzIGlzIG5vdCBhbiBhcnJheS4gUGxlYXNlIGNoZWNrIHRoZSBjb250ZW50IG9mIHRoZSBjb25maWd1cmVkQnJpZGdlc0NvbmZpZ0ZpbGUuJyk7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoKTtcbiAgICB9XG4gICAgYnJpZGdlcy5jb25maWd1cmVkQnJpZGdlcy5mb3JFYWNoKChpdGVtOiBCcmlkZ2VDb25maWcpID0+IHtcbiAgICAgIGlmICghcm91dGluZ0NvbnRyYWN0c01hcFtpdGVtLnNvdXJjZV0pIHtcbiAgICAgICAgcm91dGluZ0NvbnRyYWN0c01hcFtpdGVtLnNvdXJjZV0gPSB7fTtcbiAgICAgIH1cbiAgICAgIHJvdXRpbmdDb250cmFjdHNNYXBbaXRlbS5zb3VyY2VdW2l0ZW0uZGVzdGluYXRpb25dID0gaXRlbS5hZGRyZXNzZXM7XG4gICAgfSk7XG4gIH1cbiAgaWYgKHNraXApIHtcbiAgICAvLyBBZGQgZW1wdHkgcm91dGluZ0NvbnRyYWN0c01hcCB2YXJpYWJsZVxuICAgIHNvdXJjZUZpbGUuYWRkVmFyaWFibGVTdGF0ZW1lbnQoe1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ3JvdXRpbmdDb250cmFjdHNNYXAnLFxuICAgICAgICAgIHR5cGU6ICdSb3V0aW5nTWFwJyxcbiAgICAgICAgICBpbml0aWFsaXplcjogJ3t9JyxcbiAgICAgICAgfSxcbiAgICAgIF0sXG4gICAgICBpc0V4cG9ydGVkOiB0cnVlLFxuICAgIH0pO1xuICAgIGxvZ2dlci5pbmZvKGBTa2lwcGVkIGJyaWRnZS5gKTtcbiAgfSBlbHNlIHtcbiAgICAvLyBBZGQgcm91dGluZ0NvbnRyYWN0c01hcCB2YXJpYWJsZVxuICAgIHNvdXJjZUZpbGUuYWRkVmFyaWFibGVTdGF0ZW1lbnQoe1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ3JvdXRpbmdDb250cmFjdHNNYXAnLFxuICAgICAgICAgIHR5cGU6ICdSb3V0aW5nTWFwJyxcbiAgICAgICAgICBpbml0aWFsaXplcjogX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsKHJvdXRpbmdDb250cmFjdHNNYXApLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfSk7XG4gICAgbG9nZ2VyLmluZm8oYENvbmZpZ3VyZWQgJHticmlkZ2VzLmNvbmZpZ3VyZWRCcmlkZ2VzLmxlbmd0aH0gYnJpZGdlcy5gKTtcbiAgfVxuICByZXR1cm4gc291cmNlRmlsZTtcbn1cblxuY29uc3QgX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsID0gKG9iajogUm91dGluZ01hcCk6IHN0cmluZyA9PiB7XG4gIGNvbnN0IGZvcm1hdFZhbHVlID0gKHZhbHVlOiBzdHJpbmcgfCBudW1iZXIgfCBib29sZWFuIHwgbnVsbCk6IHN0cmluZyA9PiB7XG4gICAgaWYgKHR5cGVvZiB2YWx1ZSA9PT0gJ3N0cmluZycpIHtcbiAgICAgIHJldHVybiBgXCIke3ZhbHVlfVwiYDtcbiAgICB9XG4gICAgcmV0dXJuIFN0cmluZyh2YWx1ZSk7XG4gIH07XG5cbiAgY29uc3QgZW50cmllcyA9IE9iamVjdC5lbnRyaWVzKG9iaik7XG4gIGNvbnN0IGZvcm1hdHRlZEVudHJpZXMgPSBlbnRyaWVzLm1hcCgoW2tleSwgdmFsdWVdKSA9PiB7XG4gICAgY29uc3QgaW5uZXJFbnRyaWVzID0gT2JqZWN0LmVudHJpZXModmFsdWUpO1xuICAgIGNvbnN0IGlubmVyRm9ybWF0dGVkRW50cmllcyA9IGlubmVyRW50cmllcy5tYXAoKFtpbm5lcktleSwgaW5uZXJWYWx1ZV0pID0+IHtcbiAgICAgIGNvbnN0IGlubmVySW5uZXJFbnRyaWVzID0gT2JqZWN0LmVudHJpZXMoaW5uZXJWYWx1ZSk7XG4gICAgICBjb25zdCBpbm5lcklubmVyRm9ybWF0dGVkRW50cmllcyA9IGlubmVySW5uZXJFbnRyaWVzLm1hcChcbiAgICAgICAgKFtpbm5lcklubmVyS2V5LCBpbm5lcklubmVyVmFsdWVdKSA9PiBgJHtpbm5lcklubmVyS2V5fTogJHtmb3JtYXRWYWx1ZShpbm5lcklubmVyVmFsdWUpfWAsXG4gICAgICApO1xuICAgICAgcmV0dXJuIGAke2lubmVyS2V5fTogeyR7aW5uZXJJbm5lckZvcm1hdHRlZEVudHJpZXMuam9pbignLCAnKX19YDtcbiAgICB9KTtcbiAgICByZXR1cm4gYCR7a2V5fTogeyR7aW5uZXJGb3JtYXR0ZWRFbnRyaWVzLmpvaW4oJywgJyl9fWA7XG4gIH0pO1xuXG4gIHJldHVybiBgeyR7Zm9ybWF0dGVkRW50cmllcy5qb2luKCcsICcpfX1gO1xufTtcbiIsICJ7XG4gIFwiJGlkXCI6IFwiY29uZmlndXJlZEJyaWRnZXMuanNvblwiLFxuICBcInR5cGVcIjogXCJvYmplY3RcIixcbiAgXCJwcm9wZXJ0aWVzXCI6IHtcbiAgICBcImNvbmZpZ3VyZWRCcmlkZ2VzXCI6IHtcbiAgICAgIFwidHlwZVwiOiBcImFycmF5XCIsXG4gICAgICBcIml0ZW1zXCI6IHtcbiAgICAgICAgXCJ0eXBlXCI6IFwib2JqZWN0XCIsXG4gICAgICAgIFwicHJvcGVydGllc1wiOiB7XG4gICAgICAgICAgXCJzb3VyY2VcIjoge1xuICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICB9LFxuICAgICAgICAgIFwiZGVzdGluYXRpb25cIjoge1xuICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICB9LFxuICAgICAgICAgIFwiYWRkcmVzc2VzXCI6IHtcbiAgICAgICAgICAgIFwidHlwZVwiOiBcIm9iamVjdFwiLFxuICAgICAgICAgICAgXCJwcm9wZXJ0aWVzXCI6IHtcbiAgICAgICAgICAgICAgXCJicmlkZ2VBZGRyZXNzXCI6IHtcbiAgICAgICAgICAgICAgICBcInR5cGVcIjogXCJzdHJpbmdcIlxuICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgICBcImVyYzIwVmF1bHRBZGRyZXNzXCI6IHtcbiAgICAgICAgICAgICAgICBcInR5cGVcIjogXCJzdHJpbmdcIlxuICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgICBcImV0aGVyVmF1bHRBZGRyZXNzXCI6IHtcbiAgICAgICAgICAgICAgICBcInR5cGVcIjogXCJzdHJpbmdcIlxuICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgICBcImVyYzcyMVZhdWx0QWRkcmVzc1wiOiB7XG4gICAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgICAgfSxcbiAgICAgICAgICAgICAgXCJlcmMxMTU1VmF1bHRBZGRyZXNzXCI6IHtcbiAgICAgICAgICAgICAgICBcInR5cGVcIjogXCJzdHJpbmdcIlxuICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgICBcImNyb3NzQ2hhaW5TeW5jQWRkcmVzc1wiOiB7XG4gICAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgICAgfSxcbiAgICAgICAgICAgICAgXCJzaWduYWxTZXJ2aWNlQWRkcmVzc1wiOiB7XG4gICAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgfSxcbiAgICAgICAgICAgIFwicmVxdWlyZWRcIjogW1xuICAgICAgICAgICAgICBcImJyaWRnZUFkZHJlc3NcIixcbiAgICAgICAgICAgICAgXCJlcmMyMFZhdWx0QWRkcmVzc1wiLFxuICAgICAgICAgICAgICBcImVyYzcyMVZhdWx0QWRkcmVzc1wiLFxuICAgICAgICAgICAgICBcImVyYzExNTVWYXVsdEFkZHJlc3NcIixcbiAgICAgICAgICAgICAgXCJjcm9zc0NoYWluU3luY0FkZHJlc3NcIixcbiAgICAgICAgICAgICAgXCJzaWduYWxTZXJ2aWNlQWRkcmVzc1wiXG4gICAgICAgICAgICBdLFxuICAgICAgICAgICAgXCJhZGRpdGlvbmFsUHJvcGVydGllc1wiOiBmYWxzZVxuICAgICAgICAgIH1cbiAgICAgICAgfSxcbiAgICAgICAgXCJyZXF1aXJlZFwiOiBbXCJzb3VyY2VcIiwgXCJkZXN0aW5hdGlvblwiLCBcImFkZHJlc3Nlc1wiXSxcbiAgICAgICAgXCJhZGRpdGlvbmFsUHJvcGVydGllc1wiOiBmYWxzZVxuICAgICAgfVxuICAgIH1cbiAgfSxcbiAgXCJyZXF1aXJlZFwiOiBbXCJjb25maWd1cmVkQnJpZGdlc1wiXSxcbiAgXCJhZGRpdGlvbmFsUHJvcGVydGllc1wiOiBmYWxzZVxufVxuIiwgImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCIvaG9tZS9qZWZmL2NvZGUvdGFpa29jaGFpbi90YWlrby1tb25vL3BhY2thZ2VzL2JyaWRnZS11aS12Mi9zY3JpcHRzL3V0aWxzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ZpbGVuYW1lID0gXCIvaG9tZS9qZWZmL2NvZGUvdGFpa29jaGFpbi90YWlrby1tb25vL3BhY2thZ2VzL2JyaWRnZS11aS12Mi9zY3JpcHRzL3V0aWxzL2RlY29kZUJhc2U2NFRvSnNvbi50c1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwgPSBcImZpbGU6Ly8vaG9tZS9qZWZmL2NvZGUvdGFpa29jaGFpbi90YWlrby1tb25vL3BhY2thZ2VzL2JyaWRnZS11aS12Mi9zY3JpcHRzL3V0aWxzL2RlY29kZUJhc2U2NFRvSnNvbi50c1wiO2ltcG9ydCB7IEJ1ZmZlciB9IGZyb20gJ2J1ZmZlcic7XG5cbmV4cG9ydCBjb25zdCBkZWNvZGVCYXNlNjRUb0pzb24gPSAoYmFzZTY0OiBzdHJpbmcpID0+IHtcbiAgcmV0dXJuIEpTT04ucGFyc2UoQnVmZmVyLmZyb20oYmFzZTY0LCAnYmFzZTY0JykudG9TdHJpbmcoJ3V0Zi04JykpO1xufTtcbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy91dGlsc1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy91dGlscy9mb3JtYXRTb3VyY2VGaWxlLnRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHMvZm9ybWF0U291cmNlRmlsZS50c1wiO2ltcG9ydCB7IHByb21pc2VzIGFzIGZzIH0gZnJvbSAnZnMnO1xuaW1wb3J0ICogYXMgcHJldHRpZXIgZnJvbSAncHJldHRpZXInO1xuXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gZm9ybWF0U291cmNlRmlsZSh0c0ZpbGVQYXRoOiBzdHJpbmcpIHtcbiAgY29uc3QgZ2VuZXJhdGVkQ29kZSA9IGF3YWl0IGZzLnJlYWRGaWxlKHRzRmlsZVBhdGgsICd1dGYtOCcpO1xuXG4gIC8vIEZvcm1hdCB0aGUgY29kZSB1c2luZyBQcmV0dGllclxuICByZXR1cm4gYXdhaXQgcHJldHRpZXIuZm9ybWF0KGdlbmVyYXRlZENvZGUsIHsgcGFyc2VyOiAndHlwZXNjcmlwdCcgfSk7XG59XG4iLCAiY29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2Rpcm5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHMvUGx1Z2luTG9nZ2VyLmpzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHMvUGx1Z2luTG9nZ2VyLmpzXCI7LyogZXNsaW50LWRpc2FibGUgbm8tY29uc29sZSAqL1xuY29uc3QgRmdNYWdlbnRhID0gJ1xceDFiWzM1bSc7XG5jb25zdCBGZ1llbGxvdyA9ICdcXHgxYlszM20nO1xuY29uc3QgRmdSZWQgPSAnXFx4MWJbMzFtJztcbmNvbnN0IEJyaWdodCA9ICdcXHgxYlsxbSc7XG5jb25zdCBSZXNldCA9ICdcXHgxYlswbSc7XG5cbmNvbnN0IHRpbWVzdGFtcCA9ICgpID0+IG5ldyBEYXRlKCkudG9Mb2NhbGVUaW1lU3RyaW5nKCk7XG5cbmV4cG9ydCBjbGFzcyBQbHVnaW5Mb2dnZXIge1xuICAvKipcbiAgICogQHBhcmFtIHtzdHJpbmd9IHBsdWdpbk5hbWVcbiAgICovXG4gIGNvbnN0cnVjdG9yKHBsdWdpbk5hbWUpIHtcbiAgICB0aGlzLnBsdWdpbk5hbWUgPSBwbHVnaW5OYW1lO1xuICB9XG5cbiAgLyoqXG4gICAqIEBwYXJhbSB7c3RyaW5nfSBtZXNzYWdlXG4gICAqL1xuICBpbmZvKG1lc3NhZ2UpIHtcbiAgICB0aGlzLl9sb2dXaXRoQ29sb3IoRmdNYWdlbnRhLCBtZXNzYWdlKTtcbiAgfVxuXG4gIC8qKlxuICAgKiBAcGFyYW0ge2FueX0gbWVzc2FnZVxuICAgKi9cbiAgd2FybihtZXNzYWdlKSB7XG4gICAgdGhpcy5fbG9nV2l0aENvbG9yKEZnWWVsbG93LCBtZXNzYWdlKTtcbiAgfVxuXG4gIC8qKlxuICAgKiBAcGFyYW0ge3N0cmluZ30gbWVzc2FnZVxuICAgKi9cbiAgZXJyb3IobWVzc2FnZSkge1xuICAgIHRoaXMuX2xvZ1dpdGhDb2xvcihGZ1JlZCwgbWVzc2FnZSwgdHJ1ZSk7XG4gIH1cblxuICAvKipcbiAgICogQHBhcmFtIHtzdHJpbmd9IGNvbG9yXG4gICAqIEBwYXJhbSB7YW55fSBtZXNzYWdlXG4gICAqL1xuICBfbG9nV2l0aENvbG9yKGNvbG9yLCBtZXNzYWdlLCBpc0Vycm9yID0gZmFsc2UpIHtcbiAgICBjb25zb2xlLmxvZyhcbiAgICAgIGAke2NvbG9yfSR7dGltZXN0YW1wKCl9JHtCcmlnaHR9IFske3RoaXMucGx1Z2luTmFtZX1dJHtSZXNldH0ke2lzRXJyb3IgPyBjb2xvciA6ICcnfSAke21lc3NhZ2V9ICR7XG4gICAgICAgIGlzRXJyb3IgPyBSZXNldCA6ICcnXG4gICAgICB9IGAsXG4gICAgKTtcbiAgfVxufVxuXG4vLyBVc2FnZVxuLy8gY29uc3QgbG9nZ2VyID0gbmV3IExvZ2dlcihcInBsdWdpbi1uYW1lXCIpO1xuXG4vLyBsb2dnZXIuaW5mbyhcIlRoaXMgaXMgYSBsb2cgbWVzc2FnZS5cIik7ICAvLyBMb2dzIGluIG1hZ2VudGFcbi8vIGxvZ2dlci53YXJuKFwiVGhpcyBpcyBhIHdhcm5pbmcgbWVzc2FnZS5cIik7ICAvLyBMb2dzIGluIHllbGxvd1xuLy8gbG9nZ2VyLmVycm9yKFwiVGhpcyBpcyBhbiBlcnJvciBtZXNzYWdlLlwiKTsgIC8vIExvZ3MgaW4gcmVkXG4iLCAiY29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2Rpcm5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHMvdmFsaWRhdGVKc29uLnRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdXRpbHMvdmFsaWRhdGVKc29uLnRzXCI7LyogZXNsaW50LWRpc2FibGUgbm8tY29uc29sZSAqL1xuaW1wb3J0IEFqdiwgeyB0eXBlIFNjaGVtYSB9IGZyb20gJ2Fqdic7XG5cbmltcG9ydCB7IFBsdWdpbkxvZ2dlciB9IGZyb20gJy4vUGx1Z2luTG9nZ2VyJztcblxuY29uc3QgYWp2ID0gbmV3IEFqdih7IHN0cmljdDogZmFsc2UgfSk7XG5cbnR5cGUgU2NobWFXaXRoSWQgPSBTY2hlbWEgJiB7ICRpZD86IHN0cmluZyB9O1xuXG5jb25zdCBsb2dnZXIgPSBuZXcgUGx1Z2luTG9nZ2VyKCdqc29uLXZhbGlkYXRvcicpO1xuXG5leHBvcnQgY29uc3QgdmFsaWRhdGVKc29uQWdhaW5zdFNjaGVtYSA9IChqc29uOiBKU09OLCBzY2hlbWE6IFNjaG1hV2l0aElkKTogYm9vbGVhbiA9PiB7XG4gIGxvZ2dlci5pbmZvKGBWYWxpZGF0aW5nICR7c2NoZW1hLiRpZH1gKTtcbiAgY29uc3QgdmFsaWRhdGUgPSBhanYuY29tcGlsZShzY2hlbWEpO1xuXG4gIGNvbnN0IHZhbGlkID0gdmFsaWRhdGUoanNvbik7XG5cbiAgaWYgKCF2YWxpZCkge1xuICAgIGxvZ2dlci5lcnJvcignVmFsaWRhdGlvbiBmYWlsZWQuJyk7XG4gICAgY29uc29sZS5lcnJvcignRXJyb3IgZGV0YWlsczonLCBhanYuZXJyb3JzKTtcbiAgICByZXR1cm4gZmFsc2U7XG4gIH1cbiAgbG9nZ2VyLmluZm8oYFZhbGlkYXRpb24gb2YgJHtzY2hlbWEuJGlkfSBzdWNjZWVkZWQuYCk7XG4gIHJldHVybiB0cnVlO1xufTtcbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQ2hhaW5Db25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVDaGFpbkNvbmZpZy50c1wiOy8qIGVzbGludC1kaXNhYmxlIG5vLWNvbnNvbGUgKi9cbmltcG9ydCBkb3RlbnYgZnJvbSAnZG90ZW52JztcbmltcG9ydCB7IHByb21pc2VzIGFzIGZzIH0gZnJvbSAnZnMnO1xuaW1wb3J0IHBhdGggZnJvbSAncGF0aCc7XG5pbXBvcnQgeyBQcm9qZWN0LCBTb3VyY2VGaWxlLCBWYXJpYWJsZURlY2xhcmF0aW9uS2luZCB9IGZyb20gJ3RzLW1vcnBoJztcblxuaW1wb3J0IGNvbmZpZ3VyZWRDaGFpbnNTY2hlbWEgZnJvbSAnLi4vLi4vY29uZmlnL3NjaGVtYXMvY29uZmlndXJlZENoYWlucy5zY2hlbWEuanNvbic7XG5pbXBvcnQgdHlwZSB7IENoYWluQ29uZmlnLCBDaGFpbkNvbmZpZ01hcCwgQ29uZmlndXJlZENoYWlucyB9IGZyb20gJy4uLy4uL3NyYy9saWJzL2NoYWluL3R5cGVzJztcbmltcG9ydCB7IGRlY29kZUJhc2U2NFRvSnNvbiB9IGZyb20gJy4vLi4vdXRpbHMvZGVjb2RlQmFzZTY0VG9Kc29uJztcbmltcG9ydCB7IGZvcm1hdFNvdXJjZUZpbGUgfSBmcm9tICcuLy4uL3V0aWxzL2Zvcm1hdFNvdXJjZUZpbGUnO1xuaW1wb3J0IHsgUGx1Z2luTG9nZ2VyIH0gZnJvbSAnLi8uLi91dGlscy9QbHVnaW5Mb2dnZXInO1xuaW1wb3J0IHsgdmFsaWRhdGVKc29uQWdhaW5zdFNjaGVtYSB9IGZyb20gJy4vLi4vdXRpbHMvdmFsaWRhdGVKc29uJztcbmRvdGVudi5jb25maWcoKTtcblxuY29uc3QgcGx1Z2luTmFtZSA9ICdnZW5lcmF0ZUNoYWluQ29uZmlnJztcbmNvbnN0IGxvZ2dlciA9IG5ldyBQbHVnaW5Mb2dnZXIocGx1Z2luTmFtZSk7XG5cbmNvbnN0IHNraXAgPSBwcm9jZXNzLmVudi5TS0lQX0VOVl9WQUxESUFUSU9OIHx8IGZhbHNlO1xuXG5jb25zdCBjdXJyZW50RGlyID0gcGF0aC5yZXNvbHZlKG5ldyBVUkwoaW1wb3J0Lm1ldGEudXJsKS5wYXRobmFtZSk7XG5cbmNvbnN0IG91dHB1dFBhdGggPSBwYXRoLmpvaW4ocGF0aC5kaXJuYW1lKGN1cnJlbnREaXIpLCAnLi4vLi4vc3JjL2dlbmVyYXRlZC9jaGFpbkNvbmZpZy50cycpO1xuXG5leHBvcnQgZnVuY3Rpb24gZ2VuZXJhdGVDaGFpbkNvbmZpZygpIHtcbiAgcmV0dXJuIHtcbiAgICBuYW1lOiBwbHVnaW5OYW1lLFxuICAgIGFzeW5jIGJ1aWxkU3RhcnQoKSB7XG4gICAgICBsb2dnZXIuaW5mbygnUGx1Z2luIGluaXRpYWxpemVkLicpO1xuICAgICAgbGV0IGNvbmZpZ3VyZWRDaGFpbnNDb25maWdGaWxlO1xuICAgICAgaWYgKCFza2lwKSB7XG4gICAgICAgIGlmICghcHJvY2Vzcy5lbnYuQ09ORklHVVJFRF9DSEFJTlMpIHtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoXG4gICAgICAgICAgICAnQ09ORklHVVJFRF9DSEFJTlMgaXMgbm90IGRlZmluZWQgaW4gZW52aXJvbm1lbnQuIE1ha2Ugc3VyZSB0byBydW4gdGhlIGV4cG9ydCBzdGVwIGluIHRoZSBkb2N1bWVudGF0aW9uLicsXG4gICAgICAgICAgKTtcbiAgICAgICAgfVxuICAgICAgICAvLyBEZWNvZGUgYmFzZTY0IGVuY29kZWQgSlNPTiBzdHJpbmdcbiAgICAgICAgY29uZmlndXJlZENoYWluc0NvbmZpZ0ZpbGUgPSBkZWNvZGVCYXNlNjRUb0pzb24ocHJvY2Vzcy5lbnYuQ09ORklHVVJFRF9DSEFJTlMgfHwgJycpO1xuICAgICAgICAvLyBWYWxpZGUgSlNPTiBhZ2FpbnN0IHNjaGVtYVxuICAgICAgICBjb25zdCBpc1ZhbGlkID0gdmFsaWRhdGVKc29uQWdhaW5zdFNjaGVtYShjb25maWd1cmVkQ2hhaW5zQ29uZmlnRmlsZSwgY29uZmlndXJlZENoYWluc1NjaGVtYSk7XG5cbiAgICAgICAgaWYgKCFpc1ZhbGlkKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCdlbmNvZGVkIGNvbmZpZ3VyZWRCcmlkZ2VzLmpzb24gaXMgbm90IHZhbGlkLicpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBjb25maWd1cmVkQ2hhaW5zQ29uZmlnRmlsZSA9ICcnO1xuICAgICAgfVxuXG4gICAgICAvLyBQYXRoIHRvIHdoZXJlIHlvdSB3YW50IHRvIHNhdmUgdGhlIGdlbmVyYXRlZCBUeXBlU2NyaXB0IGZpbGVcbiAgICAgIGNvbnN0IHRzRmlsZVBhdGggPSBwYXRoLnJlc29sdmUob3V0cHV0UGF0aCk7XG5cbiAgICAgIGNvbnN0IHByb2plY3QgPSBuZXcgUHJvamVjdCgpO1xuICAgICAgY29uc3Qgbm90aWZpY2F0aW9uID0gYC8vIEdlbmVyYXRlZCBieSAke3BsdWdpbk5hbWV9IG9uICR7bmV3IERhdGUoKS50b0xvY2FsZVN0cmluZygpfWA7XG4gICAgICBjb25zdCB3YXJuaW5nID0gYC8vIFdBUk5JTkc6IERvIG5vdCBjaGFuZ2UgdGhpcyBmaWxlIG1hbnVhbGx5IGFzIGl0IHdpbGwgYmUgb3ZlcndyaXR0ZW5gO1xuXG4gICAgICBsZXQgc291cmNlRmlsZSA9IHByb2plY3QuY3JlYXRlU291cmNlRmlsZSh0c0ZpbGVQYXRoLCBgJHtub3RpZmljYXRpb259XFxuJHt3YXJuaW5nfVxcbmAsIHsgb3ZlcndyaXRlOiB0cnVlIH0pO1xuXG4gICAgICAvLyBDcmVhdGUgdGhlIFR5cGVTY3JpcHQgY29udGVudFxuICAgICAgc291cmNlRmlsZSA9IGF3YWl0IHN0b3JlVHlwZXMoc291cmNlRmlsZSk7XG4gICAgICBzb3VyY2VGaWxlID0gYXdhaXQgYnVpbGRDaGFpbkNvbmZpZyhzb3VyY2VGaWxlLCBjb25maWd1cmVkQ2hhaW5zQ29uZmlnRmlsZSk7XG4gICAgICBhd2FpdCBzb3VyY2VGaWxlLnNhdmVTeW5jKCk7XG5cbiAgICAgIGNvbnN0IGZvcm1hdHRlZCA9IGF3YWl0IGZvcm1hdFNvdXJjZUZpbGUodHNGaWxlUGF0aCk7XG5cbiAgICAgIC8vIFdyaXRlIHRoZSBmb3JtYXR0ZWQgY29kZSBiYWNrIHRvIHRoZSBmaWxlXG4gICAgICBhd2FpdCBmcy53cml0ZUZpbGUodHNGaWxlUGF0aCwgZm9ybWF0dGVkKTtcblxuICAgICAgbG9nZ2VyLmluZm8oYEZvcm1hdHRlZCBjb25maWcgZmlsZSBzYXZlZCB0byAke3RzRmlsZVBhdGh9YCk7XG4gICAgfSxcbiAgfTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gc3RvcmVUeXBlcyhzb3VyY2VGaWxlOiBTb3VyY2VGaWxlKSB7XG4gIGxvZ2dlci5pbmZvKGBTdG9yaW5nIHR5cGVzLi4uYCk7XG5cbiAgLy8gQ2hhaW5Db25maWdNYXBcbiAgc291cmNlRmlsZS5hZGRJbXBvcnREZWNsYXJhdGlvbih7XG4gICAgbmFtZWRJbXBvcnRzOiBbJ0NoYWluQ29uZmlnTWFwJ10sXG4gICAgbW9kdWxlU3BlY2lmaWVyOiAnJGxpYnMvY2hhaW4nLFxuICAgIGlzVHlwZU9ubHk6IHRydWUsXG4gIH0pO1xuXG4gIC8vIExheWVyVHlwZVxuICBzb3VyY2VGaWxlLmFkZEVudW0oe1xuICAgIG5hbWU6ICdMYXllclR5cGUnLFxuICAgIGlzRXhwb3J0ZWQ6IGZhbHNlLFxuICAgIG1lbWJlcnM6IFtcbiAgICAgIHsgbmFtZTogJ0wxJywgdmFsdWU6ICdMMScgfSxcbiAgICAgIHsgbmFtZTogJ0wyJywgdmFsdWU6ICdMMicgfSxcbiAgICAgIHsgbmFtZTogJ0wzJywgdmFsdWU6ICdMMycgfSxcbiAgICBdLFxuICB9KTtcblxuICBsb2dnZXIuaW5mbygnVHlwZXMgc3RvcmVkLicpO1xuICByZXR1cm4gc291cmNlRmlsZTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gYnVpbGRDaGFpbkNvbmZpZyhzb3VyY2VGaWxlOiBTb3VyY2VGaWxlLCBjb25maWd1cmVkQ2hhaW5zQ29uZmlnRmlsZTogQ29uZmlndXJlZENoYWlucykge1xuICBjb25zdCBjaGFpbkNvbmZpZzogQ2hhaW5Db25maWdNYXAgPSB7fTtcblxuICBjb25zdCBjaGFpbnM6IENvbmZpZ3VyZWRDaGFpbnMgPSBjb25maWd1cmVkQ2hhaW5zQ29uZmlnRmlsZTtcblxuICBpZiAoIXNraXApIHtcbiAgICBpZiAoIWNoYWlucy5jb25maWd1cmVkQ2hhaW5zIHx8ICFBcnJheS5pc0FycmF5KGNoYWlucy5jb25maWd1cmVkQ2hhaW5zKSkge1xuICAgICAgY29uc29sZS5lcnJvcignY29uZmlndXJlZENoYWlucyBpcyBub3QgYW4gYXJyYXkuIFBsZWFzZSBjaGVjayB0aGUgY29udGVudCBvZiB0aGUgY29uZmlndXJlZENoYWluc0NvbmZpZ0ZpbGUuJyk7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoKTtcbiAgICB9XG5cbiAgICBjaGFpbnMuY29uZmlndXJlZENoYWlucy5mb3JFYWNoKChpdGVtOiBSZWNvcmQ8c3RyaW5nLCBDaGFpbkNvbmZpZz4pID0+IHtcbiAgICAgIGZvciAoY29uc3QgW2NoYWluSWRTdHIsIGNvbmZpZ10gb2YgT2JqZWN0LmVudHJpZXMoaXRlbSkpIHtcbiAgICAgICAgY29uc3QgY2hhaW5JZCA9IE51bWJlcihjaGFpbklkU3RyKTtcbiAgICAgICAgY29uc3QgdHlwZSA9IGNvbmZpZy50eXBlIGFzIExheWVyVHlwZTtcblxuICAgICAgICAvLyBDaGVjayBmb3IgZHVwbGljYXRlc1xuICAgICAgICBpZiAoT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsKGNoYWluQ29uZmlnLCBjaGFpbklkKSkge1xuICAgICAgICAgIGxvZ2dlci5lcnJvcihgRHVwbGljYXRlIGNoYWluSWQgJHtjaGFpbklkfSBmb3VuZCBpbiBjb25maWd1cmVkQ2hhaW5zLmpzb25gKTtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoKTtcbiAgICAgICAgfVxuXG4gICAgICAgIC8vIFZhbGlkYXRlIExheWVyVHlwZVxuICAgICAgICBpZiAoIU9iamVjdC52YWx1ZXMoTGF5ZXJUeXBlKS5pbmNsdWRlcyhjb25maWcudHlwZSkpIHtcbiAgICAgICAgICBsb2dnZXIuZXJyb3IoYEludmFsaWQgTGF5ZXJUeXBlICR7Y29uZmlnLnR5cGV9IGZvdW5kIGZvciBjaGFpbklkICR7Y2hhaW5JZH1gKTtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoKTtcbiAgICAgICAgfVxuXG4gICAgICAgIGNoYWluQ29uZmlnW2NoYWluSWRdID0geyAuLi5jb25maWcsIHR5cGUgfTtcbiAgICAgIH1cbiAgICB9KTtcbiAgfVxuXG4gIC8vIEFkZCBjaGFpbkNvbmZpZyB2YXJpYWJsZSB0byBzb3VyY2VGaWxlXG4gIHNvdXJjZUZpbGUuYWRkVmFyaWFibGVTdGF0ZW1lbnQoe1xuICAgIGRlY2xhcmF0aW9uS2luZDogVmFyaWFibGVEZWNsYXJhdGlvbktpbmQuQ29uc3QsXG4gICAgZGVjbGFyYXRpb25zOiBbXG4gICAgICB7XG4gICAgICAgIG5hbWU6ICdjaGFpbkNvbmZpZycsXG4gICAgICAgIHR5cGU6ICdDaGFpbkNvbmZpZ01hcCcsXG4gICAgICAgIGluaXRpYWxpemVyOiBfZm9ybWF0T2JqZWN0VG9Uc0xpdGVyYWwoY2hhaW5Db25maWcpLFxuICAgICAgfSxcbiAgICBdLFxuICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gIH0pO1xuXG4gIGlmIChza2lwKSB7XG4gICAgbG9nZ2VyLmluZm8oYFNraXBwZWQgY2hhaW5zLmApO1xuICB9IGVsc2Uge1xuICAgIGxvZ2dlci5pbmZvKGBDb25maWd1cmVkICR7T2JqZWN0LmtleXMoY2hhaW5Db25maWcpLmxlbmd0aH0gY2hhaW5zLmApO1xuICB9XG4gIHJldHVybiBzb3VyY2VGaWxlO1xufVxuXG5lbnVtIExheWVyVHlwZSB7XG4gIEwxID0gJ0wxJyxcbiAgTDIgPSAnTDInLFxuICBMMyA9ICdMMycsXG59XG5cbmNvbnN0IF9mb3JtYXRPYmplY3RUb1RzTGl0ZXJhbCA9IChvYmo6IENoYWluQ29uZmlnTWFwKTogc3RyaW5nID0+IHtcbiAgY29uc3QgZm9ybWF0VmFsdWUgPSAodmFsdWU6IENoYWluQ29uZmlnKTogc3RyaW5nID0+IHtcbiAgICBpZiAodHlwZW9mIHZhbHVlID09PSAnc3RyaW5nJykge1xuICAgICAgaWYgKHR5cGVvZiB2YWx1ZSA9PT0gJ3N0cmluZycpIHtcbiAgICAgICAgaWYgKE9iamVjdC52YWx1ZXMoTGF5ZXJUeXBlKS5pbmNsdWRlcyh2YWx1ZSBhcyBMYXllclR5cGUpKSB7XG4gICAgICAgICAgcmV0dXJuIGBMYXllclR5cGUuJHt2YWx1ZX1gOyAvLyBUaGlzIGxpbmUgaXMgdXNpbmcgTGF5ZXJUeXBlIGFzIGFuIGVudW0sIGJ1dCBpdCBpcyBub3cgYSB0eXBlXG4gICAgICAgIH1cbiAgICAgICAgcmV0dXJuIGBcIiR7dmFsdWV9XCJgO1xuICAgICAgfVxuICAgICAgcmV0dXJuIGBcIiR7dmFsdWV9XCJgO1xuICAgIH1cbiAgICBpZiAodHlwZW9mIHZhbHVlID09PSAnbnVtYmVyJyB8fCB0eXBlb2YgdmFsdWUgPT09ICdib29sZWFuJyB8fCB2YWx1ZSA9PT0gbnVsbCkge1xuICAgICAgcmV0dXJuIFN0cmluZyh2YWx1ZSk7XG4gICAgfVxuICAgIGlmIChBcnJheS5pc0FycmF5KHZhbHVlKSkge1xuICAgICAgcmV0dXJuIGBbJHt2YWx1ZS5tYXAoZm9ybWF0VmFsdWUpLmpvaW4oJywgJyl9XWA7XG4gICAgfVxuICAgIGlmICh0eXBlb2YgdmFsdWUgPT09ICdvYmplY3QnKSB7XG4gICAgICByZXR1cm4gX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsKHZhbHVlKTtcbiAgICB9XG4gICAgcmV0dXJuICd1bmRlZmluZWQnO1xuICB9O1xuXG4gIGlmIChBcnJheS5pc0FycmF5KG9iaikpIHtcbiAgICByZXR1cm4gYFske29iai5tYXAoZm9ybWF0VmFsdWUpLmpvaW4oJywgJyl9XWA7XG4gIH1cblxuICBjb25zdCBlbnRyaWVzID0gT2JqZWN0LmVudHJpZXMob2JqKTtcbiAgY29uc3QgZm9ybWF0dGVkRW50cmllcyA9IGVudHJpZXMubWFwKChba2V5LCB2YWx1ZV0pID0+IGAke2tleX06ICR7Zm9ybWF0VmFsdWUodmFsdWUpfWApO1xuXG4gIHJldHVybiBgeyR7Zm9ybWF0dGVkRW50cmllcy5qb2luKCcsICcpfX1gO1xufTtcbiIsICJ7XG4gIFwiJGlkXCI6IFwiY29uZmlndXJlZENoYWlucy5qc29uXCIsXG4gIFwicHJvcGVydGllc1wiOiB7XG4gICAgXCJjb25maWd1cmVkQ2hhaW5zXCI6IHtcbiAgICAgIFwidHlwZVwiOiBcImFycmF5XCIsXG4gICAgICBcIml0ZW1zXCI6IHtcbiAgICAgICAgXCJ0eXBlXCI6IFwib2JqZWN0XCIsXG4gICAgICAgIFwicHJvcGVydHlOYW1lc1wiOiB7XG4gICAgICAgICAgXCJwYXR0ZXJuXCI6IFwiXlswLTldKyRcIlxuICAgICAgICB9LFxuICAgICAgICBcImFkZGl0aW9uYWxQcm9wZXJ0aWVzXCI6IHtcbiAgICAgICAgICBcInR5cGVcIjogXCJvYmplY3RcIixcbiAgICAgICAgICBcInByb3BlcnRpZXNcIjoge1xuICAgICAgICAgICAgXCJuYW1lXCI6IHtcbiAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgIH0sXG4gICAgICAgICAgICBcImljb25cIjoge1xuICAgICAgICAgICAgICBcInR5cGVcIjogXCJzdHJpbmdcIlxuICAgICAgICAgICAgfSxcbiAgICAgICAgICAgIFwidHlwZVwiOiB7XG4gICAgICAgICAgICAgIFwidHlwZVwiOiBcInN0cmluZ1wiXG4gICAgICAgICAgICB9LFxuICAgICAgICAgICAgXCJ1cmxzXCI6IHtcbiAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwib2JqZWN0XCIsXG4gICAgICAgICAgICAgIFwicHJvcGVydGllc1wiOiB7XG4gICAgICAgICAgICAgICAgXCJycGNcIjoge1xuICAgICAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgICAgIFwiZXhwbG9yZXJcIjoge1xuICAgICAgICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgIH0sXG4gICAgICAgICAgICAgIFwicmVxdWlyZWRcIjogW1wicnBjXCIsIFwiZXhwbG9yZXJcIl1cbiAgICAgICAgICAgIH1cbiAgICAgICAgICB9LFxuICAgICAgICAgIFwicmVxdWlyZWRcIjogW1wibmFtZVwiLCBcImljb25cIiwgXCJ0eXBlXCIsIFwidXJsc1wiXVxuICAgICAgICB9XG4gICAgICB9XG4gICAgfVxuICB9LFxuICBcInJlcXVpcmVkXCI6IFtcImNvbmZpZ3VyZWRDaGFpbnNcIl1cbn1cbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlQ3VzdG9tVG9rZW5Db25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnMvZ2VuZXJhdGVDdXN0b21Ub2tlbkNvbmZpZy50c1wiO2ltcG9ydCBkb3RlbnYgZnJvbSAnZG90ZW52JztcbmltcG9ydCB7IHByb21pc2VzIGFzIGZzIH0gZnJvbSAnZnMnO1xuaW1wb3J0IHBhdGggZnJvbSAncGF0aCc7XG5pbXBvcnQgeyBQcm9qZWN0LCBTb3VyY2VGaWxlLCBWYXJpYWJsZURlY2xhcmF0aW9uS2luZCB9IGZyb20gJ3RzLW1vcnBoJztcblxuaW1wb3J0IGNvbmZpZ3VyZWRDaGFpbnNTY2hlbWEgZnJvbSAnLi4vLi4vY29uZmlnL3NjaGVtYXMvY29uZmlndXJlZENoYWlucy5zY2hlbWEuanNvbic7XG5pbXBvcnQgdHlwZSB7IFRva2VuIH0gZnJvbSAnLi4vLi4vc3JjL2xpYnMvdG9rZW4vdHlwZXMnO1xuaW1wb3J0IHsgZGVjb2RlQmFzZTY0VG9Kc29uIH0gZnJvbSAnLi8uLi91dGlscy9kZWNvZGVCYXNlNjRUb0pzb24nO1xuaW1wb3J0IHsgZm9ybWF0U291cmNlRmlsZSB9IGZyb20gJy4vLi4vdXRpbHMvZm9ybWF0U291cmNlRmlsZSc7XG5pbXBvcnQgeyBQbHVnaW5Mb2dnZXIgfSBmcm9tICcuLy4uL3V0aWxzL1BsdWdpbkxvZ2dlcic7XG5pbXBvcnQgeyB2YWxpZGF0ZUpzb25BZ2FpbnN0U2NoZW1hIH0gZnJvbSAnLi8uLi91dGlscy92YWxpZGF0ZUpzb24nO1xuXG5kb3RlbnYuY29uZmlnKCk7XG5jb25zdCBwbHVnaW5OYW1lID0gJ2dlbmVyYXRlVG9rZW5zJztcbmNvbnN0IGxvZ2dlciA9IG5ldyBQbHVnaW5Mb2dnZXIocGx1Z2luTmFtZSk7XG5cbmNvbnN0IHNraXAgPSBwcm9jZXNzLmVudi5TS0lQX0VOVl9WQUxESUFUSU9OIHx8IGZhbHNlO1xuXG5jb25zdCBjdXJyZW50RGlyID0gcGF0aC5yZXNvbHZlKG5ldyBVUkwoaW1wb3J0Lm1ldGEudXJsKS5wYXRobmFtZSk7XG5cbmNvbnN0IG91dHB1dFBhdGggPSBwYXRoLmpvaW4ocGF0aC5kaXJuYW1lKGN1cnJlbnREaXIpLCAnLi4vLi4vc3JjL2dlbmVyYXRlZC9jdXN0b21Ub2tlbkNvbmZpZy50cycpO1xuXG5leHBvcnQgZnVuY3Rpb24gZ2VuZXJhdGVDdXN0b21Ub2tlbkNvbmZpZygpIHtcbiAgcmV0dXJuIHtcbiAgICBuYW1lOiBwbHVnaW5OYW1lLFxuICAgIGFzeW5jIGJ1aWxkU3RhcnQoKSB7XG4gICAgICBsb2dnZXIuaW5mbygnUGx1Z2luIGluaXRpYWxpemVkLicpO1xuICAgICAgbGV0IGNvbmZpZ3VyZWRUb2tlbkNvbmZpZ0ZpbGU7XG5cbiAgICAgIGlmICghc2tpcCkge1xuICAgICAgICBpZiAoIXByb2Nlc3MuZW52LkNPTkZJR1VSRURfQ1VTVE9NX1RPS0VOKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKFxuICAgICAgICAgICAgJ0NPTkZJR1VSRURfQ1VTVE9NX1RPS0VOIGlzIG5vdCBkZWZpbmVkIGluIGVudmlyb25tZW50LiBNYWtlIHN1cmUgdG8gcnVuIHRoZSBleHBvcnQgc3RlcCBpbiB0aGUgZG9jdW1lbnRhdGlvbi4nLFxuICAgICAgICAgICk7XG4gICAgICAgIH1cblxuICAgICAgICAvLyBEZWNvZGUgYmFzZTY0IGVuY29kZWQgSlNPTiBzdHJpbmdcbiAgICAgICAgY29uZmlndXJlZFRva2VuQ29uZmlnRmlsZSA9IGRlY29kZUJhc2U2NFRvSnNvbihwcm9jZXNzLmVudi5DT05GSUdVUkVEX0NVU1RPTV9UT0tFTiB8fCAnJyk7XG5cbiAgICAgICAgLy8gVmFsaWRlIEpTT04gYWdhaW5zdCBzY2hlbWFcbiAgICAgICAgY29uc3QgaXNWYWxpZCA9IHZhbGlkYXRlSnNvbkFnYWluc3RTY2hlbWEoY29uZmlndXJlZFRva2VuQ29uZmlnRmlsZSwgY29uZmlndXJlZENoYWluc1NjaGVtYSk7XG5cbiAgICAgICAgaWYgKCFpc1ZhbGlkKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCdlbmNvZGVkIGNvbmZpZ3VyZWRCcmlkZ2VzLmpzb24gaXMgbm90IHZhbGlkLicpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBjb25maWd1cmVkVG9rZW5Db25maWdGaWxlID0gJyc7XG4gICAgICB9XG4gICAgICBjb25zdCB0c0ZpbGVQYXRoID0gcGF0aC5yZXNvbHZlKG91dHB1dFBhdGgpO1xuXG4gICAgICBjb25zdCBwcm9qZWN0ID0gbmV3IFByb2plY3QoKTtcbiAgICAgIGNvbnN0IG5vdGlmaWNhdGlvbiA9IGAvLyBHZW5lcmF0ZWQgYnkgJHtwbHVnaW5OYW1lfSBvbiAke25ldyBEYXRlKCkudG9Mb2NhbGVTdHJpbmcoKX1gO1xuICAgICAgY29uc3Qgd2FybmluZyA9IGAvLyBXQVJOSU5HOiBEbyBub3QgY2hhbmdlIHRoaXMgZmlsZSBtYW51YWxseSBhcyBpdCB3aWxsIGJlIG92ZXJ3cml0dGVuYDtcblxuICAgICAgbGV0IHNvdXJjZUZpbGUgPSBwcm9qZWN0LmNyZWF0ZVNvdXJjZUZpbGUodHNGaWxlUGF0aCwgYCR7bm90aWZpY2F0aW9ufVxcbiR7d2FybmluZ31cXG5gLCB7IG92ZXJ3cml0ZTogdHJ1ZSB9KTtcblxuICAgICAgLy8gQ3JlYXRlIHRoZSBUeXBlU2NyaXB0IGNvbnRlbnRcbiAgICAgIHNvdXJjZUZpbGUgPSBhd2FpdCBzdG9yZVR5cGVzKHNvdXJjZUZpbGUpO1xuICAgICAgc291cmNlRmlsZSA9IGF3YWl0IGJ1aWxkQ3VzdG9tVG9rZW5Db25maWcoc291cmNlRmlsZSwgY29uZmlndXJlZFRva2VuQ29uZmlnRmlsZSk7XG5cbiAgICAgIGF3YWl0IHNvdXJjZUZpbGUuc2F2ZSgpO1xuXG4gICAgICBjb25zdCBmb3JtYXR0ZWQgPSBhd2FpdCBmb3JtYXRTb3VyY2VGaWxlKHRzRmlsZVBhdGgpO1xuXG4gICAgICAvLyBXcml0ZSB0aGUgZm9ybWF0dGVkIGNvZGUgYmFjayB0byB0aGUgZmlsZVxuICAgICAgYXdhaXQgZnMud3JpdGVGaWxlKHRzRmlsZVBhdGgsIGZvcm1hdHRlZCk7XG4gICAgICBsb2dnZXIuaW5mbyhgRm9ybWF0dGVkIGNvbmZpZyBmaWxlIHNhdmVkIHRvICR7dHNGaWxlUGF0aH1gKTtcbiAgICB9LFxuICB9O1xufVxuXG5hc3luYyBmdW5jdGlvbiBzdG9yZVR5cGVzKHNvdXJjZUZpbGU6IFNvdXJjZUZpbGUpIHtcbiAgbG9nZ2VyLmluZm8oYFN0b3JpbmcgdHlwZXMuLi5gKTtcbiAgc291cmNlRmlsZS5hZGRJbXBvcnREZWNsYXJhdGlvbih7XG4gICAgbmFtZWRJbXBvcnRzOiBbJ1Rva2VuJ10sXG4gICAgbW9kdWxlU3BlY2lmaWVyOiAnJGxpYnMvdG9rZW4nLFxuICAgIGlzVHlwZU9ubHk6IHRydWUsXG4gIH0pO1xuXG4gIHNvdXJjZUZpbGUuYWRkSW1wb3J0RGVjbGFyYXRpb24oe1xuICAgIG5hbWVkSW1wb3J0czogWydUb2tlblR5cGUnXSxcbiAgICBtb2R1bGVTcGVjaWZpZXI6ICckbGlicy90b2tlbicsXG4gIH0pO1xuICBsb2dnZXIuaW5mbygnVHlwZSBzdG9yZWQuJyk7XG4gIHJldHVybiBzb3VyY2VGaWxlO1xufVxuXG5hc3luYyBmdW5jdGlvbiBidWlsZEN1c3RvbVRva2VuQ29uZmlnKHNvdXJjZUZpbGU6IFNvdXJjZUZpbGUsIGNvbmZpZ3VyZWRUb2tlbkNvbmZpZ0ZpbGU6IFRva2VuW10pIHtcbiAgbG9nZ2VyLmluZm8oJ0J1aWxkaW5nIGN1c3RvbSB0b2tlbiBjb25maWcuLi4nKTtcbiAgaWYgKHNraXApIHtcbiAgICBzb3VyY2VGaWxlLmFkZFZhcmlhYmxlU3RhdGVtZW50KHtcbiAgICAgIGRlY2xhcmF0aW9uS2luZDogVmFyaWFibGVEZWNsYXJhdGlvbktpbmQuQ29uc3QsXG4gICAgICBkZWNsYXJhdGlvbnM6IFtcbiAgICAgICAge1xuICAgICAgICAgIG5hbWU6ICdjdXN0b21Ub2tlbicsXG4gICAgICAgICAgaW5pdGlhbGl6ZXI6ICdbXScsXG4gICAgICAgICAgdHlwZTogJ1Rva2VuW10nLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfSk7XG4gICAgbG9nZ2VyLmluZm8oYFNraXBwZWQgdG9rZW4uYCk7XG4gIH0gZWxzZSB7XG4gICAgY29uc3QgdG9rZW5zOiBUb2tlbltdID0gY29uZmlndXJlZFRva2VuQ29uZmlnRmlsZTtcblxuICAgIHNvdXJjZUZpbGUuYWRkVmFyaWFibGVTdGF0ZW1lbnQoe1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ2N1c3RvbVRva2VuJyxcbiAgICAgICAgICBpbml0aWFsaXplcjogX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsKHRva2VucyksXG4gICAgICAgICAgdHlwZTogJ1Rva2VuW10nLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfSk7XG4gICAgbG9nZ2VyLmluZm8oYENvbmZpZ3VyZWQgJHt0b2tlbnMubGVuZ3RofSB0b2tlbnMuYCk7XG4gIH1cblxuICByZXR1cm4gc291cmNlRmlsZTtcbn1cblxuY29uc3QgX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsID0gKHRva2VuczogVG9rZW5bXSk6IHN0cmluZyA9PiB7XG4gIGNvbnN0IGZvcm1hdFRva2VuID0gKHRva2VuOiBUb2tlbik6IHN0cmluZyA9PiB7XG4gICAgY29uc3QgZW50cmllcyA9IE9iamVjdC5lbnRyaWVzKHRva2VuKTtcbiAgICBjb25zdCBmb3JtYXR0ZWRFbnRyaWVzID0gZW50cmllcy5tYXAoKFtrZXksIHZhbHVlXSkgPT4ge1xuICAgICAgaWYgKGtleSA9PT0gJ3R5cGUnICYmIHR5cGVvZiB2YWx1ZSA9PT0gJ3N0cmluZycpIHtcbiAgICAgICAgcmV0dXJuIGAke2tleX06IFRva2VuVHlwZS4ke3ZhbHVlfWA7XG4gICAgICB9XG4gICAgICBpZiAodHlwZW9mIHZhbHVlID09PSAnb2JqZWN0Jykge1xuICAgICAgICByZXR1cm4gYCR7a2V5fTogJHtKU09OLnN0cmluZ2lmeSh2YWx1ZSl9YDtcbiAgICAgIH1cbiAgICAgIHJldHVybiBgJHtrZXl9OiAke0pTT04uc3RyaW5naWZ5KHZhbHVlKX1gO1xuICAgIH0pO1xuXG4gICAgcmV0dXJuIGB7JHtmb3JtYXR0ZWRFbnRyaWVzLmpvaW4oJywgJyl9fWA7XG4gIH07XG5cbiAgcmV0dXJuIGBbJHt0b2tlbnMubWFwKGZvcm1hdFRva2VuKS5qb2luKCcsICcpfV1gO1xufTtcbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlRXZlbnRJbmRleGVyQ29uZmlnLnRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlRXZlbnRJbmRleGVyQ29uZmlnLnRzXCI7LyogZXNsaW50LWRpc2FibGUgbm8tY29uc29sZSAqL1xuaW1wb3J0IGRvdGVudiBmcm9tICdkb3RlbnYnO1xuaW1wb3J0IHsgcHJvbWlzZXMgYXMgZnMgfSBmcm9tICdmcyc7XG5pbXBvcnQgcGF0aCBmcm9tICdwYXRoJztcbmltcG9ydCB7IFByb2plY3QsIFNvdXJjZUZpbGUsIFZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIH0gZnJvbSAndHMtbW9ycGgnO1xuXG5pbXBvcnQgY29uZmlndXJlZEV2ZW50SW5kZXhlclNjaGVtYSBmcm9tICcuLi8uLi9jb25maWcvc2NoZW1hcy9jb25maWd1cmVkRXZlbnRJbmRleGVyLnNjaGVtYS5qc29uJztcbmltcG9ydCB0eXBlIHsgQ29uZmlndXJlZEV2ZW50SW5kZXhlciwgRXZlbnRJbmRleGVyQ29uZmlnIH0gZnJvbSAnLi4vLi4vc3JjL2xpYnMvZXZlbnRJbmRleGVyL3R5cGVzJztcbmltcG9ydCB7IGRlY29kZUJhc2U2NFRvSnNvbiB9IGZyb20gJy4vLi4vdXRpbHMvZGVjb2RlQmFzZTY0VG9Kc29uJztcbmltcG9ydCB7IGZvcm1hdFNvdXJjZUZpbGUgfSBmcm9tICcuLy4uL3V0aWxzL2Zvcm1hdFNvdXJjZUZpbGUnO1xuaW1wb3J0IHsgUGx1Z2luTG9nZ2VyIH0gZnJvbSAnLi8uLi91dGlscy9QbHVnaW5Mb2dnZXInO1xuaW1wb3J0IHsgdmFsaWRhdGVKc29uQWdhaW5zdFNjaGVtYSB9IGZyb20gJy4vLi4vdXRpbHMvdmFsaWRhdGVKc29uJztcblxuZG90ZW52LmNvbmZpZygpO1xuXG5jb25zdCBwbHVnaW5OYW1lID0gJ2dlbmVyYXRlRXZlbnRJbmRleGVyQ29uZmlnJztcbmNvbnN0IGxvZ2dlciA9IG5ldyBQbHVnaW5Mb2dnZXIocGx1Z2luTmFtZSk7XG5cbmNvbnN0IHNraXAgPSBwcm9jZXNzLmVudi5TS0lQX0VOVl9WQUxESUFUSU9OIHx8IGZhbHNlO1xuXG5jb25zdCBjdXJyZW50RGlyID0gcGF0aC5yZXNvbHZlKG5ldyBVUkwoaW1wb3J0Lm1ldGEudXJsKS5wYXRobmFtZSk7XG5cbmNvbnN0IG91dHB1dFBhdGggPSBwYXRoLmpvaW4ocGF0aC5kaXJuYW1lKGN1cnJlbnREaXIpLCAnLi4vLi4vc3JjL2dlbmVyYXRlZC9ldmVudEluZGV4ZXJDb25maWcudHMnKTtcblxuZXhwb3J0IGZ1bmN0aW9uIGdlbmVyYXRlRXZlbnRJbmRleGVyQ29uZmlnKCkge1xuICByZXR1cm4ge1xuICAgIG5hbWU6IHBsdWdpbk5hbWUsXG4gICAgYXN5bmMgYnVpbGRTdGFydCgpIHtcbiAgICAgIGxvZ2dlci5pbmZvKCdQbHVnaW4gaW5pdGlhbGl6ZWQuJyk7XG4gICAgICBsZXQgY29uZmlndXJlZEV2ZW50SW5kZXhlckNvbmZpZ0ZpbGU7XG5cbiAgICAgIGlmICghc2tpcCkge1xuICAgICAgICBpZiAoIXByb2Nlc3MuZW52LkNPTkZJR1VSRURfRVZFTlRfSU5ERVhFUikge1xuICAgICAgICAgIHRocm93IG5ldyBFcnJvcihcbiAgICAgICAgICAgICdDT05GSUdVUkVEX0VWRU5UX0lOREVYRVIgaXMgbm90IGRlZmluZWQgaW4gZW52aXJvbm1lbnQuIE1ha2Ugc3VyZSB0byBydW4gdGhlIGV4cG9ydCBzdGVwIGluIHRoZSBkb2N1bWVudGF0aW9uLicsXG4gICAgICAgICAgKTtcbiAgICAgICAgfVxuXG4gICAgICAgIC8vIERlY29kZSBiYXNlNjQgZW5jb2RlZCBKU09OIHN0cmluZ1xuICAgICAgICBjb25maWd1cmVkRXZlbnRJbmRleGVyQ29uZmlnRmlsZSA9IGRlY29kZUJhc2U2NFRvSnNvbihwcm9jZXNzLmVudi5DT05GSUdVUkVEX0VWRU5UX0lOREVYRVIgfHwgJycpO1xuXG4gICAgICAgIC8vIFZhbGlkZSBKU09OIGFnYWluc3Qgc2NoZW1hXG4gICAgICAgIGNvbnN0IGlzVmFsaWQgPSB2YWxpZGF0ZUpzb25BZ2FpbnN0U2NoZW1hKGNvbmZpZ3VyZWRFdmVudEluZGV4ZXJDb25maWdGaWxlLCBjb25maWd1cmVkRXZlbnRJbmRleGVyU2NoZW1hKTtcbiAgICAgICAgaWYgKCFpc1ZhbGlkKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKCdlbmNvZGVkIGNvbmZpZ3VyZWRCcmlkZ2VzLmpzb24gaXMgbm90IHZhbGlkLicpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBjb25maWd1cmVkRXZlbnRJbmRleGVyQ29uZmlnRmlsZSA9ICcnO1xuICAgICAgfVxuICAgICAgLy8gUGF0aCB0byB3aGVyZSB5b3Ugd2FudCB0byBzYXZlIHRoZSBnZW5lcmF0ZWQgVHlwIGVTY3JpcHQgZmlsZVxuICAgICAgY29uc3QgdHNGaWxlUGF0aCA9IHBhdGgucmVzb2x2ZShvdXRwdXRQYXRoKTtcblxuICAgICAgY29uc3QgcHJvamVjdCA9IG5ldyBQcm9qZWN0KCk7XG4gICAgICBjb25zdCBub3RpZmljYXRpb24gPSBgLy8gR2VuZXJhdGVkIGJ5ICR7cGx1Z2luTmFtZX0gb24gJHtuZXcgRGF0ZSgpLnRvTG9jYWxlU3RyaW5nKCl9YDtcbiAgICAgIGNvbnN0IHdhcm5pbmcgPSBgLy8gV0FSTklORzogRG8gbm90IGNoYW5nZSB0aGlzIGZpbGUgbWFudWFsbHkgYXMgaXQgd2lsbCBiZSBvdmVyd3JpdHRlbmA7XG5cbiAgICAgIGxldCBzb3VyY2VGaWxlID0gcHJvamVjdC5jcmVhdGVTb3VyY2VGaWxlKHRzRmlsZVBhdGgsIGAke25vdGlmaWNhdGlvbn1cXG4ke3dhcm5pbmd9XFxuYCwgeyBvdmVyd3JpdGU6IHRydWUgfSk7XG5cbiAgICAgIC8vIENyZWF0ZSB0aGUgVHlwZVNjcmlwdCBjb250ZW50XG4gICAgICBzb3VyY2VGaWxlID0gYXdhaXQgc3RvcmVUeXBlc0FuZEVudW1zKHNvdXJjZUZpbGUpO1xuICAgICAgc291cmNlRmlsZSA9IGF3YWl0IGJ1aWxkRXZlbnRJbmRleGVyQ29uZmlnKHNvdXJjZUZpbGUsIGNvbmZpZ3VyZWRFdmVudEluZGV4ZXJDb25maWdGaWxlKTtcblxuICAgICAgYXdhaXQgc291cmNlRmlsZS5zYXZlKCk7XG5cbiAgICAgIGNvbnN0IGZvcm1hdHRlZCA9IGF3YWl0IGZvcm1hdFNvdXJjZUZpbGUodHNGaWxlUGF0aCk7XG4gICAgICBjb25zb2xlLmxvZygnZm9ybWF0dGVkJywgdHNGaWxlUGF0aCk7XG5cbiAgICAgIC8vIFdyaXRlIHRoZSBmb3JtYXR0ZWQgY29kZSBiYWNrIHRvIHRoZSBmaWxlXG4gICAgICBhd2FpdCBmcy53cml0ZUZpbGUodHNGaWxlUGF0aCwgZm9ybWF0dGVkKTtcbiAgICAgIGxvZ2dlci5pbmZvKGBGb3JtYXR0ZWQgY29uZmlnIGZpbGUgc2F2ZWQgdG8gJHt0c0ZpbGVQYXRofWApO1xuICAgIH0sXG4gIH07XG59XG5cbmFzeW5jIGZ1bmN0aW9uIHN0b3JlVHlwZXNBbmRFbnVtcyhzb3VyY2VGaWxlOiBTb3VyY2VGaWxlKSB7XG4gIGxvZ2dlci5pbmZvKGBTdG9yaW5nIHR5cGVzLi4uYCk7XG4gIC8vIFJlbGF5ZXJDb25maWdcbiAgc291cmNlRmlsZS5hZGRJbXBvcnREZWNsYXJhdGlvbih7XG4gICAgbmFtZWRJbXBvcnRzOiBbJ0V2ZW50SW5kZXhlckNvbmZpZyddLFxuICAgIG1vZHVsZVNwZWNpZmllcjogJyRsaWJzL2V2ZW50SW5kZXhlcicsXG4gICAgaXNUeXBlT25seTogdHJ1ZSxcbiAgfSk7XG5cbiAgbG9nZ2VyLmluZm8oJ1R5cGVzIHN0b3JlZC4nKTtcbiAgcmV0dXJuIHNvdXJjZUZpbGU7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIGJ1aWxkRXZlbnRJbmRleGVyQ29uZmlnKFxuICBzb3VyY2VGaWxlOiBTb3VyY2VGaWxlLFxuICBjb25maWd1cmVkRXZlbnRJbmRleGVyQ29uZmlnRmlsZTogQ29uZmlndXJlZEV2ZW50SW5kZXhlcixcbikge1xuICBsb2dnZXIuaW5mbygnQnVpbGRpbmcgZXZlbnQgaW5kZXhlciBjb25maWcuLi4nKTtcblxuICBjb25zdCBpbmRleGVyOiBDb25maWd1cmVkRXZlbnRJbmRleGVyID0gY29uZmlndXJlZEV2ZW50SW5kZXhlckNvbmZpZ0ZpbGU7XG5cbiAgaWYgKCFza2lwKSB7XG4gICAgaWYgKCFpbmRleGVyLmNvbmZpZ3VyZWRFdmVudEluZGV4ZXIgfHwgIUFycmF5LmlzQXJyYXkoaW5kZXhlci5jb25maWd1cmVkRXZlbnRJbmRleGVyKSkge1xuICAgICAgY29uc29sZS5lcnJvcihcbiAgICAgICAgJ2NvbmZpZ3VyZWRFdmVudEluZGV4ZXIgaXMgbm90IGFuIGFycmF5LiBQbGVhc2UgY2hlY2sgdGhlIGNvbnRlbnQgb2YgdGhlIGNvbmZpZ3VyZWRFdmVudEluZGV4ZXJDb25maWdGaWxlLicsXG4gICAgICApO1xuICAgICAgdGhyb3cgbmV3IEVycm9yKCk7XG4gICAgfVxuICAgIC8vIENyZWF0ZSBhIGNvbnN0YW50IHZhcmlhYmxlIGZvciB0aGUgY29uZmlndXJhdGlvblxuICAgIGNvbnN0IGV2ZW50SW5kZXhlckNvbmZpZ1ZhcmlhYmxlID0ge1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ2NvbmZpZ3VyZWRFdmVudEluZGV4ZXInLFxuICAgICAgICAgIGluaXRpYWxpemVyOiBfZm9ybWF0T2JqZWN0VG9Uc0xpdGVyYWwoaW5kZXhlci5jb25maWd1cmVkRXZlbnRJbmRleGVyKSxcbiAgICAgICAgICB0eXBlOiAnRXZlbnRJbmRleGVyQ29uZmlnW10nLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfTtcbiAgICBzb3VyY2VGaWxlLmFkZFZhcmlhYmxlU3RhdGVtZW50KGV2ZW50SW5kZXhlckNvbmZpZ1ZhcmlhYmxlKTtcbiAgfSBlbHNlIHtcbiAgICBjb25zdCBlbXB0eUV2ZW50SW5kZXhlckNvbmZpZ1ZhcmlhYmxlID0ge1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ2NvbmZpZ3VyZWRFdmVudEluZGV4ZXInLFxuICAgICAgICAgIGluaXRpYWxpemVyOiAnW10nLFxuICAgICAgICAgIHR5cGU6ICdFdmVudEluZGV4ZXJDb25maWdbXScsXG4gICAgICAgIH0sXG4gICAgICBdLFxuICAgICAgaXNFeHBvcnRlZDogdHJ1ZSxcbiAgICB9O1xuICAgIHNvdXJjZUZpbGUuYWRkVmFyaWFibGVTdGF0ZW1lbnQoZW1wdHlFdmVudEluZGV4ZXJDb25maWdWYXJpYWJsZSk7XG4gIH1cblxuICBsb2dnZXIuaW5mbygnRXZlbnRJbmRleGVyIGNvbmZpZyBidWlsdC4nKTtcbiAgcmV0dXJuIHNvdXJjZUZpbGU7XG59XG5cbmNvbnN0IF9mb3JtYXRFdmVudEluZGV4ZXJDb25maWdUb1RzTGl0ZXJhbCA9IChjb25maWc6IEV2ZW50SW5kZXhlckNvbmZpZyk6IHN0cmluZyA9PiB7XG4gIHJldHVybiBge2NoYWluSWRzOiBbJHtjb25maWcuY2hhaW5JZHMgPyBjb25maWcuY2hhaW5JZHMuam9pbignLCAnKSA6ICcnfV0sIHVybDogXCIke2NvbmZpZy51cmx9XCJ9YDtcbn07XG5cbmNvbnN0IF9mb3JtYXRPYmplY3RUb1RzTGl0ZXJhbCA9IChpbmRleGVyOiBFdmVudEluZGV4ZXJDb25maWdbXSk6IHN0cmluZyA9PiB7XG4gIHJldHVybiBgWyR7aW5kZXhlci5tYXAoX2Zvcm1hdEV2ZW50SW5kZXhlckNvbmZpZ1RvVHNMaXRlcmFsKS5qb2luKCcsICcpfV1gO1xufTtcbiIsICJ7XG4gIFwiJGlkXCI6IFwiY29uZmlndXJlZEV2ZW50SW5kZXhlci5qc29uXCIsXG4gIFwidHlwZVwiOiBcIm9iamVjdFwiLFxuICBcInByb3BlcnRpZXNcIjoge1xuICAgIFwiY29uZmlndXJlZEV2ZW50SW5kZXhlclwiOiB7XG4gICAgICBcInR5cGVcIjogXCJhcnJheVwiLFxuICAgICAgXCJpdGVtc1wiOiB7XG4gICAgICAgIFwidHlwZVwiOiBcIm9iamVjdFwiLFxuICAgICAgICBcInByb3BlcnRpZXNcIjoge1xuICAgICAgICAgIFwiY2hhaW5JZHNcIjoge1xuICAgICAgICAgICAgXCJ0eXBlXCI6IFwiYXJyYXlcIixcbiAgICAgICAgICAgIFwiaXRlbXNcIjoge1xuICAgICAgICAgICAgICBcInR5cGVcIjogXCJpbnRlZ2VyXCJcbiAgICAgICAgICAgIH1cbiAgICAgICAgICB9LFxuICAgICAgICAgIFwidXJsXCI6IHtcbiAgICAgICAgICAgIFwidHlwZVwiOiBcInN0cmluZ1wiXG4gICAgICAgICAgfVxuICAgICAgICB9LFxuICAgICAgICBcInJlcXVpcmVkXCI6IFtcImNoYWluSWRzXCIsIFwidXJsXCJdXG4gICAgICB9XG4gICAgfVxuICB9LFxuICBcInJlcXVpcmVkXCI6IFtcImNvbmZpZ3VyZWRFdmVudEluZGV4ZXJcIl1cbn1cbiIsICJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWktdjIvc2NyaXB0cy92aXRlLXBsdWdpbnNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9ob21lL2plZmYvY29kZS90YWlrb2NoYWluL3RhaWtvLW1vbm8vcGFja2FnZXMvYnJpZGdlLXVpLXYyL3NjcmlwdHMvdml0ZS1wbHVnaW5zL2dlbmVyYXRlUmVsYXllckNvbmZpZy50c1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwgPSBcImZpbGU6Ly8vaG9tZS9qZWZmL2NvZGUvdGFpa29jaGFpbi90YWlrby1tb25vL3BhY2thZ2VzL2JyaWRnZS11aS12Mi9zY3JpcHRzL3ZpdGUtcGx1Z2lucy9nZW5lcmF0ZVJlbGF5ZXJDb25maWcudHNcIjsvKiBlc2xpbnQtZGlzYWJsZSBuby1jb25zb2xlICovXG5pbXBvcnQgZG90ZW52IGZyb20gJ2RvdGVudic7XG5pbXBvcnQgeyBwcm9taXNlcyBhcyBmcyB9IGZyb20gJ2ZzJztcbmltcG9ydCBwYXRoIGZyb20gJ3BhdGgnO1xuaW1wb3J0IHsgUHJvamVjdCwgU291cmNlRmlsZSwgVmFyaWFibGVEZWNsYXJhdGlvbktpbmQgfSBmcm9tICd0cy1tb3JwaCc7XG5cbmltcG9ydCBjb25maWd1cmVkUmVsYXllclNjaGVtYSBmcm9tICcuLi8uLi9jb25maWcvc2NoZW1hcy9jb25maWd1cmVkUmVsYXllci5zY2hlbWEuanNvbic7XG5pbXBvcnQgdHlwZSB7IENvbmZpZ3VyZWRSZWxheWVyLCBSZWxheWVyQ29uZmlnIH0gZnJvbSAnLi4vLi4vc3JjL2xpYnMvcmVsYXllci90eXBlcyc7XG5pbXBvcnQgeyBkZWNvZGVCYXNlNjRUb0pzb24gfSBmcm9tICcuLy4uL3V0aWxzL2RlY29kZUJhc2U2NFRvSnNvbic7XG5pbXBvcnQgeyBmb3JtYXRTb3VyY2VGaWxlIH0gZnJvbSAnLi8uLi91dGlscy9mb3JtYXRTb3VyY2VGaWxlJztcbmltcG9ydCB7IFBsdWdpbkxvZ2dlciB9IGZyb20gJy4vLi4vdXRpbHMvUGx1Z2luTG9nZ2VyJztcbmltcG9ydCB7IHZhbGlkYXRlSnNvbkFnYWluc3RTY2hlbWEgfSBmcm9tICcuLy4uL3V0aWxzL3ZhbGlkYXRlSnNvbic7XG5cbmRvdGVudi5jb25maWcoKTtcblxuY29uc3QgcGx1Z2luTmFtZSA9ICdnZW5lcmF0ZVJlbGF5ZXJDb25maWcnO1xuY29uc3QgbG9nZ2VyID0gbmV3IFBsdWdpbkxvZ2dlcihwbHVnaW5OYW1lKTtcblxuY29uc3Qgc2tpcCA9IHByb2Nlc3MuZW52LlNLSVBfRU5WX1ZBTERJQVRJT04gfHwgZmFsc2U7XG5cbmNvbnN0IGN1cnJlbnREaXIgPSBwYXRoLnJlc29sdmUobmV3IFVSTChpbXBvcnQubWV0YS51cmwpLnBhdGhuYW1lKTtcblxuY29uc3Qgb3V0cHV0UGF0aCA9IHBhdGguam9pbihwYXRoLmRpcm5hbWUoY3VycmVudERpciksICcuLi8uLi9zcmMvZ2VuZXJhdGVkL3JlbGF5ZXJDb25maWcudHMnKTtcblxuZXhwb3J0IGZ1bmN0aW9uIGdlbmVyYXRlUmVsYXllckNvbmZpZygpIHtcbiAgcmV0dXJuIHtcbiAgICBuYW1lOiBwbHVnaW5OYW1lLFxuICAgIGFzeW5jIGJ1aWxkU3RhcnQoKSB7XG4gICAgICBsb2dnZXIuaW5mbygnUGx1Z2luIGluaXRpYWxpemVkLicpO1xuICAgICAgbGV0IGNvbmZpZ3VyZWRSZWxheWVyQ29uZmlnRmlsZTtcblxuICAgICAgaWYgKCFza2lwKSB7XG4gICAgICAgIGlmICghcHJvY2Vzcy5lbnYuQ09ORklHVVJFRF9SRUxBWUVSKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IEVycm9yKFxuICAgICAgICAgICAgJ0NPTkZJR1VSRURfUkVMQVlFUiBpcyBub3QgZGVmaW5lZCBpbiBlbnZpcm9ubWVudC4gTWFrZSBzdXJlIHRvIHJ1biB0aGUgZXhwb3J0IHN0ZXAgaW4gdGhlIGRvY3VtZW50YXRpb24uJyxcbiAgICAgICAgICApO1xuICAgICAgICB9XG5cbiAgICAgICAgLy8gRGVjb2RlIGJhc2U2NCBlbmNvZGVkIEpTT04gc3RyaW5nXG4gICAgICAgIGNvbmZpZ3VyZWRSZWxheWVyQ29uZmlnRmlsZSA9IGRlY29kZUJhc2U2NFRvSnNvbihwcm9jZXNzLmVudi5DT05GSUdVUkVEX1JFTEFZRVIgfHwgJycpO1xuXG4gICAgICAgIC8vIFZhbGlkZSBKU09OIGFnYWluc3Qgc2NoZW1hXG4gICAgICAgIGNvbnN0IGlzVmFsaWQgPSB2YWxpZGF0ZUpzb25BZ2FpbnN0U2NoZW1hKGNvbmZpZ3VyZWRSZWxheWVyQ29uZmlnRmlsZSwgY29uZmlndXJlZFJlbGF5ZXJTY2hlbWEpO1xuICAgICAgICBpZiAoIWlzVmFsaWQpIHtcbiAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoJ2VuY29kZWQgY29uZmlndXJlZEJyaWRnZXMuanNvbiBpcyBub3QgdmFsaWQuJyk7XG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGNvbmZpZ3VyZWRSZWxheWVyQ29uZmlnRmlsZSA9ICcnO1xuICAgICAgfVxuICAgICAgLy8gUGF0aCB0byB3aGVyZSB5b3Ugd2FudCB0byBzYXZlIHRoZSBnZW5lcmF0ZWQgVHlwIGVTY3JpcHQgZmlsZVxuICAgICAgY29uc3QgdHNGaWxlUGF0aCA9IHBhdGgucmVzb2x2ZShvdXRwdXRQYXRoKTtcblxuICAgICAgY29uc3QgcHJvamVjdCA9IG5ldyBQcm9qZWN0KCk7XG4gICAgICBjb25zdCBub3RpZmljYXRpb24gPSBgLy8gR2VuZXJhdGVkIGJ5ICR7cGx1Z2luTmFtZX0gb24gJHtuZXcgRGF0ZSgpLnRvTG9jYWxlU3RyaW5nKCl9YDtcbiAgICAgIGNvbnN0IHdhcm5pbmcgPSBgLy8gV0FSTklORzogRG8gbm90IGNoYW5nZSB0aGlzIGZpbGUgbWFudWFsbHkgYXMgaXQgd2lsbCBiZSBvdmVyd3JpdHRlbmA7XG5cbiAgICAgIGxldCBzb3VyY2VGaWxlID0gcHJvamVjdC5jcmVhdGVTb3VyY2VGaWxlKHRzRmlsZVBhdGgsIGAke25vdGlmaWNhdGlvbn1cXG4ke3dhcm5pbmd9XFxuYCwgeyBvdmVyd3JpdGU6IHRydWUgfSk7XG5cbiAgICAgIC8vIENyZWF0ZSB0aGUgVHlwZVNjcmlwdCBjb250ZW50XG4gICAgICBzb3VyY2VGaWxlID0gYXdhaXQgc3RvcmVUeXBlc0FuZEVudW1zKHNvdXJjZUZpbGUpO1xuICAgICAgc291cmNlRmlsZSA9IGF3YWl0IGJ1aWxkUmVsYXllckNvbmZpZyhzb3VyY2VGaWxlLCBjb25maWd1cmVkUmVsYXllckNvbmZpZ0ZpbGUpO1xuXG4gICAgICBhd2FpdCBzb3VyY2VGaWxlLnNhdmUoKTtcblxuICAgICAgY29uc3QgZm9ybWF0dGVkID0gYXdhaXQgZm9ybWF0U291cmNlRmlsZSh0c0ZpbGVQYXRoKTtcbiAgICAgIGNvbnNvbGUubG9nKCdmb3JtYXR0ZWQnLCB0c0ZpbGVQYXRoKTtcblxuICAgICAgLy8gV3JpdGUgdGhlIGZvcm1hdHRlZCBjb2RlIGJhY2sgdG8gdGhlIGZpbGVcbiAgICAgIGF3YWl0IGZzLndyaXRlRmlsZSh0c0ZpbGVQYXRoLCBmb3JtYXR0ZWQpO1xuICAgICAgbG9nZ2VyLmluZm8oYEZvcm1hdHRlZCBjb25maWcgZmlsZSBzYXZlZCB0byAke3RzRmlsZVBhdGh9YCk7XG4gICAgfSxcbiAgfTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gc3RvcmVUeXBlc0FuZEVudW1zKHNvdXJjZUZpbGU6IFNvdXJjZUZpbGUpIHtcbiAgbG9nZ2VyLmluZm8oYFN0b3JpbmcgdHlwZXMuLi5gKTtcbiAgLy8gUmVsYXllckNvbmZpZ1xuICBzb3VyY2VGaWxlLmFkZEltcG9ydERlY2xhcmF0aW9uKHtcbiAgICBuYW1lZEltcG9ydHM6IFsnUmVsYXllckNvbmZpZyddLFxuICAgIG1vZHVsZVNwZWNpZmllcjogJyRsaWJzL3JlbGF5ZXInLFxuICAgIGlzVHlwZU9ubHk6IHRydWUsXG4gIH0pO1xuXG4gIGxvZ2dlci5pbmZvKCdUeXBlcyBzdG9yZWQuJyk7XG4gIHJldHVybiBzb3VyY2VGaWxlO1xufVxuXG5hc3luYyBmdW5jdGlvbiBidWlsZFJlbGF5ZXJDb25maWcoc291cmNlRmlsZTogU291cmNlRmlsZSwgY29uZmlndXJlZFJlbGF5ZXJDb25maWdGaWxlOiBDb25maWd1cmVkUmVsYXllcikge1xuICBsb2dnZXIuaW5mbygnQnVpbGRpbmcgcmVsYXllciBjb25maWcuLi4nKTtcblxuICBjb25zdCByZWxheWVyOiBDb25maWd1cmVkUmVsYXllciA9IGNvbmZpZ3VyZWRSZWxheWVyQ29uZmlnRmlsZTtcblxuICBpZiAoIXNraXApIHtcbiAgICBpZiAoIXJlbGF5ZXIuY29uZmlndXJlZFJlbGF5ZXIgfHwgIUFycmF5LmlzQXJyYXkocmVsYXllci5jb25maWd1cmVkUmVsYXllcikpIHtcbiAgICAgIGNvbnNvbGUuZXJyb3IoJ2NvbmZpZ3VyZWRSZWxheWVyIGlzIG5vdCBhbiBhcnJheS4gUGxlYXNlIGNoZWNrIHRoZSBjb250ZW50IG9mIHRoZSBjb25maWd1cmVkUmVsYXllckNvbmZpZ0ZpbGUuJyk7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoKTtcbiAgICB9XG4gICAgLy8gQ3JlYXRlIGEgY29uc3RhbnQgdmFyaWFibGUgZm9yIHRoZSBjb25maWd1cmF0aW9uXG4gICAgY29uc3QgcmVsYXllckNvbmZpZ1ZhcmlhYmxlID0ge1xuICAgICAgZGVjbGFyYXRpb25LaW5kOiBWYXJpYWJsZURlY2xhcmF0aW9uS2luZC5Db25zdCxcbiAgICAgIGRlY2xhcmF0aW9uczogW1xuICAgICAgICB7XG4gICAgICAgICAgbmFtZTogJ2NvbmZpZ3VyZWRSZWxheWVyJyxcbiAgICAgICAgICBpbml0aWFsaXplcjogX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsKHJlbGF5ZXIuY29uZmlndXJlZFJlbGF5ZXIpLFxuICAgICAgICAgIHR5cGU6ICdSZWxheWVyQ29uZmlnW10nLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfTtcbiAgICBzb3VyY2VGaWxlLmFkZFZhcmlhYmxlU3RhdGVtZW50KHJlbGF5ZXJDb25maWdWYXJpYWJsZSk7XG4gIH0gZWxzZSB7XG4gICAgY29uc3QgZW1wdHlSZWxheWVyQ29uZmlnVmFyaWFibGUgPSB7XG4gICAgICBkZWNsYXJhdGlvbktpbmQ6IFZhcmlhYmxlRGVjbGFyYXRpb25LaW5kLkNvbnN0LFxuICAgICAgZGVjbGFyYXRpb25zOiBbXG4gICAgICAgIHtcbiAgICAgICAgICBuYW1lOiAnY29uZmlndXJlZFJlbGF5ZXInLFxuICAgICAgICAgIGluaXRpYWxpemVyOiAnW10nLFxuICAgICAgICAgIHR5cGU6ICdSZWxheWVyQ29uZmlnW10nLFxuICAgICAgICB9LFxuICAgICAgXSxcbiAgICAgIGlzRXhwb3J0ZWQ6IHRydWUsXG4gICAgfTtcbiAgICBzb3VyY2VGaWxlLmFkZFZhcmlhYmxlU3RhdGVtZW50KGVtcHR5UmVsYXllckNvbmZpZ1ZhcmlhYmxlKTtcbiAgfVxuXG4gIGxvZ2dlci5pbmZvKCdSZWxheWVyIGNvbmZpZyBidWlsdC4nKTtcbiAgcmV0dXJuIHNvdXJjZUZpbGU7XG59XG5cbmNvbnN0IF9mb3JtYXRSZWxheWVyQ29uZmlnVG9Uc0xpdGVyYWwgPSAoY29uZmlnOiBSZWxheWVyQ29uZmlnKTogc3RyaW5nID0+IHtcbiAgcmV0dXJuIGB7Y2hhaW5JZHM6IFske2NvbmZpZy5jaGFpbklkcyA/IGNvbmZpZy5jaGFpbklkcy5qb2luKCcsICcpIDogJyd9XSwgdXJsOiBcIiR7Y29uZmlnLnVybH1cIn1gO1xufTtcblxuY29uc3QgX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsID0gKHJlbGF5ZXJzOiBSZWxheWVyQ29uZmlnW10pOiBzdHJpbmcgPT4ge1xuICByZXR1cm4gYFske3JlbGF5ZXJzLm1hcChfZm9ybWF0UmVsYXllckNvbmZpZ1RvVHNMaXRlcmFsKS5qb2luKCcsICcpfV1gO1xufTtcbiIsICJ7XG4gIFwiJGlkXCI6IFwiY29uZmlndXJlZFJlbGF5ZXIuanNvblwiLFxuICBcInR5cGVcIjogXCJvYmplY3RcIixcbiAgXCJwcm9wZXJ0aWVzXCI6IHtcbiAgICBcImNvbmZpZ3VyZWRSZWxheWVyXCI6IHtcbiAgICAgIFwidHlwZVwiOiBcImFycmF5XCIsXG4gICAgICBcIml0ZW1zXCI6IHtcbiAgICAgICAgXCJ0eXBlXCI6IFwib2JqZWN0XCIsXG4gICAgICAgIFwicHJvcGVydGllc1wiOiB7XG4gICAgICAgICAgXCJjaGFpbklkc1wiOiB7XG4gICAgICAgICAgICBcInR5cGVcIjogXCJhcnJheVwiLFxuICAgICAgICAgICAgXCJpdGVtc1wiOiB7XG4gICAgICAgICAgICAgIFwidHlwZVwiOiBcImludGVnZXJcIlxuICAgICAgICAgICAgfVxuICAgICAgICAgIH0sXG4gICAgICAgICAgXCJ1cmxcIjoge1xuICAgICAgICAgICAgXCJ0eXBlXCI6IFwic3RyaW5nXCJcbiAgICAgICAgICB9XG4gICAgICAgIH0sXG4gICAgICAgIFwicmVxdWlyZWRcIjogW1wiY2hhaW5JZHNcIiwgXCJ1cmxcIl1cbiAgICAgIH1cbiAgICB9XG4gIH0sXG4gIFwicmVxdWlyZWRcIjogW1wiY29uZmlndXJlZFJlbGF5ZXJcIl1cbn1cbiJdLAogICJtYXBwaW5ncyI6ICI7QUFBbVcsU0FBUyxpQkFBaUI7QUFDN1gsT0FBTyxtQkFBbUI7QUFDMUIsU0FBUyxvQkFBb0I7OztBQ0Z1WixPQUFPLFlBQVk7QUFDdmMsU0FBUyxZQUFZQSxXQUFVO0FBQy9CLE9BQU8sVUFBVTtBQUNqQixTQUFTLFNBQXFCLCtCQUErQjs7O0FDSDdEO0FBQUEsRUFDRSxLQUFPO0FBQUEsRUFDUCxNQUFRO0FBQUEsRUFDUixZQUFjO0FBQUEsSUFDWixtQkFBcUI7QUFBQSxNQUNuQixNQUFRO0FBQUEsTUFDUixPQUFTO0FBQUEsUUFDUCxNQUFRO0FBQUEsUUFDUixZQUFjO0FBQUEsVUFDWixRQUFVO0FBQUEsWUFDUixNQUFRO0FBQUEsVUFDVjtBQUFBLFVBQ0EsYUFBZTtBQUFBLFlBQ2IsTUFBUTtBQUFBLFVBQ1Y7QUFBQSxVQUNBLFdBQWE7QUFBQSxZQUNYLE1BQVE7QUFBQSxZQUNSLFlBQWM7QUFBQSxjQUNaLGVBQWlCO0FBQUEsZ0JBQ2YsTUFBUTtBQUFBLGNBQ1Y7QUFBQSxjQUNBLG1CQUFxQjtBQUFBLGdCQUNuQixNQUFRO0FBQUEsY0FDVjtBQUFBLGNBQ0EsbUJBQXFCO0FBQUEsZ0JBQ25CLE1BQVE7QUFBQSxjQUNWO0FBQUEsY0FDQSxvQkFBc0I7QUFBQSxnQkFDcEIsTUFBUTtBQUFBLGNBQ1Y7QUFBQSxjQUNBLHFCQUF1QjtBQUFBLGdCQUNyQixNQUFRO0FBQUEsY0FDVjtBQUFBLGNBQ0EsdUJBQXlCO0FBQUEsZ0JBQ3ZCLE1BQVE7QUFBQSxjQUNWO0FBQUEsY0FDQSxzQkFBd0I7QUFBQSxnQkFDdEIsTUFBUTtBQUFBLGNBQ1Y7QUFBQSxZQUNGO0FBQUEsWUFDQSxVQUFZO0FBQUEsY0FDVjtBQUFBLGNBQ0E7QUFBQSxjQUNBO0FBQUEsY0FDQTtBQUFBLGNBQ0E7QUFBQSxjQUNBO0FBQUEsWUFDRjtBQUFBLFlBQ0Esc0JBQXdCO0FBQUEsVUFDMUI7QUFBQSxRQUNGO0FBQUEsUUFDQSxVQUFZLENBQUMsVUFBVSxlQUFlLFdBQVc7QUFBQSxRQUNqRCxzQkFBd0I7QUFBQSxNQUMxQjtBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQUEsRUFDQSxVQUFZLENBQUMsbUJBQW1CO0FBQUEsRUFDaEMsc0JBQXdCO0FBQzFCOzs7QUMxRDJaLFNBQVMsY0FBYztBQUUzYSxJQUFNLHFCQUFxQixDQUFDLFdBQW1CO0FBQ3BELFNBQU8sS0FBSyxNQUFNLE9BQU8sS0FBSyxRQUFRLFFBQVEsRUFBRSxTQUFTLE9BQU8sQ0FBQztBQUNuRTs7O0FDSnVaLFNBQVMsWUFBWSxVQUFVO0FBQ3RiLFlBQVksY0FBYztBQUUxQixlQUFzQixpQkFBaUIsWUFBb0I7QUFDekQsUUFBTSxnQkFBZ0IsTUFBTSxHQUFHLFNBQVMsWUFBWSxPQUFPO0FBRzNELFNBQU8sTUFBZSxnQkFBTyxlQUFlLEVBQUUsUUFBUSxhQUFhLENBQUM7QUFDdEU7OztBQ1BBLElBQU0sWUFBWTtBQUNsQixJQUFNLFdBQVc7QUFDakIsSUFBTSxRQUFRO0FBQ2QsSUFBTSxTQUFTO0FBQ2YsSUFBTSxRQUFRO0FBRWQsSUFBTSxZQUFZLE9BQU0sb0JBQUksS0FBSyxHQUFFLG1CQUFtQjtBQUUvQyxJQUFNLGVBQU4sTUFBbUI7QUFBQTtBQUFBO0FBQUE7QUFBQSxFQUl4QixZQUFZQyxhQUFZO0FBQ3RCLFNBQUssYUFBYUE7QUFBQSxFQUNwQjtBQUFBO0FBQUE7QUFBQTtBQUFBLEVBS0EsS0FBSyxTQUFTO0FBQ1osU0FBSyxjQUFjLFdBQVcsT0FBTztBQUFBLEVBQ3ZDO0FBQUE7QUFBQTtBQUFBO0FBQUEsRUFLQSxLQUFLLFNBQVM7QUFDWixTQUFLLGNBQWMsVUFBVSxPQUFPO0FBQUEsRUFDdEM7QUFBQTtBQUFBO0FBQUE7QUFBQSxFQUtBLE1BQU0sU0FBUztBQUNiLFNBQUssY0FBYyxPQUFPLFNBQVMsSUFBSTtBQUFBLEVBQ3pDO0FBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQSxFQU1BLGNBQWMsT0FBTyxTQUFTLFVBQVUsT0FBTztBQUM3QyxZQUFRO0FBQUEsTUFDTixHQUFHLEtBQUssR0FBRyxVQUFVLENBQUMsR0FBRyxNQUFNLEtBQUssS0FBSyxVQUFVLElBQUksS0FBSyxHQUFHLFVBQVUsUUFBUSxFQUFFLElBQUksT0FBTyxJQUM1RixVQUFVLFFBQVEsRUFDcEI7QUFBQSxJQUNGO0FBQUEsRUFDRjtBQUNGOzs7QUNoREEsT0FBTyxTQUEwQjtBQUlqQyxJQUFNLE1BQU0sSUFBSSxJQUFJLEVBQUUsUUFBUSxNQUFNLENBQUM7QUFJckMsSUFBTSxTQUFTLElBQUksYUFBYSxnQkFBZ0I7QUFFekMsSUFBTSw0QkFBNEIsQ0FBQyxNQUFZLFdBQWlDO0FBQ3JGLFNBQU8sS0FBSyxjQUFjLE9BQU8sR0FBRyxFQUFFO0FBQ3RDLFFBQU0sV0FBVyxJQUFJLFFBQVEsTUFBTTtBQUVuQyxRQUFNLFFBQVEsU0FBUyxJQUFJO0FBRTNCLE1BQUksQ0FBQyxPQUFPO0FBQ1YsV0FBTyxNQUFNLG9CQUFvQjtBQUNqQyxZQUFRLE1BQU0sa0JBQWtCLElBQUksTUFBTTtBQUMxQyxXQUFPO0FBQUEsRUFDVDtBQUNBLFNBQU8sS0FBSyxpQkFBaUIsT0FBTyxHQUFHLGFBQWE7QUFDcEQsU0FBTztBQUNUOzs7QUx4QmlSLElBQU0sMkNBQTJDO0FBWWxVLE9BQU8sT0FBTztBQUNkLElBQU0sYUFBYTtBQUNuQixJQUFNQyxVQUFTLElBQUksYUFBYSxVQUFVO0FBRTFDLElBQU0sT0FBTyxRQUFRLElBQUksdUJBQXVCO0FBRWhELElBQU0sYUFBYSxLQUFLLFFBQVEsSUFBSSxJQUFJLHdDQUFlLEVBQUUsUUFBUTtBQUVqRSxJQUFNLGFBQWEsS0FBSyxLQUFLLEtBQUssUUFBUSxVQUFVLEdBQUcscUNBQXFDO0FBRXJGLFNBQVMsdUJBQXVCO0FBQ3JDLFNBQU87QUFBQSxJQUNMLE1BQU07QUFBQSxJQUNOLE1BQU0sYUFBYTtBQUNqQixNQUFBQSxRQUFPLEtBQUsscUJBQXFCO0FBQ2pDLFVBQUk7QUFDSixVQUFJLENBQUMsTUFBTTtBQUNULFlBQUksQ0FBQyxRQUFRLElBQUksb0JBQW9CO0FBQ25DLGdCQUFNLElBQUk7QUFBQSxZQUNSO0FBQUEsVUFDRjtBQUFBLFFBQ0Y7QUFHQSxzQ0FBOEIsbUJBQW1CLFFBQVEsSUFBSSxzQkFBc0IsRUFBRTtBQUdyRixjQUFNLFVBQVUsMEJBQTBCLDZCQUE2QixnQ0FBdUI7QUFFOUYsWUFBSSxDQUFDLFNBQVM7QUFDWixnQkFBTSxJQUFJLE1BQU0sOENBQThDO0FBQUEsUUFDaEU7QUFBQSxNQUNGLE9BQU87QUFDTCxzQ0FBOEI7QUFBQSxNQUNoQztBQUVBLFlBQU0sYUFBYSxLQUFLLFFBQVEsVUFBVTtBQUUxQyxZQUFNLFVBQVUsSUFBSSxRQUFRO0FBQzVCLFlBQU0sZUFBZSxtQkFBbUIsVUFBVSxRQUFPLG9CQUFJLEtBQUssR0FBRSxlQUFlLENBQUM7QUFDcEYsWUFBTSxVQUFVO0FBRWhCLFVBQUksYUFBYSxRQUFRLGlCQUFpQixZQUFZLEdBQUcsWUFBWTtBQUFBLEVBQUssT0FBTztBQUFBLEdBQU0sRUFBRSxXQUFXLEtBQUssQ0FBQztBQUcxRyxtQkFBYSxNQUFNLFdBQVcsVUFBVTtBQUN4QyxtQkFBYSxNQUFNLGtCQUFrQixZQUFZLDJCQUEyQjtBQUc1RSxZQUFNLFdBQVcsU0FBUztBQUMxQixNQUFBQSxRQUFPLEtBQUssdUJBQXVCO0FBRW5DLFlBQU0sV0FBVyxTQUFTO0FBRTFCLFlBQU0sWUFBWSxNQUFNLGlCQUFpQixVQUFVO0FBR25ELFlBQU1DLElBQUcsVUFBVSxZQUFZLFNBQVM7QUFDeEMsTUFBQUQsUUFBTyxLQUFLLGtDQUFrQyxVQUFVLEVBQUU7QUFBQSxJQUM1RDtBQUFBLEVBQ0Y7QUFDRjtBQUVBLGVBQWUsV0FBVyxZQUF3QjtBQUNoRCxFQUFBQSxRQUFPLEtBQUssa0JBQWtCO0FBRzlCLGFBQVcscUJBQXFCO0FBQUEsSUFDOUIsY0FBYyxDQUFDLFlBQVk7QUFBQSxJQUMzQixpQkFBaUI7QUFBQSxJQUNqQixZQUFZO0FBQUEsRUFDZCxDQUFDO0FBRUQsRUFBQUEsUUFBTyxLQUFLLGNBQWM7QUFDMUIsU0FBTztBQUNUO0FBRUEsZUFBZSxrQkFBa0IsWUFBd0IsNkJBQW9EO0FBQzNHLEVBQUFBLFFBQU8sS0FBSywyQkFBMkI7QUFDdkMsUUFBTSxzQkFBa0MsQ0FBQztBQUV6QyxRQUFNLFVBQWlDO0FBRXZDLE1BQUksQ0FBQyxNQUFNO0FBQ1QsUUFBSSxDQUFDLFFBQVEscUJBQXFCLENBQUMsTUFBTSxRQUFRLFFBQVEsaUJBQWlCLEdBQUc7QUFDM0UsTUFBQUEsUUFBTyxNQUFNLGlHQUFpRztBQUM5RyxZQUFNLElBQUksTUFBTTtBQUFBLElBQ2xCO0FBQ0EsWUFBUSxrQkFBa0IsUUFBUSxDQUFDLFNBQXVCO0FBQ3hELFVBQUksQ0FBQyxvQkFBb0IsS0FBSyxNQUFNLEdBQUc7QUFDckMsNEJBQW9CLEtBQUssTUFBTSxJQUFJLENBQUM7QUFBQSxNQUN0QztBQUNBLDBCQUFvQixLQUFLLE1BQU0sRUFBRSxLQUFLLFdBQVcsSUFBSSxLQUFLO0FBQUEsSUFDNUQsQ0FBQztBQUFBLEVBQ0g7QUFDQSxNQUFJLE1BQU07QUFFUixlQUFXLHFCQUFxQjtBQUFBLE1BQzlCLGlCQUFpQix3QkFBd0I7QUFBQSxNQUN6QyxjQUFjO0FBQUEsUUFDWjtBQUFBLFVBQ0UsTUFBTTtBQUFBLFVBQ04sTUFBTTtBQUFBLFVBQ04sYUFBYTtBQUFBLFFBQ2Y7QUFBQSxNQUNGO0FBQUEsTUFDQSxZQUFZO0FBQUEsSUFDZCxDQUFDO0FBQ0QsSUFBQUEsUUFBTyxLQUFLLGlCQUFpQjtBQUFBLEVBQy9CLE9BQU87QUFFTCxlQUFXLHFCQUFxQjtBQUFBLE1BQzlCLGlCQUFpQix3QkFBd0I7QUFBQSxNQUN6QyxjQUFjO0FBQUEsUUFDWjtBQUFBLFVBQ0UsTUFBTTtBQUFBLFVBQ04sTUFBTTtBQUFBLFVBQ04sYUFBYSx5QkFBeUIsbUJBQW1CO0FBQUEsUUFDM0Q7QUFBQSxNQUNGO0FBQUEsTUFDQSxZQUFZO0FBQUEsSUFDZCxDQUFDO0FBQ0QsSUFBQUEsUUFBTyxLQUFLLGNBQWMsUUFBUSxrQkFBa0IsTUFBTSxXQUFXO0FBQUEsRUFDdkU7QUFDQSxTQUFPO0FBQ1Q7QUFFQSxJQUFNLDJCQUEyQixDQUFDLFFBQTRCO0FBQzVELFFBQU0sY0FBYyxDQUFDLFVBQW9EO0FBQ3ZFLFFBQUksT0FBTyxVQUFVLFVBQVU7QUFDN0IsYUFBTyxJQUFJLEtBQUs7QUFBQSxJQUNsQjtBQUNBLFdBQU8sT0FBTyxLQUFLO0FBQUEsRUFDckI7QUFFQSxRQUFNLFVBQVUsT0FBTyxRQUFRLEdBQUc7QUFDbEMsUUFBTSxtQkFBbUIsUUFBUSxJQUFJLENBQUMsQ0FBQyxLQUFLLEtBQUssTUFBTTtBQUNyRCxVQUFNLGVBQWUsT0FBTyxRQUFRLEtBQUs7QUFDekMsVUFBTSx3QkFBd0IsYUFBYSxJQUFJLENBQUMsQ0FBQyxVQUFVLFVBQVUsTUFBTTtBQUN6RSxZQUFNLG9CQUFvQixPQUFPLFFBQVEsVUFBVTtBQUNuRCxZQUFNLDZCQUE2QixrQkFBa0I7QUFBQSxRQUNuRCxDQUFDLENBQUMsZUFBZSxlQUFlLE1BQU0sR0FBRyxhQUFhLEtBQUssWUFBWSxlQUFlLENBQUM7QUFBQSxNQUN6RjtBQUNBLGFBQU8sR0FBRyxRQUFRLE1BQU0sMkJBQTJCLEtBQUssSUFBSSxDQUFDO0FBQUEsSUFDL0QsQ0FBQztBQUNELFdBQU8sR0FBRyxHQUFHLE1BQU0sc0JBQXNCLEtBQUssSUFBSSxDQUFDO0FBQUEsRUFDckQsQ0FBQztBQUVELFNBQU8sSUFBSSxpQkFBaUIsS0FBSyxJQUFJLENBQUM7QUFDeEM7OztBTWhLQSxPQUFPRSxhQUFZO0FBQ25CLFNBQVMsWUFBWUMsV0FBVTtBQUMvQixPQUFPQyxXQUFVO0FBQ2pCLFNBQVMsV0FBQUMsVUFBcUIsMkJBQUFDLGdDQUErQjs7O0FDSjdEO0FBQUEsRUFDRSxLQUFPO0FBQUEsRUFDUCxZQUFjO0FBQUEsSUFDWixrQkFBb0I7QUFBQSxNQUNsQixNQUFRO0FBQUEsTUFDUixPQUFTO0FBQUEsUUFDUCxNQUFRO0FBQUEsUUFDUixlQUFpQjtBQUFBLFVBQ2YsU0FBVztBQUFBLFFBQ2I7QUFBQSxRQUNBLHNCQUF3QjtBQUFBLFVBQ3RCLE1BQVE7QUFBQSxVQUNSLFlBQWM7QUFBQSxZQUNaLE1BQVE7QUFBQSxjQUNOLE1BQVE7QUFBQSxZQUNWO0FBQUEsWUFDQSxNQUFRO0FBQUEsY0FDTixNQUFRO0FBQUEsWUFDVjtBQUFBLFlBQ0EsTUFBUTtBQUFBLGNBQ04sTUFBUTtBQUFBLFlBQ1Y7QUFBQSxZQUNBLE1BQVE7QUFBQSxjQUNOLE1BQVE7QUFBQSxjQUNSLFlBQWM7QUFBQSxnQkFDWixLQUFPO0FBQUEsa0JBQ0wsTUFBUTtBQUFBLGdCQUNWO0FBQUEsZ0JBQ0EsVUFBWTtBQUFBLGtCQUNWLE1BQVE7QUFBQSxnQkFDVjtBQUFBLGNBQ0Y7QUFBQSxjQUNBLFVBQVksQ0FBQyxPQUFPLFVBQVU7QUFBQSxZQUNoQztBQUFBLFVBQ0Y7QUFBQSxVQUNBLFVBQVksQ0FBQyxRQUFRLFFBQVEsUUFBUSxNQUFNO0FBQUEsUUFDN0M7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFBQSxFQUNBLFVBQVksQ0FBQyxrQkFBa0I7QUFDakM7OztBRHpDZ1IsSUFBTUMsNENBQTJDO0FBWWpVQyxRQUFPLE9BQU87QUFFZCxJQUFNQyxjQUFhO0FBQ25CLElBQU1DLFVBQVMsSUFBSSxhQUFhRCxXQUFVO0FBRTFDLElBQU1FLFFBQU8sUUFBUSxJQUFJLHVCQUF1QjtBQUVoRCxJQUFNQyxjQUFhQyxNQUFLLFFBQVEsSUFBSSxJQUFJTix5Q0FBZSxFQUFFLFFBQVE7QUFFakUsSUFBTU8sY0FBYUQsTUFBSyxLQUFLQSxNQUFLLFFBQVFELFdBQVUsR0FBRyxvQ0FBb0M7QUFFcEYsU0FBUyxzQkFBc0I7QUFDcEMsU0FBTztBQUFBLElBQ0wsTUFBTUg7QUFBQSxJQUNOLE1BQU0sYUFBYTtBQUNqQixNQUFBQyxRQUFPLEtBQUsscUJBQXFCO0FBQ2pDLFVBQUk7QUFDSixVQUFJLENBQUNDLE9BQU07QUFDVCxZQUFJLENBQUMsUUFBUSxJQUFJLG1CQUFtQjtBQUNsQyxnQkFBTSxJQUFJO0FBQUEsWUFDUjtBQUFBLFVBQ0Y7QUFBQSxRQUNGO0FBRUEscUNBQTZCLG1CQUFtQixRQUFRLElBQUkscUJBQXFCLEVBQUU7QUFFbkYsY0FBTSxVQUFVLDBCQUEwQiw0QkFBNEIsK0JBQXNCO0FBRTVGLFlBQUksQ0FBQyxTQUFTO0FBQ1osZ0JBQU0sSUFBSSxNQUFNLDhDQUE4QztBQUFBLFFBQ2hFO0FBQUEsTUFDRixPQUFPO0FBQ0wscUNBQTZCO0FBQUEsTUFDL0I7QUFHQSxZQUFNLGFBQWFFLE1BQUssUUFBUUMsV0FBVTtBQUUxQyxZQUFNLFVBQVUsSUFBSUMsU0FBUTtBQUM1QixZQUFNLGVBQWUsbUJBQW1CTixXQUFVLFFBQU8sb0JBQUksS0FBSyxHQUFFLGVBQWUsQ0FBQztBQUNwRixZQUFNLFVBQVU7QUFFaEIsVUFBSSxhQUFhLFFBQVEsaUJBQWlCLFlBQVksR0FBRyxZQUFZO0FBQUEsRUFBSyxPQUFPO0FBQUEsR0FBTSxFQUFFLFdBQVcsS0FBSyxDQUFDO0FBRzFHLG1CQUFhLE1BQU1PLFlBQVcsVUFBVTtBQUN4QyxtQkFBYSxNQUFNLGlCQUFpQixZQUFZLDBCQUEwQjtBQUMxRSxZQUFNLFdBQVcsU0FBUztBQUUxQixZQUFNLFlBQVksTUFBTSxpQkFBaUIsVUFBVTtBQUduRCxZQUFNQyxJQUFHLFVBQVUsWUFBWSxTQUFTO0FBRXhDLE1BQUFQLFFBQU8sS0FBSyxrQ0FBa0MsVUFBVSxFQUFFO0FBQUEsSUFDNUQ7QUFBQSxFQUNGO0FBQ0Y7QUFFQSxlQUFlTSxZQUFXLFlBQXdCO0FBQ2hELEVBQUFOLFFBQU8sS0FBSyxrQkFBa0I7QUFHOUIsYUFBVyxxQkFBcUI7QUFBQSxJQUM5QixjQUFjLENBQUMsZ0JBQWdCO0FBQUEsSUFDL0IsaUJBQWlCO0FBQUEsSUFDakIsWUFBWTtBQUFBLEVBQ2QsQ0FBQztBQUdELGFBQVcsUUFBUTtBQUFBLElBQ2pCLE1BQU07QUFBQSxJQUNOLFlBQVk7QUFBQSxJQUNaLFNBQVM7QUFBQSxNQUNQLEVBQUUsTUFBTSxNQUFNLE9BQU8sS0FBSztBQUFBLE1BQzFCLEVBQUUsTUFBTSxNQUFNLE9BQU8sS0FBSztBQUFBLE1BQzFCLEVBQUUsTUFBTSxNQUFNLE9BQU8sS0FBSztBQUFBLElBQzVCO0FBQUEsRUFDRixDQUFDO0FBRUQsRUFBQUEsUUFBTyxLQUFLLGVBQWU7QUFDM0IsU0FBTztBQUNUO0FBRUEsZUFBZSxpQkFBaUIsWUFBd0IsNEJBQThDO0FBQ3BHLFFBQU0sY0FBOEIsQ0FBQztBQUVyQyxRQUFNLFNBQTJCO0FBRWpDLE1BQUksQ0FBQ0MsT0FBTTtBQUNULFFBQUksQ0FBQyxPQUFPLG9CQUFvQixDQUFDLE1BQU0sUUFBUSxPQUFPLGdCQUFnQixHQUFHO0FBQ3ZFLGNBQVEsTUFBTSwrRkFBK0Y7QUFDN0csWUFBTSxJQUFJLE1BQU07QUFBQSxJQUNsQjtBQUVBLFdBQU8saUJBQWlCLFFBQVEsQ0FBQyxTQUFzQztBQUNyRSxpQkFBVyxDQUFDLFlBQVksTUFBTSxLQUFLLE9BQU8sUUFBUSxJQUFJLEdBQUc7QUFDdkQsY0FBTSxVQUFVLE9BQU8sVUFBVTtBQUNqQyxjQUFNLE9BQU8sT0FBTztBQUdwQixZQUFJLE9BQU8sVUFBVSxlQUFlLEtBQUssYUFBYSxPQUFPLEdBQUc7QUFDOUQsVUFBQUQsUUFBTyxNQUFNLHFCQUFxQixPQUFPLGlDQUFpQztBQUMxRSxnQkFBTSxJQUFJLE1BQU07QUFBQSxRQUNsQjtBQUdBLFlBQUksQ0FBQyxPQUFPLE9BQU8sU0FBUyxFQUFFLFNBQVMsT0FBTyxJQUFJLEdBQUc7QUFDbkQsVUFBQUEsUUFBTyxNQUFNLHFCQUFxQixPQUFPLElBQUksc0JBQXNCLE9BQU8sRUFBRTtBQUM1RSxnQkFBTSxJQUFJLE1BQU07QUFBQSxRQUNsQjtBQUVBLG9CQUFZLE9BQU8sSUFBSSxFQUFFLEdBQUcsUUFBUSxLQUFLO0FBQUEsTUFDM0M7QUFBQSxJQUNGLENBQUM7QUFBQSxFQUNIO0FBR0EsYUFBVyxxQkFBcUI7QUFBQSxJQUM5QixpQkFBaUJRLHlCQUF3QjtBQUFBLElBQ3pDLGNBQWM7QUFBQSxNQUNaO0FBQUEsUUFDRSxNQUFNO0FBQUEsUUFDTixNQUFNO0FBQUEsUUFDTixhQUFhQywwQkFBeUIsV0FBVztBQUFBLE1BQ25EO0FBQUEsSUFDRjtBQUFBLElBQ0EsWUFBWTtBQUFBLEVBQ2QsQ0FBQztBQUVELE1BQUlSLE9BQU07QUFDUixJQUFBRCxRQUFPLEtBQUssaUJBQWlCO0FBQUEsRUFDL0IsT0FBTztBQUNMLElBQUFBLFFBQU8sS0FBSyxjQUFjLE9BQU8sS0FBSyxXQUFXLEVBQUUsTUFBTSxVQUFVO0FBQUEsRUFDckU7QUFDQSxTQUFPO0FBQ1Q7QUFFQSxJQUFLLFlBQUwsa0JBQUtVLGVBQUw7QUFDRSxFQUFBQSxXQUFBLFFBQUs7QUFDTCxFQUFBQSxXQUFBLFFBQUs7QUFDTCxFQUFBQSxXQUFBLFFBQUs7QUFIRixTQUFBQTtBQUFBLEdBQUE7QUFNTCxJQUFNRCw0QkFBMkIsQ0FBQyxRQUFnQztBQUNoRSxRQUFNLGNBQWMsQ0FBQyxVQUErQjtBQUNsRCxRQUFJLE9BQU8sVUFBVSxVQUFVO0FBQzdCLFVBQUksT0FBTyxVQUFVLFVBQVU7QUFDN0IsWUFBSSxPQUFPLE9BQU8sU0FBUyxFQUFFLFNBQVMsS0FBa0IsR0FBRztBQUN6RCxpQkFBTyxhQUFhLEtBQUs7QUFBQSxRQUMzQjtBQUNBLGVBQU8sSUFBSSxLQUFLO0FBQUEsTUFDbEI7QUFDQSxhQUFPLElBQUksS0FBSztBQUFBLElBQ2xCO0FBQ0EsUUFBSSxPQUFPLFVBQVUsWUFBWSxPQUFPLFVBQVUsYUFBYSxVQUFVLE1BQU07QUFDN0UsYUFBTyxPQUFPLEtBQUs7QUFBQSxJQUNyQjtBQUNBLFFBQUksTUFBTSxRQUFRLEtBQUssR0FBRztBQUN4QixhQUFPLElBQUksTUFBTSxJQUFJLFdBQVcsRUFBRSxLQUFLLElBQUksQ0FBQztBQUFBLElBQzlDO0FBQ0EsUUFBSSxPQUFPLFVBQVUsVUFBVTtBQUM3QixhQUFPQSwwQkFBeUIsS0FBSztBQUFBLElBQ3ZDO0FBQ0EsV0FBTztBQUFBLEVBQ1Q7QUFFQSxNQUFJLE1BQU0sUUFBUSxHQUFHLEdBQUc7QUFDdEIsV0FBTyxJQUFJLElBQUksSUFBSSxXQUFXLEVBQUUsS0FBSyxJQUFJLENBQUM7QUFBQSxFQUM1QztBQUVBLFFBQU0sVUFBVSxPQUFPLFFBQVEsR0FBRztBQUNsQyxRQUFNLG1CQUFtQixRQUFRLElBQUksQ0FBQyxDQUFDLEtBQUssS0FBSyxNQUFNLEdBQUcsR0FBRyxLQUFLLFlBQVksS0FBSyxDQUFDLEVBQUU7QUFFdEYsU0FBTyxJQUFJLGlCQUFpQixLQUFLLElBQUksQ0FBQztBQUN4Qzs7O0FFM0w4YixPQUFPRSxhQUFZO0FBQ2pkLFNBQVMsWUFBWUMsV0FBVTtBQUMvQixPQUFPQyxXQUFVO0FBQ2pCLFNBQVMsV0FBQUMsVUFBcUIsMkJBQUFDLGdDQUErQjtBQUh5TixJQUFNQyw0Q0FBMkM7QUFZdlVDLFFBQU8sT0FBTztBQUNkLElBQU1DLGNBQWE7QUFDbkIsSUFBTUMsVUFBUyxJQUFJLGFBQWFELFdBQVU7QUFFMUMsSUFBTUUsUUFBTyxRQUFRLElBQUksdUJBQXVCO0FBRWhELElBQU1DLGNBQWFDLE1BQUssUUFBUSxJQUFJLElBQUlOLHlDQUFlLEVBQUUsUUFBUTtBQUVqRSxJQUFNTyxjQUFhRCxNQUFLLEtBQUtBLE1BQUssUUFBUUQsV0FBVSxHQUFHLDBDQUEwQztBQUUxRixTQUFTLDRCQUE0QjtBQUMxQyxTQUFPO0FBQUEsSUFDTCxNQUFNSDtBQUFBLElBQ04sTUFBTSxhQUFhO0FBQ2pCLE1BQUFDLFFBQU8sS0FBSyxxQkFBcUI7QUFDakMsVUFBSTtBQUVKLFVBQUksQ0FBQ0MsT0FBTTtBQUNULFlBQUksQ0FBQyxRQUFRLElBQUkseUJBQXlCO0FBQ3hDLGdCQUFNLElBQUk7QUFBQSxZQUNSO0FBQUEsVUFDRjtBQUFBLFFBQ0Y7QUFHQSxvQ0FBNEIsbUJBQW1CLFFBQVEsSUFBSSwyQkFBMkIsRUFBRTtBQUd4RixjQUFNLFVBQVUsMEJBQTBCLDJCQUEyQiwrQkFBc0I7QUFFM0YsWUFBSSxDQUFDLFNBQVM7QUFDWixnQkFBTSxJQUFJLE1BQU0sOENBQThDO0FBQUEsUUFDaEU7QUFBQSxNQUNGLE9BQU87QUFDTCxvQ0FBNEI7QUFBQSxNQUM5QjtBQUNBLFlBQU0sYUFBYUUsTUFBSyxRQUFRQyxXQUFVO0FBRTFDLFlBQU0sVUFBVSxJQUFJQyxTQUFRO0FBQzVCLFlBQU0sZUFBZSxtQkFBbUJOLFdBQVUsUUFBTyxvQkFBSSxLQUFLLEdBQUUsZUFBZSxDQUFDO0FBQ3BGLFlBQU0sVUFBVTtBQUVoQixVQUFJLGFBQWEsUUFBUSxpQkFBaUIsWUFBWSxHQUFHLFlBQVk7QUFBQSxFQUFLLE9BQU87QUFBQSxHQUFNLEVBQUUsV0FBVyxLQUFLLENBQUM7QUFHMUcsbUJBQWEsTUFBTU8sWUFBVyxVQUFVO0FBQ3hDLG1CQUFhLE1BQU0sdUJBQXVCLFlBQVkseUJBQXlCO0FBRS9FLFlBQU0sV0FBVyxLQUFLO0FBRXRCLFlBQU0sWUFBWSxNQUFNLGlCQUFpQixVQUFVO0FBR25ELFlBQU1DLElBQUcsVUFBVSxZQUFZLFNBQVM7QUFDeEMsTUFBQVAsUUFBTyxLQUFLLGtDQUFrQyxVQUFVLEVBQUU7QUFBQSxJQUM1RDtBQUFBLEVBQ0Y7QUFDRjtBQUVBLGVBQWVNLFlBQVcsWUFBd0I7QUFDaEQsRUFBQU4sUUFBTyxLQUFLLGtCQUFrQjtBQUM5QixhQUFXLHFCQUFxQjtBQUFBLElBQzlCLGNBQWMsQ0FBQyxPQUFPO0FBQUEsSUFDdEIsaUJBQWlCO0FBQUEsSUFDakIsWUFBWTtBQUFBLEVBQ2QsQ0FBQztBQUVELGFBQVcscUJBQXFCO0FBQUEsSUFDOUIsY0FBYyxDQUFDLFdBQVc7QUFBQSxJQUMxQixpQkFBaUI7QUFBQSxFQUNuQixDQUFDO0FBQ0QsRUFBQUEsUUFBTyxLQUFLLGNBQWM7QUFDMUIsU0FBTztBQUNUO0FBRUEsZUFBZSx1QkFBdUIsWUFBd0IsMkJBQW9DO0FBQ2hHLEVBQUFBLFFBQU8sS0FBSyxpQ0FBaUM7QUFDN0MsTUFBSUMsT0FBTTtBQUNSLGVBQVcscUJBQXFCO0FBQUEsTUFDOUIsaUJBQWlCTyx5QkFBd0I7QUFBQSxNQUN6QyxjQUFjO0FBQUEsUUFDWjtBQUFBLFVBQ0UsTUFBTTtBQUFBLFVBQ04sYUFBYTtBQUFBLFVBQ2IsTUFBTTtBQUFBLFFBQ1I7QUFBQSxNQUNGO0FBQUEsTUFDQSxZQUFZO0FBQUEsSUFDZCxDQUFDO0FBQ0QsSUFBQVIsUUFBTyxLQUFLLGdCQUFnQjtBQUFBLEVBQzlCLE9BQU87QUFDTCxVQUFNLFNBQWtCO0FBRXhCLGVBQVcscUJBQXFCO0FBQUEsTUFDOUIsaUJBQWlCUSx5QkFBd0I7QUFBQSxNQUN6QyxjQUFjO0FBQUEsUUFDWjtBQUFBLFVBQ0UsTUFBTTtBQUFBLFVBQ04sYUFBYUMsMEJBQXlCLE1BQU07QUFBQSxVQUM1QyxNQUFNO0FBQUEsUUFDUjtBQUFBLE1BQ0Y7QUFBQSxNQUNBLFlBQVk7QUFBQSxJQUNkLENBQUM7QUFDRCxJQUFBVCxRQUFPLEtBQUssY0FBYyxPQUFPLE1BQU0sVUFBVTtBQUFBLEVBQ25EO0FBRUEsU0FBTztBQUNUO0FBRUEsSUFBTVMsNEJBQTJCLENBQUMsV0FBNEI7QUFDNUQsUUFBTSxjQUFjLENBQUMsVUFBeUI7QUFDNUMsVUFBTSxVQUFVLE9BQU8sUUFBUSxLQUFLO0FBQ3BDLFVBQU0sbUJBQW1CLFFBQVEsSUFBSSxDQUFDLENBQUMsS0FBSyxLQUFLLE1BQU07QUFDckQsVUFBSSxRQUFRLFVBQVUsT0FBTyxVQUFVLFVBQVU7QUFDL0MsZUFBTyxHQUFHLEdBQUcsZUFBZSxLQUFLO0FBQUEsTUFDbkM7QUFDQSxVQUFJLE9BQU8sVUFBVSxVQUFVO0FBQzdCLGVBQU8sR0FBRyxHQUFHLEtBQUssS0FBSyxVQUFVLEtBQUssQ0FBQztBQUFBLE1BQ3pDO0FBQ0EsYUFBTyxHQUFHLEdBQUcsS0FBSyxLQUFLLFVBQVUsS0FBSyxDQUFDO0FBQUEsSUFDekMsQ0FBQztBQUVELFdBQU8sSUFBSSxpQkFBaUIsS0FBSyxJQUFJLENBQUM7QUFBQSxFQUN4QztBQUVBLFNBQU8sSUFBSSxPQUFPLElBQUksV0FBVyxFQUFFLEtBQUssSUFBSSxDQUFDO0FBQy9DOzs7QUMxSUEsT0FBT0MsYUFBWTtBQUNuQixTQUFTLFlBQVlDLFdBQVU7QUFDL0IsT0FBT0MsV0FBVTtBQUNqQixTQUFTLFdBQUFDLFVBQXFCLDJCQUFBQyxnQ0FBK0I7OztBQ0o3RDtBQUFBLEVBQ0UsS0FBTztBQUFBLEVBQ1AsTUFBUTtBQUFBLEVBQ1IsWUFBYztBQUFBLElBQ1osd0JBQTBCO0FBQUEsTUFDeEIsTUFBUTtBQUFBLE1BQ1IsT0FBUztBQUFBLFFBQ1AsTUFBUTtBQUFBLFFBQ1IsWUFBYztBQUFBLFVBQ1osVUFBWTtBQUFBLFlBQ1YsTUFBUTtBQUFBLFlBQ1IsT0FBUztBQUFBLGNBQ1AsTUFBUTtBQUFBLFlBQ1Y7QUFBQSxVQUNGO0FBQUEsVUFDQSxLQUFPO0FBQUEsWUFDTCxNQUFRO0FBQUEsVUFDVjtBQUFBLFFBQ0Y7QUFBQSxRQUNBLFVBQVksQ0FBQyxZQUFZLEtBQUs7QUFBQSxNQUNoQztBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQUEsRUFDQSxVQUFZLENBQUMsd0JBQXdCO0FBQ3ZDOzs7QUR4QnVSLElBQU1DLDRDQUEyQztBQWF4VUMsUUFBTyxPQUFPO0FBRWQsSUFBTUMsY0FBYTtBQUNuQixJQUFNQyxVQUFTLElBQUksYUFBYUQsV0FBVTtBQUUxQyxJQUFNRSxRQUFPLFFBQVEsSUFBSSx1QkFBdUI7QUFFaEQsSUFBTUMsY0FBYUMsTUFBSyxRQUFRLElBQUksSUFBSU4seUNBQWUsRUFBRSxRQUFRO0FBRWpFLElBQU1PLGNBQWFELE1BQUssS0FBS0EsTUFBSyxRQUFRRCxXQUFVLEdBQUcsMkNBQTJDO0FBRTNGLFNBQVMsNkJBQTZCO0FBQzNDLFNBQU87QUFBQSxJQUNMLE1BQU1IO0FBQUEsSUFDTixNQUFNLGFBQWE7QUFDakIsTUFBQUMsUUFBTyxLQUFLLHFCQUFxQjtBQUNqQyxVQUFJO0FBRUosVUFBSSxDQUFDQyxPQUFNO0FBQ1QsWUFBSSxDQUFDLFFBQVEsSUFBSSwwQkFBMEI7QUFDekMsZ0JBQU0sSUFBSTtBQUFBLFlBQ1I7QUFBQSxVQUNGO0FBQUEsUUFDRjtBQUdBLDJDQUFtQyxtQkFBbUIsUUFBUSxJQUFJLDRCQUE0QixFQUFFO0FBR2hHLGNBQU0sVUFBVSwwQkFBMEIsa0NBQWtDLHFDQUE0QjtBQUN4RyxZQUFJLENBQUMsU0FBUztBQUNaLGdCQUFNLElBQUksTUFBTSw4Q0FBOEM7QUFBQSxRQUNoRTtBQUFBLE1BQ0YsT0FBTztBQUNMLDJDQUFtQztBQUFBLE1BQ3JDO0FBRUEsWUFBTSxhQUFhRSxNQUFLLFFBQVFDLFdBQVU7QUFFMUMsWUFBTSxVQUFVLElBQUlDLFNBQVE7QUFDNUIsWUFBTSxlQUFlLG1CQUFtQk4sV0FBVSxRQUFPLG9CQUFJLEtBQUssR0FBRSxlQUFlLENBQUM7QUFDcEYsWUFBTSxVQUFVO0FBRWhCLFVBQUksYUFBYSxRQUFRLGlCQUFpQixZQUFZLEdBQUcsWUFBWTtBQUFBLEVBQUssT0FBTztBQUFBLEdBQU0sRUFBRSxXQUFXLEtBQUssQ0FBQztBQUcxRyxtQkFBYSxNQUFNLG1CQUFtQixVQUFVO0FBQ2hELG1CQUFhLE1BQU0sd0JBQXdCLFlBQVksZ0NBQWdDO0FBRXZGLFlBQU0sV0FBVyxLQUFLO0FBRXRCLFlBQU0sWUFBWSxNQUFNLGlCQUFpQixVQUFVO0FBQ25ELGNBQVEsSUFBSSxhQUFhLFVBQVU7QUFHbkMsWUFBTU8sSUFBRyxVQUFVLFlBQVksU0FBUztBQUN4QyxNQUFBTixRQUFPLEtBQUssa0NBQWtDLFVBQVUsRUFBRTtBQUFBLElBQzVEO0FBQUEsRUFDRjtBQUNGO0FBRUEsZUFBZSxtQkFBbUIsWUFBd0I7QUFDeEQsRUFBQUEsUUFBTyxLQUFLLGtCQUFrQjtBQUU5QixhQUFXLHFCQUFxQjtBQUFBLElBQzlCLGNBQWMsQ0FBQyxvQkFBb0I7QUFBQSxJQUNuQyxpQkFBaUI7QUFBQSxJQUNqQixZQUFZO0FBQUEsRUFDZCxDQUFDO0FBRUQsRUFBQUEsUUFBTyxLQUFLLGVBQWU7QUFDM0IsU0FBTztBQUNUO0FBRUEsZUFBZSx3QkFDYixZQUNBLGtDQUNBO0FBQ0EsRUFBQUEsUUFBTyxLQUFLLGtDQUFrQztBQUU5QyxRQUFNLFVBQWtDO0FBRXhDLE1BQUksQ0FBQ0MsT0FBTTtBQUNULFFBQUksQ0FBQyxRQUFRLDBCQUEwQixDQUFDLE1BQU0sUUFBUSxRQUFRLHNCQUFzQixHQUFHO0FBQ3JGLGNBQVE7QUFBQSxRQUNOO0FBQUEsTUFDRjtBQUNBLFlBQU0sSUFBSSxNQUFNO0FBQUEsSUFDbEI7QUFFQSxVQUFNLDZCQUE2QjtBQUFBLE1BQ2pDLGlCQUFpQk0seUJBQXdCO0FBQUEsTUFDekMsY0FBYztBQUFBLFFBQ1o7QUFBQSxVQUNFLE1BQU07QUFBQSxVQUNOLGFBQWFDLDBCQUF5QixRQUFRLHNCQUFzQjtBQUFBLFVBQ3BFLE1BQU07QUFBQSxRQUNSO0FBQUEsTUFDRjtBQUFBLE1BQ0EsWUFBWTtBQUFBLElBQ2Q7QUFDQSxlQUFXLHFCQUFxQiwwQkFBMEI7QUFBQSxFQUM1RCxPQUFPO0FBQ0wsVUFBTSxrQ0FBa0M7QUFBQSxNQUN0QyxpQkFBaUJELHlCQUF3QjtBQUFBLE1BQ3pDLGNBQWM7QUFBQSxRQUNaO0FBQUEsVUFDRSxNQUFNO0FBQUEsVUFDTixhQUFhO0FBQUEsVUFDYixNQUFNO0FBQUEsUUFDUjtBQUFBLE1BQ0Y7QUFBQSxNQUNBLFlBQVk7QUFBQSxJQUNkO0FBQ0EsZUFBVyxxQkFBcUIsK0JBQStCO0FBQUEsRUFDakU7QUFFQSxFQUFBUCxRQUFPLEtBQUssNEJBQTRCO0FBQ3hDLFNBQU87QUFDVDtBQUVBLElBQU0sdUNBQXVDLENBQUMsV0FBdUM7QUFDbkYsU0FBTyxlQUFlLE9BQU8sV0FBVyxPQUFPLFNBQVMsS0FBSyxJQUFJLElBQUksRUFBRSxZQUFZLE9BQU8sR0FBRztBQUMvRjtBQUVBLElBQU1RLDRCQUEyQixDQUFDLFlBQTBDO0FBQzFFLFNBQU8sSUFBSSxRQUFRLElBQUksb0NBQW9DLEVBQUUsS0FBSyxJQUFJLENBQUM7QUFDekU7OztBRTNJQSxPQUFPQyxhQUFZO0FBQ25CLFNBQVMsWUFBWUMsV0FBVTtBQUMvQixPQUFPQyxXQUFVO0FBQ2pCLFNBQVMsV0FBQUMsVUFBcUIsMkJBQUFDLGdDQUErQjs7O0FDSjdEO0FBQUEsRUFDRSxLQUFPO0FBQUEsRUFDUCxNQUFRO0FBQUEsRUFDUixZQUFjO0FBQUEsSUFDWixtQkFBcUI7QUFBQSxNQUNuQixNQUFRO0FBQUEsTUFDUixPQUFTO0FBQUEsUUFDUCxNQUFRO0FBQUEsUUFDUixZQUFjO0FBQUEsVUFDWixVQUFZO0FBQUEsWUFDVixNQUFRO0FBQUEsWUFDUixPQUFTO0FBQUEsY0FDUCxNQUFRO0FBQUEsWUFDVjtBQUFBLFVBQ0Y7QUFBQSxVQUNBLEtBQU87QUFBQSxZQUNMLE1BQVE7QUFBQSxVQUNWO0FBQUEsUUFDRjtBQUFBLFFBQ0EsVUFBWSxDQUFDLFlBQVksS0FBSztBQUFBLE1BQ2hDO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFBQSxFQUNBLFVBQVksQ0FBQyxtQkFBbUI7QUFDbEM7OztBRHhCa1IsSUFBTUMsNENBQTJDO0FBYW5VQyxRQUFPLE9BQU87QUFFZCxJQUFNQyxjQUFhO0FBQ25CLElBQU1DLFVBQVMsSUFBSSxhQUFhRCxXQUFVO0FBRTFDLElBQU1FLFFBQU8sUUFBUSxJQUFJLHVCQUF1QjtBQUVoRCxJQUFNQyxjQUFhQyxNQUFLLFFBQVEsSUFBSSxJQUFJTix5Q0FBZSxFQUFFLFFBQVE7QUFFakUsSUFBTU8sY0FBYUQsTUFBSyxLQUFLQSxNQUFLLFFBQVFELFdBQVUsR0FBRyxzQ0FBc0M7QUFFdEYsU0FBUyx3QkFBd0I7QUFDdEMsU0FBTztBQUFBLElBQ0wsTUFBTUg7QUFBQSxJQUNOLE1BQU0sYUFBYTtBQUNqQixNQUFBQyxRQUFPLEtBQUsscUJBQXFCO0FBQ2pDLFVBQUk7QUFFSixVQUFJLENBQUNDLE9BQU07QUFDVCxZQUFJLENBQUMsUUFBUSxJQUFJLG9CQUFvQjtBQUNuQyxnQkFBTSxJQUFJO0FBQUEsWUFDUjtBQUFBLFVBQ0Y7QUFBQSxRQUNGO0FBR0Esc0NBQThCLG1CQUFtQixRQUFRLElBQUksc0JBQXNCLEVBQUU7QUFHckYsY0FBTSxVQUFVLDBCQUEwQiw2QkFBNkIsZ0NBQXVCO0FBQzlGLFlBQUksQ0FBQyxTQUFTO0FBQ1osZ0JBQU0sSUFBSSxNQUFNLDhDQUE4QztBQUFBLFFBQ2hFO0FBQUEsTUFDRixPQUFPO0FBQ0wsc0NBQThCO0FBQUEsTUFDaEM7QUFFQSxZQUFNLGFBQWFFLE1BQUssUUFBUUMsV0FBVTtBQUUxQyxZQUFNLFVBQVUsSUFBSUMsU0FBUTtBQUM1QixZQUFNLGVBQWUsbUJBQW1CTixXQUFVLFFBQU8sb0JBQUksS0FBSyxHQUFFLGVBQWUsQ0FBQztBQUNwRixZQUFNLFVBQVU7QUFFaEIsVUFBSSxhQUFhLFFBQVEsaUJBQWlCLFlBQVksR0FBRyxZQUFZO0FBQUEsRUFBSyxPQUFPO0FBQUEsR0FBTSxFQUFFLFdBQVcsS0FBSyxDQUFDO0FBRzFHLG1CQUFhLE1BQU1PLG9CQUFtQixVQUFVO0FBQ2hELG1CQUFhLE1BQU0sbUJBQW1CLFlBQVksMkJBQTJCO0FBRTdFLFlBQU0sV0FBVyxLQUFLO0FBRXRCLFlBQU0sWUFBWSxNQUFNLGlCQUFpQixVQUFVO0FBQ25ELGNBQVEsSUFBSSxhQUFhLFVBQVU7QUFHbkMsWUFBTUMsSUFBRyxVQUFVLFlBQVksU0FBUztBQUN4QyxNQUFBUCxRQUFPLEtBQUssa0NBQWtDLFVBQVUsRUFBRTtBQUFBLElBQzVEO0FBQUEsRUFDRjtBQUNGO0FBRUEsZUFBZU0sb0JBQW1CLFlBQXdCO0FBQ3hELEVBQUFOLFFBQU8sS0FBSyxrQkFBa0I7QUFFOUIsYUFBVyxxQkFBcUI7QUFBQSxJQUM5QixjQUFjLENBQUMsZUFBZTtBQUFBLElBQzlCLGlCQUFpQjtBQUFBLElBQ2pCLFlBQVk7QUFBQSxFQUNkLENBQUM7QUFFRCxFQUFBQSxRQUFPLEtBQUssZUFBZTtBQUMzQixTQUFPO0FBQ1Q7QUFFQSxlQUFlLG1CQUFtQixZQUF3Qiw2QkFBZ0Q7QUFDeEcsRUFBQUEsUUFBTyxLQUFLLDRCQUE0QjtBQUV4QyxRQUFNLFVBQTZCO0FBRW5DLE1BQUksQ0FBQ0MsT0FBTTtBQUNULFFBQUksQ0FBQyxRQUFRLHFCQUFxQixDQUFDLE1BQU0sUUFBUSxRQUFRLGlCQUFpQixHQUFHO0FBQzNFLGNBQVEsTUFBTSxpR0FBaUc7QUFDL0csWUFBTSxJQUFJLE1BQU07QUFBQSxJQUNsQjtBQUVBLFVBQU0sd0JBQXdCO0FBQUEsTUFDNUIsaUJBQWlCTyx5QkFBd0I7QUFBQSxNQUN6QyxjQUFjO0FBQUEsUUFDWjtBQUFBLFVBQ0UsTUFBTTtBQUFBLFVBQ04sYUFBYUMsMEJBQXlCLFFBQVEsaUJBQWlCO0FBQUEsVUFDL0QsTUFBTTtBQUFBLFFBQ1I7QUFBQSxNQUNGO0FBQUEsTUFDQSxZQUFZO0FBQUEsSUFDZDtBQUNBLGVBQVcscUJBQXFCLHFCQUFxQjtBQUFBLEVBQ3ZELE9BQU87QUFDTCxVQUFNLDZCQUE2QjtBQUFBLE1BQ2pDLGlCQUFpQkQseUJBQXdCO0FBQUEsTUFDekMsY0FBYztBQUFBLFFBQ1o7QUFBQSxVQUNFLE1BQU07QUFBQSxVQUNOLGFBQWE7QUFBQSxVQUNiLE1BQU07QUFBQSxRQUNSO0FBQUEsTUFDRjtBQUFBLE1BQ0EsWUFBWTtBQUFBLElBQ2Q7QUFDQSxlQUFXLHFCQUFxQiwwQkFBMEI7QUFBQSxFQUM1RDtBQUVBLEVBQUFSLFFBQU8sS0FBSyx1QkFBdUI7QUFDbkMsU0FBTztBQUNUO0FBRUEsSUFBTSxrQ0FBa0MsQ0FBQyxXQUFrQztBQUN6RSxTQUFPLGVBQWUsT0FBTyxXQUFXLE9BQU8sU0FBUyxLQUFLLElBQUksSUFBSSxFQUFFLFlBQVksT0FBTyxHQUFHO0FBQy9GO0FBRUEsSUFBTVMsNEJBQTJCLENBQUMsYUFBc0M7QUFDdEUsU0FBTyxJQUFJLFNBQVMsSUFBSSwrQkFBK0IsRUFBRSxLQUFLLElBQUksQ0FBQztBQUNyRTs7O0FaN0hBLElBQU8sc0JBQVEsYUFBYTtBQUFBLEVBQzFCLE9BQU87QUFBQSxJQUNMLFdBQVc7QUFBQSxFQUNiO0FBQUEsRUFDQSxTQUFTO0FBQUEsSUFDUCxVQUFVO0FBQUE7QUFBQTtBQUFBLElBR1YsY0FBYztBQUFBLElBQ2QscUJBQXFCO0FBQUEsSUFDckIsb0JBQW9CO0FBQUEsSUFDcEIsc0JBQXNCO0FBQUEsSUFDdEIsMEJBQTBCO0FBQUEsSUFDMUIsMkJBQTJCO0FBQUEsRUFDN0I7QUFBQSxFQUNBLE1BQU07QUFBQSxJQUNKLGFBQWE7QUFBQSxJQUNiLFNBQVM7QUFBQSxJQUNULFNBQVMsQ0FBQyw4QkFBOEI7QUFBQSxFQUMxQztBQUNGLENBQUM7IiwKICAibmFtZXMiOiBbImZzIiwgInBsdWdpbk5hbWUiLCAibG9nZ2VyIiwgImZzIiwgImRvdGVudiIsICJmcyIsICJwYXRoIiwgIlByb2plY3QiLCAiVmFyaWFibGVEZWNsYXJhdGlvbktpbmQiLCAiX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCIsICJkb3RlbnYiLCAicGx1Z2luTmFtZSIsICJsb2dnZXIiLCAic2tpcCIsICJjdXJyZW50RGlyIiwgInBhdGgiLCAib3V0cHV0UGF0aCIsICJQcm9qZWN0IiwgInN0b3JlVHlwZXMiLCAiZnMiLCAiVmFyaWFibGVEZWNsYXJhdGlvbktpbmQiLCAiX2Zvcm1hdE9iamVjdFRvVHNMaXRlcmFsIiwgIkxheWVyVHlwZSIsICJkb3RlbnYiLCAiZnMiLCAicGF0aCIsICJQcm9qZWN0IiwgIlZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIiwgIl9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwiLCAiZG90ZW52IiwgInBsdWdpbk5hbWUiLCAibG9nZ2VyIiwgInNraXAiLCAiY3VycmVudERpciIsICJwYXRoIiwgIm91dHB1dFBhdGgiLCAiUHJvamVjdCIsICJzdG9yZVR5cGVzIiwgImZzIiwgIlZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIiwgIl9mb3JtYXRPYmplY3RUb1RzTGl0ZXJhbCIsICJkb3RlbnYiLCAiZnMiLCAicGF0aCIsICJQcm9qZWN0IiwgIlZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIiwgIl9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwiLCAiZG90ZW52IiwgInBsdWdpbk5hbWUiLCAibG9nZ2VyIiwgInNraXAiLCAiY3VycmVudERpciIsICJwYXRoIiwgIm91dHB1dFBhdGgiLCAiUHJvamVjdCIsICJmcyIsICJWYXJpYWJsZURlY2xhcmF0aW9uS2luZCIsICJfZm9ybWF0T2JqZWN0VG9Uc0xpdGVyYWwiLCAiZG90ZW52IiwgImZzIiwgInBhdGgiLCAiUHJvamVjdCIsICJWYXJpYWJsZURlY2xhcmF0aW9uS2luZCIsICJfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsIiwgImRvdGVudiIsICJwbHVnaW5OYW1lIiwgImxvZ2dlciIsICJza2lwIiwgImN1cnJlbnREaXIiLCAicGF0aCIsICJvdXRwdXRQYXRoIiwgIlByb2plY3QiLCAic3RvcmVUeXBlc0FuZEVudW1zIiwgImZzIiwgIlZhcmlhYmxlRGVjbGFyYXRpb25LaW5kIiwgIl9mb3JtYXRPYmplY3RUb1RzTGl0ZXJhbCJdCn0K
