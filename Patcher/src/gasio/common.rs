pub mod parsing {
    fn is_symbol_char(x: char) -> bool {
        x.is_alphanumeric() || x == '.' || x == '_' || x == '$'
    }

    fn is_ws_but_newline(x: char) -> bool {
        x.is_whitespace() && x != '\n'
    }

    named!(pub ws_but_newline<&str, &str>, take_while!(is_ws_but_newline));

    named!(pub symbol_no_ws<&str, &str>, take_while1!(is_symbol_char));

    named!(pub symbol<&str, &str>, sep!(ws_but_newline, symbol_no_ws));
}
