
// this file is generated — do not edit it


/// <reference types="@sveltejs/kit" />

/**
 * Environment variables [loaded by Vite](https://vitejs.dev/guide/env-and-mode.html#env-files) from `.env` files and `process.env`. Like [`$env/dynamic/private`](https://kit.svelte.dev/docs/modules#$env-dynamic-private), this module cannot be imported into client-side code. This module only includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://kit.svelte.dev/docs/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://kit.svelte.dev/docs/configuration#env) (if configured).
 * 
 * _Unlike_ [`$env/dynamic/private`](https://kit.svelte.dev/docs/modules#$env-dynamic-private), the values exported from this module are statically injected into your bundle at build time, enabling optimisations like dead code elimination.
 * 
 * ```ts
 * import { API_KEY } from '$env/static/private';
 * ```
 * 
 * Note that all environment variables referenced in your code should be declared (for example in an `.env` file), even if they don't have a value until the app is deployed:
 * 
 * ```
 * MY_FEATURE_FLAG=""
 * ```
 * 
 * You can override `.env` values from the command line like so:
 * 
 * ```bash
 * MY_FEATURE_FLAG="enabled" npm run dev
 * ```
 */
declare module '$env/static/private' {
	export const SENTRY_ORG: string;
	export const SENTRY_PROJECT: string;
	export const SENTRY_AUTH_TOKEN: string;
	export const CONFIGURED_BRIDGES: string;
	export const CONFIGURED_CHAINS: string;
	export const CONFIGURED_CUSTOM_TOKEN: string;
	export const CONFIGURED_RELAYER: string;
	export const CONFIGURED_EVENT_INDEXER: string;
	export const GJS_DEBUG_TOPICS: string;
	export const LESSOPEN: string;
	export const DOCUMENTDB_KEYSTORE_PASSWORD: string;
	export const LANGUAGE: string;
	export const USER: string;
	export const npm_config_user_agent: string;
	export const XDG_SEAT: string;
	export const SSH_AGENT_PID: string;
	export const XDG_SESSION_TYPE: string;
	export const GIT_ASKPASS: string;
	export const npm_node_execpath: string;
	export const SHLVL: string;
	export const npm_config_noproxy: string;
	export const HOME: string;
	export const CHROME_DESKTOP: string;
	export const OLDPWD: string;
	export const TERM_PROGRAM_VERSION: string;
	export const DESKTOP_SESSION: string;
	export const NVM_BIN: string;
	export const npm_package_json: string;
	export const PYENV_SHELL: string;
	export const NVM_INC: string;
	export const GIO_LAUNCHED_DESKTOP_FILE: string;
	export const npm_config_auto_install_peers: string;
	export const APPLICATION_INSIGHTS_NO_DIAGNOSTIC_CHANNEL: string;
	export const GTK_MODULES: string;
	export const XDG_SEAT_PATH: string;
	export const VSCODE_GIT_ASKPASS_MAIN: string;
	export const VSCODE_GIT_ASKPASS_NODE: string;
	export const npm_config_userconfig: string;
	export const npm_config_local_prefix: string;
	export const CINNAMON_VERSION: string;
	export const GOROOT: string;
	export const DBUS_SESSION_BUS_ADDRESS: string;
	export const npm_config_engine_strict: string;
	export const npm_config_resolution_mode: string;
	export const COLORTERM: string;
	export const TERMINATOR_DBUS_NAME: string;
	export const LIBVIRT_DEFAULT_URI: string;
	export const GIO_LAUNCHED_DESKTOP_FILE_PID: string;
	export const COLOR: string;
	export const NVM_DIR: string;
	export const npm_config_metrics_registry: string;
	export const MANDATORY_PATH: string;
	export const QT_QPA_PLATFORMTHEME: string;
	export const LOGNAME: string;
	export const DOCUMENTDB_PASSWORD: string;
	export const _: string;
	export const npm_config_prefix: string;
	export const XDG_SESSION_CLASS: string;
	export const DEFAULTS_PATH: string;
	export const TERM: string;
	export const GTK_OVERLAY_SCROLLING: string;
	export const XDG_SESSION_ID: string;
	export const npm_config_cache: string;
	export const GNOME_DESKTOP_SESSION_ID: string;
	export const npm_config_node_gyp: string;
	export const PATH: string;
	export const SESSION_MANAGER: string;
	export const GDM_LANG: string;
	export const NODE: string;
	export const npm_package_name: string;
	export const XDG_SESSION_PATH: string;
	export const XDG_RUNTIME_DIR: string;
	export const GDK_BACKEND: string;
	export const DISPLAY: string;
	export const TERMINATOR_DBUS_PATH: string;
	export const LANG: string;
	export const XDG_CURRENT_DESKTOP: string;
	export const ARTIFACTORY_API_KEY: string;
	export const XDG_SESSION_DESKTOP: string;
	export const XAUTHORITY: string;
	export const LS_COLORS: string;
	export const VSCODE_GIT_IPC_HANDLE: string;
	export const TERM_PROGRAM: string;
	export const npm_lifecycle_script: string;
	export const SSH_AUTH_SOCK: string;
	export const XDG_GREETER_DATA_DIR: string;
	export const ORIGINAL_XDG_CURRENT_DESKTOP: string;
	export const SHELL: string;
	export const TERMINATOR_UUID: string;
	export const npm_package_version: string;
	export const npm_lifecycle_event: string;
	export const NODE_PATH: string;
	export const QT_ACCESSIBILITY: string;
	export const NO_AT_BRIDGE: string;
	export const GDMSESSION: string;
	export const LESSCLOSE: string;
	export const GPG_AGENT_INFO: string;
	export const GJS_DEBUG_OUTPUT: string;
	export const ANDROID_SDK_ROOT: string;
	export const VSCODE_GIT_ASKPASS_EXTRA_ARGS: string;
	export const XDG_VTNR: string;
	export const ARTIFACTORY_USER: string;
	export const npm_config_globalconfig: string;
	export const npm_config_init_module: string;
	export const JAVA_HOME: string;
	export const PWD: string;
	export const npm_execpath: string;
	export const XDG_CONFIG_DIRS: string;
	export const NVM_CD_FLAGS: string;
	export const PYENV_ROOT: string;
	export const XDG_DATA_DIRS: string;
	export const npm_config_global_prefix: string;
	export const npm_command: string;
	export const MANPATH: string;
	export const PNPM_HOME: string;
	export const VTE_VERSION: string;
	export const INIT_CWD: string;
	export const EDITOR: string;
	export const NODE_ENV: string;
}

