#[derive(Debug, Clone)]
pub(crate) struct Style {
    pub display: Display,
    pub margin: Margin,
    pub font: Font,
    pub color: Color,
    pub text_decoration: TextDecoration,
}

impl Style {
    pub(crate) fn new(
        display: Display,
        margin: Margin,
        font: Font,
        color: Color,
        text_decoration: TextDecoration,
    ) -> Self {
        Self {
            display,
            margin,
            font,
            color,
            text_decoration,
        }
    }
}

impl Default for Style {
    fn default() -> Self {
        Self {
            display: Display::Block,
            margin: Margin::default(),
            font: Font::default(),
            color: Color::default(),
            text_decoration: TextDecoration::default(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Display {
    Block,
    Inline,
}

impl Default for Display {
    fn default() -> Self {
        Self::Inline
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct Margin {
    pub top: Unit,
    pub right: Unit,
    pub bottom: Unit,
    pub left: Unit,
}

impl Margin {
    pub(crate) fn new(top: Unit, right: Unit, bottom: Unit, left: Unit) -> Self {
        Self {
            top,
            right,
            bottom,
            left,
        }
    }
}

impl Default for Margin {
    fn default() -> Self {
        Self {
            top: Unit::Px(0.0),
            right: Unit::Px(0.0),
            bottom: Unit::Px(0.0),
            left: Unit::Px(0.0),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) enum Unit {
    Px(f32),
    Em(f32),
    Rem(f32),
}

impl Unit {
    pub(crate) fn to_pixels(&self, scale: f32) -> f32 {
        match self {
            Self::Px(px) => *px,
            Self::Em(m) => scale * m,
            Self::Rem(m) => 16.0 * m,
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) struct Font {
    pub size: Unit,
    pub family: FontFamily,
    pub weight: FontWeight,
    pub style: FontStyle,
}

impl Font {
    pub(crate) fn new(size: Unit, family: FontFamily, weight: FontWeight, style: FontStyle) -> Self {
        Self {
            size,
            family,
            weight,
            style,
        }
    }
}

impl Default for Font {
    fn default() -> Self {
        Self {
            size: Unit::Px(16.0),
            family: FontFamily::default(),
            weight: FontWeight::default(),
            style: FontStyle::default(),
        }
    }
}


#[derive(Debug, Copy, Clone, PartialEq, Eq, Hash)]
pub enum FontFamily {
    TimesNewRoman,
    Arial,
}

impl Default for FontFamily {
    fn default() -> Self {
        Self::TimesNewRoman
    }
    
}
#[derive(Debug, Copy, Clone, PartialEq, Eq, Hash)]
pub enum FontWeight {
    Normal,
    Bold,
}

impl Default for FontWeight {
    fn default() -> Self {
        Self::Normal
    }
}

#[derive(Debug, Copy, Clone)]
pub enum FontStyle {
    Normal,
    Italic,
}

impl Default for FontStyle {
    fn default() -> Self {
        Self::Normal
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct Color {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

impl Default for Color {
    fn default() -> Self {
        Self {
            r: 0,
            g: 0,
            b: 0,
            a: 255,
        }
    }
}

impl Color {
    pub(crate) fn new(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b, a: 255 }
    }
}

impl From<Color> for macroquad::color::Color {
    fn from(color: Color) -> Self {
        macroquad::color::Color::from_rgba(color.r, color.g, color.b, color.a)
    }
}

#[derive(Debug, Clone)]
pub(crate) struct TextDecoration {
    pub color: Color,
    pub line: TextDecorationLine,
    pub style: TextDecorationStyle,
}

impl Default for TextDecoration {
    fn default() -> Self {
        Self {
            color: Color::default(),
            line: TextDecorationLine::default(),
            style: TextDecorationStyle::default(),
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) enum TextDecorationLine {
    None,
    Underline,
    Overline,
    LineThrough,
}

impl Default for TextDecorationLine {
    fn default() -> Self {
        Self::None
    }
}

#[derive(Debug, Clone)]
pub(crate) enum TextDecorationStyle {
    Solid,
    Double,
    Dotted,
    Dashed,
    Wavy,
}

impl Default for TextDecorationStyle {
    fn default() -> Self {
        Self::Solid
    }
}
