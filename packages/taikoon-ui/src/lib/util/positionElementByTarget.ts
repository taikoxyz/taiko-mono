// TODO: add support for other positions: 'top-left', 'bottom-right', etc...
export function positionElementByTarget(
  elementToPosition: HTMLElement,
  targetElement: HTMLElement,
  position: Position = 'top',
  gap = 10,
) {
  const { style } = elementToPosition;

  // Reset styles.
  style.top = '';
  style.bottom = '';
  style.left = '';
  style.right = '';
  style.transform = '';

  switch (position) {
    case 'top':
    case 'top-right':
    case 'top-left':
      style.bottom = `${targetElement.offsetHeight + gap}px`;
      style.left = '50%';
      style.transform = 'translateX(-50%)';
      break;
    case 'bottom':
    case 'bottom-right':
    case 'bottom-left':
      style.top = `${targetElement.offsetHeight + gap}px`;
      style.left = '50%';
      style.transform = 'translateX(-50%)';
      break;
    case 'left':
      style.left = 'auto';
      style.right = `${targetElement.offsetWidth + gap}px`;
      style.top = '50%';
      style.transform = 'translateY(-50%)';
      break;
    case 'right':
      style.right = 'auto';
      style.left = `${targetElement.offsetWidth + gap}px`;
      style.top = '50%';
      style.transform = 'translateY(-50%)';
      break;
  }
}
