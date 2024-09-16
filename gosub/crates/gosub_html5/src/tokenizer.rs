pub mod state;
pub mod token;

mod character_reference;
mod replacement_tables;

#[cfg(test)]
mod test_cases;

use crate::error_logger::{ErrorLogger, ParserError};
use crate::errors::Error;
use crate::node::HTML_NAMESPACE;
use crate::tokenizer::state::State;
use crate::tokenizer::token::Token;
use gosub_shared::byte_stream::Character::{Ch, StreamEnd};
use gosub_shared::byte_stream::{ByteStream, Character, Location, LocationHandler, Stream};
use gosub_shared::types::Result;
use std::cell::{Ref, RefCell};
use std::collections::HashMap;
use std::rc::Rc;

/// Constants that are not directly captured as visible chars
pub const CHAR_NUL: char = '\u{0000}';
pub const CHAR_TAB: char = '\u{0009}';
pub const CHAR_LF: char = '\u{000A}';
pub const CHAR_CR: char = '\u{000D}';
pub const CHAR_FF: char = '\u{000C}';
pub const CHAR_SPACE: char = '\u{0020}';
pub const CHAR_REPLACEMENT: char = '\u{FFFD}';

/// The tokenizer will read the input stream and emit tokens that can be used by the parser.
pub struct Tokenizer<'stream> {
    /// HTML character input stream
    pub stream: &'stream mut ByteStream,
    /// Current location in the stream
    location_handler: LocationHandler,
    /// Current state of the tokenizer
    pub state: State,
    /// Current consumed characters for current token
    pub consumed: String,
    /// Current attribute name that we need to store temporary in case we are parsing attributes
    pub current_attr_name: String,
    /// Current attribute value that we need to store temporary in case we are parsing attributes
    pub current_attr_value: String,
    /// Current attributes
    pub current_attrs: HashMap<String, String>,
    /// Token that is currently in the making (if any)
    pub current_token: Option<Token>,
    /// Temporary buffer
    pub temporary_buffer: String,
    /// Queue of emitted tokens. Needed because we can generate multiple tokens during iteration
    pub token_queue: Vec<Token>,
    /// The last emitted start token (or empty if none)
    pub last_start_token: String,
    /// Last token location
    pub last_token_location: Location,
    /// Last read character
    pub last_char: Character,
    /// Error logger to log errors to
    pub error_logger: Rc<RefCell<ErrorLogger>>,
}

impl<'stream> Tokenizer<'stream> {
    pub(crate) fn insert_tokens_at_queue_start(&mut self, first_tokens: &[Token]) {
        let mut new_queue = first_tokens.to_owned();
        new_queue.extend(self.token_queue.iter().cloned());

        self.token_queue = new_queue;
    }
}

/// This struct is a gateway between the parser and the tokenizer. It holds data that can be needed
/// by the tokenizer in certain cases. See https://github.com/gosub-browser/gosub-engine/issues/230 for
/// more information and how we should refactor this properly.
pub struct ParserData {
    pub adjusted_node_namespace: String,
}

impl Default for ParserData {
    fn default() -> Self {
        Self {
            adjusted_node_namespace: HTML_NAMESPACE.to_string(),
        }
    }
}

/// Options that can be passed to the tokenizer. Mostly needed when dealing with tests.
pub struct Options {
    /// Sets the initial state of the tokenizer. Normally only needed when dealing with tests
    pub initial_state: State,
    /// Sets the last starting tag in the tokenizer. Normally only needed when dealing with tests
    pub last_start_tag: String,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            initial_state: State::Data,
            last_start_tag: String::new(),
        }
    }
}

/// Convert a character to lower case value (assumes character is in A-Z range)
macro_rules! to_lowercase {
    ($c:expr) => {
        $c.to_lowercase().next().unwrap()
    };
}

impl<'stream> Tokenizer<'stream> {
    /// Creates a new tokenizer with the given input stream and additional options if any
    #[must_use]
    pub fn new(
        stream: &'stream mut ByteStream,
        opts: Option<Options>,
        error_logger: Rc<RefCell<ErrorLogger>>,
        start_location: Location,
    ) -> Self {
        Self {
            stream,
            location_handler: LocationHandler::new(start_location),
            state: opts.as_ref().map_or(State::Data, |o| o.initial_state),
            last_start_token: opts.map_or(String::new(), |o| o.last_start_tag),
            last_token_location: Location::default(),
            consumed: String::new(),
            current_token: None,
            token_queue: vec![],
            current_attr_name: String::new(),
            current_attr_value: String::new(),
            current_attrs: HashMap::new(),
            temporary_buffer: String::new(),
            last_char: StreamEnd,
            error_logger,
        }
    }

    /// Returns the current location in the stream (with line/col number and byte offset)
    #[inline]
    pub(crate) fn get_location(&self) -> Location {
        self.location_handler.cur_location.clone()
    }

    /// Retrieves the next token from the input stream or Token::EOF when the end is reached
    pub fn next_token(&mut self, parser_data: ParserData) -> Result<Token> {
        self.consume_stream(parser_data)?;

        if self.token_queue.is_empty() {
            return Ok(Token::Eof {
                location: self.get_location(),
            });
        }

        Ok(self.token_queue.remove(0))
    }

    /// Returns the error logger
    pub fn get_error_logger(&self) -> Ref<ErrorLogger> {
        self.error_logger.borrow()
    }

    /// Sets the tokenizer state to a new state
    pub(crate) fn set_state(&mut self, state: State) {
        self.state = state;
    }

