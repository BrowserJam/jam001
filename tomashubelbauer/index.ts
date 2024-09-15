import { write } from 'bun';
import { createCanvas } from '@napi-rs/canvas';
import parse from './parse';
import layout from './layout';
import render from './render';
import fetchCached from './fetchCached';

// TODO: Accept a custom URL from the CLI
// Download the 1st WWW website page and parse it
// Use `view-source:http://info.cern.ch/hypertext/WWW/TheProject.html` to debug
const url = 'http://info.cern.ch/hypertext/WWW/TheProject.html';

// Set up the native, Skia-based `canvas` and its 2D rendering `context`
const canvas = createCanvas(640, 480);
const context = canvas.getContext('2d');

context.save();
context.fillStyle = 'white';
context.fillRect(0, 0, canvas.width, canvas.height);
context.restore();

const html = await fetchCached(url);
let document = parse(html);
if (document.errors.length > 0) {
  let html = `<DIV color=red>Leveret failed to parse ${url}!</DIV>`;
  for (const error of document.errors) {
    html += `<DIV>${error}</DIV>`;
  }

  document = parse(html);
}

const { node, getSuperNode, errors, infos } = document;
if (errors.length > 0) {
  throw new Error(`Failed to parse ${url}:\n${errors.join('\n')}`);
}

for (const info of infos) {
  console.log(info);
}

render(layout(node, getSuperNode, context), context);
await write('index.png', await canvas.encode('png'));
