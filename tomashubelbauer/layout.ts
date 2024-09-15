import { SKRSContext2D } from '@napi-rs/canvas';
import isBlock from './isBlock';
import fitText from './fitText';
import type { Node, TextNode, ElementNode } from './parse';

export type LayoutData = { width: number; height: number; x: number; y: number; layout?: 'removed' | 'added'; };
export type LayoutTextNode = TextNode & LayoutData;
export type LayoutElementNode = Omit<ElementNode, 'nodes'> & { nodes?: LayoutNode[]; } & LayoutData;
export type LayoutNode = LayoutTextNode | LayoutElementNode;

type LayoutStyles = {
  x?: number;
  y?: number;
  font?: string;
};

const userAgentLayoutStyles: { [tag: string]: LayoutStyles } = {
  BODY: {
    x: 8,
    y: 8,
  },
  P: {
    y: 8,
  },
  DT: {
    y: 8,
  },
  DD: {
    x: 32,
  },
  H1: {
    font: 'bold 24px serif',
    x: 8,
  },
};

export default function layout(node: Node, getSuperNode: (node: Node) => ElementNode | undefined, context: SKRSContext2D) {
  const layoutNode = node as LayoutNode;
  const getLayoutSuperNode = (node: LayoutNode) => getSuperNode(node) as (LayoutElementNode | undefined);
  if (layoutNode.type === 'element') {
    doLayout(layoutNode, getLayoutSuperNode, context, { x: 0, y: 0 }, userAgentLayoutStyles[layoutNode.tag]);
  }
  else {
    doLayout(layoutNode, getLayoutSuperNode, context, { x: 0, y: 0 }, {});
  }

  return layoutNode;
}

