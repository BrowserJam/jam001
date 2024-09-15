#[derive(Debug)]
pub enum HTMLToken {
    Text(String),
    Comment(String),
    OpenTag {
        tag: String,
        attributes: Vec<(String, String)>,
    },
    CloseTag {
        tag: String,
    },
}

/// Removes quotes from the beginning and end of a string
fn strip_quotes(s: &str) -> String {
    let mut chars = s.chars();
    let first = chars.next();
    let last = chars.next_back();

    match (first, last) {
        (Some('"'), Some('"')) => s[1..s.len() - 1].to_string(),
        _ => s.to_string(),
    }
}

fn parse_tag(iterator: &mut std::iter::Peekable<std::str::Chars>) -> HTMLToken {
    match iterator.next() {
        Some('<') => {}
        _ => panic!("Unexpected character"),
    }
    let mut tag = String::new();
    let mut parsing_tag = true;
    let mut unparsed_attributes = String::new();

    while let Some(&c) = iterator.peek() {
        if c == '>' {
            iterator.next();
            break;
        }

        if parsing_tag {
            if c == ' ' || c == '\n' || c == '\t' {
                parsing_tag = false;
            } else {
                tag.push(c);
            }
            iterator.next();
        } else {
            unparsed_attributes.push(c);
            iterator.next();
        }
    }

    if tag.starts_with("!--") {
        let comment = tag[3..].to_string() + &unparsed_attributes;
        return HTMLToken::Comment(comment);
    }

    let mut attributes = vec![];

    let mut key = String::new();
    let mut value = String::new();
    let mut parsing_key = true;

    for c in unparsed_attributes.chars() {
        if c == '=' {
            parsing_key = false;
        } else if c == ' ' || c == '\n' || c == '\t' {
            if key.len() > 0 {
                attributes.push((key.clone().to_lowercase(), strip_quotes(value.as_str())));
                key.clear();
                value.clear();
                parsing_key = true;
            }
        } else if parsing_key {
            key.push(c);
        } else {
            value.push(c);
        }
    }

    if key.len() > 0 {
        attributes.push((key.clone().to_lowercase(), strip_quotes(value.as_str())));
    }

    if tag.starts_with("/") {
        return HTMLToken::CloseTag {
            tag: tag[1..].to_string().to_lowercase(),
        };
    } else {
        return HTMLToken::OpenTag {
            tag: tag.to_lowercase(),
            attributes,
        };
    }
}

pub fn tokenize_html(html: &str) -> Vec<HTMLToken> {
    let mut elements = vec![];

    let mut iterator = html.chars().peekable();

    loop {
        match iterator.peek() {
            Some(_) => {}
            None => break,
        }

        let mut text = String::new();

        while let Some(&c) = iterator.peek() {
            if c == '<' {
                break;
            }

            text.push(iterator.next().unwrap());
        }

        if text.len() > 0 {
            elements.push(HTMLToken::Text(text));
        }

        if iterator.peek() == None {
            break;
        }

        let tag = parse_tag(&mut iterator);

        elements.push(tag);
    }

    return elements;
}
