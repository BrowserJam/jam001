use crate::tokenize::HTMLToken;

#[derive(Debug)]
pub enum HTMLNode {
    Text(String),
    Element {
        tag: String,
        attributes: Vec<(String, String)>,
        children: Vec<HTMLNode>,
    },
}

fn parse_node(tokens: &mut std::iter::Peekable<std::slice::Iter<HTMLToken>>, parent_tag: Option<String>) -> Option<HTMLNode> {
    match tokens.peek() {
        Some(HTMLToken::Text(text)) => {
            tokens.next();
            Some(HTMLNode::Text(text.clone()))
        },
        Some(HTMLToken::OpenTag { .. }) => Some(parse_tag(tokens, parent_tag)),
        Some(HTMLToken::CloseTag { .. }) => {
            // HTML ignores extraneous closing tags – we can just skip them (wtfrick)
            tokens.next();
            None
        }
        None => panic!("No more tokens to parse"),
    }
}

fn parse_tag(tokens: &mut std::iter::Peekable<std::slice::Iter<HTMLToken>>, parent_tag: Option<String>) -> HTMLNode {
    match tokens.next() {
        Some(HTMLToken::OpenTag { tag, attributes }) => {
            if tag == "nextid" {
                return HTMLNode::Element {
                    tag: tag.clone(),
                    attributes: attributes.clone(),
                    children: vec![],
                };
            }
            let mut children = vec![];
            loop {
                // Handle open tags that don't have closing tags
                if tag == "p" {
                    match tokens.peek() {
                        Some(HTMLToken::OpenTag { tag: next_tag, .. }) if next_tag == "dl" => {
                            break;
                        },
                        _ => {},
                    }
                }
                if tag == "dt" || tag == "dd" {
                    match tokens.peek() {
                        Some(HTMLToken::OpenTag { tag: next_tag, .. }) if next_tag == "dt" || next_tag == "dd" => {
                            break;
                        },
                        Some(HTMLToken::CloseTag { tag: next_tag }) if next_tag.clone() == parent_tag.clone().unwrap() => {
                            break;
                        },
                        _ => {},
                    }
                }
                
                // Handle the correct closing tags
                match tokens.peek() {
                    Some(HTMLToken::CloseTag { tag: closing_tag }) if closing_tag == tag => {
                        tokens.next();
                        break;
                    },
                    _ => match parse_node(tokens, Some(tag.clone())) {
                        Some(node) => children.push(node),
                        None => {},
                    }
                }
            }
            HTMLNode::Element {
                tag: tag.clone(),
                attributes: attributes.clone(),
                children,
            }
        },
        _ => panic!("Unexpected token"),
    }
}

pub fn parse(tokens: Vec<HTMLToken>) -> Vec<HTMLNode> {
    let mut tokens = tokens.iter().peekable();
    let mut nodes = vec![];
    while tokens.peek().is_some() {
        match parse_node(&mut tokens, None) { 
            Some(node) => nodes.push(node),
            None => {},
        }
    }
    println!("{:#?}", nodes);
    nodes
}
