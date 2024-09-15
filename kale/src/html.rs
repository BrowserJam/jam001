#[derive(Debug)]
pub(crate) enum HTMLElement {
    Element {
        tag: String,
        attributes: Vec<(String, String)>,
        children: Vec<HTMLElement>,
    },
    Text(String),
}

impl HTMLElement {
    pub(crate) fn element(
        tag: String,
        attributes: Vec<(String, String)>,
        children: Vec<HTMLElement>,
    ) -> Self {
        Self::Element {
            tag,
            attributes,
            children,
        }
    }

    pub(crate) fn text_node(text: String) -> Self {
        Self::Text(text)
    }

    pub(crate) fn is_header(&self) -> bool {
        match self {
            HTMLElement::Element { tag, .. } => {
                tag == "head" || tag == "HEAD" || tag == "title" || tag == "TITLE"
            }
            _ => false,
        }
    }
}

impl ToString for HTMLElement {
    fn to_string(&self) -> String {
        match self {
            HTMLElement::Element {
                tag,
                attributes,
                children,
            } => {
                let mut attributes_str = String::new();
                for (name, value) in attributes {
                    attributes_str.push_str(&format!(" {}=\"{}\"", name, value));
                }

                let mut children_str = String::new();
                for child in children {
                    children_str.push_str(&child.to_string());
                }

                if children.is_empty() {
                    format!("<{}{}/>", tag, attributes_str)
                } else {
                    format!("<{}{}>{}</{}>", tag, attributes_str, children_str, tag)
                }
            }
            HTMLElement::Text(s) => s.clone(),
        }
    }
}
