import { ElementNode } from './parse';

const BLOCKS = ['HTML', 'BODY', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'P', 'DL', 'DD', 'DT', 'UL', 'LI', 'MENU', 'DIV', 'HEADER'];

export default function isBlock(node: ElementNode) {
  return BLOCKS.includes(node.tag);
}
