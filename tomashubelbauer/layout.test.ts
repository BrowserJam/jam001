import { expect, test } from 'bun:test';
import parse from './parse';
import { createCanvas } from '@napi-rs/canvas';
import layout from './layout';
import fetchCached from './fetchCached';

test('top-level text', () => {
  const { node, getSuperNode } = parse('test');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'text',
        text: 'test',
        width: 16,
        height: 9,
        x: 0,
        y: 0,
      }
    ],
    width: 16,
    height: 9,
    x: 0,
    y: 0,
  });
});

test('top-level overflowing text', () => {
  const { node, getSuperNode } = parse('test hello world'.repeat(15));
  const canvas = createCanvas(320, 240);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'text',
        text: 'test hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello world',
        width: 1000,
        height: 9,
        x: 0,
        y: 0,
        layout: 'removed',
      },
      {
        type: 'text',
        text: 'test hello worldtest hello worldtest hello worldtest hello worldtest hello w',
        width: 316,
        height: 9,
        x: 0,
        y: 0,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'orldtest hello worldtest hello worldtest hello worldtest hello worldtest hell',
        width: 317,
        height: 9,
        x: 0,
        y: 9,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'o worldtest hello worldtest hello worldtest hello worldtest hello worldtest ',
        width: 317,
        height: 9,
        x: 0,
        y: 18,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'hello world',
        width: 50,
        height: 9,
        x: 0,
        y: 27,
        layout: 'added',
      }
    ],
    width: 317,
    height: 36,
    x: 0,
    y: 0,
  });
});

test('paragraph text', () => {
  const { node, getSuperNode } = parse('<P>test');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'P',
    nodes: [
      {
        type: 'text',
        text: 'test',
        width: 16,
        height: 9,
        x: 0,
        y: 8,
      }
    ],
    width: 16,
    height: 9,
    x: 0,
    y: 8,
  });
});

test('paragraph overflowing text', () => {
  const { node, getSuperNode } = parse('<P>' + 'test hello world'.repeat(15));
  const canvas = createCanvas(320, 240);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'P',
    nodes: [
      {
        type: 'text',
        text: 'test hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello worldtest hello world',
        width: 1000,
        height: 9,
        x: 0,
        y: 0,
        layout: 'removed',
      },
      {
        type: 'text',
        text: 'test hello worldtest hello worldtest hello worldtest hello worldtest hello w',
        width: 316,
        height: 9,
        x: 0,
        y: 8,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'orldtest hello worldtest hello worldtest hello worldtest hello worldtest hell',
        width: 317,
        height: 9,
        x: 0,
        y: 17,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'o worldtest hello worldtest hello worldtest hello worldtest hello worldtest ',
        width: 317,
        height: 9,
        x: 0,
        y: 26,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'hello world',
        width: 50,
        height: 9,
        x: 0,
        y: 35,
        layout: 'added',
      }
    ],
    width: 317,
    height: 36,
    x: 0,
    y: 8,
  });
});

test('paragraph text and paragraph text', () => {
  const { node, getSuperNode } = parse('<P>first<P>second');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 8,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 8,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 0,
            y: 25,
          }
        ],
        width: 32,
        height: 9,
        x: 0,
        y: 25,
      }
    ],
    width: 32,
    height: 34,
    x: 0,
    y: 0,
  });
});

test('overflowing paragraph text and paragraph text', () => {
  const { node, getSuperNode } = parse(`<P>first<P>${'second '.repeat(20)}`);
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 8,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 8,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'second second second second second second second second second second second second second second second second second second second second ',
            width: 700,
            height: 9,
            x: 0,
            y: 0,
            layout: 'removed',
          },
          {
            type: 'text',
            text: 'second second second second second second second second second second second second second second second second second second s',
            width: 635,
            height: 9,
            x: 0,
            y: 25,
            layout: 'added',
          },
          {
            type: 'text',
            text: 'econd second ',
            width: 65,
            height: 9,
            x: 0,
            y: 34,
            layout: 'added',
          }
        ],
        width: 635,
        height: 18,
        x: 0,
        y: 25,
      }
    ],
    width: 635,
    height: 43,
    x: 0,
    y: 0,
  });
});

