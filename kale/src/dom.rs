use crate::{
    html::HTMLElement,
    styling::{
        Color, Display, Font, FontFamily, FontStyle, FontWeight, Margin, Style, TextDecoration,
        TextDecorationLine, TextDecorationStyle, Unit,
    },
};

use uuid::Uuid;

#[derive(Debug, Clone)]
pub(crate) enum DOMElement {
    View {
        id: String,
        tag: String,
        style: Style,
        children: Vec<DOMElement>,
        actions: Vec<DOMAction>,
    },
    Text {
        id: String,
        style: Style,
        text: String,
        actions: Vec<DOMAction>,
    },
}

impl DOMElement {
    pub(crate) fn style(&self) -> &Style {
        match self {
            Self::View { style, .. } => style,
            Self::Text { style, .. } => style,
        }
    }
    pub(crate) fn actions(&self) -> &Vec<DOMAction> {
        match self {
            Self::View { actions, .. } => actions,
            Self::Text { actions, .. } => actions,
        }
    }

    pub(crate) fn id(&self) -> &str {
        match self {
            Self::View { id, .. } => id,
            Self::Text { id, .. } => id,
        }
    }

    pub(crate) fn tag(&self) -> &str {
        match self {
            Self::View { tag, .. } => tag,
            Self::Text { .. } => "text",
        }
    }
}

impl DOMElement {
    pub(crate) fn set_style(&mut self, style: Style) {
        match self {
            Self::View { style: s, .. } => *s = style,
            Self::Text { style: s, .. } => *s = style,
        }
    }

    pub(crate) fn get(&self, id: &str) -> Option<&DOMElement> {
        if self.id() == id {
            return Some(self);
        }
        match self {
            Self::View { children, .. } => {
                for child in children {
                    if let Some(e) = child.get(id) {
                        return Some(e);
                    }
                }
            }
            Self::Text { id: self_id, .. } => {
                if self_id == id {
                    return Some(self);
                }
            }
        }
        None
    }

    pub(crate) fn get_mut(&mut self, id: &str) -> Option<&mut DOMElement> {
        if self.id() == id {
            return Some(self);
        }
        match self {
            Self::View { children, .. } => {
                for child in children {
                    if let Some(e) = child.get_mut(id) {
                        return Some(e);
                    }
                }
            }
            Self::Text { id: self_id, .. } => {
                if self_id == id {
                    return Some(self);
                }
            }
        }
        None
    }

    pub(crate) fn set_clicked(&mut self, id: &str) {
        match self {
            Self::View {
                children,
                id: id_,
                style,
                ..
            } => {
                if id == id_ {
                    let style = style.clone();
                    self.set_style(Style {
                        color: Color::new(255, 0, 0),
                        ..style
                    });
                } else {
                    for child in children {
                        child.set_hovered(id);
                    }
                }
            }
            Self::Text { id: self_id, .. } => {
                if self_id == id {
                    self.set_style(Style {
                        color: Color::new(255, 0, 0),
                        ..self.style().clone()
                    });
                }
            }
        }
    }

    pub(crate) fn set_hovered(&mut self, id: &str) {
        match self {
            Self::View {
                children,
                id: id_,
                style,
                ..
            } => {
                if id == id_ {
                    let style = style.clone();
                    self.set_style(Style {
                        color: Color::new(255, 0, 0),
                        ..style
                    });
                } else {
                    for child in children {
                        child.set_hovered(id);
                    }
                }
            }
            Self::Text { id: self_id, .. } => {
                if self_id == id {
                    self.set_style(Style {
                        color: Color::new(255, 0, 0),
                        ..self.style().clone()
                    });
                }
            }
        }
    }
}

