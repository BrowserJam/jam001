import isNonVisual from './isNonVisual';
import { SKRSContext2D } from '@napi-rs/canvas';
import { LayoutNode } from './layout';

type RenderStyles = {
  fillStyle?: string;
  strokeStyle?: string;
  font?: string;
};

const userAgentRenderStyles: { [tag: string]: RenderStyles } = {
  A: {
    fillStyle: 'blue',
  },
  H1: {
    font: 'bold 24px sans-serif',
  }
};

export default function render(node: LayoutNode, context: SKRSContext2D, styles: RenderStyles = {}) {
  if (isNonVisual(node)) {
    return;
  }

  if (node.type === 'text') {
    context.save();

    if (styles.fillStyle) {
      context.fillStyle = styles.fillStyle;
    }

    if (styles.strokeStyle) {
      context.strokeStyle = styles.strokeStyle;
    }

    if (styles.font) {
      context.font = styles.font;
    }

    context.fillText(node.text, node.x, node.y);
    context.restore();
    return;
  }

  if (node.nodes) {
    for (const subNode of node.nodes) {
      if (subNode.type === 'element') {
        render(subNode, context, { ...styles, ...userAgentRenderStyles[subNode.tag] });
      }
      else {
        render(subNode, context, { ...styles, ...userAgentRenderStyles[node.tag] });
      }
    }
  }
}