test('text link overflow text in paragraph', () => {
  const { node, getSuperNode } = parse(`<P>hello <A>there</A> world how are you</P>`);
  const canvas = createCanvas(100, 100);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'P',
    nodes: [
      {
        type: 'text',
        text: 'hello ',
        width: 23,
        height: 9,
        x: 0,
        y: 8,
      },
      {
        type: 'element',
        tag: 'A',
        nodes: [
          {
            type: 'text',
            text: 'there',
            width: 22,
            height: 9,
            x: 23,
            y: 8,
          },
        ],
        width: 22,
        height: 9,
        x: 23,
        y: 8,
      },
      {
        type: 'text',
        text: ' world how are you',
        width: 83,
        height: 9,
        x: 0,
        y: 0,
        layout: 'removed'
      },
      {
        type: 'text',
        text: ' world how ',
        width: 50,
        height: 9,
        x: 45,
        y: 8,
        layout: 'added'
      },
      {
        type: 'text',
        text: 'are you',
        width: 33,
        height: 9,
        x: 0,
        y: 17,
        layout: 'added'
      },
    ],
    width: 95,
    height: 18,
    x: 0,
    y: 8,
  });
});

test('paragraph text and overflowing paragraph text', () => {
  const { node, getSuperNode } = parse(`<P>${'first '.repeat(40)}<P>second`);
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first ',
            width: 755,
            height: 9,
            x: 0,
            y: 0,
            layout: 'removed',
          },
          {
            type: 'text',
            text: 'first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first first',
            width: 639,
            height: 9,
            x: 0,
            y: 8,
            layout: 'added',
          },
          {
            type: 'text',
            text: ' first first first first first first ',
            width: 116,
            height: 9,
            x: 0,
            y: 17,
            layout: 'added',
          }
        ],
        width: 639,
        height: 18,
        x: 0,
        y: 8,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 0,
            y: 34,
          }
        ],
        width: 32,
        height: 9,
        x: 0,
        y: 34,
      },
    ],
    width: 639,
    height: 43,
    x: 0,
    y: 0,
  });
});

// TODO: Add tests for 9 combinations of three items of paragraph text and overflowing paragraph text to validate nesting

test('two blocks with short texts', () => {
  const { node, getSuperNode } = parse('<P>first<P>second');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 8,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 8,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 0,
            y: 25,
          }
        ],
        width: 32,
        height: 9,
        x: 0,
        y: 25,
      }
    ],
    width: 32,
    height: 34,
    x: 0,
    y: 0,
  });
});

test('one inline', () => {
  const { node, getSuperNode } = parse('<A>link</A>');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'A',
    nodes: [
      {
        type: 'text',
        text: 'link',
        width: 15,
        height: 9,
        x: 0,
        y: 0,
      }
    ],
    width: 15,
    height: 9,
    x: 0,
    y: 0,
  });
});

test('two inlines', () => {
  const { node, getSuperNode } = parse('<A>first</A><A>second</A>');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'A',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 0,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'A',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 16,
            y: 0,
          }
        ],
        width: 32,
        height: 9,
        x: 16,
        y: 0,
      }
    ],
    width: 48,
    height: 9,
    x: 0,
    y: 0,
  });
});

