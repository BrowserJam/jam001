use std::{error::Error, fs};

use tokenize::tokenize_html;

mod tokenize;
mod parse;
mod print;

fn main() -> Result<(), Box<dyn Error>> {
    let resp = reqwest::blocking::get("https://info.cern.ch/hypertext/WWW/TheProject.html")?.text()?;
    let tokens = tokenize_html(resp.as_str());
    let nodes = parse::parse(tokens);
    println!("{}", print::print_html(nodes));
    
    Ok(())
}