/**
 * Similar to [`$env/static/private`](https://kit.svelte.dev/docs/modules#$env-static-private), except that it only includes environment variables that begin with [`config.kit.env.publicPrefix`](https://kit.svelte.dev/docs/configuration#env) (which defaults to `PUBLIC_`), and can therefore safely be exposed to client-side code.
 * 
 * Values are replaced statically at build time.
 * 
 * ```ts
 * import { PUBLIC_BASE_URL } from '$env/static/public';
 * ```
 */
declare module '$env/static/public' {
	export const PUBLIC_DEFAULT_EXPLORER: string;
	export const PUBLIC_GUIDE_URL: string;
	export const PUBLIC_WALLETCONNECT_PROJECT_ID: string;
	export const PUBLIC_NFT_BRIDGE_ENABLED: string;
	export const PUBLIC_SENTRY_DSN: string;
}

/**
 * This module provides access to runtime environment variables, as defined by the platform you're running on. For example if you're using [`adapter-node`](https://github.com/sveltejs/kit/tree/master/packages/adapter-node) (or running [`vite preview`](https://kit.svelte.dev/docs/cli)), this is equivalent to `process.env`. This module only includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://kit.svelte.dev/docs/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://kit.svelte.dev/docs/configuration#env) (if configured).
 * 
 * This module cannot be imported into client-side code.
 * 
 * ```ts
 * import { env } from '$env/dynamic/private';
 * console.log(env.DEPLOYMENT_SPECIFIC_VARIABLE);
 * ```
 * 
 * > In `dev`, `$env/dynamic` always includes environment variables from `.env`. In `prod`, this behavior will depend on your adapter.
 */
