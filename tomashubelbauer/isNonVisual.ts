import { LayoutNode } from './layout';

const NON_VISUALS = ['HEADER'];

export default function isNonVisual(node: LayoutNode) {
  return (node.type === 'element' && NON_VISUALS.includes(node.tag)) || node.layout === 'removed';
}
