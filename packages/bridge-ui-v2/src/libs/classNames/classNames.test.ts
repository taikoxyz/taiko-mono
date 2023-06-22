import { classNames } from './classNames';

test('classNames lib', () => {
  expect(classNames('class1', 'class2 class3')).toBe('class1 class2 class3');
  expect(classNames('class1', 'class2', null)).toBe('class1 class2');
  expect(classNames('class1', 'class2', undefined)).toBe('class1 class2');
  expect(classNames('class1', null, 'class3', '', 'class5')).toBe('class1 class3 class5');
});
