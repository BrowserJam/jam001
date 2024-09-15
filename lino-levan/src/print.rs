use crate::parse::HTMLNode;

/// Print HTML nodes to a string
/// Helpful for debugging parse.rs
pub fn print_html(parse: &Vec<HTMLNode>) -> String {
    let mut html = String::new();

    for node in parse {
        match node {
            HTMLNode::Text(text) => html.push_str(&text),
            HTMLNode::Comment(comment) => html.push_str(&format!("<!--{}-->", comment)),
            HTMLNode::Element {
                tag,
                attributes,
                children,
            } => {
                html.push_str(&format!(
                    "<{}{}>",
                    tag,
                    attributes
                        .iter()
                        .map(|(key, value)| format!(" {}=\"{}\"", key, value))
                        .collect::<String>()
                ));
                html.push_str(&print_html(children));
                html.push_str(&format!("</{}>", tag));
            }
        }
    }

    return html;
}
