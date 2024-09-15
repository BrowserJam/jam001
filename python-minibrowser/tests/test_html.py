import unittest

import minihtml


class HTMLTests(unittest.TestCase):
    maxDiff = None

    def test_empty(self):
        html = ''
        parser = minihtml.CernHTMLParser()
        parser.feed(html)

        expected = minihtml.Element(
            tag='html', attrs={},
            inner_text='',
            children=[]
        )

        self.assertEqual(expected, parser.tree)

    def test_html(self):
        html = '<html></html>'
        parser = minihtml.CernHTMLParser()
        parser.feed(html)

        expected = minihtml.Element(
            tag='html', attrs={},
            inner_text='',
            children=[]
        )

        self.assertEqual(expected, parser.tree)

    def test_inner_text(self):
        html = (
            '<header>'
            'hello'
            '</br>'
            'next line'
            '</header>'
        )
        parser = minihtml.CernHTMLParser()
        parser.feed(html)

        header = minihtml.Element(
            tag='header', attrs={},
            inner_text='hello',
            children=[
                minihtml.Element(
                    tag='inner_text', attrs={},
                    inner_text='hello',
                    children=[]
                ),
                minihtml.Element(
                    tag='br', attrs={},
                    inner_text='',
                    children=[]
                ),
                minihtml.Element(
                    tag='inner_text', attrs={},
                    inner_text='next line',
                    children=[]
                ),
            ]
        )

        self.assertEqual(header.tag, parser.tree.children[0].tag)
        self.assertEqual(header.attrs, parser.tree.children[0].attrs)
        self.assertEqual(header.children, parser.tree.children[0].children)

    def test_attrs(self):
        html = '<a HREF="http://localhost">hello</header>'
        parser = minihtml.CernHTMLParser()
        parser.feed(html)

        header = minihtml.Element(
            tag='a', attrs={
                'href': 'http://localhost'
            },
            inner_text='',
            children=[
                minihtml.Element(
                    tag='inner_text', attrs={},
                    inner_text='hello',
                    children=[]
                ),
            ]
        )

        self.assertEqual(header.tag, parser.tree.children[0].tag)
        self.assertEqual(header.children, parser.tree.children[0].children)
        self.assertEqual(header.attrs, parser.tree.children[0].attrs)

    def test_dx(self):
        html = '<dl><dt name="test">a term</dt></dl>'
        parser = minihtml.CernHTMLParser()
        parser.feed(html)

        html = minihtml.Element(
            tag='html', attrs={},
            inner_text='',
            children=[
                minihtml.Element(
                    tag='dl', attrs={},
                    inner_text='',
                    children=[
                        minihtml.Element(
                            tag='dt', attrs={
                                'name': 'test'
                            },
                            inner_text='',
                            children=[
                                minihtml.Element(
                                    tag='inner_text', attrs={},
                                    inner_text='a term',
                                    children=[]
                                ),
                            ]
                        )
                    ]
                )
            ]
        )

        self.assertEqual(html, parser.tree)


class TraversalTest(unittest.TestCase):
    def test_empty(self):
        html = minihtml.Element(
            tag='html', attrs={},
            inner_text='',
            children=[]
        )
        _, el = minihtml.find_first_tag(html, 'html')
        self.assertEqual(html, el)

    def test_find_tag(self):
        dt = minihtml.Element(
            tag='dt', attrs={
                'name': 'test'
            },
            inner_text='a term',
            children=[]
        )
        html = minihtml.Element(
            tag='html', attrs={},
            inner_text='',
            children=[
                minihtml.Element(
                    tag='dl', attrs={},
                    inner_text='',
                    children=[
                        dt
                    ]
                )
            ]
        )
        _, el = minihtml.find_first_tag(html, 'dt')
        self.assertEqual(dt, el)