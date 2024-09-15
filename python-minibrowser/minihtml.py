from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass

from html.parser import HTMLParser


@dataclass
class Element:
    tag: str
    attrs: Dict[str, str]
    children: List['Element']
    inner_text: str = ''


class CernHTMLParser(HTMLParser):
    def __init__(self):
        super(CernHTMLParser, self).__init__()
        self.tree = Element(
            tag='html', attrs={},
            inner_text='',
            children=[],
        )
        self.current = self.tree
        self.parent = None

    def handle_starttag(self, tag, attrs):
        attrd = {
            k: v for k, v in attrs
        }
        tagl = tag.lower().strip()

        el = None
        if tagl in [
            'header', 'title',
            'body',
            'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
            'a',
            'p',
            'dl', 'dt', 'dd'
        ]:
            el = Element(
                tag=tagl, attrs=attrd, inner_text='', children=[]
            )

        if el:  # any tag we understand
            self.current.children.append(el)
            self.parent = self.current
            self.current = el

    def handle_endtag(self, tag):
        tagl = tag.lower().strip()
        if tagl == 'br':
            el = Element(
                tag=tagl, attrs={}, inner_text='', children=[]
            )
            self.current.children.append(el)
            return

        if self.parent is not None:  # if not tree root (html)
            # go up the tree
            self.current = self.parent

    def handle_data(self, data):
        inner_text = data.replace('\n', ' ').strip(' ')
        if self.current.tag == 'title':
            self.current.inner_text = inner_text
        elif inner_text:
            self.current.children.append(
                Element(
                    tag='inner_text', attrs={}, inner_text=inner_text, children=[]
                )
            )


def find_first_tag(tree: Element, tag: str) -> Tuple[
    bool, Optional[Element]
]:
    if tree.tag == tag:
        return True, tree
    if tree.children:
        found, el = False, None
        for child in tree.children:
            found, el = find_first_tag(child, tag)
            if found:
                break
        return found, el
    return False, None

