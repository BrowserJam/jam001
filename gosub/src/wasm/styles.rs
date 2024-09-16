use url::Url;

use gosub_html5::parser::document::{Document, DocumentBuilder};
use gosub_html5::parser::Html5Parser;
use gosub_styling::render_tree::generate_render_tree;
use wasm_bindgen::prelude::wasm_bindgen;

#[wasm_bindgen]
pub struct StylesOptions {
    url: String,
}

#[wasm_bindgen]
impl StylesOptions {
    #[wasm_bindgen(constructor)]
    pub fn new(url: String) -> Self {
        Self { url }
    }
}

#[wasm_bindgen]
pub struct StylesOutput {
    errors: String,
    render_tree: String,
}

#[wasm_bindgen]
impl StylesOutput {
    pub fn to_string(&self) -> String {
        format!("{}\n{}", self.render_tree, self.errors)
    }

    pub fn render_tree(&self) -> String {
        self.render_tree.clone()
    }

    pub fn errors(&self) -> String {
        self.errors.clone()
    }
}

#[wasm_bindgen]
pub fn styles_parser(input: &str, opts: StylesOptions) -> StylesOutput {
    let url = Url::parse(&opts.url).ok();
    let doc = DocumentBuilder::new_document(url);

    let mut stream = ByteStream::new(Encoding::UTF8, None);
    stream.read_from_str(&input, Some(Encoding::UTF8));
    stream.close();

    let mut errors = String::new();

    match Html5Parser::parse_document(&mut stream, Document::clone(&doc), None) {
        Ok(errs) => {
            for e in errs {
                errors.push_str(&format!("{}@{}:{}\n", e.message, e.line, e.col));
            }
        }
        Err(e) => {
            errors = format!("Failed to parse HTML: {}", e);
        }
    }

    let render_tree = match generate_render_tree(Document::clone(&doc)) {
        Ok(tree) => tree,
        Err(e) => {
            errors = format!("{}\nFailed to generate render tree: {}", errors, e);
            return StylesOutput {
                errors,
                render_tree: String::new(),
            };
        }
    };

    StylesOutput {
        errors,
        render_tree: format!("{:?}", render_tree),
    }
}
