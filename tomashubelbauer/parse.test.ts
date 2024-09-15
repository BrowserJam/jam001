import { test, expect } from 'bun:test';
import parse from './parse';
import fetchCached from './fetchCached';

// TODO: Fix following the parsing changes (seems to be parsing okayish still)
test.todo('first web page', async () => {
  const text = await fetchCached('http://info.cern.ch/hypertext/WWW/TheProject.html');
  const { node, errors, infos } = parse(text);

  expect(infos).toEqual(['Could not find a matching opening tag for A']);
  expect(errors).toEqual([]);
  expect(node).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'HEADER',
        nodes: [
          {
            type: 'element',
            tag: 'TITLE',
            nodes: [
              {
                type: 'text',
                text: 'The World Wide Web project'
              }
            ]
          },
          {
            type: 'element',
            tag: 'NEXTID',
            attributes: {
              N: '55'
            }
          }
        ]
      },
      {
        type: 'element',
        tag: 'BODY',
        nodes: [
          {
            type: 'element',
            tag: 'H1',
            nodes: [
              {
                type: 'text',
                text: 'World Wide Web'
              }
            ]
          },
          {
            type: 'text',
            text: 'The WorldWideWeb (W3) is a wide-area'
          },
          {
            type: 'element',
            tag: 'A',
            attributes: {
              NAME: '0',
              HREF: 'WhatIs.html'
            },
            nodes: [
              {
                type: 'text',
                text: 'hypermedia'
              }
            ]
          },
          {
            type: 'text',
            text: ' information retrieval initiative aiming to give universal access to a large universe of documents.'
          },
          {
            type: 'element',
            tag: 'P',
            nodes: [
              {
                type: 'text',
                text: 'Everything there is online about W3 is linked directly or indirectly to this document, including an '
              },
              {
                type: 'element',
                tag: 'A',
                attributes: {
                  NAME: '24',
                  HREF: 'Summary.html'
                },
                nodes: [
                  {
                    type: 'text',
                    text: 'executive summary'
                  }
                ]
              },
              {
                type: 'text',
                text: ' of the project, '
              },
              {
                type: 'element',
                tag: 'A',
                attributes: {
                  NAME: '29',
                  HREF: 'Administration/Mailing/Overview.html'
                },
                nodes: [
                  {
                    type: 'text',
                    text: 'Mailing lists'
                  }
                ]
              },
              {
                type: 'text',
                text: ', '
              },
              {
                type: 'element',
                tag: 'A',
                attributes: {
                  NAME: '30',
                  HREF: 'Policy.html'
                },
                nodes: [
                  {
                    type: 'text',
                    text: 'Policy'
                  }
                ]
              },
              {
                type: 'text',
                text: ' , November\'s  '
              },
              {
                type: 'element',
                tag: 'A',
                attributes: {
                  NAME: '34',
                  HREF: 'News/9211.html'
                },
                nodes: [
                  {
                    type: 'text',
                    text: 'W3  news'
                  }
                ]
              },
              {
                type: 'text',
                text: ' , '
              },
              {
                type: 'element',
                tag: 'A',
                attributes: {
                  NAME: '41',
                  HREF: 'FAQ/List.html'
                },
                nodes: [
                  {
                    type: 'text',
                    text: 'Frequently Asked Questions'
                  }
                ]
              },
              {
                type: 'text',
                text: ' . '
              },
              {
                type: 'element',
                tag: 'DL',
                nodes: [
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '44',
                          HREF: '../DataSources/Top.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'What\'s out there?'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' Pointers to the world\'s online information,'
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '45',
                          HREF: '../DataSources/bySubject/Overview.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: ' subjects'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ', '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: 'z54',
                          HREF: '../DataSources/WWW/Servers.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'W3 servers'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ', etc. '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '46',
                          HREF: 'Help.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Help'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' on the browser you are using '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '13',
                          HREF: 'Status.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Software Products'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' A list of W3 project components and their current state. (e.g. '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '27',
                          HREF: 'LineMode/Browser.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Line Mode'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ,X11 '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '35',
                          HREF: 'Status.html#35'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Viola'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ,  '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '26',
                          HREF: 'NeXT/WorldWideWeb.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'NeXTStep'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ', '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '25',
                          HREF: 'Daemon/Overview.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Servers'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' , '
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '51',
                          HREF: 'Tools/Overview.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Tools'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ,'
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '53',
                          HREF: 'MailRobot/Overview.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: ' Mail robot'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ,'
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '52',
                          HREF: 'Status.html#57'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Library'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ) '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '47',
                          HREF: 'Technical.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Technical'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' Details of protocols, formats, program internals etc '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '40',
                          HREF: 'Bibliography.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Bibliography'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' Paper documentation on  W3 and references. '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '14',
                          HREF: 'People.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'People'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' A list of some people involved in the project. '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '15',
                          HREF: 'History.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'History'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' A summary of the history of the project. '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '37',
                          HREF: 'Helping.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'How can I help'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' ? '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' If you would like to support the web.. '
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DT',
                    nodes: [
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '48',
                          HREF: '../README.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'Getting code'
                          }
                        ]
                      }
                    ]
                  },
                  {
                    type: 'element',
                    tag: 'DD',
                    nodes: [
                      {
                        type: 'text',
                        text: ' Getting the code by'
                      },
                      {
                        type: 'element',
                        tag: 'A',
                        attributes: {
                          NAME: '49',
                          HREF: 'LineMode/Defaults/Distribution.html'
                        },
                        nodes: [
                          {
                            type: 'text',
                            text: 'anonymous FTP'
                          }
                        ]
                      },
                      {
                        type: 'text',
                        text: ' , etc.'
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  });
});

test('three paragraphs', () => {
  const { node, errors, infos } = parse(`
<P>first</P>
<P>second</P>
<P>third</P>
`);

  expect(infos).toEqual([]);
  expect(errors).toEqual([]);
  expect(node).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'P',
        nodes: [
          { type: 'text', text: 'first' }
        ]
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          { type: 'text', text: 'second' }
        ]
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [
          { type: 'text', text: 'third' }
        ]
      },
    ]
  });
});

test('plain text', () => {
  const { node, errors, infos } = parse('test');

  expect(infos).toEqual([]);
  expect(errors).toEqual([]);
  expect(node).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'text',
        text: 'test',
      }
    ]
  });
});

test('self-closing tag', () => {
  const { node, errors, infos } = parse('<IMG />');

  expect(infos).toEqual([]);
  expect(errors).toEqual([]);
  expect(node).toEqual({
    type: 'element',
    tag: 'IMG',
  });
});

test('auto-closing tag', () => {
  const { node, errors, infos } = parse('<DT>question<DD>answer<P>A<P>B');

  expect(infos).toEqual([]);
  expect(errors).toEqual([]);
  expect(node).toEqual({
    type: 'element',
    tag: 'HTML',
    nodes: [
      {
        type: 'element',
        tag: 'DT',
        nodes: [{ type: 'text', text: 'question' }],
      },
      {
        type: 'element',
        tag: 'DD',
        nodes: [{ type: 'text', text: 'answer' }],
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [{ type: 'text', text: 'A' }],
      },
      {
        type: 'element',
        tag: 'P',
        nodes: [{ type: 'text', text: 'B' }],
      },
    ]
  });
});
