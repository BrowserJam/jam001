from typing import TypedDict

import imgui

import minihtml


COLORS = {
    'red':   dict(r=1.0, g=.0,  b=.0),
    'green': dict(r=.0,  g=1.0, b=.0),
    'blue':  dict(r=.0,  g=.0,  b=1.0),
}

class Style(TypedDict):
    text_color: str
    text_decoration_line: str
    display: str


DEFAULT_STYLE = Style(
    text_color='currentcolor',
    text_decoration_line='none',
    display='block',
)


LINK_STYLE = Style(
    text_color='blue',
    text_decoration_line='underline',
    display='inline',
)


def draw_element(el: minihtml.Element, style: Style):
    if el.tag == 'body':
        pass
    elif el.tag == 'inner_text' and el.inner_text:
        if style['text_color'] in COLORS:
            color = COLORS[style['text_color']]
            # imgui.text_colored(text=f"{style['display']} {el.inner_text}", **color, a=1.0)
            imgui.push_style_color(imgui.COLOR_TEXT, r=.0,  g=.0,  b=1.0, a=1.0)
            imgui.text_wrapped(f'{el.inner_text}')
            imgui.pop_style_color()
        else:
            for t in el.inner_text.split(' '):
                imgui.text_wrapped(f"{t}"); imgui.same_line()
            # imgui.text_wrapped(f"[{style['display']}] {el.inner_text}")
        imgui.same_line()
    elif el.tag in ['p']:
        imgui.text('')
    elif el.tag in ['dl', 'dt', 'dd']:
        pass
    elif el.inner_text:
        imgui.text_wrapped(f'{el.inner_text}'); imgui.same_line()

    tag_name = '_' if el.tag == 'inner_text' else el.tag


    if el.children:
        child_style = {
            **style
        }
        if el.tag == 'a':
            child_style = Style({
                **LINK_STYLE,
                'display': 'inline',
            })
        for child in el.children:
            if child.tag == 'inner_text':
                child_style = Style({
                    **child_style,
                    'display': 'inline',
                })
            if child.tag in ['dl', 'dt', 'dd']:
                child_style = Style({
                    **child_style,
                    'display': 'block',
                })
            draw_element(child, child_style)

    if style['display'] == 'block':
        imgui.text('')


def show_window(filename: str, w=1280, h=768):
    with open(filename, 'r') as f:
        html = f.read()

    parser = minihtml.CernHTMLParser()
    parser.feed(html)

    window_flags = 0
    window_flags |= imgui.WINDOW_NO_MOVE
    window_flags |= imgui.WINDOW_NO_COLLAPSE
    window_flags |= imgui.WINDOW_NO_NAV

    imgui.style_colors_light()
    imgui.set_next_window_position(0, 0)
    imgui.set_next_window_size(w, h)

    found, title = minihtml.find_first_tag(parser.tree, 'title')
    title_str = 'no title' if not found else title.inner_text
    imgui.begin(title_str, flags=window_flags)

    found, body = minihtml.find_first_tag(parser.tree, 'body')
    if found:
        draw_element(body, Style(
            text_color='currentcolor',
            text_decoration_line='none',
            display='block',
        ))

    imgui.end()