import os

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

from openai import OpenAI
import json

client = OpenAI(api_key=OPENAI_API_KEY)
assistant = client.beta.assistants.create(
    name="LLMB",
    instructions="""
You are transforming HTML documents into draw calls, and load requests; without any superfluous elements like comments, one call/request per line.
Do not include {{user}} or {{assistant}} in the output.

Here's a list of calls you can use:
- draw.text_run(location, text, style_properties) -> rect
- draw.rectangle(rect, style_properties) -> rect
- fetch(url) -> str

And here's a list of properties you can use:
- location [rect].top_left
- location [rect].bottom_left
- location [rect].top_right
- location [rect].bottom_right
- str [window].meta.title
- list[str] [window].meta.console

Do not forget about hyperlinks, and that 'A' tags do not create new lines.

For example:
{{user}}
http://blank.example.com
{{/user}}
{{assistant}}
l1 = fetch("http://blank.example.com")
{{/assistant}}
{{user}}
l1 = "<html><p>test</p><a HREF="x">test2</a><title>blank</title><style src="a.css"></style><script src="b.js"></script></html>"
{{/user}}
{{assistant}}
l2 = fetch("http://blank.example.com/a.css")
l3 = fetch("http://blank.example.com/b.js")
window.meta.title = "blank"
t_rect = draw.text_run(window.rect.top_left, "test")
t_rect = draw.text_run(t_rect.bottom_left, "test2", {'hyperlink': 'x'})
{{/assistant}}
{{user}}
l2 = "p { color: red; font-size: 20px; } html { background-color: black; }"
l3 = "console.log('hi');\n"
{{/user}}
{{assistant}}
draw.rectangle(window.rect, {'color': '#000000'})
t_rect = draw.text_run(window.rect.top_left, "test", {'color': '#ff0000', 'font_size': 20})
t_rect = draw.text_run(t_rect.bottom_left, "test2", {'color': '#ff0000', 'font_size': 20, 'hyperlink': 'x'})
window.meta.console.append("hi")
{{/assistant}}
""",
    model="gpt-3.5-turbo",
)

thread = client.beta.threads.create()


# Meta Handlers:
import requests

MetaResponse = dict[str, str]


class Meta:
    def __init__(self):
        self.title = ""
        self.console = []


class Rect:
    def __init__(self, name: str):
        self.name = name
        self.top_left = f"{name}.top_left"
        self.bottom_left = f"{name}.bottom_left"
        self.top_right = f"{name}.top_right"
        self.bottom_right = f"{name}.bottom_right"

    def __repr__(self):
        return f"Rect({self.name})"


class W:
    def __init__(self):
        self.draw_calls = []
        self.meta = Meta()
        self.rect = Rect("window")

    def __str__(self):
        return (
            f"Window({self.meta}) {{"
            + "\n".join(repr(x) for x in self.draw_calls)
            + "}"
        )


WINDOW = W()


def fetch(url: str) -> str:
    return requests.get(url).text


def draw_text_run(
    location: str, text: str, properties: dict[str, str | int | float] = {}
) -> Rect:
    calls = WINDOW.draw_calls
    rect = f"rect_{len(calls)}"
    calls.append(
        {
            "type": "text_run",
            "location": location,
            "text": text,
            "properties": properties,
            "out_rect": rect,
        }
    )

    return Rect(rect)


def draw_rectangle(location: str, properties: dict[str, str | int | float]) -> Rect:
    calls = WINDOW.draw_calls
    rect = f"rect_{len(calls)}"
    calls.append(
        {
            "type": "rectangle",
            "location": location,
            "properties": properties,
            "out_rect": rect,
        }
    )

    return Rect(rect)


class Draw:
    def __init__(self):
        self.text_run = draw_text_run
        self.rectangle = draw_rectangle


draw = Draw()


def candump(v):
    try:
        json.dumps(v)
        return True
    except:
        return False


def handle_command(command, context) -> MetaResponse:
    print(command)
    locals = {
        **context,
        "window": WINDOW,
    }
    exec(command, globals(), locals)
    return {k: v for k, v in locals.items()}


import tkinter as tk
from tkinter import Label

