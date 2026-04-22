import { positionElementByTarget } from './positionElementByTarget';

const targetElement = {
  offsetHeight: 10,
  offsetWidth: 10,
} as HTMLElement;

const elementToPosition = {
  style: {
    top: '',
    bottom: '',
    left: '',
    right: '',
    transform: '',
  },
  offsetHeight: 100,
  offsetWidth: 100,
} as HTMLElement;

describe('positionElementByTarget', () => {
  it('should position element to the top', () => {
    positionElementByTarget(elementToPosition, targetElement, 'top', 15);

    expect(elementToPosition.style.top).toBe('');
    expect(elementToPosition.style.bottom).toBe('25px'); // 10 + 15
    expect(elementToPosition.style.left).toBe('50%');
    expect(elementToPosition.style.right).toBe('');
    expect(elementToPosition.style.transform).toBe('translateX(-50%)');
  });

  it('should position element to the bottom', () => {
    positionElementByTarget(elementToPosition, targetElement, 'bottom', 20);

    expect(elementToPosition.style.top).toBe('30px'); // 10 + 20
    expect(elementToPosition.style.bottom).toBe('');
    expect(elementToPosition.style.left).toBe('50%');
    expect(elementToPosition.style.right).toBe('');
    expect(elementToPosition.style.transform).toBe('translateX(-50%)');
  });

  it('should position element to the left', () => {
    positionElementByTarget(elementToPosition, targetElement, 'left', 25);

    expect(elementToPosition.style.top).toBe('50%');
    expect(elementToPosition.style.bottom).toBe('');
    expect(elementToPosition.style.left).toBe('auto');
    expect(elementToPosition.style.right).toBe('35px'); // 10 + 25
    expect(elementToPosition.style.transform).toBe('translateY(-50%)');
  });

  it('should position element to the right', () => {
    positionElementByTarget(elementToPosition, targetElement, 'right', 30);

    expect(elementToPosition.style.top).toBe('50%');
    expect(elementToPosition.style.bottom).toBe('');
    expect(elementToPosition.style.left).toBe('40px'); // 10 + 30
    expect(elementToPosition.style.right).toBe('auto');
    expect(elementToPosition.style.transform).toBe('translateY(-50%)');
  });
});