test('one blocks with alternating texts and inlines', () => {
  const { node, getSuperNode } = parse('<P>1<A>A</A>2<A>B</A>3<A>C</A>4</P>');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: "element",
    tag: "P",
    nodes: [
      {
        type: "text",
        text: "1",
        width: 5,
        height: 9,
        x: 0,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "A",
            width: 6,
            height: 9,
            x: 5,
            y: 8,
          }
        ],
        width: 6,
        height: 9,
        x: 5,
        y: 8,
      }, {
        type: "text",
        text: "2",
        width: 5,
        height: 9,
        x: 11,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "B",
            width: 6,
            height: 9,
            x: 16,
            y: 8,
          }
        ],
        width: 6,
        height: 9,
        x: 16,
        y: 8,
      }, {
        type: "text",
        text: "3",
        width: 5,
        height: 9,
        x: 22,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "C",
            width: 7,
            height: 9,
            x: 27,
            y: 8,
          }
        ],
        width: 7,
        height: 9,
        x: 27,
        y: 8,
      }, {
        type: "text",
        text: "4",
        width: 5,
        height: 9,
        x: 34,
        y: 8,
      }
    ],
    width: 39,
    height: 9,
    x: 0,
    y: 8,
  });
});

test('definition list', () => {
  const { node, getSuperNode } = parse(`
<DL>
  <DT>term1</DT>
  <DD>def1</DD>
  <DT>term2</DT>
  <DD>def2</DD>
</DL>
`);

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'DL',
    nodes: [
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'DT',
        nodes: [
          {
            type: 'text',
            text: 'term1',
            width: 25,
            height: 9,
            x: 5,
            y: 8
          }
        ],
        width: 25,
        height: 9,
        x: 5,
        y: 8,
      },
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 17,
      },
      {
        type: 'element',
        tag: 'DD',
        nodes: [
          {
            type: 'text',
            text: 'def1',
            width: 19,
            height: 9,
            x: 37,
            y: 17
          }
        ],
        width: 19,
        height: 9,
        x: 37,
        y: 17,
      },
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 26,
      },
      {
        type: 'element',
        tag: 'DT',
        nodes: [
          {
            type: 'text',
            text: 'term2',
            width: 25,
            height: 9,
            x: 5,
            y: 34
          }
        ],
        width: 25,
        height: 9,
        x: 5,
        y: 34,
      },
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 43,
      },
      {
        type: 'element',
        tag: 'DD',
        nodes: [
          {
            type: 'text',
            text: 'def2',
            width: 19,
            height: 9,
            x: 37,
            y: 43
          }
        ],
        width: 19,
        height: 9,
        x: 37,
        y: 43,
      },
    ],
    width: 56,
    height: 52,
    x: 0,
    y: 0,
  });
});

