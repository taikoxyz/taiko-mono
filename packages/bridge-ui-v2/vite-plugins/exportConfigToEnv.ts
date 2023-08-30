import { execSync } from 'child_process';
import crypto from 'crypto';
import dotenv from 'dotenv';
import { existsSync, readFileSync } from 'fs';

import { Logger } from './utils/Logger';

const pluginName = 'exportConfigToEnv';
const logger = new Logger(pluginName);

dotenv.config();

const prevHashes: { [filename: string]: string } = {};

function hashFile(filePath: string): string | null {
    if (existsSync(filePath)) {
        const data = readFileSync(filePath);
        return crypto.createHash('md5').update(data).digest('hex');
    }
    return null;
}

const configPaths = [
    'config/configuredBridges.json',
    'config/configuredChains.json',
    'config/configuredCustomTokens.json',
    'config/configuredRelayer.json',
];

export function exportConfigToEnv(): { name: string; enforce: 'pre'; buildStart(): Promise<void>; } {
    return {
        name: pluginName,
        enforce: 'pre',
        async buildStart() {
            exportToEnv()
        },
    };
}

function exportToEnv() {
    logger.info('Plugin initialized.');

    // ToDo: not working yet due to all plugins running in parallel

    // let changed = false;
    // for (const path of configPaths) {
    //     const newHash = hashFile(path);

    //     if (newHash !== prevHashes[path] && newHash) {
    //         prevHashes[path] = newHash;
    //         changed = true;
    //     }
    // }

    // if (changed) {
    //     try {
    //         const stdout: string = execSync('pnpm export:config').toString();
    //         logger.info(stdout);
    //     } catch (error) {
    //         if (error instanceof Error) {
    //             logger.error(`Error executing script: ${error.message}`);
    //             logger.error(error.message);
    //         }
    //     }
    // }
}