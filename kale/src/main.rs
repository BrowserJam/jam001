use std::collections::HashMap;

use dom::DOM;
use macroquad;
use macroquad::prelude::*;
use rendering::render_dom;
use styling::{FontFamily, FontWeight};

mod dom;
mod html;
mod parser;
mod rendering;
mod styling;

#[macroquad::main("Kale")]
async fn main() {
    let url = std::env::args().nth(1);
    let html = if let Some(url) = url {
        reqwest::blocking::get(&url).unwrap().text().unwrap()
    } else {
        include_str!("../pages/project2.html").to_string()
    };

    let html_elements = parser::parse(&html).unwrap();
    let mut dom = DOM::construct_dom(html_elements);
    let mut fonts = HashMap::new();
    let mut view_port_start = 0.0;
    fonts.insert(
        (FontFamily::TimesNewRoman, FontWeight::Normal),
        load_ttf_font("tnr.ttf").await.unwrap(),
    );
    fonts.insert(
        (FontFamily::TimesNewRoman, FontWeight::Bold),
        load_ttf_font("tnrb.ttf").await.unwrap(),
    );

    loop {
        let draw_text = |text: &str, x: f32, y: f32, font_size: u16, color: Color, font: &Font| {
            macroquad::text::draw_text_ex(
                text,
                x,
                view_port_start + y,
                TextParams {
                    font: Some(font),
                    font_size: font_size,
                    font_scale: 1.0,
                    font_scale_aspect: 1.0,
                    rotation: 0.0,
                    color: color,
                },
            )
        };

        let draw_line = |start: Vec2, end: Vec2, color: Color| {
            macroquad::shapes::draw_line(
                start.x,
                view_port_start + start.y,
                end.x,
                view_port_start + end.y,
                1.0,
                color,
            )
        };

        let element_boxes = render_dom(&dom, &draw_text, &draw_line, &fonts);
        let end_depth = element_boxes
            .iter()
            .map(|(bbox, _, _)| (bbox.y + bbox.height) as i32)
            .max();
        if macroquad::input::is_mouse_button_down(macroquad::input::MouseButton::Left) {
            for (bbox, actions, id) in element_boxes.iter() {
                if bbox.contains(macroquad::input::mouse_position().into()) {
                    println!(
                        "Clicked on {id} {} {:?}",
                        dom.get(&id).unwrap().tag(),
                        actions
                    );
                    for action in actions {
                        println!("{:?}", action);
                        match action {
                            dom::DOMAction::ClickToRedirect(url) => {
                                dom.set_clicked(&id);
                                // Fetch the new page
                                let base = "http://info.cern.ch/hypertext/WWW";
                                let url = url[1..url.len() - 1].to_string();
                                let url = if url.starts_with("http") {
                                    url.to_string()
                                } else if url.starts_with("/") {
                                    format!("{}{}", base, url)
                                } else {
                                    format!("{}/{}", base, url)
                                };

                                println!("Fetching {}", url);

                                let html = reqwest::blocking::get(&url).unwrap().text().unwrap();
                                let html_elements = parser::parse(&html).unwrap();
                                // Write the fetched HTML to a file
                                let url = url.replace("/", "_");
                                std::fs::write(format!("pages/{}", url), &html).unwrap();

                                dom = DOM::construct_dom(html_elements);
                            }
                        }
                    }
                }
            }
        }

        let scroll = macroquad::input::mouse_wheel().1;
        if scroll != 0.0 {
            view_port_start += scroll * 10.0;
            view_port_start = view_port_start.min(0.0);
            view_port_start = view_port_start.max((-end_depth.unwrap()) as f32);
        }
        // let cursor = macroquad::input::mouse_position();
        // for (bbox, actions, id) in element_boxes {
        //     if bbox.contains(cursor.into()) {
        //         dom.set_hovered(&id);
        //     }
        // }
        next_frame().await
    }
}