// Mutate the tree instead of copying so sub-nodes can refer to their super-node
// and see its layout data in order to find their bounds when breaking lines.
function doLayout(node: LayoutNode, getSuperNode: (node: LayoutNode) => LayoutElementNode | undefined, context: SKRSContext2D, cursor: { x: number, y: number }, styles: LayoutStyles) {
  // Skip over new nodes added to the tree while breaking down text nodes
  if (node.layout === 'added') {
    return;
  }

  node.width = 0;
  node.height = 0;
  node.x = cursor.x + (styles?.x ?? 0);
  node.y = cursor.y + (styles?.y ?? 0);

  const superNode = getSuperNode(node);
  if (node.type === 'text') {
    if (!superNode) {
      throw new Error('No super-node for text node');
    }

    if (!superNode.nodes) {
      throw new Error('Super-node has no sub-nodes');
    }

    if (!superNode.nodes.includes(node)) {
      throw new Error('Super-node does not have its sub-node');
    }

    context.save();

    if (styles.font) {
      context.font = styles.font;
    }

    // Measure the text node's width and height
    const { width, emHeightAscent } = context.measureText(node.text);
    context.restore();

    node.width = ~~width;
    node.height = ~~emHeightAscent;

    // Make a clone of the text node for slicing without mutating the original
    const sliceNode = { ...node };

    let breaks = 0;
    while (cursor.x + sliceNode.width > context.canvas.width) {
      breaks++;

      const fit = fitText(sliceNode.text, context.canvas.width - cursor.x, context);
      const fitTextNode = { ...sliceNode, text: fit.text, width: fit.width, height: sliceNode.height, x: cursor.x, y: cursor.y, layout: 'added' as const };
      fitTextNode.x += styles?.x ?? 0;
      fitTextNode.y += styles?.y ?? 0;

      // Put the layouted text node in the super-node if it's a block element
      if (isBlock(superNode)) {
        if (!superNode.nodes) {
          throw new Error('Super-node has no sub-nodes');
        }

        const index = superNode.nodes.indexOf(node);
        if (index === -1) {
          throw new Error('Supra-node does not have its sub-super-node');
        }

        // Add the replacement inline element after the original super-node
        superNode.nodes.splice(index + breaks, 0, fitTextNode);

        // Move the cursor to the next line as this one has been used up fully
        // Note that the trailing last text part will be layouted after the loop
        cursor.x = superNode.x;
        cursor.y += fitTextNode.height;

        // Cut the original node to remove the part that was layouted
        sliceNode.text = sliceNode.text.slice(fit.text.length);
        sliceNode.width -= fit.width;

        // Point the original node to the next line's start as this one is done 
        sliceNode.x = superNode.x;
        sliceNode.y += fitTextNode.height;
      }

      // Wrap the layouted text node in the super-node element and replace it
      else {
        // Wrap each `fitNode` in the original `superNode`
        const fitElementNode = { ...superNode, nodes: [fitTextNode], width: fitTextNode.width, height: fitTextNode.height, x: cursor.x, y: cursor.y, layout: 'added' as const };

        // Put the new inline elements instead of the original super-node
        // Note the `superMode` will be removed from layout at the loop's end
        const supraNode = getSuperNode(superNode);

        if (!supraNode) {
          throw new Error('No supra-node for super-node');
        }

        if (!supraNode.nodes) {
          throw new Error('Supra-node has no sub-nodes');
        }

        const index = supraNode.nodes.indexOf(superNode);
        if (index === -1) {
          throw new Error('Supra-node does not have its sub-super-node');
        }

        // TODO: Wrap each single-line part in a `layout=added` DIV element
        // node to correctly indicate it is its own standalone block element
        // even if it wasn't already laid out (so the line is a block element)

        // Add the replacement inline element after the original super-node
        supraNode.nodes.splice(index + breaks, 0, fitElementNode);

        // Move the cursor to the next line as this one has been used up fully
        // Note that the trailing last text part will be layouted after the loop
        cursor.x = supraNode.x;
        cursor.y += fitTextNode.height;

        // Cut the original node to remove the part that was layouted
        sliceNode.text = sliceNode.text.slice(fit.text.length);
        sliceNode.width -= fitTextNode.width;

        // Point the original node to the next line's start as this one is done 
        sliceNode.x = supraNode.x;
        sliceNode.y += fitTextNode.height;
      }
    }

    if (!breaks) {
      cursor.x += node.width;
      return;
    }

    // Hide the original multi-line text node; it will be renderer through the
    // individual single-line text nodes it was broken up into
    node.layout = 'removed';

    // Reset the `node` layout since it has become a non-visual text
    node.x = 0;
    node.y = 0;

    // Layout the trailing text that wasn't layouted in the loop if any
    if (sliceNode.text) {
      breaks++;

      const textNode = { ...sliceNode, text: sliceNode.text, width: sliceNode.width, height: sliceNode.height, x: cursor.x, y: cursor.y, layout: 'added' as const };
      textNode.x += styles?.x ?? 0;
      textNode.y += styles?.y ?? 0;

      // Put the layouted text node in the super-node if it's a block element
      if (isBlock(superNode)) {
        if (!superNode.nodes) {
          throw new Error('Super-node has no sub-nodes');
        }

        const index = superNode.nodes.indexOf(node);
        if (index === -1) {
          throw new Error('Supra-node does not have its sub-super-node');
        }

        // Add the replacement inline element after the original super-node
        superNode.nodes.splice(index + breaks, 0, textNode);

        // Move the cursor to the next line as this one has been used up fully
        // Note that the trailing last text part will be layouted after the loop
        cursor.x = superNode.x;
        cursor.y += textNode.height;
      }

      // Wrap the layouted text node in the super-node element and replace it
      else {
        // Wrap the remaining `textNode` in the original `superNode`
        const elementNode = { ...superNode, nodes: [textNode], width: textNode.width, height: textNode.height, x: cursor.x, y: cursor.y, layout: 'added' as const };

        // Put the new inline elements instead of the original super-node
        // Note the `superMode` will be removed from layout at the loop's end
        const supraNode = getSuperNode(superNode);

        if (!supraNode) {
          throw new Error('No supra-node for super-node');
        }

        if (!supraNode.nodes) {
          throw new Error('Supra-node has no sub-nodes');
        }

        const index = supraNode.nodes.indexOf(superNode);
        if (index === -1) {
          throw new Error('Supra-node does not have its sub-super-node');
        }

        // TODO: Wrap each single-line part in a `layout: 'added'` DIV element
        // node to correctly indicate it is its own standalone block element
        // even if it wasn't already laid out (so the line is a block element)
        // (for now I think I will do without this but it would make the tree
        // structure dead easy to understand in terms of layout and rendering
        // and could let me drop `width` and `height` for block elements)

        // Add the replacement inline element after the original super-node
        supraNode.nodes.splice(index + breaks, 0, elementNode);

        cursor.x += elementNode.width;

        if (!superNode) {
          throw new Error('No super-node for multi-line text node');
        }

        // Hide the element node that contained the multi-line text node since it
        // will be rendered through the individual single-line element nodes that
        // the broken up text nodes of the multi-line text node were wrapped into
        superNode.layout = 'removed';

        // Reset the `superNode` layout since it has become a non-visual element
        superNode.x = 0;
        superNode.y = 0;
      }
    }

    return;
  }

  if (node.nodes) {
    for (const subNode of node.nodes) {
      if (subNode.type === 'element') {
        doLayout(subNode, getSuperNode, context, cursor, { ...styles, ...userAgentLayoutStyles[subNode.tag] });
      }
      else {
        doLayout(subNode, getSuperNode, context, cursor, { ...styles, ...userAgentLayoutStyles[node.tag] });
      }
    }

    node.width = node.nodes
      .filter(node => node.layout !== 'removed')
      .reduce((width, subNode) => Math.max(width, (subNode.x - node.x) + subNode.width), 0);

    node.height = node.nodes
      .filter(node => node.layout !== 'removed')
      .reduce((height, subNode) => Math.max(height, subNode.height + (subNode.y - node.y)), 0);

    if (isBlock(node)) {
      cursor.x = superNode?.x ?? 0;
      cursor.y = node.y + node.height;

      //   // Propagate the height rise up all the way to the top-level super-node
      //   let chainSuperNode: LayoutElementNode | undefined = superNode;
      //   while (chainSuperNode) {
      //     if (isBlock(chainSuperNode)) {
      //       chainSuperNode.height += node.height;
      //     }

      //     chainSuperNode = getSuperNode(chainSuperNode);
      //   }
    }
  }
}
