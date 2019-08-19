//! This module is an incomplete implementation of a parser for the GNU
//! assembler syntax, only enough for parsing a compiler's output.
//!
//! The grammar is roughly derived from [the GAS documentation] and does not
//! likely match its actual syntax.
//!
//! [the GAS documentation]: https://sourceware.org/binutils/docs/as/
use std::io::{self, BufRead};

#[derive(Debug, Clone)]
pub enum Item<'a> {
    Empty,
    Statement(Statement<'a>),
}

#[derive(Debug, Clone)]
pub struct Statement<'a> {
    /// Zero or more labels.
    pub labels: Vec<&'a str>,
    /// The directive.
    pub directive: Option<Directive<'a>>,
}

#[derive(Debug, Clone)]
pub struct Directive<'a> {
    /// The key symbol.
    pub key: &'a str,
    /// The rest part of the statement.
    pub rest: &'a str,
}

#[derive(Debug)]
pub enum Error {
    IoError(io::Error),
    SyntaxError { message: String, line: usize },
}

impl From<io::Error> for Error {
    fn from(x: io::Error) -> Self {
        Error::IoError(x)
    }
}

mod parsing {
    use super::*;
    use nom::IResult;

    fn is_symbol_char(x: char) -> bool {
        x.is_alphanumeric() || x == '.' || x == '_' || x == '$'
    }

    fn is_ws_but_newline(x: char) -> bool {
        x.is_whitespace() && x != '\n'
    }

    named!(ws_but_newline<&str, &str>, take_while!(is_ws_but_newline));

    named!(symbol_no_ws<&str, &str>, take_while1!(is_symbol_char));

    named!(symbol<&str, &str>, sep!(ws_but_newline, symbol_no_ws));

    named!(label<&str, &str>, sep!(ws_but_newline, terminated!(symbol_no_ws, char!(':'))));

    named!(directive<&str, Directive>, do_parse!(
        key: symbol                    >>
        rest: take_until!("\n")        >>
        (Directive {
            key,
            rest,
        })
    ));

    named!(statement<&str, Statement>, do_parse!(
        labels: many0!(label)       >>
        directive: opt!(directive)  >>
        (Statement {
            labels,
            directive,
        })
    ));

    named!(statement_or_empty<&str, Option<Statement>>,
        complete!(terminated!(sep!(ws_but_newline, opt!(statement)), char!('\n'))));

    pub fn parse(input: &str) -> Result<Option<Statement>, String> {
        println!("parsing {:?}", input);
        match statement_or_empty(input) {
            IResult::Done(_, stmt) => Ok(stmt),
            IResult::Incomplete(_) => Err("unexpected EOF".to_owned()),
            IResult::Error(e) => Err(format!("failed to parse {:?}", e)),
        }
    }
}

#[derive(Debug)]
pub struct GasParser<T> {
    reader: T,

    /// The current line number.
    line_index: usize,

    /// Stores the contents of the current logical (i.e., can span across
    /// multiple physical lines if there are any intervening block comments) line.
    line_buffer: String,
}

impl<T> GasParser<T> {
    pub fn new(reader: T) -> Self {
        Self {
            reader,
            line_index: 0,
            line_buffer: String::new(),
        }
    }
}

impl<T: BufRead> GasParser<T> {
    pub fn next(&mut self) -> Result<Option<Item>, Error> {
        self.line_buffer.clear();

        // Read the current logical line
        let mut start = self.line_buffer.len();
        let bytes_read = self.reader.read_line(&mut self.line_buffer)?;

        if bytes_read == 0 {
            return Ok(None);
        }

        self.line_index += 1;

        // Remove the newline character
        self.line_buffer.pop();

        loop {
            // Look for a starting character of a comment
            let i_comment_line = self.line_buffer[start..].find(&['#', '@'][..]);
            let i_comment_block = self.line_buffer[start..].find("/*");
            let i_comment = [i_comment_line, i_comment_block]
                .iter()
                .filter_map(|&x| x)
                .min();

            if let Some(i) = i_comment {
                if self.line_buffer[start + i..].starts_with(&['#', '@'][..]) {
                    // Line comment
                    self.line_buffer.truncate(start + i);
                    break;
                }

                // Block comment - find the terminator
                start += i;
                loop {
                    let i_comment_end = self.line_buffer[start..].find("*/");

                    let remove_until = i_comment_end
                        .map(|x| x + start + 2)
                        .unwrap_or(self.line_buffer.len());
                    self.line_buffer.replace_range(start..remove_until, "");

                    if i_comment_end.is_some() {
                        // Found the terminator
                        break;
                    } else {
                        // Keep reading
                        let bytes_read = self.reader.read_line(&mut self.line_buffer)?;
                        if bytes_read == 0 {
                            return Err(Error::SyntaxError {
                                line: self.line_index,
                                message: "found a unterminated block comment".to_owned(),
                            });
                        }
                        self.line_index += 1;

                        // Remove the newline character
                        self.line_buffer.pop();
                    }
                }
            } else {
                break;
            }
        }

        self.line_buffer.push('\n');

        // Parse the current logical line
        match parsing::parse(&self.line_buffer) {
            Ok(Some(x)) => Ok(Some(Item::Statement(x))),
            Ok(None) => Ok(Some(Item::Empty)),
            Err(x) => Err(Error::SyntaxError {
                line: self.line_index,
                message: x,
            }),
        }
    }
}