test.todo('mix of blocks and inlines', () => {
  const { node, getSuperNode } = parse(`
<P>first</P>
<P>second</P>
<P>third</P>
<DL>
  <DT>term1</DT>
  <DD>def1</DD>
  <DT>term2</DT>
  <DD>def2</DD>
</DL>
<MENU>
  <A>first</A>
  |
  <A>second</A>
  |
  <A>third</A>
</MENU>
<DIV>
  long text followed by an <IMG />
  long text followed by an <IMG />
  long text followed by an <IMG />
  long text followed by an <IMG />
  long text followed by an <IMG />
</DIV>
`);

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 0,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 0,
            y: 9,
          }
        ],
        width: 32,
        height: 9,
        x: 0,
        y: 9,
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          {
            type: 'text',
            text: 'third',
            width: 19,
            height: 9,
            x: 0,
            y: 18,
          }
        ],
        width: 19,
        height: 9,
        x: 0,
        y: 18,
      },
      {
        type: 'element',
        tag: 'UL',
        nodes: [
          {
            type: 'text',
            text: '  ',
            width: 5,
            height: 9,
            x: 0,
            y: 27,
          }, {
            type: 'element',
            tag: 'LI',
            nodes: [
              {
                type: 'text',
                text: 'first',
                width: 16,
                height: 9,
                x: 5,
                y: 27,
              }
            ],
            width: 16,
            height: 9,
            x: 5,
            y: 27,
          }, {
            type: 'text',
            text: '  ',
            width: 5,
            height: 9,
            x: 0,
            y: 36,
          }, {
            type: 'element',
            tag: 'LI',
            nodes: [
              {
                type: 'text',
                text: 'second',
                width: 32,
                height: 9,
                x: 5,
                y: 36,
              }
            ],
            width: 32,
            height: 9,
            x: 5,
            y: 36,
          }, {
            type: 'text',
            text: '  ',
            width: 5,
            height: 9,
            x: 0,
            y: 45,
          }, {
            type: 'element',
            tag: 'LI',
            nodes: [
              {
                type: 'text',
                text: 'third',
                width: 19,
                height: 9,
                x: 5,
                y: 45,
              }
            ],
            width: 19,
            height: 9,
            x: 5,
            y: 45,
          }
        ],
        width: 82,
        height: 9,
        x: 0,
        y: 27,
      }, {
        type: 'element',
        tag: 'MENU',
        nodes: [
          {
            type: 'text',
            text: '  ',
            width: 5,
            height: 9,
            x: 0,
            y: 36,
          }, {
            type: 'element',
            tag: 'A',
            nodes: [
              {
                type: 'text',
                text: 'first',
                width: 16,
                height: 9,
                x: 5,
                y: 36,
              }
            ],
            width: 16,
            height: 9,
            x: 5,
            y: 36,
          }, {
            type: 'text',
            text: '  |   ',
            width: 16,
            height: 9,
            x: 21,
            y: 36,
          }, {
            type: 'element',
            tag: 'A',
            nodes: [
              {
                type: 'text',
                text: 'second',
                width: 32,
                height: 9,
                x: 37,
                y: 36,
              }
            ],
            width: 32,
            height: 9,
            x: 37,
            y: 36,
          }, {
            type: 'text',
            text: '  |   ',
            width: 16,
            height: 9,
            x: 69,
            y: 36,
          }, {
            type: 'element',
            tag: 'A',
            nodes: [
              {
                type: 'text',
                text: 'third',
                width: 19,
                height: 9,
                x: 85,
                y: 36,
              }
            ],
            width: 19,
            height: 9,
            x: 85,
            y: 36,
          }
        ],
        width: 104,
        height: 9,
        x: 0,
        y: 36,
      }, {
        type: 'element',
        tag: 'DIV',
        nodes: [
          {
            type: 'text',
            text: '  long text followed by an ',
            width: 112,
            height: 9,
            x: 0,
            y: 45,
          }, {
            type: 'element',
            tag: 'IMG',
            nodes: [
              {
                type: 'text',
                text: '  long text followed by an ',
                width: 112,
                height: 9,
                x: 112,
                y: 45,
              }, {
                type: 'element',
                tag: 'IMG',
                nodes: [
                  {
                    type: 'text',
                    text: '  long text followed by an ',
                    width: 112,
                    height: 9,
                    x: 224,
                    y: 45,
                  }, {
                    type: 'element',
                    tag: 'IMG',
                    nodes: [

                    ],
                    width: 224,
                    height: 9,
                    x: 336,
                    y: 45,
                  }
                ],
                width: 336,
                height: 9,
                x: 224,
                y: 45,
              }
            ],
            width: 448,
            height: 9,
            x: 112,
            y: 45,
          }
        ],
        width: 560,
        height: 9,
        x: 0,
        y: 45,
      }
    ],
    width: 813,
    height: 9,
    x: 0,
    y: 0,
  });
});

test('nested blocks', () => {
  const { node, getSuperNode } = parse(`<DIV><DIV>first</DIV><DIV>second</DIV></DIV>`);
  const canvas = createCanvas(320, 240);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'DIV',
    nodes: [
      {
        type: 'element',
        tag: 'DIV',
        nodes: [
          {
            type: 'text',
            text: 'first',
            width: 16,
            height: 9,
            x: 0,
            y: 0,
          }
        ],
        width: 16,
        height: 9,
        x: 0,
        y: 0,
      }, {
        type: 'element',
        tag: 'DIV',
        nodes: [
          {
            type: 'text',
            text: 'second',
            width: 32,
            height: 9,
            x: 0,
            y: 9,
          }
        ],
        width: 32,
        height: 9,
        x: 0,
        y: 9,
      }
    ],
    width: 32,
    height: 18,
    x: 0,
    y: 0,
  });
});

