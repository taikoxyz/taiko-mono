/**
 * Svelte custom action to close a modal on escape or outside click
 *
 * Example usage:
 * <div use:closeOnEscapeOrOutsideClick={{ enabled: modalIsOpen, callback: closeModal }}></div>
 *
 * @export
 * @param {HTMLElement} node
 * @param {{ enabled: boolean; callback: () => void }} { enabled, callback }
 * @return {*}
 */
export function closeOnEscapeOrOutsideClick(
	node: HTMLElement,
	{ enabled, callback }: { enabled: boolean; callback: () => void }
) {
	const handleClick = (event: Event) => {
		if (enabled && !node.contains(event.target as Node)) {
			callback();
		}
	};

	const handleKeydown = (event: KeyboardEvent) => {
		if (enabled && event.key === 'Escape') {
			callback();
		}
	};

	document.addEventListener('click', handleClick);
	document.addEventListener('keydown', handleKeydown);

	return {
		destroy() {
			document.removeEventListener('click', handleClick);
			document.removeEventListener('keydown', handleKeydown);
		},
		update({ enabled: newEnabled, callback: newCb }: { enabled: boolean; callback: () => void }) {
			enabled = newEnabled;
			callback = newCb;
		}
	};
}
