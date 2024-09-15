export type ElementNode = { type: 'element'; tag: string; attributes?: { [name: string]: string; }, nodes?: Node[]; };
export type TextNode = { type: 'text'; text: string; };
export type Node =
  | ElementNode
  | TextNode
  ;

type RootState = { type: 'root' };
type OpeningTagState = { type: 'opening-tag' };
type OpeningTagNameState = { type: 'opening-tag-name', tag: string };
type ElementState = { type: 'element' };
type TextState = { type: 'text', text: string };
type ClosingTagState = { type: 'closing-tag' };
type ClosingTagNameState = { type: 'closing-tag-name', tag: string };
type AttributeState = { type: 'attribute' };
type AttributeNameState = { type: 'attribute-name', name: string };
type OpeningQuoteState = { type: 'opening-quote', attribute: string };
type AttributeValueState = { type: 'attribute-value', name: string, value: string };
type UnqoutedAttributeValueState = { type: 'unqouted-attribute-value', name: string, value: string };
type SelfClosingTagState = { type: 'self-closing-tag' };
type State =
  | RootState
  | OpeningTagState
  | OpeningTagNameState
  | ElementState
  | TextState
  | ClosingTagState
  | ClosingTagNameState
  | AttributeState
  | AttributeNameState
  | OpeningQuoteState
  | AttributeValueState
  | UnqoutedAttributeValueState
  | SelfClosingTagState;
;

// Map tags which when encountered should cause the `cursor` to self-close
// TODO: Make this more general instead of specifying the pairings
// Do this by keeping an array of self-closing tags and auto-close others
const autoClosingTags = {
  'DD': ['DT'],
  'DT': ['DD'],
  'P': ['DD', 'P'],
  'DL': 'P',
};