test('nested blocks that both overflow', () => {
  const { node, getSuperNode } = parse(`
<DIV>
  <DIV>${'first '.repeat(20)}</DIV>
  <DIV>${'second '.repeat(20)}</DIV>
</DIV>
`);

  const canvas = createCanvas(320, 240);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'DIV',
    nodes: [
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'DIV',
        nodes: [
          {
            type: 'text',
            text: 'first first first first first first first first first first first first first first first first first first first first ',
            width: 377,
            height: 9,
            x: 0,
            y: 0,
            layout: 'removed'
          },
          {
            type: 'text',
            text: 'first first first first first first first first first first first first first first first first firs',
            width: 315,
            height: 9,
            x: 5,
            y: 0,
            layout: 'added'
          },
          {
            type: 'text',
            text: 't first first first ',
            width: 62,
            height: 9,
            x: 5,
            y: 9,
            layout: 'added'
          }
        ],
        width: 315,
        height: 18,
        x: 5,
        y: 0,
      },
      {
        type: 'text',
        text: '  ',
        width: 5,
        height: 9,
        x: 0,
        y: 18,
      },
      {
        type: 'element',
        tag: 'DIV',
        nodes: [
          {
            type: 'text',
            text: 'second second second second second second second second second second second second second second second second second second second second ',
            width: 700,
            height: 9,
            x: 0,
            y: 0,
            layout: 'removed'
          },
          {
            type: 'text',
            text: 'second second second second second second second second second ',
            width: 315,
            height: 9,
            x: 5,
            y: 18,
            layout: 'added'
          },
          {
            type: 'text',
            text: 'second second second second second second second second second ',
            width: 315,
            height: 9,
            x: 5,
            y: 27,
            layout: 'added'
          },
          {
            type: 'text',
            text: 'second second ',
            width: 70,
            height: 9,
            x: 5,
            y: 36,
            layout: 'added'
          }
        ],
        width: 315,
        height: 27,
        x: 5,
        y: 18,
      }
    ],
    width: 320,
    height: 45,
    x: 0,
    y: 0,
  });
});

test('text and a multi-line wrapped link', () => {
  const { node, getSuperNode } = parse(`Hello, world! <A>This text is wrapped. It will exceed multiple lines.</A> Goodbye, world!`);
  const canvas = createCanvas(100, 100);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: "element",
    tag: "HTML",
    nodes: [
      {
        type: "text",
        text: "Hello, world! ",
        width: 57,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "This text is wrapped. It will exceed multiple lines.",
            width: 215,
            height: 9,
            x: 0,
            y: 0,
            layout: "removed",
          }
        ],
        width: 0,
        height: 0,
        x: 0,
        y: 0,
        layout: "removed",
      },
      {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "This text i",
            width: 42,
            height: 9,
            x: 57,
            y: 0,
            layout: "added",
          }
        ],
        width: 42,
        height: 9,
        x: 57,
        y: 0,
        layout: "added",
      },
      {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "s wrapped. It will exce",
            width: 97,
            height: 9,
            x: 0,
            y: 9,
            layout: "added",
          }
        ],
        width: 97,
        height: 9,
        x: 0,
        y: 9,
        layout: "added",
      },
      {
        type: "element",
        tag: "A",
        nodes: [
          {
            type: "text",
            text: "ed multiple lines.",
            width: 76,
            height: 9,
            x: 0,
            y: 18,
            layout: "added",
          }
        ],
        width: 76,
        height: 9,
        x: 0,
        y: 18,
        layout: "added",
      },
      {
        type: "text",
        text: " Goodbye, world!",
        width: 75,
        height: 9,
        x: 0,
        y: 0,
        layout: "removed",
      },
      {
        type: "text",
        text: " Goo",
        width: 21,
        height: 9,
        x: 76,
        y: 18,
        layout: "added",
      },
      {
        type: "text",
        text: "dbye, world!",
        width: 54,
        height: 9,
        x: 0,
        y: 27,
        layout: "added",
      },
    ],
    width: 99,
    height: 36,
    x: 0,
    y: 0,
  });
});

