export function withHoverAndFocusListener(
	node: HTMLElement,
	{
		onFocusChange,
		onHoverChange
	}: { onFocusChange: (focused: boolean) => void; onHoverChange: (hovered: boolean) => void }
) {
	const updateFocusState = () => {
		onFocusChange(document.activeElement === node);
	};

	const updateHoverState = (hovered: boolean) => {
		onHoverChange(hovered);
	};

	node.addEventListener('focus', updateFocusState);
	node.addEventListener('blur', updateFocusState);
	node.addEventListener('mouseenter', () => updateHoverState(true));
	node.addEventListener('mouseleave', () => updateHoverState(false));

	return {
		destroy() {
			node.removeEventListener('focus', updateFocusState);
			node.removeEventListener('blur', updateFocusState);
			node.removeEventListener('mouseenter', () => updateHoverState(true));
			node.removeEventListener('mouseleave', () => updateHoverState(false));
		}
	};
}
