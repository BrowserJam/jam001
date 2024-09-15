use std::collections::HashMap;

use macroquad::{
    math::Vec2,
    shapes::{draw_circle, draw_line, draw_rectangle_lines},
    text::{measure_text, Font, TextDimensions},
};
use pest::Position;

use crate::{
    dom::{DOMAction, DOMElement, DOM},
    styling::{Display, FontFamily, FontWeight, TextDecorationLine},
};

pub fn render_dom(
    dom: &DOM,
    draw_text: &dyn Fn(&str, f32, f32, u16, macroquad::color::Color, &Font) -> TextDimensions,
    draw_line: &dyn Fn(Vec2, Vec2, macroquad::color::Color),
    fonts: &HashMap<(FontFamily, FontWeight), Font>,
) -> Vec<(BoundingBox, Vec<DOMAction>, String)> {
    macroquad::window::clear_background(macroquad::color::WHITE);

    let bbox = BoundingBox {
        x: 0.0,
        y: 0.0,
        width: macroquad::window::screen_width(),
        height: macroquad::window::screen_height(),
    };

    let mut position = Point { x: 0.0, y: 0.0 };

    let mut element_boxes = vec![];

    for element in dom.elements.iter() {
        position = render_dom_element(
            element,
            bbox,
            position,
            draw_text,
            draw_line,
            fonts,
            &mut element_boxes,
        );
    }

    element_boxes
}

#[derive(Debug, Copy, Clone)]
pub(crate) struct BoundingBox {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl BoundingBox {
    pub(crate) fn contains(&self, point: Point) -> bool {
        point.x >= self.x
            && point.x <= self.x + self.width
            && point.y >= self.y
            && point.y <= self.y + self.height
    }
}

#[derive(Debug, Copy, Clone)]
pub(crate) struct Point {
    pub x: f32,
    pub y: f32,
}

impl Point {
    pub(crate) fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

impl From<(f32, f32)> for Point {
    fn from((x, y): (f32, f32)) -> Self {
        Self { x, y }
    }
}

pub(crate) fn render_dom_element(
    element: &DOMElement,
    bbox: BoundingBox,
    position: Point,
    draw_text: &dyn Fn(&str, f32, f32, u16, macroquad::color::Color, &Font) -> TextDimensions,
    draw_line: &dyn Fn(Vec2, Vec2, macroquad::color::Color),
    fonts: &HashMap<(FontFamily, FontWeight), Font>,
    element_boxes: &mut Vec<(BoundingBox, Vec<DOMAction>, String)>,
) -> Point {
    let mut cursor = position;
    let mut bbox = bbox;
    match element {
        DOMElement::View {
            style,
            children,
            actions,
            id,
            tag,
            ..
        } => match style.display {
            Display::Block => {
                let line_height = style.font.size.to_pixels(16.0);
                let margin_top = style.margin.top.to_pixels(line_height);
                let margin_left = style.margin.left.to_pixels(line_height);

                cursor.y += margin_top;
                bbox.x += margin_left;
                cursor.x = bbox.x;

                let mut last_child = None;
                for child in children {
                    if let Some(last_child) = last_child {
                        if last_child == Display::Inline && child.style().display == Display::Block
                        {
                            cursor.y += line_height;
                            cursor.x = bbox.x;
                        }
                    }
                    cursor = render_dom_element(
                        child,
                        bbox,
                        cursor,
                        draw_text,
                        draw_line,
                        fonts,
                        element_boxes,
                    );
                    last_child = Some(child.style().display);
                }
                let margin_bottom = style.margin.bottom.to_pixels(line_height);
                let margin_right = style.margin.right.to_pixels(line_height);

                element_boxes.push((
                    BoundingBox {
                        x: position.x,
                        y: position.y,
                        width: cursor.x - position.x + margin_right,
                        height: cursor.y - position.y + margin_bottom,
                    },
                    actions.clone(),
                    id.clone(),
                ));

                Point::new(position.x, cursor.y + line_height + margin_bottom)
            }
            Display::Inline => {
                let mut cursor = position;
                for child in children {
                    cursor = render_dom_element(
                        child,
                        bbox,
                        cursor,
                        draw_text,
                        draw_line,
                        fonts,
                        element_boxes,
                    );
                }

                element_boxes.push((
                    BoundingBox {
                        x: position.x,
                        y: position.y,
                        width: cursor.x - position.x,
                        height: cursor.y - position.y,
                    },
                    actions.clone(),
                    id.clone(),
                ));

                Point::new(cursor.x, cursor.y)
            }
        },
        DOMElement::Text {
            text,
            style,
            actions,
            id,
        } => {
            // Tokenization
            let mut local_element_boxes = vec![];
            let tokens = text.split_whitespace();
            let line_height = style.font.size.to_pixels(16.0);
            let space_width = measure_text(
                " ",
                fonts.get(&(style.font.family, style.font.weight)),
                style.font.size.to_pixels(16.0).round() as u16,
                1.0,
            );
            let mut line_beginning = cursor.x;

            for token in tokens {
                let dimensions = measure_text(
                    token,
                    fonts.get(&(style.font.family, style.font.weight)),
                    line_height.round() as u16,
                    1.0,
                );

                if cursor.x + dimensions.width > bbox.width {
                    local_element_boxes.push((
                        BoundingBox {
                            x: line_beginning,
                            y: cursor.y,
                            width: cursor.x - line_beginning,
                            height: line_height,
                        },
                        actions.clone(),
                        id.clone(),
                    ));

                    // draw_rectangle_lines(
                    //     line_beginning,
                    //     cursor.y,
                    //     cursor.x - line_beginning,
                    //     line_height,
                    //     3.0,
                    //     macroquad::color::BLACK,
                    // );

                    cursor.y += line_height;
                    cursor.x = bbox.x;
                    line_beginning = cursor.x;
                }

                if let TextDecorationLine::Underline = style.text_decoration.line {
                    draw_line(
                        Vec2::new(cursor.x, cursor.y + line_height),
                        Vec2::new(cursor.x + dimensions.width, cursor.y + line_height),
                        style.text_decoration.color.into(),
                    );
                }

                draw_text(
                    &token,
                    cursor.x,
                    cursor.y + line_height,
                    line_height.round() as u16,
                    style.color.into(),
                    fonts.get(&(style.font.family, style.font.weight)).unwrap(),
                );

                cursor.x += dimensions.width + space_width.width;
            }

            let last_element = local_element_boxes.last();

            if last_element.is_none() || last_element.unwrap().0.y == cursor.y - line_height {
                local_element_boxes.push((
                    BoundingBox {
                        x: line_beginning,
                        y: cursor.y,
                        width: cursor.x - line_beginning,
                        height: line_height,
                    },
                    actions.clone(),
                    id.clone(),
                ));
                // draw_rectangle_lines(
                //     line_beginning,
                //     cursor.y,
                //     cursor.x - line_beginning,
                //     line_height,
                //     3.0,
                //     macroquad::color::BLUE,
                // );
            }

            element_boxes.extend(local_element_boxes);

            Point::new(cursor.x, cursor.y)
        }
    }
}