test('paragraph with a link', () => {
  const { node, getSuperNode } = parse(`
The WorldWideWeb (W3) is a wide-area<A
NAME=0 HREF="WhatIs.html">
hypermedia</A> information retrieval
initiative aiming to give universal
access to a large universe of documents
`);

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'text',
        text: 'The WorldWideWeb (W3) is a wide-area',
        width: 178,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'A',
        attributes: {
          HREF: 'WhatIs.html',
          NAME: '0',
        },
        nodes: [
          {
            type: 'text',
            text: 'hypermedia',
            width: 52,
            height: 9,
            x: 178,
            y: 0,
          }
        ],
        width: 52,
        height: 9,
        x: 178,
        y: 0,
      },
      {
        type: 'text',
        text: ' information retrieval initiative aiming to give universal access to a large universe of documents ',
        width: 421,
        height: 9,
        x: 0,
        y: 0,
        layout: 'removed',
      },
      {
        type: 'text',
        text: ' information retrieval initiative aiming to give universal access to a large universe of documen',
        width: 410,
        height: 9,
        x: 230,
        y: 0,
        layout: 'added',
      },
      {
        type: 'text',
        text: 'ts ',
        width: 11,
        height: 9,
        x: 0,
        y: 9,
        layout: 'added',
      }
    ],
    width: 640,
    height: 18,
    x: 0,
    y: 0,
  });
});

test('paragraph with several links', () => {
  const { node, getSuperNode } = parse(`
<P>
Everything there is online about
W3 is linked directly or indirectly
to this document, including an <A
NAME=24 HREF="Summary.html">executive
summary</A> of the project, <A
NAME=29 HREF="Administration/Mailing/Overview.html">Mailing lists</A>
, <A
NAME=30 HREF="Policy.html">Policy</A> , November's  <A
NAME=34 HREF="News/9211.html">W3  news</A> ,
<A
NAME=41 HREF="FAQ/List.html">Frequently Asked Questions</A> .
`);

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: "element",
    tag: "P",
    nodes: [
      {
        type: "text",
        text: "Everything there is online about W3 is linked directly or indirectly to this document, including an ",
        width: 422,
        height: 9,
        x: 0,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "24",
          HREF: "Summary.html",
        },
        nodes: [
          {
            type: "text",
            text: "executive summary",
            width: 86,
            height: 9,
            x: 422,
            y: 8,
          }
        ],
        width: 86,
        height: 9,
        x: 422,
        y: 8,
      }, {
        type: "text",
        text: " of the project, ",
        width: 66,
        height: 9,
        x: 508,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "29",
          HREF: "Administration/Mailing/Overview.html",
        },
        nodes: [
          {
            type: "text",
            text: "Mailing lists",
            width: 51,
            height: 9,
            x: 574,
            y: 8,
          }
        ],
        width: 51,
        height: 9,
        x: 574,
        y: 8,
      }, {
        type: "text",
        text: ", ",
        width: 5,
        height: 9,
        x: 625,
        y: 8,
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "30",
          HREF: "Policy.html",
        },
        nodes: [
          {
            type: "text",
            text: "Policy",
            width: 26,
            height: 9,
            x: 0,
            y: 0,
            layout: "removed",
          }
        ],
        width: 0,
        height: 0,
        x: 0,
        y: 0,
        layout: "removed",
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "30",
          HREF: "Policy.html",
        },
        nodes: [
          {
            type: "text",
            text: "P",
            width: 6,
            height: 9,
            x: 630,
            y: 8,
            layout: "added",
          }
        ],
        width: 6,
        height: 9,
        x: 630,
        y: 0,
        layout: "added",
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "30",
          HREF: "Policy.html",
        },
        nodes: [
          {
            type: "text",
            text: "olicy",
            width: 20,
            height: 9,
            x: 0,
            y: 17,
            layout: "added",
          }
        ],
        width: 20,
        height: 9,
        x: 0,
        y: 9,
        layout: "added",
      }, {
        type: "text",
        text: " , November's  ",
        width: 66,
        height: 9,
        x: 20,
        y: 17,
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "34",
          HREF: "News/9211.html",
        },
        nodes: [
          {
            type: "text",
            text: "W3  news",
            width: 43,
            height: 9,
            x: 86,
            y: 17,
          }
        ],
        width: 43,
        height: 9,
        x: 86,
        y: 17,
      }, {
        type: "text",
        text: " , ",
        width: 8,
        height: 9,
        x: 129,
        y: 17,
      }, {
        type: "element",
        tag: "A",
        attributes: {
          NAME: "41",
          HREF: "FAQ/List.html",
        },
        nodes: [
          {
            type: "text",
            text: "Frequently Asked Questions",
            width: 125,
            height: 9,
            x: 137,
            y: 17,
          }
        ],
        width: 125,
        height: 9,
        x: 137,
        y: 17,
      }, {
        type: "text",
        text: " . ",
        width: 8,
        height: 9,
        x: 262,
        y: 17,
      }
    ],
    width: 636,
    height: 18,
    x: 0,
    y: 8,
  });
});

