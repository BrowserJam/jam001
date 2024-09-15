use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use skia_bindings::SkFont;
use skia_safe::{Color, Font, FontMgr, FontStyle, Handle, Paint, TextBlob};

use crate::parse::HTMLNode;

static FONT_CACHE: LazyLock<Mutex<HashMap<i32, Handle<SkFont>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn get_font(size: i32) -> Handle<SkFont> {
    let mut map = FONT_CACHE.lock().unwrap();
    match map.get(&size) {
        Some(font) => font.clone(),
        None => {
            let font = Font::from_typeface(
                FontMgr::new()
                    .legacy_make_typeface(None, FontStyle::default())
                    .unwrap(),
                size as f32 * 2.0,
            );
            map.insert(size, font.clone());
            font
        }
    }
}

fn is_whitespace(str: String) -> bool {
    str.chars().all(char::is_whitespace)
}

fn draw_words(
    text: &str,
    canvas: &skia_safe::canvas::Canvas,
    x: &mut f32,
    y: &mut f32,
    adjustment: f32,
    start_x: f32,
    paint: &skia_safe::Paint,
    font: &skia_safe::Font,
) {
    let text = text.trim();
    let width = canvas.base_layer_size().width as f32 - 32.0;

    let words = text.split_whitespace();
    for word in words {
        if is_whitespace(word.to_string()) {
            continue;
        }
        // println!("Drawing word: '{}'", word);
        let text_blob = TextBlob::from_str(word, font).unwrap();
        let text_width = text_blob.bounds().width() - adjustment;
        let text_height = text_blob.bounds().height();
        if *x > start_x && *x + text_width > width {
            *x = start_x;
            *y += text_height;
        }
        canvas.draw_text_blob(&text_blob, (*x, *y + text_height / 2.0), paint);
        *x += text_width;
    }
}

