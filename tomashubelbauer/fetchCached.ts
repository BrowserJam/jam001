import { file, write } from 'bun';

export default async function fetchCached(url: string) {
  const protocol = new URL(url).protocol;
  if (protocol !== 'http:' && protocol !== 'https:') {
    throw new Error('Only HTTP(S) URLs are supported');
  }

  const name = url.slice((protocol + '//').length).replace(/[^a-z0-9]+/gi, '-');
  const path = `${import.meta.file}.${name}.html`;

  const cache = file(path);
  if (await cache.exists()) {
    return await cache.text();
  }

  const response = await fetch(url);
  const text = await response.text();
  write(path, text);
  return text;
}