test('inline after block', () => {
  const { node, getSuperNode } = parse(`<H1>Header</H1><A>Link</A>`);

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'H1',
        nodes: [
          {
            type: 'text',
            text: 'Header',
            width: 81,
            height: 21,
            x: 8,
            y: 0,
          }
        ],
        width: 81,
        height: 21,
        x: 8,
        y: 0,
      },
      {
        type: 'element',
        tag: 'A',
        nodes: [
          {
            type: 'text',
            text: 'Link',
            width: 18,
            height: 9,
            x: 0,
            y: 21,
          }
        ],
        width: 18,
        height: 9,
        x: 0,
        y: 21,
      },
    ],
    width: 89,
    height: 30,
    x: 0,
    y: 0,
  });
});

test('first web page title', async () => {
  const text = await fetchCached('http://info.cern.ch/hypertext/WWW/TheProject.html');
  const { node, getSuperNode } = parse(text.slice(0, text.indexOf('<BODY>')));

  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'HEADER',
    nodes: [
      {
        type: 'element',
        tag: 'TITLE',
        nodes: [
          {
            type: 'text',
            text: 'The World Wide Web project',
            width: 127,
            height: 9,
            x: 0,
            y: 0,
          },
        ],
        width: 127,
        height: 9,
        x: 0,
        y: 0,
      },
      {
        type: 'element',
        tag: 'NEXTID',
        attributes: {
          N: '55',
        },
        width: 0,
        height: 0,
        x: 127,
        y: 0,
      }
    ],
    width: 127,
    height: 9,
    x: 0,
    y: 0,
  },);
});

test('H1 user agent font', () => {
  const { node, getSuperNode } = parse('<H1>Header</H1>');
  const canvas = createCanvas(640, 480);
  const context = canvas.getContext('2d');
  expect(layout(node, getSuperNode, context)).toEqual({
    type: 'element',
    tag: 'H1',
    nodes: [
      {
        type: 'text',
        text: 'Header',
        width: 81,
        height: 21,
        x: 8,
        y: 0,
      }
    ],
    width: 81,
    height: 21,
    x: 8,
    y: 0,
  });
});