pub fn render_frame(nodes: &Vec<HTMLNode>, canvas: &skia_safe::canvas::Canvas) {
    let paint = Paint::default();
    let mut blue_paint = Paint::default();
    blue_paint.set_color(Color::BLUE);

    for node in nodes {
        match node {
            HTMLNode::Text(_) | HTMLNode::Comment(_) => {
                // Do nothing, this text is outside of a tag
            }
            HTMLNode::Element {
                tag,
                attributes: _,
                children,
            } => match tag.as_str() {
                "header" | "head" => {
                    continue;
                }
                "h1" => {
                    let mut x = 0.0;
                    let mut y = 0.0;
                    for child in children {
                        match child {
                            HTMLNode::Text(text) => {
                                draw_words(
                                    text,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    100.0,
                                    0.0,
                                    &paint,
                                    &get_font(32),
                                );
                            }
                            HTMLNode::Element {
                                tag,
                                attributes: _,
                                children,
                            } if tag == "a" => {
                                let words = match children.first().clone() {
                                    Some(HTMLNode::Text(text)) => text,
                                    _ => panic!("Expected text node in a a"),
                                };
                                draw_words(
                                    words,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    150.0,
                                    0.0,
                                    &blue_paint,
                                    &get_font(32),
                                );
                            }
                            _ => {
                                println!("Unknown tag in p: {}", tag);
                            }
                        }
                    }
                    canvas.translate((0, y as i32 + 100));
                }
                "p" => {
                    let mut x = 0.0;
                    let mut y = 0.0;
                    for child in children {
                        match child {
                            HTMLNode::Text(text) => {
                                draw_words(
                                    text,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    50.0,
                                    0.0,
                                    &paint,
                                    &get_font(16),
                                );
                            }
                            HTMLNode::Element {
                                tag,
                                attributes: _,
                                children,
                            } if tag == "a" => {
                                let words = match children.first().clone() {
                                    Some(HTMLNode::Text(text)) => text,
                                    _ => panic!("Expected text node in a a"),
                                };
                                draw_words(
                                    words,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    50.0,
                                    0.0,
                                    &blue_paint,
                                    &get_font(16),
                                );
                            }
                            _ => {
                                println!("Unknown tag in p: {}", tag);
                            }
                        }
                    }
                    canvas.translate((0, y as i32 + 65));
                }
                "body" => {
                    let mut x = 0.0;
                    let mut y = 0.0;
                    for child in children {
                        match child {
                            HTMLNode::Text(text) => {
                                if is_whitespace(text.to_string()) {
                                    continue;
                                }
                                draw_words(
                                    text,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    50.0,
                                    0.0,
                                    &paint,
                                    &get_font(16),
                                );
                            }
                            HTMLNode::Element {
                                tag,
                                attributes: _,
                                children,
                            } if tag == "a" => {
                                let words = match children.first().clone() {
                                    Some(HTMLNode::Text(text)) => text,
                                    _ => panic!("Expected text node in a a"),
                                };
                                draw_words(
                                    words,
                                    canvas,
                                    &mut x,
                                    &mut y,
                                    50.0,
                                    0.0,
                                    &blue_paint,
                                    &get_font(16),
                                );
                            }
                            _ => {
                                if x > 0.0 {
                                    canvas.translate((0, y as i32 + 65));
                                    y = 0.0;
                                    x = 0.0;
                                }
                                render_frame(&vec![child.clone()], canvas);
                            }
                        }
                    }
                }
                "dl" => {
                    for child in children {
                        match child {
                            HTMLNode::Element {
                                tag,
                                attributes: _,
                                children,
                            } if tag == "dt" => {
                                let mut x = 0.0;
                                let mut y = 0.0;
                                for child in children {
                                    match child {
                                        HTMLNode::Text(text) => {
                                            let text = text.trim();
                                            if is_whitespace(text.to_string()) {
                                                continue;
                                            }
                                            draw_words(
                                                text,
                                                canvas,
                                                &mut x,
                                                &mut y,
                                                50.0,
                                                0.0,
                                                &paint,
                                                &get_font(16),
                                            );
                                        }
                                        HTMLNode::Element {
                                            tag,
                                            attributes: _,
                                            children,
                                        } if tag == "a" => {
                                            let words = match children.first().clone() {
                                                Some(HTMLNode::Text(text)) => text,
                                                _ => panic!("Expected text node in a a"),
                                            };
                                            draw_words(
                                                words,
                                                canvas,
                                                &mut x,
                                                &mut y,
                                                50.0,
                                                0.0,
                                                &blue_paint,
                                                &get_font(16),
                                            );
                                        }
                                        _ => {}
                                    }
                                }
                                canvas.translate((0, y as i32 + 50));
                            }
                            HTMLNode::Element {
                                tag,
                                attributes: _,
                                children,
                            } if tag == "dd" => {
                                let mut x = 64.0;
                                let mut y = 0.0;
                                for child in children {
                                    match child {
                                        HTMLNode::Text(text) => {
                                            let text = text.trim();
                                            if is_whitespace(text.to_string()) {
                                                continue;
                                            }
                                            draw_words(
                                                text,
                                                canvas,
                                                &mut x,
                                                &mut y,
                                                50.0,
                                                64.0,
                                                &paint,
                                                &get_font(16),
                                            );
                                        }
                                        HTMLNode::Element {
                                            tag,
                                            attributes: _,
                                            children,
                                        } if tag == "a" => {
                                            let words = match children.first().clone() {
                                                Some(HTMLNode::Text(text)) => text,
                                                _ => panic!("Expected text node in a a"),
                                            };
                                            draw_words(
                                                words,
                                                canvas,
                                                &mut x,
                                                &mut y,
                                                50.0,
                                                64.0,
                                                &blue_paint,
                                                &get_font(16),
                                            );
                                        }
                                        _ => {}
                                    }
                                }
                                canvas.translate((0, y as i32 + 50));
                            }
                            _ => {
                                // no-op
                            }
                        }
                    }
                }
                "html" => {
                    render_frame(children, canvas);
                }
                "div" => {
                    render_frame(children, canvas);
                }
                "!doctype" => {
                    // no-op
                }
                _ => {
                    println!("Unknown tag: {}", tag);
                }
            },
        }
    }
}

// canvas.draw_text_blob(&text, (0, (12.0 * font_scale) as i32), &Paint::default());
// canvas.translate((0, (12.0 * FONT_SCALE) as i32));
// println!("{}", str);
// let text = TextBlob::from_str(
//     str,
//     &Font::from_typeface(font_mgr
//         .legacy_make_typeface(None, FontStyle::default())
//         .unwrap(), 12.0 * font_scale as f32),
// )
// .unwrap();