    /// Consumes the input stream. Continues until the stream is completed or a token has been generated.
    fn consume_stream(&mut self, parser_data: ParserData) -> Result<()> {
        loop {
            // Something is already in the token buffer, so we can return it.
            if !self.token_queue.is_empty() {
                return Ok(());
            }

            match self.state {
                State::Data => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('&') => self.state = State::CharacterReferenceInData,
                        Ch('<') => {
                            self.state = {
                                self.last_token_location = loc.clone();
                                State::TagOpen
                            }
                        }
                        Ch(CHAR_NUL) => {
                            self.consume(c.into());
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                        }
                        StreamEnd => self.emit_token(Token::Eof {
                            location: self.get_location(),
                        }),
                        _ => self.consume(c.into()),
                    }
                }
                State::CharacterReferenceInData => {
                    self.consume_character_reference(None, false);
                    self.state = State::Data;
                }
                State::RCDATA => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('&') => self.state = State::CharacterReferenceInRcData,
                        Ch('<') => self.state = State::RCDATALessThanSign,
                        StreamEnd => self.emit_token(Token::Eof {
                            location: self.get_location(),
                        }),
                        Ch(CHAR_NUL) => {
                            self.consume(CHAR_REPLACEMENT);
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                        }
                        _ => self.consume(c.into()),
                    }
                }
                State::CharacterReferenceInRcData => {
                    // consume character reference
                    self.consume_character_reference(None, false);
                    self.state = State::RCDATA;
                }
                State::RAWTEXT => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('<') => self.state = State::RAWTEXTLessThanSign,
                        Ch(CHAR_NUL) => {
                            self.consume(CHAR_REPLACEMENT);
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                        }
                        StreamEnd => self.emit_token(Token::Eof {
                            location: self.get_location(),
                        }),
                        _ => self.consume(c.into()),
                    }
                }
                State::ScriptData => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('<') => self.state = State::ScriptDataLessThenSign,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                        }
                        StreamEnd => self.emit_token(Token::Eof {
                            location: self.get_location(),
                        }),
                        _ => self.consume(c.into()),
                    }
                }
                State::PLAINTEXT => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                        }
                        StreamEnd => self.emit_token(Token::Eof {
                            location: self.get_location(),
                        }),
                        _ => self.consume(c.into()),
                    }
                }
                State::TagOpen => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('!') => self.state = State::MarkupDeclarationOpen,
                        Ch('/') => self.state = State::EndTagOpen,
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::StartTag {
                                name: String::new(),
                                is_self_closing: false,
                                attributes: HashMap::new(),
                                location: self.last_token_location.clone(),
                            });
                            self.stream_prev();
                            self.state = State::TagName;
                        }
                        Ch('?') => {
                            self.current_token = Some(Token::Comment {
                                comment: String::new(),
                                location: self.last_token_location.clone(),
                            });
                            self.parse_error(
                                ParserError::UnexpectedQuestionMarkInsteadOfTagName,
                                loc,
                            );
                            self.stream_prev();
                            self.state = State::BogusComment;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofBeforeTagName, loc);
                            self.consume('<');
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(ParserError::InvalidFirstCharacterOfTagName, loc);
                            self.consume('<');
                            self.stream_prev();
                            self.state = State::Data;
                        }
                    }
                }
                State::EndTagOpen => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::EndTag {
                                name: String::new(),
                                is_self_closing: false,
                                location: self.last_token_location.clone(),
                            });
                            self.stream_prev();
                            self.state = State::TagName;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingEndTagName, loc);
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofBeforeTagName, loc);
                            self.consume('<');
                            self.consume('/');
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(ParserError::InvalidFirstCharacterOfTagName, loc);
                            self.current_token = Some(Token::Comment {
                                comment: String::new(),
                                location: self.last_token_location.clone(),
                            });
                            self.stream_prev();
                            self.state = State::BogusComment;
                        }
                    }
                }
                State::TagName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeAttributeName;
                        }
                        Ch('/') => self.state = State::SelfClosingStart,
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch(ch @ 'A'..='Z') => self.add_to_token_name(to_lowercase!(ch)),
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_to_token_name(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => self.add_to_token_name(c.into()),
                    }
                }
                State::RCDATALessThanSign => {
                    let c = self.read_char();
                    if let Ch('/') = c {
                        self.temporary_buffer.clear();
                        self.state = State::RCDATAEndTagOpen;
                    } else {
                        self.consume('<');
                        self.stream_prev();
                        self.state = State::RCDATA;
                    }
                }
                State::RCDATAEndTagOpen => {
                    let c = self.read_char();
                    match c {
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::EndTag {
                                name: String::new(),
                                is_self_closing: false,
                                location: self.last_token_location.clone(),
                            });
                            self.stream_prev();
                            self.state = State::RCDATAEndTagName;
                        }
                        _ => {
                            self.consume('<');
                            self.consume('/');
                            self.stream_prev();
                            self.state = State::RCDATA;
                        }
                    }
                }
                State::RCDATAEndTagName => {
                    let c = self.read_char();

                    // we use this flag because a lot of matches will actually do the same thing
                    let mut consume_anything_else = false;

                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::BeforeAttributeName;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('/') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::SelfClosingStart;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('>') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.emit_current_token();
                                self.last_start_token = String::new();
                                self.state = State::Data;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.add_to_token_name(to_lowercase!(ch));
                            self.temporary_buffer.push(ch);
                        }
                        _ => {
                            consume_anything_else = true;
                        }
                    }

                    if consume_anything_else {
                        self.stream_prev();
                        self.transition_to(State::RCDATA);
                    }
                }
                State::RAWTEXTLessThanSign => {
                    let c = self.read_char();
                    if let Ch('/') = c {
                        self.temporary_buffer.clear();
                        self.state = State::RAWTEXTEndTagOpen;
                    } else {
                        self.consume('<');
                        self.stream_prev();
                        self.state = State::RAWTEXT;
                    }
                }
                State::RAWTEXTEndTagOpen => {
                    let c = self.read_char();
                    match c {
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::EndTag {
                                name: String::new(),
                                is_self_closing: false,
                                location: self.last_token_location.clone(),
                            });
                            self.stream_prev();
                            self.state = State::RAWTEXTEndTagName;
                        }
                        _ => {
                            self.consume('<');
                            self.consume('/');
                            self.stream_prev();
                            self.state = State::RAWTEXT;
                        }
                    }
                }
                State::RAWTEXTEndTagName => {
                    let c = self.read_char();

                    // we use this flag because a lot of matches will actually do the same thing
                    let mut consume_anything_else = false;

                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::BeforeAttributeName;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('/') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::SelfClosingStart;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('>') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.emit_current_token();
                                self.last_start_token = String::new();
                                self.state = State::Data;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.add_to_token_name(to_lowercase!(ch));
                            self.temporary_buffer.push(ch);
                        }
                        _ => {
                            consume_anything_else = true;
                        }
                    }

                    if consume_anything_else {
                        self.stream_prev();
                        self.transition_to(State::RAWTEXT);
                    }
                }
                State::ScriptDataLessThenSign => {
                    let c = self.read_char();
                    match c {
                        Ch('/') => {
                            self.temporary_buffer.clear();
                            self.state = State::ScriptDataEndTagOpen;
                        }
                        Ch('!') => {
                            self.consume('<');
                            self.consume('!');
                            self.state = State::ScriptDataEscapeStart;
                        }
                        _ => {
                            self.consume('<');
                            self.stream_prev();
                            self.state = State::ScriptData;
                        }
                    }
                }
                State::ScriptDataEndTagOpen => {
                    let c = self.read_char();
                    match c {
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::EndTag {
                                name: format!("{}", to_lowercase!(ch)),
                                is_self_closing: false,
                                location: self.last_token_location.clone(),
                            });

                            self.temporary_buffer.push(ch);

                            self.state = State::ScriptDataEndTagName;
                        }
                        _ => {
                            self.consume('<');
                            self.consume('/');
                            self.stream_prev();
                            self.state = State::ScriptData;
                        }
                    }
                }
                State::ScriptDataEndTagName => {
                    let c = self.read_char();

                    // we use this flag because a lot of matches will actually do the same thing
                    let mut consume_anything_else = false;

                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::BeforeAttributeName;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('/') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::SelfClosingStart;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('>') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.emit_current_token();
                                self.last_start_token = String::new();
                                self.state = State::Data;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.add_to_token_name(to_lowercase!(ch));
                            self.temporary_buffer.push(ch);
                        }
                        _ => {
                            consume_anything_else = true;
                        }
                    }

                    if consume_anything_else {
                        self.stream_prev();
                        self.transition_to(State::ScriptData);
                    }
                }
                State::ScriptDataEscapeStart => {
                    let c = self.read_char();
                    if let Ch('-') = c {
                        self.consume('-');
                        self.state = State::ScriptDataEscapeStartDash;
                    } else {
                        self.stream_prev();
                        self.state = State::ScriptData;
                    }
                }
                State::ScriptDataEscapeStartDash => {
                    let c = self.read_char();
                    if let Ch('-') = c {
                        self.consume('-');
                        self.state = State::ScriptDataEscapedDashDash;
                    } else {
                        self.stream_prev();
                        self.state = State::ScriptData;
                    }
                }
                State::ScriptDataEscaped => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.consume('-');
                            self.state = State::ScriptDataEscapedDash;
                        }
                        Ch('<') => {
                            self.state = State::ScriptDataEscapedLessThanSign;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.consume(c.into());
                        }
                    }
                }
                State::ScriptDataEscapedDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.consume('-');
                            self.state = State::ScriptDataEscapedDashDash;
                        }
                        Ch('<') => {
                            self.state = State::ScriptDataEscapedLessThanSign;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                            self.state = State::ScriptDataEscaped;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.consume(c.into());
                            self.state = State::ScriptDataEscaped;
                        }
                    }
                }
                State::ScriptDataEscapedDashDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.consume('-');
                        }
                        Ch('<') => {
                            self.state = State::ScriptDataEscapedLessThanSign;
                        }
                        Ch('>') => {
                            self.consume('>');
                            self.state = State::ScriptData;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                            self.state = State::ScriptDataEscaped;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.consume(c.into());
                            self.state = State::ScriptDataEscaped;
                        }
                    }
                }
                State::ScriptDataEscapedLessThanSign => {
                    let c = self.read_char();
                    match c {
                        Ch('/') => {
                            self.temporary_buffer.clear();
                            self.state = State::ScriptDataEscapedEndTagOpen;
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.temporary_buffer.clear();
                            self.consume('<');
                            self.stream_prev();
                            self.state = State::ScriptDataDoubleEscapeStart;
                        }
                        _ => {
                            // anything else
                            self.consume('<');
                            self.stream_prev();
                            self.state = State::ScriptDataEscaped;
                        }
                    }
                }
                State::ScriptDataEscapedEndTagOpen => {
                    let c = self.read_char();
                    match c {
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.current_token = Some(Token::EndTag {
                                name: String::new(),
                                is_self_closing: false,
                                location: self.last_token_location.clone(),
                            });

                            self.stream_prev();
                            self.state = State::ScriptDataEscapedEndTagName;
                        }
                        _ => {
                            self.consume('<');
                            self.consume('/');
                            self.stream_prev();
                            self.state = State::ScriptDataEscaped;
                        }
                    }
                }
                State::ScriptDataEscapedEndTagName => {
                    let c = self.read_char();

                    // we use this flag because a lot of matches will actually do the same thing
                    let mut consume_anything_else = false;

                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::BeforeAttributeName;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('/') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.state = State::SelfClosingStart;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch('>') => {
                            let current_end_tag_name = match &self.current_token {
                                Some(Token::EndTag { name, .. }) => name,
                                _ => "",
                            };
                            if self.is_appropriate_end_token(current_end_tag_name) {
                                self.emit_current_token();
                                self.last_start_token = String::new();
                                self.state = State::Data;
                            } else {
                                consume_anything_else = true;
                            }
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.add_to_token_name(to_lowercase!(ch));
                            self.temporary_buffer.push(ch);
                        }
                        _ => {
                            consume_anything_else = true;
                        }
                    }

                    if consume_anything_else {
                        self.stream_prev();
                        self.transition_to(State::ScriptDataEscaped);
                    }
                }
                State::ScriptDataDoubleEscapeStart => {
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE | '/' | '>') => {
                            if self.temporary_buffer == "script" {
                                self.state = State::ScriptDataDoubleEscaped;
                            } else {
                                self.state = State::ScriptDataEscaped;
                            }
                            self.consume(c.into());
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.temporary_buffer.push(to_lowercase!(ch));
                            self.consume(ch);
                        }
                        _ => {
                            self.stream_prev();
                            self.state = State::ScriptDataEscaped;
                        }
                    }
                }
                State::ScriptDataDoubleEscaped => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.consume('-');
                            self.state = State::ScriptDataDoubleEscapedDash;
                        }
                        Ch('<') => {
                            self.consume('<');
                            self.state = State::ScriptDataDoubleEscapedLessThanSign;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => self.consume(c.into()),
                    }
                }
                State::ScriptDataDoubleEscapedDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.state = State::ScriptDataDoubleEscapedDashDash;
                            self.consume('-');
                        }
                        Ch('<') => {
                            self.state = State::ScriptDataDoubleEscapedLessThanSign;
                            self.consume('<');
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                            self.state = State::ScriptDataDoubleEscaped;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.consume(c.into());
                            self.state = State::ScriptDataDoubleEscaped;
                        }
                    }
                }
                State::ScriptDataDoubleEscapedDashDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => self.consume('-'),
                        Ch('<') => {
                            self.consume('<');
                            self.state = State::ScriptDataDoubleEscapedLessThanSign;
                        }
                        Ch('>') => {
                            self.consume('>');
                            self.state = State::ScriptData;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.consume(CHAR_REPLACEMENT);
                            self.state = State::ScriptDataDoubleEscaped;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInScriptHtmlCommentLikeText, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.consume(c.into());
                            self.state = State::ScriptDataDoubleEscaped;
                        }
                    }
                }
                State::ScriptDataDoubleEscapedLessThanSign => {
                    let c = self.read_char();
                    if let Ch('/') = c {
                        self.temporary_buffer.clear();
                        self.consume('/');
                        self.state = State::ScriptDataDoubleEscapeEnd;
                    } else {
                        self.stream_prev();
                        self.state = State::ScriptDataDoubleEscaped;
                    }
                }
                State::ScriptDataDoubleEscapeEnd => {
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE | '/' | '>') => {
                            if self.temporary_buffer == "script" {
                                self.state = State::ScriptDataEscaped;
                            } else {
                                self.state = State::ScriptDataDoubleEscaped;
                            }
                            self.consume(c.into());
                        }
                        Ch(ch) if ch.is_ascii_alphabetic() => {
                            self.temporary_buffer.push(to_lowercase!(ch));
                            self.consume(ch);
                        }
                        _ => {
                            self.stream_prev();
                            self.state = State::ScriptDataDoubleEscaped;
                        }
                    }
                }
                State::BeforeAttributeName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // Ignore character
                        }
                        Ch('/' | '>') | StreamEnd => {
                            self.stream_prev();
                            self.state = State::AfterAttributeName;
                        }
                        Ch('=') => {
                            self.parse_error(
                                ParserError::UnexpectedEqualsSignBeforeAttributeName,
                                loc,
                            );

                            self.store_and_clear_current_attribute();
                            self.current_attr_name.push(c.into());

                            self.state = State::AttributeName;
                        }
                        _ => {
                            // Store an existing attribute if any and clear
                            self.store_and_clear_current_attribute();

                            self.stream_prev();
                            self.state = State::AttributeName;
                        }
                    }
                }
                State::AttributeName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE | '/' | '>') => {
                            if self.attr_already_exists() {
                                self.parse_error(ParserError::DuplicateAttribute, loc);
                            }
                            self.stream_prev();

                            self.state = State::AfterAttributeName;
                        }
                        StreamEnd => {
                            if self.attr_already_exists() {
                                self.parse_error(ParserError::DuplicateAttribute, loc);
                            }
                            self.state = State::AfterAttributeName;
                        }
                        Ch('=') => {
                            if self.attr_already_exists() {
                                self.parse_error(ParserError::DuplicateAttribute, loc);
                            }
                            self.state = State::BeforeAttributeValue;
                        }
                        Ch(ch @ 'A'..='Z') => {
                            self.current_attr_name.push(to_lowercase!(ch));
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.current_attr_name.push(CHAR_REPLACEMENT);
                        }
                        Ch('"' | '\'' | '<') => {
                            self.parse_error(ParserError::UnexpectedCharacterInAttributeName, loc);
                            self.current_attr_name.push(c.into());
                        }
                        _ => self.current_attr_name.push(c.into()),
                    }
                }
                State::AfterAttributeName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // Ignore
                        }
                        Ch('/') => self.state = State::SelfClosingStart,
                        Ch('=') => self.state = State::BeforeAttributeValue,
                        Ch('>') => {
                            self.store_and_clear_current_attribute();
                            self.add_stored_attributes_to_current_token();
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.store_and_clear_current_attribute();
                            self.stream_prev();
                            self.state = State::AttributeName;
                        }
                    }
                }
                State::BeforeAttributeValue => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // Ignore
                        }
                        Ch('"') => self.state = State::AttributeValueDoubleQuoted,
                        Ch('\'') => {
                            self.state = State::AttributeValueSingleQuoted;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingAttributeValue, loc);

                            self.store_and_clear_current_attribute();
                            self.add_stored_attributes_to_current_token();
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.stream_prev();
                            self.state = State::AttributeValueUnquoted;
                        }
                    }
                }
                State::AttributeValueDoubleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('"') => self.state = State::AfterAttributeValueQuoted,
                        Ch('&') => {
                            self.consume_character_reference(Some(Ch('"')), true);
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.current_attr_value.push(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.current_attr_value.push(c.into());
                        }
                    }
                }
                State::AttributeValueSingleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('\'') => self.state = State::AfterAttributeValueQuoted,
                        Ch('&') => {
                            self.consume_character_reference(Some(Ch('\'')), true);
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.current_attr_value.push(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.current_attr_value.push(c.into());
                        }
                    }
                }
                State::AttributeValueUnquoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeAttributeName;
                        }
                        Ch('&') => {
                            self.consume_character_reference(Some(Ch('>')), true);
                        }
                        Ch('>') => {
                            self.store_and_clear_current_attribute();
                            self.add_stored_attributes_to_current_token();
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.current_attr_value.push(CHAR_REPLACEMENT);
                        }
                        Ch('"' | '\'' | '<' | '=' | '`') => {
                            self.parse_error(
                                ParserError::UnexpectedCharacterInUnquotedAttributeValue,
                                loc,
                            );
                            self.current_attr_value.push(c.into());
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.current_attr_value.push(c.into());
                        }
                    }
                }
                // State::CharacterReferenceInAttributeValue => {}
                State::AfterAttributeValueQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeAttributeName;
                        }
                        Ch('/') => self.state = State::SelfClosingStart,
                        Ch('>') => {
                            self.store_and_clear_current_attribute();
                            self.add_stored_attributes_to_current_token();
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(ParserError::MissingWhitespaceBetweenAttributes, loc);
                            self.stream_prev();
                            self.state = State::BeforeAttributeName;
                        }
                    }
                }
                State::SelfClosingStart => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('>') => {
                            self.set_is_closing_in_current_token(true);

                            self.state = State::Data;

                            self.store_and_clear_current_attribute();
                            self.add_stored_attributes_to_current_token();
                            self.emit_current_token();
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInTag, loc);
                            self.state = State::Data;
                        }
                        _ => {
                            self.stream_prev();
                            self.parse_error(ParserError::UnexpectedSolidusInTag, loc);
                            self.state = State::BeforeAttributeName;
                        }
                    }
                }
                State::BogusComment => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('>') | StreamEnd => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_to_token_value(CHAR_REPLACEMENT);
                        }
                        _ => {
                            self.add_to_token_value(c.into());
                        }
                    }
                }
                State::MarkupDeclarationOpen => {
                    if Character::slice_to_string(self.stream.get_slice(2)) == "--" {
                        self.current_token = Some(Token::Comment {
                            comment: String::new(),
                            location: self.get_location(),
                        });

                        // Skip the two -- signs
                        self.stream_next_n(2);

                        self.state = State::CommentStart;
                        continue;
                    }

                    if Character::slice_to_string(self.stream.get_slice(7)).to_uppercase()
                        == "DOCTYPE"
                    {
                        self.stream_next_n(7);
                        self.state = State::DOCTYPE;
                        continue;
                    }

                    if Character::slice_to_string(self.stream.get_slice(7)) == "[CDATA[" {
                        self.stream_next_n(6);
                        let loc = self.get_location();
                        self.stream_next_n(1);

                        if parser_data.adjusted_node_namespace != HTML_NAMESPACE {
                            self.state = State::CDATASection;
                            continue;
                        }

                        self.parse_error(ParserError::CdataInHtmlContent, loc);
                        self.current_token = Some(Token::Comment {
                            comment: "[CDATA[".into(),
                            location: self.get_location(),
                        });

                        self.state = State::BogusComment;
                        continue;
                    }

                    self.parse_error(ParserError::IncorrectlyOpenedComment, self.get_location());
                    self.current_token = Some(Token::Comment {
                        comment: String::new(),
                        location: self.last_token_location.clone(),
                    });

                    self.state = State::BogusComment;
                }
                State::CommentStart => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.state = State::CommentStartDash;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptClosingOfEmptyComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::CommentStartDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.state = State::CommentEnd;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptClosingOfEmptyComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.add_to_token_value('-');
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::Comment => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('<') => {
                            self.add_to_token_value(c.into());
                            self.state = State::CommentLessThanSign;
                        }
                        Ch('-') => self.state = State::CommentEndDash,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_to_token_value(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.add_to_token_value(c.into());
                        }
                    }
                }
                State::CommentLessThanSign => {
                    let c = self.read_char();
                    match c {
                        Ch('!') => {
                            self.add_to_token_value(c.into());
                            self.state = State::CommentLessThanSignBang;
                        }
                        Ch('<') => {
                            self.add_to_token_value(c.into());
                        }
                        _ => {
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::CommentLessThanSignBang => {
                    let c = self.read_char();
                    if let Ch('-') = c {
                        self.state = State::CommentLessThanSignBangDash;
                    } else {
                        self.stream_prev();
                        self.state = State::Comment;
                    }
                }
                State::CommentLessThanSignBangDash => {
                    let c = self.read_char();
                    if let Ch('-') = c {
                        self.state = State::CommentLessThanSignBangDashDash;
                    } else {
                        self.stream_prev();
                        self.state = State::CommentEndDash;
                    }
                }
                State::CommentLessThanSignBangDashDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        StreamEnd => {
                            self.state = State::CommentEnd;
                        }
                        Ch('>') => {
                            self.stream_prev();
                            self.state = State::CommentEnd;
                        }
                        _ => {
                            self.parse_error(ParserError::NestedComment, loc);
                            self.stream_prev();
                            self.state = State::CommentEnd;
                        }
                    }
                }
                State::CommentEndDash => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.state = State::CommentEnd;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.add_to_token_value('-');
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::CommentEnd => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch('!') => self.state = State::CommentEndBang,
                        Ch('-') => self.add_to_token_value('-'),
                        StreamEnd => {
                            self.parse_error(ParserError::EofInComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.add_to_token_value('-');
                            self.add_to_token_value('-');
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::CommentEndBang => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('-') => {
                            self.add_to_token_value('-');
                            self.add_to_token_value('-');
                            self.add_to_token_value('!');

                            self.state = State::CommentEndDash;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::IncorrectlyClosedComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInComment, loc);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.add_to_token_value('-');
                            self.add_to_token_value('-');
                            self.add_to_token_value('!');
                            self.stream_prev();
                            self.state = State::Comment;
                        }
                    }
                }
                State::DOCTYPE => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeDOCTYPEName;
                        }
                        Ch('>') => {
                            self.stream_prev();
                            self.state = State::BeforeDOCTYPEName;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);

                            self.emit_token(Token::DocType {
                                name: None,
                                force_quirks: true,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.get_location(),
                            });

                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(ParserError::MissingWhitespaceBeforeDoctypeName, loc);
                            self.stream_prev();
                            self.state = State::BeforeDOCTYPEName;
                        }
                    }
                }
                State::BeforeDOCTYPEName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch(ch @ 'A'..='Z') => {
                            self.current_token = Some(Token::DocType {
                                name: None,
                                force_quirks: false,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.last_token_location.clone(),
                            });

                            self.add_to_token_name(to_lowercase!(ch));
                            self.state = State::DOCTYPEName;
                        }
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.current_token = Some(Token::DocType {
                                name: None,
                                force_quirks: false,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.last_token_location.clone(),
                            });

                            self.add_to_token_name(CHAR_REPLACEMENT);
                            self.state = State::DOCTYPEName;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingDoctypeName, loc);
                            self.emit_token(Token::DocType {
                                name: None,
                                force_quirks: true,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.last_token_location.clone(),
                            });

                            self.state = State::Data;
                        }

                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);

                            self.emit_token(Token::DocType {
                                name: None,
                                force_quirks: true,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.last_token_location.clone(),
                            });

                            self.state = State::Data;
                        }
                        _ => {
                            self.current_token = Some(Token::DocType {
                                name: None,
                                force_quirks: false,
                                pub_identifier: None,
                                sys_identifier: None,
                                location: self.last_token_location.clone(),
                            });

                            self.add_to_token_name(c.into());
                            self.state = State::DOCTYPEName;
                        }
                    }
                }
                State::DOCTYPEName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::AfterDOCTYPEName;
                        }
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch(ch @ 'A'..='Z') => self.add_to_token_name(to_lowercase!(ch)),
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_to_token_name(CHAR_REPLACEMENT);
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => self.add_to_token_name(c.into()),
                    }
                }
                State::AfterDOCTYPEName => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.stream_prev();
                            if Character::slice_to_string(self.stream.get_slice(6)).to_uppercase()
                                == "PUBLIC"
                            {
                                self.stream_next_n(6);
                                self.state = State::AfterDOCTYPEPublicKeyword;
                                continue;
                            }
                            if Character::slice_to_string(self.stream.get_slice(6)).to_uppercase()
                                == "SYSTEM"
                            {
                                self.stream_next_n(6);
                                self.state = State::AfterDOCTYPESystemKeyword;
                                continue;
                            }
                            // Make sure the parser is on the correct position again since we just
                            // unread the character
                            let loc = self.get_location();
                            self.stream_next_n(1);
                            self.parse_error(
                                ParserError::InvalidCharacterSequenceAfterDoctypeName,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.stream_prev();
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::AfterDOCTYPEPublicKeyword => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeDOCTYPEPublicIdentifier;
                        }
                        Ch('"') => {
                            self.parse_error(
                                ParserError::MissingWhitespaceAfterDoctypePublicKeyword,
                                loc,
                            );
                            self.set_public_identifier(String::new());
                            self.state = State::DOCTYPEPublicIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.parse_error(
                                ParserError::MissingWhitespaceAfterDoctypePublicKeyword,
                                loc,
                            );
                            self.set_public_identifier(String::new());
                            self.state = State::DOCTYPEPublicIdentifierSingleQuoted;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingDoctypePublicIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypePublicIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::BeforeDOCTYPEPublicIdentifier => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch('"') => {
                            self.set_public_identifier(String::new());
                            self.state = State::DOCTYPEPublicIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.set_public_identifier(String::new());
                            self.state = State::DOCTYPEPublicIdentifierSingleQuoted;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingDoctypePublicIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.stream_prev();
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypePublicIdentifier,
                                loc,
                            );
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::DOCTYPEPublicIdentifierDoubleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('"') => self.state = State::AfterDOCTYPEPublicIdentifier,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_public_identifier(CHAR_REPLACEMENT);
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptDoctypePublicIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => self.add_public_identifier(c.into()),
                    }
                }
                State::DOCTYPEPublicIdentifierSingleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('\'') => self.state = State::AfterDOCTYPEPublicIdentifier,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_public_identifier(CHAR_REPLACEMENT);
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptDoctypePublicIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => self.add_public_identifier(c.into()),
                    }
                }
                State::AfterDOCTYPEPublicIdentifier => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BetweenDOCTYPEPublicAndSystemIdentifiers;
                        }
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch('"') => {
                            self.parse_error(ParserError::MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers, loc);
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.parse_error(ParserError::MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers, loc);
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierSingleQuoted;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypeSystemIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::BetweenDOCTYPEPublicAndSystemIdentifiers => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch('"') => {
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierSingleQuoted;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypeSystemIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::AfterDOCTYPESystemKeyword => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            self.state = State::BeforeDOCTYPESystemIdentifier;
                        }
                        Ch('"') => {
                            self.parse_error(
                                ParserError::MissingWhitespaceAfterDoctypeSystemKeyword,
                                loc,
                            );
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.parse_error(
                                ParserError::MissingWhitespaceAfterDoctypeSystemKeyword,
                                loc,
                            );
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierSingleQuoted;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingDoctypeSystemIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypeSystemIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::BeforeDOCTYPESystemIdentifier => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch('"') => {
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierDoubleQuoted;
                        }
                        Ch('\'') => {
                            self.set_system_identifier(String::new());
                            self.state = State::DOCTYPESystemIdentifierSingleQuoted;
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::MissingDoctypeSystemIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::MissingQuoteBeforeDoctypeSystemIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.set_quirks_mode(true);
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::DOCTYPESystemIdentifierDoubleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('"') => self.state = State::AfterDOCTYPESystemIdentifier,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_system_identifier(CHAR_REPLACEMENT);
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptDoctypeSystemIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => self.add_system_identifier(c.into()),
                    }
                }
                State::DOCTYPESystemIdentifierSingleQuoted => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('\'') => self.state = State::AfterDOCTYPESystemIdentifier,
                        Ch(CHAR_NUL) => {
                            self.parse_error(ParserError::UnexpectedNullCharacter, loc);
                            self.add_system_identifier(CHAR_REPLACEMENT);
                        }
                        Ch('>') => {
                            self.parse_error(ParserError::AbruptDoctypeSystemIdentifier, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => self.add_system_identifier(c.into()),
                    }
                }
                State::AfterDOCTYPESystemIdentifier => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(CHAR_TAB | CHAR_LF | CHAR_FF | CHAR_SPACE) => {
                            // ignore
                        }
                        Ch('>') => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInDoctype, loc);
                            self.set_quirks_mode(true);
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        _ => {
                            self.parse_error(
                                ParserError::UnexpectedCharacterAfterDoctypeSystemIdentifier,
                                loc,
                            );
                            self.stream_prev();
                            self.state = State::BogusDOCTYPE;
                        }
                    }
                }
                State::BogusDOCTYPE => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch('>') | StreamEnd => {
                            self.emit_current_token();
                            self.state = State::Data;
                        }
                        Ch(CHAR_NUL) => self.parse_error(ParserError::UnexpectedNullCharacter, loc),
                        _ => {
                            // ignore
                        }
                    }
                }
                State::CDATASection => {
                    let loc = self.get_location();
                    let c = self.read_char();
                    match c {
                        Ch(']') => {
                            self.state = State::CDATASectionBracket;
                        }
                        StreamEnd => {
                            self.parse_error(ParserError::EofInCdata, loc);
                            self.state = State::Data;
                        }
                        _ => self.consume(c.into()),
                    }
                }
                State::CDATASectionBracket => {
                    let c = self.read_char();
                    if let Ch(']') = c {
                        self.state = State::CDATASectionEnd;
                    } else {
                        self.consume(']');
                        self.stream_prev();
                        self.state = State::CDATASection;
                    }
                }
                State::CDATASectionEnd => {
                    let c = self.read_char();
                    match c {
                        Ch('>') => self.state = State::Data,
                        Ch(']') => self.consume(']'),
                        StreamEnd => {
                            self.consume(']');
                            self.consume(']');
                            self.state = State::CDATASection;
                        }
                        _ => {
                            self.consume(']');
                            self.consume(']');
                            self.consume(c.into());
                            self.state = State::CDATASection;
                        }
                    }
                }
                State::CharacterReferenceInAttributeValue => {
                    panic!("state {:?} not implemented", self.state);
                }
            }
        }
    }

    /// This macro reads a character from the input stream and optionally generates (tokenization)
    /// errors if the character is not valid.
    fn read_char(&mut self) -> Character {
        let loc = self.get_location();
        let mut c = self.stream_read_and_next();

        match c {
            Character::Surrogate(..) => {
                self.parse_error(ParserError::SurrogateInInputStream, loc);
                c = Ch(CHAR_REPLACEMENT);
            }
            Ch(c) if self.is_control_char(c as u32) => {
                self.parse_error(ParserError::ControlCharacterInInputStream, loc);
            }
            Ch(c) if self.is_noncharacter(c as u32) => {
                self.parse_error(ParserError::NoncharacterInInputStream, loc);
            }
            _ => {}
        }

        // println!("stream_read(): {:?}", c);

        c
    }

    /// Adds the given character to the current token's value (if applicable)
    fn add_to_token_value(&mut self, c: char) {
        if let Some(Token::Comment { comment: value, .. }) = &mut self.current_token {
            value.push(c);
        }
    }

    /// Sets the public identifier of the current token (if applicable)
    fn set_public_identifier(&mut self, s: String) {
        if let Some(Token::DocType { pub_identifier, .. }) = &mut self.current_token {
            *pub_identifier = Some(s);
        }
    }

    /// Adds the given character to the current token's public identifier (if applicable)
    fn add_public_identifier(&mut self, c: char) {
        if let Some(Token::DocType {
            pub_identifier: Some(pid),
            ..
        }) = &mut self.current_token
        {
            pid.push(c);
        }
    }

    /// Sets the system identifier of the current token (if applicable)
    fn set_system_identifier(&mut self, s: String) {
        if let Some(Token::DocType { sys_identifier, .. }) = &mut self.current_token {
            *sys_identifier = Some(s);
        }
    }

    /// Adds the given character to the current token's system identifier (if applicable)
    fn add_system_identifier(&mut self, c: char) {
        if let Some(Token::DocType {
            sys_identifier: Some(sid),
            ..
        }) = &mut self.current_token
        {
            sid.push(c);
        }
    }

    /// Adds the given character to the current token's name (if applicable)
    fn add_to_token_name(&mut self, c: char) {
        match &mut self.current_token {
            Some(Token::StartTag { name, .. } | Token::EndTag { name, .. }) => {
                name.push(c);
            }
            Some(Token::DocType { name, .. }) => {
                // DOCTYPE can have an optional name
                match name {
                    Some(ref mut string) => string.push(c),
                    None => *name = Some(c.to_string()),
                }
            }
            _ => {}
        }
    }

    /// Emits the current stored token
    fn emit_current_token(&mut self) {
        if let Some(t) = self.current_token.take() {
            self.emit_token(t);
        }
    }

    /// Emits the given stored token. It does not have to be stored first.
    fn emit_token(&mut self, token: Token) {
        // Save the start token name if we are pushing it. This helps us in detecting matching tags.
        if let Token::StartTag { name, .. } = &token {
            self.last_start_token = String::from(name);
        }

        // If there is any consumed data, emit this first as a text token
        if self.has_consumed_data() {
            let value = self.get_consumed_str().to_string();

            self.token_queue.push(Token::Text {
                text: value.to_string(),
                location: self.last_token_location.clone(),
            });

            self.clear_consume_buffer();
        }

        self.token_queue.push(token);
    }

    // Consumes the given character
    pub(crate) fn consume(&mut self, c: char) {
        // Add c to the current token data
        self.consumed.push(c);
    }

    /// Pushes an end-tag and changes to the given state
    fn transition_to(&mut self, state: State) {
        self.consumed.push_str("</");
        self.consumed.push_str(&self.temporary_buffer);
        self.temporary_buffer.clear();

        self.state = state;
    }

    /// Consumes the given string
    #[allow(dead_code)]
    pub(crate) fn consume_str(&mut self, s: &str) {
        // Add s to the current token data
        self.consumed.push_str(s);
    }

    /// Return true when the given end_token matches the stored start token (ie: 'table' matches when
    /// last_start_token = 'table')
    fn is_appropriate_end_token(&self, end_token: &str) -> bool {
        self.last_start_token == end_token
    }

    /// Return the consumed string as a String
    pub fn get_consumed_str(&self) -> &str {
        &self.consumed
    }

    /// Returns true if there is anything in the consume buffer
    pub fn has_consumed_data(&self) -> bool {
        !self.consumed.is_empty()
    }

    /// Clears the current consume buffer
    pub(crate) fn clear_consume_buffer(&mut self) {
        self.consumed.clear();
    }

    /// Creates a parser log error message
    pub(crate) fn parse_error(&mut self, message: ParserError, location: Location) {
        self.error_logger
            .borrow_mut()
            .add_error(location, message.as_str());
    }

    /// Set is_closing_tag in current token
    fn set_is_closing_in_current_token(&mut self, is_closing: bool) {
        match &mut self.current_token.as_mut().unwrap() {
            Token::EndTag { .. } => {
                self.stream_prev();
                self.parse_error(ParserError::EndTagWithTrailingSolidus, self.get_location());
                self.stream_next_n(1);
            }
            Token::StartTag {
                is_self_closing, ..
            } => {
                *is_self_closing = is_closing;
            }
            _ => {}
        }
    }

    /// Set force_quirk mode in current token
    fn set_quirks_mode(&mut self, quirky: bool) {
        if let Token::DocType { force_quirks, .. } = &mut self.current_token.as_mut().unwrap() {
            *force_quirks = quirky;
        }
    }

    /// Adds a new attribute to the current token
    #[allow(dead_code)]
    fn set_add_attribute_to_current_token(&mut self, name: &str, value: &str) {
        if let Token::StartTag { attributes, .. } = &mut self.current_token.as_mut().unwrap() {
            attributes.insert(name.into(), value.into());
        }

        self.current_attr_name.clear();
    }

    /// Sets the given name into the current token
    #[allow(dead_code)]
    fn set_name_in_current_token(&mut self, new_name: String) -> Result<()> {
        match &mut self.current_token.as_mut().expect("current token") {
            Token::StartTag { name, .. } | Token::EndTag { name, .. } => {
                *name = new_name;
            }
            _ => {
                return Err(Error::Parse(
                    "trying to set the name of a non start/end tag token".into(),
                )
                .into())
            }
        }

        Ok(())
    }

    /// This function checks to see if there is already an attribute name like the one in current_attr_name.
    fn attr_already_exists(&mut self) -> bool {
        self.current_attrs.contains_key(&self.current_attr_name)
    }

    /// Saves the current attribute name and value onto the current_attrs stack, if there is anything to store
    fn store_and_clear_current_attribute(&mut self) {
        if !self.current_attr_name.is_empty()
            && !self.current_attrs.contains_key(&self.current_attr_name)
        {
            self.current_attrs.insert(
                self.current_attr_name.clone(),
                self.current_attr_value.clone(),
            );
        }

        self.current_attr_name = String::new();
        self.current_attr_value = String::new();
    }

    /// This method will add current generated attributes to the current (start) token if needed.
    fn add_stored_attributes_to_current_token(&mut self) {
        if self.current_token.is_none() {
            return;
        }
        if self.current_attrs.is_empty() {
            return;
        }

        match self.current_token.as_mut().expect("current token") {
            Token::EndTag { .. } => {
                // Error is one char before this one. Unread, fetch location and read again
                self.stream_prev();
                self.parse_error(ParserError::EndTagWithAttributes, self.get_location());
                self.stream_next_n(1);
            }
            Token::StartTag { attributes, .. } => {
                for (key, value) in &self.current_attrs {
                    attributes.insert(key.clone(), value.clone());
                }
                self.current_attrs = HashMap::new();
            }
            _ => {}
        }
    }

    fn stream_read_and_next(&mut self) -> Character {
        let c = self.stream.read_and_next();
        self.last_char = c;
        self.location_handler.inc(c);
        c
    }

    fn stream_prev(&mut self) {
        if self.last_char == StreamEnd {
            return;
        }

        self.location_handler.dec();
        self.stream.prev();
    }

    fn stream_next_n(&mut self, n: usize) {
        for _ in 0..n {
            self.stream_read_and_next();
        }
    }
}