TK_WINDOW = None


def render():
    global TK_WINDOW
    if TK_WINDOW is None:
        TK_WINDOW = tk.Tk()
        TK_WINDOW.geometry("800x600")

    TK_WINDOW.title(WINDOW.meta.title)
    for line in WINDOW.meta.console:
        print(line)
    WINDOW.meta.console = []

    def geom(s):
        s = s.split("+")
        s = s[0].split("x") + s[1:]
        w, h, x, y = tuple(int(x) for x in s)
        return x, y, w, h

    rects = {
        "window": geom(TK_WINDOW.winfo_geometry()),
    }

    for call in WINDOW.draw_calls:
        match call["type"]:
            case "text_run":
                # Place text on the window
                l = Label(
                    TK_WINDOW,
                    text=call["text"],
                    wraplength=rects["window"][2] - 10,
                    justify="left",
                )
                loc = call["location"]
                pos = None
                properties = call["properties"]
                if "hyperlink" in properties:
                    x = properties["hyperlink"]
                    l.bind("<Button-1>", lambda e, url=x: service_request(url))
                    l.config(fg="blue", cursor="hand2")
                if "color" in properties:
                    l.config(fg=properties["color"])
                if "font_size" in properties:
                    l.config(font=("Arial", properties["font_size"]))

                if loc.endswith(".top_left"):
                    loc = loc[: -len(".top_left")]
                    pos = "nw"
                elif loc.endswith(".bottom_left"):
                    loc = loc[: -len(".bottom_left")]
                    pos = "sw"
                elif loc.endswith(".top_right"):
                    loc = loc[: -len(".top_right")]
                    pos = "ne"
                elif loc.endswith(".bottom_right"):
                    loc = loc[: -len(".bottom_right")]
                    pos = "se"

                x, y, w, h = rects[loc]
                print(pos, "relative to", loc, "(", x, y, w, h, ")")
                if pos == "ne":
                    x += w
                if pos == "se":
                    x += w
                    y += h
                if pos == "sw":
                    y += h
                l.place(x=x, y=y)
                print("Placing", l, "at", x, y, "with", pos)
                l.update()
                out_rect = geom(l.winfo_geometry())
                print("out_rect =>", out_rect)
                rects[call["out_rect"]] = out_rect
            case "rectangle":
                print(call)

    TK_WINDOW.update()


def clear():
    global WINDOW, TK_WINDOW
    WINDOW.draw_calls = []
    WINDOW.meta = Meta()

    if TK_WINDOW is not None:
        TK_WINDOW.destroy()
        TK_WINDOW = None


import time


def wait_on_run(run, thread):
    while run.status == "queued" or run.status == "in_progress":
        run = client.beta.threads.runs.retrieve(
            thread_id=thread.id,
            run_id=run.id,
        )
        time.sleep(0.5)
    return run


def service_request(input: str):
    clear()
    message = client.beta.threads.messages.create(
        thread_id=thread.id,
        role="user",
        content=input,
    )
    run = client.beta.threads.runs.create(
        thread_id=thread.id,
        assistant_id=assistant.id,
    )

    rs: MetaResponse = {}
    while True:
        wait_on_run(run, thread)
        messages = client.beta.threads.messages.list(
            thread_id=thread.id, order="asc", after=message.id
        )
        for message in messages:
            if message.role != "assistant":
                continue
            message_content = "\n".join(
                x.text.value for x in message.content
            ).splitlines()
            for line in message_content:
                rs.update(handle_command(line, rs))
        if len(rs) == 0:
            break

        response = ""
        for k, v in rs.items():
            if candump(v):
                response += f"{k} = {json.dumps(v)}\n"

        print(rs, "=>", response)
        if response == "":
            break

        message = client.beta.threads.messages.create(
            thread_id=thread.id,
            role="user",
            content=response,
        )
        run = client.beta.threads.runs.create(
            thread_id=thread.id,
            assistant_id=assistant.id,
        )
        rs = {}
        render()


service_request("http://info.cern.ch/hypertext/WWW/TheProject.html")
print(WINDOW)
render()

TK_WINDOW.mainloop()