// TODO: Don't persist nodes until fully closed, carry all attributes in state
// without relying on the cursor to recover tag name etc.
// This will help with distinguishing when to close `<IMG/>` and `<IMG />`
// TODO: Play around with generics to see if I can let the caller specify wider
// types with adornments for layout data without hard-coding them to these types
export default function parseHtml(text: string) {
  // Keep track of the top-level nodes (might be a sole `html` or multiple nodes)
  const nodes: Node[] = [];
  const errors: string[] = [];
  const infos: string[] = [];
  const states: (State & { index: number; line: number; column: number; character: string; cursor: string | undefined; })[] = [];

  const superNodes = new WeakMap<Node, ElementNode>();

  let cursor: ElementNode | undefined;

  function addTextNode(state: TextState) {
    if (cursor) {
      const node: TextNode = { type: 'text', text: state.text };
      superNodes.set(node, cursor);
      cursor.nodes ??= [];
      cursor.nodes.push(node);
      return;
    }

    const node: TextNode = { type: 'text', text: state.text };
    nodes.push(node);
  }

  function addElementNode(state: OpeningTagNameState) {
    // Auto-close the cursor if the tag is an auto-closing tag
    if (cursor && autoClosingTags[state.tag]?.includes(cursor.tag)) {
      cursor = superNodes.get(cursor);
    }

    const node: ElementNode = { type: 'element', tag: state.tag };
    if (cursor) {
      superNodes.set(node, cursor);
      cursor.nodes ??= [];
      cursor.nodes.push(node);
    }
    else {
      nodes.push(node);
    }

    cursor = node;
  }

  let state: State = { type: 'root' };
  let line = 1;
  let column = 0;
  try {
    for (let index = 0; index < text.length; index++) {
      const character = text[index];

      states.push({ index, line, column, character, cursor: cursor?.tag, ...state });
      try {
        switch (character) {
          case '<': {
            switch (state.type) {
              case 'root': {
                state = { type: 'opening-tag' };
                break;
              }
              case 'element': {
                state = { type: 'opening-tag' };
                break;
              }
              case 'text': {
                addTextNode(state);
                state = { type: 'opening-tag' };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case 'a': case 'b': case 'c': case 'd': case 'e': case 'f': case 'g': case 'h': case 'i': case 'j': case 'k': case 'l': case 'm': case 'n': case 'o': case 'p': case 'q': case 'r': case 's': case 't': case 'u': case 'v': case 'w': case 'x': case 'y': case 'z':
          case 'A': case 'B': case 'C': case 'D': case 'E': case 'F': case 'G': case 'H': case 'I': case 'J': case 'K': case 'L': case 'M': case 'N': case 'O': case 'P': case 'Q': case 'R': case 'S': case 'T': case 'U': case 'V': case 'W': case 'X': case 'Y': case 'Z': {
            switch (state.type) {
              case 'opening-tag': {
                state = { type: 'opening-tag-name', tag: character };
                break;
              }
              case 'opening-tag-name': {
                state = { type: 'opening-tag-name', tag: state.tag + character };
                break;
              }
              case 'element': {
                state = { type: 'text', text: character };
                break;
              }
              case 'text': {
                state = { type: 'text', text: state.text + character };
                break;
              }
              case 'closing-tag': {
                state = { type: 'closing-tag-name', tag: character };
                break;
              }
              case 'closing-tag-name': {
                state = { type: 'closing-tag-name', tag: state.tag + character };
                break;
              }
              case 'attribute': {
                state = { type: 'attribute-name', name: character };
                break;
              }
              case 'attribute-name': {
                state = { type: 'attribute-name', name: state.name + character };
                break;
              }
              case 'attribute-value': {
                state = { type: 'attribute-value', name: state.name, value: state.value + character };
                break;
              }
              case 'opening-quote': {
                state = { type: 'unqouted-attribute-value', name: state.attribute, value: character };
                break;
              }
              case 'root': {
                state = { type: 'text', text: character };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9': {
            switch (state.type) {
              case 'attribute-value': {
                state = { type: 'attribute-value', name: state.name, value: state.value + character };
                break;
              }
              case 'opening-tag-name': {
                state = { type: 'opening-tag-name', tag: state.tag + character };
                break;
              }
              case 'closing-tag-name': {
                state = { type: 'closing-tag-name', tag: state.tag + character };
                break;
              }
              case 'text': {
                state = { type: 'text', text: state.text + character };
                break;
              }
              case 'opening-quote': {
                state = { type: 'unqouted-attribute-value', name: state.attribute, value: character };
                break;
              }
              case 'unqouted-attribute-value': {
                state = { type: 'unqouted-attribute-value', name: state.name, value: state.value + character };
                break;
              }
              case 'element': {
                state = { type: 'text', text: character };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case ' ': {
            switch (state.type) {
              case 'text': {
                state = { type: 'text', text: state.text + character };
                break;
              }
              case 'opening-tag-name': {
                addElementNode(state);
                state = { type: 'attribute' };
                break;
              }
              case 'unqouted-attribute-value': {
                if (!cursor) {
                  throw new Error('No cursor to set the attribute value');
                }

                cursor.attributes ??= {};
                if (cursor.attributes[state.name] !== undefined) {
                  throw new Error(`Attribute ${state.name} already exists on element ${cursor.tag}`);
                }

                cursor.attributes[state.name] = state.value;
                state = { type: 'attribute' };
                break;
              }
              case 'element': {
                state = { type: 'text', text: character };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '>': {
            switch (state.type) {
              case 'opening-tag-name': {
                addElementNode(state);
                state = { type: 'element' };
                break;
              }
              case 'closing-tag-name': {
                let done = false;

                // Keep a temporary copy of the cursor to recover from stray closing tag
                let tempCursor = cursor;
                const tag = state.tag;
                while (tempCursor) {
                  // Close the element if matching
                  if (tempCursor.tag === tag) {
                    done = true;
                    state = { type: 'element' };
                    cursor = superNodes.get(tempCursor);
                    break;
                  }

                  // Walk up the tree otherwise
                  tempCursor = superNodes.get(tempCursor);
                }

                if (!done) {
                  // TODO: Track index here to be able to highlight in the HTML
                  infos.push(`Could not find a matching opening tag for ${tag}`);
                  state = { type: 'element' };
                }

                break;
              }
              case 'attribute': {
                state = { type: 'element' };
                break;
              }
              case 'self-closing-tag': {
                // TODO: Handle `<IMG/>` without space `<IMG />`
                // (Recognize which and do not create twice on space and slash)
                // addElementNode(state);
                state = { type: 'element' };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '/': {
            switch (state.type) {
              case 'opening-tag': {
                state = { type: 'closing-tag' };
                break;
              }
              case 'attribute-value': {
                state = { type: 'attribute-value', name: state.name, value: state.value + character };
                break;
              }
              case 'attribute': {
                state = { type: 'self-closing-tag' };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '=': {
            switch (state.type) {
              case 'attribute-name': {
                state = { type: 'opening-quote', attribute: state.name };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '"': {
            switch (state.type) {
              case 'opening-quote': {
                state = { type: 'attribute-value', name: state.attribute, value: '' };
                break;
              }
              case 'attribute-value': {
                if (!cursor) {
                  throw new Error('No cursor to set the attribute value');
                }

                cursor.attributes ??= {};
                if (cursor.attributes[state.name] !== undefined) {
                  throw new Error(`Attribute ${state.name} already exists on element ${cursor.tag}`);
                }

                cursor.attributes[state.name] = state.value;
                state = { type: 'attribute' };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          case '\n': {
            switch (state.type) {
              case 'root': {
                break;
              }
              case 'element': {
                // Ignore newlines between elements
                break;
              }
              case 'text': {
                state = { type: 'text', text: state.text + ' ' };
                break;
              }
              case 'opening-tag-name': {
                addElementNode(state);
                state = { type: 'attribute' };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
          default: {
            switch (state.type) {
              case 'text': {
                state = { type: 'text', text: state.text + character };
                break;
              }
              case 'opening-quote': {
                state = { type: 'unqouted-attribute-value', name: state.attribute, value: character };
                break;
              }
              case 'attribute-value': {
                state = { type: 'attribute-value', name: state.name, value: state.value + character };
                break;
              }
              case 'element': {
                state = { type: 'text', text: character };
                break;
              }
              default: {
                throw new Error(`Unexpected character: ${character} in state ${state.type}`);
              }
            }

            break;
          }
        }
      }
      catch (error) {
        const debug = states[states.length - 1];
        throw new Error(`Error at index ${index}/${text.length} (${~~((index / text.length) * 100)} %, line ${line}, column ${column}, character ${JSON.stringify(character)}) with entry state ${debug.type} and exit state ${state.type}`, { cause: error });
      }

      if (character === '\n') {
        line++;
        column = 0;
      }
      else {
        column++;
      }
    }

    switch (state.type) {
      case 'element': {
        break;
      }
      case 'text': {
        addTextNode(state);
        break;
      }
      default: {
        throw new Error(`Unexpected end of file in state ${state.type}`);
      }
    }
  }
  catch (error) {
    if (!(error instanceof Error)) {
      throw new Error(`Error: ${error}`);
    }

    console.error(error.message);
    errors.push(error.message);
    if (error.cause) {
      if (!(error.cause instanceof Error)) {
        throw new Error(`Error: ${error.cause}`);
      }

      console.error(error.cause.message);
      errors.push(error.cause.message);
    }

    const preview = 10;

    errors.push('States:');
    for (const state of states.reverse().slice(0, preview)) {
      errors.push(JSON.stringify(state));
    }

    if (states.length > preview) {
      errors.push(`…${states.length - preview} more states`);
    }

    errors.push('Nodes:');

    function printNode(node: Node, indent = 0) {
      switch (node.type) {
        case 'element': {
          errors.push(`${'  '.repeat(indent)} <${node.tag}>`);
          if (node.nodes) {
            for (const subNode of node.nodes) {
              printNode(subNode, indent + 1);
            }
          }

          break;
        }
        case 'text': {
          errors.push(`${'  '.repeat(indent)} "${node.text}"`);
          break;
        }
      }
    }

    for (const node of nodes) {
      printNode(node);
    }
  }

  const getSuperNode = (node: Node) => superNodes.get(node);

  if (nodes.length === 0) {
    const blankNode: TextNode = { type: 'text', text: '' };
    return { node: blankNode, getSuperNode, errors, infos };
  }

  const rootNode: ElementNode = { type: 'element', tag: 'HTML' };
  if (nodes.length === 1) {
    if (nodes[0].type === 'text') {
      rootNode.nodes ??= [];
      rootNode.nodes.push(nodes[0]);
      superNodes.set(nodes[0], rootNode);
      return { node: rootNode, getSuperNode, errors, infos };
    }

    return { node: nodes[0], getSuperNode, errors, infos };
  }

  for (const node of nodes) {
    rootNode.nodes ??= [];
    rootNode.nodes.push(node);
    superNodes.set(node, rootNode);
  }

  return { node: rootNode, getSuperNode, errors, infos };
}
