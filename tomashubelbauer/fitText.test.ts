import { expect, test } from 'bun:test';
import fitText from './fitText';
import { createCanvas } from '@napi-rs/canvas';

test('empty', () => {
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(fitText('', 100, context)).toEqual({ text: '', width: 0 });
});

test('fit', () => {
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(fitText('short', 100, context)).toEqual({ text: 'short', width: 22 });
});

test('one break', () => {
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');

  let text = 'short but long enough to break';

  const slice = fitText(text, 100, context);
  expect(slice).toEqual({
    text: 'short but long enough ',
    width: 99,
  });

  const rest = text.slice(slice.text.length);
  expect(fitText(rest, 100, context)).toEqual({ text: 'to break', width: 36 });
});

test('two breaks', () => {
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');

  let text = 'short but long enough to break and then break again';

  const slice1 = fitText(text, 100, context);
  expect(slice1).toEqual({
    text: 'short but long enough ',
    width: 99,
  });

  text = text.slice(slice1.text.length);

  const slice2 = fitText(text, 100, context);
  expect(slice2).toEqual({
    text: 'to break and then brea',
    width: 100,
  });

  const rest = text.slice(slice2.text.length);
  expect(fitText(rest, 100, context)).toEqual({ text: 'k again', width: 32 });
});
