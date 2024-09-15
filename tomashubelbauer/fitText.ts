import { SKRSContext2D } from '@napi-rs/canvas';

export default function fitText(text: string, limit: number, context: SKRSContext2D) {
  if (limit < 0) {
    throw new Error('limit must be greater than or equal to 0');
  }

  let low = 0;
  let high = text.length;
  let result = text;
  let finalWidth = 0;

  while (low <= high) {
    const mid = ~~((low + high) / 2);
    const candidate = text.slice(0, mid);
    const width = ~~context.measureText(candidate).width;

    if (width <= limit) {
      result = candidate;
      finalWidth = width;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return {
    text: result,
    width: finalWidth,
  };
}