impl ToString for DOMElement {
    fn to_string(&self) -> String {
        match self {
            DOMElement::View {
                tag,
                style,
                children,
                id,
                ..
            } => {
                let mut result = String::new();
                let attributes = format!("id=\"{}\"", id);
                result.push_str(&format!("<{} {}>", tag, attributes));
                for child in children {
                    result.push_str(&child.to_string());
                }
                result.push_str(&format!("</{}>", tag));
                result
            }
            DOMElement::Text { text, .. } => text.clone(),
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) enum DOMAction {
    ClickToRedirect(String),
}

impl DOMAction {
    pub(crate) fn from_html_element(tag: &str, attributes: &Vec<(String, String)>) -> Vec<Self> {
        match tag {
            "a" | "A" => {
                let mut actions = vec![];
                for (key, value) in attributes {
                    if key == "href" || key == "HREF" {
                        actions.push(DOMAction::ClickToRedirect(value.clone()));
                    }
                }
                actions
            }
            _ => vec![],
        }
    }
}

struct MaybeStyle {
    pub display: Option<Display>,
    pub margin: Option<Margin>,
    pub font: Option<Font>,
    pub color: Option<Color>,
    pub text_decoration: Option<TextDecoration>,
}

pub(crate) struct InheritableStyle {
    pub font: Font,
    pub color: Color,
    pub text_decoration: TextDecoration,
}

impl Default for InheritableStyle {
    fn default() -> Self {
        Self {
            font: Font::default(),
            color: Color::default(),
            text_decoration: TextDecoration::default(),
        }
    }
}

impl MaybeStyle {
    pub(crate) fn from_tag(tag: &str) -> Self {
        match tag {
            "p" | "P" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                )),
                font: None,
                color: None,
                text_decoration: None,
            },
            "h1" | "H1" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(0.67),
                    Unit::Em(0.0),
                    Unit::Em(0.67),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(2.0),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "h2" | "H2" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(0.83),
                    Unit::Em(0.0),
                    Unit::Em(0.83),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(1.5),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "h3" | "H3" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(1.17),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "h4" | "H4" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(1.33),
                    Unit::Em(0.0),
                    Unit::Em(1.33),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(1.0),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "h5" | "H5" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(1.67),
                    Unit::Em(0.0),
                    Unit::Em(1.67),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(0.83),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "h6" | "H6" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(2.33),
                    Unit::Em(0.0),
                    Unit::Em(2.33),
                    Unit::Em(0.0),
                )),
                font: Some(Font::new(
                    Unit::Em(0.67),
                    FontFamily::TimesNewRoman,
                    FontWeight::Bold,
                    FontStyle::Normal,
                )),
                color: None,
                text_decoration: None,
            },
            "a" | "A" => Self {
                display: None,
                margin: None,
                font: None,
                color: Some(Color::new(0, 0, 238)),
                text_decoration: Some(TextDecoration {
                    color: Color::new(0, 0, 238),
                    line: TextDecorationLine::Underline,
                    style: TextDecorationStyle::Solid,
                }),
            },
            "dl" | "DL" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                    Unit::Em(1.0),
                    Unit::Em(0.0),
                )),
                font: None,
                color: None,
                text_decoration: None,
            },
            "dt" | "DT" => Self {
                display: Some(Display::Block),
                margin: None,
                font: None,
                color: None,
                text_decoration: None,
            },
            "dd" | "DD" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Em(0.0),
                    Unit::Em(0.0),
                    Unit::Em(0.0),
                    Unit::Px(40.0),
                )),
                font: None,
                color: None,
                text_decoration: None,
            },
            "body" | "BODY" => Self {
                display: Some(Display::Block),
                margin: Some(Margin::new(
                    Unit::Px(8.0),
                    Unit::Px(8.0),
                    Unit::Px(8.0),
                    Unit::Px(8.0),
                )),
                font: Some(Font::new(
                    Unit::Em(1.0),
                    FontFamily::TimesNewRoman,
                    FontWeight::Normal,
                    FontStyle::Normal,
                )),
                color: Some(Color::new(0, 0, 0)),
                text_decoration: None,
            },
            _ => Self {
                display: None,
                margin: None,
                font: None,
                color: None,
                text_decoration: None,
            },
        }
    }
}

impl HTMLElement {
    pub(crate) fn into_dom_element(
        self,
        inherited_style: &InheritableStyle,
        mut inherited_actions: Vec<DOMAction>,
    ) -> DOMElement {
        match self {
            HTMLElement::Element {
                tag,
                attributes,
                children,
            } => {
                // Get style
                let new_style = MaybeStyle::from_tag(&tag);
                // Inherit if not present
                let style = Style {
                    display: new_style.display.unwrap_or(Display::default()),
                    margin: new_style.margin.unwrap_or(Margin::default()),
                    font: new_style.font.unwrap_or(inherited_style.font.clone()),
                    color: new_style.color.unwrap_or(inherited_style.color),
                    text_decoration: new_style
                        .text_decoration
                        .unwrap_or(inherited_style.text_decoration.clone()),
                };
                // Create new inherited style
                let inherited_style = InheritableStyle {
                    font: style.font.clone(),
                    color: style.color.clone(),
                    text_decoration: style.text_decoration.clone(),
                };
                // Get actions
                let actions = DOMAction::from_html_element(&tag, &attributes);
                inherited_actions.extend(actions);
                // Recurse on children
                let children = children
                    .into_iter()
                    .filter(|child| !child.is_header())
                    .map(|child| {
                        child.into_dom_element(&inherited_style, inherited_actions.clone())
                    })
                    .collect();
                // Return DOMElement
                DOMElement::View {
                    id: uuid::Uuid::new_v4().to_string(),
                    tag,
                    style,
                    children,
                    actions: inherited_actions,
                }
            }
            HTMLElement::Text(text) => {
                let style = Style {
                    display: Display::Inline,
                    margin: Margin::default(),
                    font: inherited_style.font.clone(),
                    color: inherited_style.color,
                    text_decoration: inherited_style.text_decoration.clone(),
                };
                DOMElement::Text {
                    id: uuid::Uuid::new_v4().to_string(),
                    style,
                    text,
                    actions: inherited_actions,
                }
            }
        }
    }
}

#[derive(Debug)]
pub(crate) struct DOM {
    pub elements: Vec<DOMElement>,
}

impl DOM {
    pub(crate) fn construct_dom(html_elements: Vec<HTMLElement>) -> Self {
        let elements = html_elements
            .into_iter()
            .filter(|element| !element.is_header())
            .map(|element| element.into_dom_element(&InheritableStyle::default(), vec![]))
            .collect();
        Self { elements }
    }
}

impl DOM {
    pub(crate) fn get(&self, id: &str) -> Option<&DOMElement> {
        for element in &self.elements {
            if let Some(e) = element.get(id) {
                return Some(e);
            }
        }
        None
    }

    pub(crate) fn set_clicked(&mut self, id: &str) {
        for element in &mut self.elements {
            element.set_clicked(id);
        }
    }

    pub(crate) fn set_hovered(&mut self, id: &str) {
        for element in &mut self.elements {
            element.set_hovered(id);
        }
    }
}

impl ToString for DOM {
    fn to_string(&self) -> String {
        let mut result = String::new();
        for element in &self.elements {
            result.push_str(&element.to_string());
        }
        result
    }
}
