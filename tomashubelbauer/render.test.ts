import { expect, test } from 'bun:test';
import parse from './parse';
import { createCanvas, SKRSContext2D } from '@napi-rs/canvas';
import layout from './layout';
import render from './render';
import { file, write } from 'bun';
import fetchCached from './fetchCached';
import type { Node, ElementNode } from './parse';

/* Note that `toMatchSnapshot` is not well suited for image snapshots */
// Note that Bun doesn't support `addSnapshotSerializer` yet:
// https://github.com/oven-sh/bun/issues/1825
// This means we can't use `toMatchSnapshot` for image snapshots that would open
// like normal image files for debugging purposes.
// Bun also doesn't support `expect.getState().currentTestName` so we can't get
// the name easily so we need to repeat the names.
async function expectMatchingImageSnapshot(name: string, context: SKRSContext2D) {
  const actualBuffer = await context.canvas.encode('png');

  const image = file(`render.test.ts.${name}.png`);
  if (await image.exists()) {
    const uint8Array = await image.bytes();
    const expectedBuffer = Buffer.from(uint8Array);
    expect(actualBuffer).toEqual(expectedBuffer);
    return;
  }

  write(`${import.meta.file}.${name}.png`, actualBuffer);
}

function renderNode(node: Node, getSuperNode: (node: Node) => ElementNode | undefined, width: number, height: number) {
  const canvas = createCanvas(width, height);
  const context = canvas.getContext('2d');

  // TODO: Do this in user agent styles
  context.save();
  context.fillStyle = 'white';
  context.fillRect(0, 0, context.canvas.width, context.canvas.height);
  context.restore();

  // TODO: Do this in `layout`
  context.translate(0, 10);

  render(layout(node, getSuperNode, context), context);
  return context;
}

test('short top-level string', async (done) => {
  const { node, getSuperNode } = parse('test');
  const context = renderNode(node, getSuperNode, 320, 240);
  await expectMatchingImageSnapshot('short-top-level-string', context);
  done();
});

test('too long top-level string', async (done) => {
  const { node, getSuperNode } = parse('test hello world'.repeat(15));
  const context = renderNode(node, getSuperNode, 320, 240);
  await expectMatchingImageSnapshot('too-long-top-level-string', context);
  done();
});

test('two blocks with short texts', async (done) => {
  const { node, getSuperNode } = parse('<P>first</P><P>second</P>');
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('two-blocks-with-short-texts', context);
  done();
});

test('one blocks with alternating texts and inlines', async (done) => {
  const { node, getSuperNode } = parse('<P>1<A>A</A>2<A>B</A>3<A>C</A>4</P>');
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('one-block-with-alternating-texts-and-inlines', context);
  done();
});

test('first web page perex', async (done) => {
  const text = await fetchCached('http://info.cern.ch/hypertext/WWW/TheProject.html');
  const { node, getSuperNode } = parse(text.slice(0, text.indexOf('<DL>')));
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('first-web-page-perex', context);
  done();
});

test('first web page', async (done) => {
  const text = await fetchCached('http://info.cern.ch/hypertext/WWW/TheProject.html');
  const { node, getSuperNode } = parse(text);
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('first-web-page', context);
  done();
});

test('paragraph with a link', async (done) => {
  const { node, getSuperNode } = parse(`
The WorldWideWeb (W3) is a wide-area<A
NAME=0 HREF="WhatIs.html">
hypermedia</A> information retrieval
initiative aiming to give universal
access to a large universe of documents
`);

  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('paragraph-with-a-link', context);
  done();
});

test('text link text', async (done) => {
  const { node, getSuperNode } = parse(`hello <A>there</A> world`);
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('text-link-text', context);
  done();
});

test('text link overflow text', async (done) => {
  const { node, getSuperNode } = parse(`hello <A>there</A> world how are you`);
  const context = renderNode(node, getSuperNode, 100, 100);
  await expectMatchingImageSnapshot('text-link-overflow-text', context);
  done();
});

test('text link text in paragraph', async (done) => {
  const { node, getSuperNode } = parse(`<P>hello <A>there</A> world</P>`);
  const context = renderNode(node, getSuperNode, 640, 480);
  await expectMatchingImageSnapshot('text-link-text-in-paragraph', context);
  done();
});

test('text link overflow text in paragraph', async (done) => {
  const { node, getSuperNode } = parse(`<P>hello <A>there</A> world how are you</P>`);
  const context = renderNode(node, getSuperNode, 100, 100);
  await expectMatchingImageSnapshot('text-link-overflow-text-in-paragraph', context);
  done();
});