declare module '$env/dynamic/private' {
	export const env: {
		SENTRY_ORG: string;
		SENTRY_PROJECT: string;
		SENTRY_AUTH_TOKEN: string;
		CONFIGURED_BRIDGES: string;
		CONFIGURED_CHAINS: string;
		CONFIGURED_CUSTOM_TOKEN: string;
		CONFIGURED_RELAYER: string;
		CONFIGURED_EVENT_INDEXER: string;
		GJS_DEBUG_TOPICS: string;
		LESSOPEN: string;
		DOCUMENTDB_KEYSTORE_PASSWORD: string;
		LANGUAGE: string;
		USER: string;
		npm_config_user_agent: string;
		XDG_SEAT: string;
		SSH_AGENT_PID: string;
		XDG_SESSION_TYPE: string;
		GIT_ASKPASS: string;
		npm_node_execpath: string;
		SHLVL: string;
		npm_config_noproxy: string;
		HOME: string;
		CHROME_DESKTOP: string;
		OLDPWD: string;
		TERM_PROGRAM_VERSION: string;
		DESKTOP_SESSION: string;
		NVM_BIN: string;
		npm_package_json: string;
		PYENV_SHELL: string;
		NVM_INC: string;
		GIO_LAUNCHED_DESKTOP_FILE: string;
		npm_config_auto_install_peers: string;
		APPLICATION_INSIGHTS_NO_DIAGNOSTIC_CHANNEL: string;
		GTK_MODULES: string;
		XDG_SEAT_PATH: string;
		VSCODE_GIT_ASKPASS_MAIN: string;
		VSCODE_GIT_ASKPASS_NODE: string;
		npm_config_userconfig: string;
		npm_config_local_prefix: string;
		CINNAMON_VERSION: string;
		GOROOT: string;
		DBUS_SESSION_BUS_ADDRESS: string;
		npm_config_engine_strict: string;
		npm_config_resolution_mode: string;
		COLORTERM: string;
		TERMINATOR_DBUS_NAME: string;
		LIBVIRT_DEFAULT_URI: string;
		GIO_LAUNCHED_DESKTOP_FILE_PID: string;
		COLOR: string;
		NVM_DIR: string;
		npm_config_metrics_registry: string;
		MANDATORY_PATH: string;
		QT_QPA_PLATFORMTHEME: string;
		LOGNAME: string;
		DOCUMENTDB_PASSWORD: string;
		_: string;
		npm_config_prefix: string;
		XDG_SESSION_CLASS: string;
		DEFAULTS_PATH: string;
		TERM: string;
		GTK_OVERLAY_SCROLLING: string;
		XDG_SESSION_ID: string;
		npm_config_cache: string;
		GNOME_DESKTOP_SESSION_ID: string;
		npm_config_node_gyp: string;
		PATH: string;
		SESSION_MANAGER: string;
		GDM_LANG: string;
		NODE: string;
		npm_package_name: string;
		XDG_SESSION_PATH: string;
		XDG_RUNTIME_DIR: string;
		GDK_BACKEND: string;
		DISPLAY: string;
		TERMINATOR_DBUS_PATH: string;
		LANG: string;
		XDG_CURRENT_DESKTOP: string;
		ARTIFACTORY_API_KEY: string;
		XDG_SESSION_DESKTOP: string;
		XAUTHORITY: string;
		LS_COLORS: string;
		VSCODE_GIT_IPC_HANDLE: string;
		TERM_PROGRAM: string;
		npm_lifecycle_script: string;
		SSH_AUTH_SOCK: string;
		XDG_GREETER_DATA_DIR: string;
		ORIGINAL_XDG_CURRENT_DESKTOP: string;
		SHELL: string;
		TERMINATOR_UUID: string;
		npm_package_version: string;
		npm_lifecycle_event: string;
		NODE_PATH: string;
		QT_ACCESSIBILITY: string;
		NO_AT_BRIDGE: string;
		GDMSESSION: string;
		LESSCLOSE: string;
		GPG_AGENT_INFO: string;
		GJS_DEBUG_OUTPUT: string;
		ANDROID_SDK_ROOT: string;
		VSCODE_GIT_ASKPASS_EXTRA_ARGS: string;
		XDG_VTNR: string;
		ARTIFACTORY_USER: string;
		npm_config_globalconfig: string;
		npm_config_init_module: string;
		JAVA_HOME: string;
		PWD: string;
		npm_execpath: string;
		XDG_CONFIG_DIRS: string;
		NVM_CD_FLAGS: string;
		PYENV_ROOT: string;
		XDG_DATA_DIRS: string;
		npm_config_global_prefix: string;
		npm_command: string;
		MANPATH: string;
		PNPM_HOME: string;
		VTE_VERSION: string;
		INIT_CWD: string;
		EDITOR: string;
		NODE_ENV: string;
		[key: `PUBLIC_${string}`]: undefined;
		[key: `${string}`]: string | undefined;
	}
}

/**
 * Similar to [`$env/dynamic/private`](https://kit.svelte.dev/docs/modules#$env-dynamic-private), but only includes variables that begin with [`config.kit.env.publicPrefix`](https://kit.svelte.dev/docs/configuration#env) (which defaults to `PUBLIC_`), and can therefore safely be exposed to client-side code.
 * 
 * Note that public dynamic environment variables must all be sent from the server to the client, causing larger network requests — when possible, use `$env/static/public` instead.
 * 
 * ```ts
 * import { env } from '$env/dynamic/public';
 * console.log(env.PUBLIC_DEPLOYMENT_SPECIFIC_VARIABLE);
 * ```
 */
declare module '$env/dynamic/public' {
	export const env: {
		PUBLIC_DEFAULT_EXPLORER: string;
		PUBLIC_GUIDE_URL: string;
		PUBLIC_WALLETCONNECT_PROJECT_ID: string;
		PUBLIC_NFT_BRIDGE_ENABLED: string;
		PUBLIC_SENTRY_DSN: string;
		[key: `PUBLIC_${string}`]: string | undefined;
	}
}
