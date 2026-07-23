namespace Toml {
    // public for v1: tests link via generated .vapi, which omits `internal` types
    public class Lexer : Object {
        string input;
        int pos;
        int line;
        int column;
        int length;

        public Lexer (string input) {
            this.input = input;
            this.length = input.length;
            this.pos = 0;
            this.line = 1;
            this.column = 1;
        }

        public Token next () throws ParseError {
            skip_whitespace_and_comments ();
            if (pos >= length) {
                return new Token (TokenKind.EOF, "", line, column);
            }

            int start_line = line;
            int start_column = column;
            unichar c = peek ();

            if (c == '\n') {
                advance ();
                return new Token (TokenKind.NEWLINE, "\n", start_line, start_column);
            }
            if (c == '\r') {
                advance ();
                if (pos < length && peek () == '\n') {
                    advance ();
                }
                return new Token (TokenKind.NEWLINE, "\n", start_line, start_column);
            }

            if (c == '=') {
                advance ();
                return new Token (TokenKind.EQUALS, "=", start_line, start_column);
            }
            if (c == '.') {
                advance ();
                return new Token (TokenKind.DOT, ".", start_line, start_column);
            }
            if (c == ',') {
                advance ();
                return new Token (TokenKind.COMMA, ",", start_line, start_column);
            }
            if (c == '{') {
                advance ();
                return new Token (TokenKind.LBRACE, "{", start_line, start_column);
            }
            if (c == '}') {
                advance ();
                return new Token (TokenKind.RBRACE, "}", start_line, start_column);
            }
            if (c == '[') {
                advance ();
                if (pos < length && peek () == '[') {
                    advance ();
                    return new Token (TokenKind.DOUBLE_LBRACKET, "[[", start_line, start_column);
                }
                return new Token (TokenKind.LBRACKET, "[", start_line, start_column);
            }
            if (c == ']') {
                advance ();
                if (pos < length && peek () == ']') {
                    advance ();
                    return new Token (TokenKind.DOUBLE_RBRACKET, "]]", start_line, start_column);
                }
                return new Token (TokenKind.RBRACKET, "]", start_line, start_column);
            }

            if (c == '"' || c == '\'') {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "quoted strings are not supported yet"));
            }

            if (c == '+' || c == '-' || c.isdigit ()) {
                return scan_number_or_datetime (start_line, start_column);
            }

            if (is_bare_key_start (c)) {
                return scan_ident_or_keyword (start_line, start_column);
            }

            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unexpected character"));
        }

        void skip_whitespace_and_comments () {
            while (pos < length) {
                unichar c = peek ();
                if (c == ' ' || c == '\t') {
                    advance ();
                    continue;
                }
                if (c == '#') {
                    while (pos < length && peek () != '\n' && peek () != '\r') {
                        advance ();
                    }
                    continue;
                }
                break;
            }
        }

        Token scan_ident_or_keyword (int start_line, int start_column) {
            int start = pos;
            while (pos < length && is_bare_key_char (peek ())) {
                advance ();
            }
            string text = input.substring (start, pos - start);

            if (text == "true" || text == "false") {
                return new Token (TokenKind.BOOLEAN, text, start_line, start_column);
            }
            if (text == "inf" || text == "nan") {
                return new Token (TokenKind.FLOAT, text, start_line, start_column);
            }
            return new Token (TokenKind.KEY, text, start_line, start_column);
        }

        Token scan_number_or_datetime (int start_line, int start_column) throws ParseError {
            int start = pos;
            unichar first = peek ();
            bool signed = (first == '+' || first == '-');
            if (signed) {
                advance ();
            }

            if (pos >= length) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid number"));
            }

            // +/-inf, +/-nan
            if (is_bare_key_start (peek ())) {
                while (pos < length && is_bare_key_char (peek ())) {
                    advance ();
                }
                string text = input.substring (start, pos - start);
                string body = signed ? text.substring (1) : text;
                if (body == "inf" || body == "nan") {
                    return new Token (TokenKind.FLOAT, text, start_line, start_column);
                }
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid number"));
            }

            // 0x / 0o / 0b (unsigned only)
            if (!signed && peek () == '0' && pos + 1 < length) {
                unichar kind = input.get_char (pos + 1);
                if (kind == 'x' || kind == 'X') {
                    return scan_prefixed_integer (start, start_line, start_column, is_hex_digit);
                }
                if (kind == 'o' || kind == 'O') {
                    return scan_prefixed_integer (start, start_line, start_column, is_oct_digit);
                }
                if (kind == 'b' || kind == 'B') {
                    return scan_prefixed_integer (start, start_line, start_column, is_bin_digit);
                }
            }

            if (!scan_decimal_digits ()) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid number"));
            }

            // Datetime-shaped tokens deferred to a later task
            if (pos < length && (peek () == '-' || peek () == ':')) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "datetimes are not supported yet"));
            }

            bool is_float = false;

            if (pos < length && peek () == '.'
                && pos + 1 < length && input.get_char (pos + 1).isdigit ()) {
                advance ();
                if (!scan_decimal_digits ()) {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "invalid float"));
                }
                is_float = true;
            }

            if (pos < length && (peek () == 'e' || peek () == 'E') && has_valid_exponent ()) {
                advance (); // e/E
                if (peek () == '+' || peek () == '-') {
                    advance ();
                }
                scan_decimal_digits ();
                is_float = true;
            }

            string text = input.substring (start, pos - start);
            if (is_float) {
                return new Token (TokenKind.FLOAT, text, start_line, start_column);
            }
            return new Token (TokenKind.INTEGER, text, start_line, start_column);
        }

        bool has_valid_exponent () {
            int i = pos + 1; // after e/E
            if (i >= length) {
                return false;
            }
            unichar c = input.get_char (i);
            if (c == '+' || c == '-') {
                i += (int) c.to_utf8 (null);
                if (i >= length) {
                    return false;
                }
                c = input.get_char (i);
            }
            return c.isdigit ();
        }

        delegate bool DigitPred (unichar c);

        Token scan_prefixed_integer (int start, int start_line, int start_column, DigitPred is_digit) throws ParseError {
            advance (); // '0'
            advance (); // x/o/b
            if (pos >= length || !is_digit (peek ())) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid integer"));
            }
            if (!scan_digits_with_underscores (is_digit)) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid integer"));
            }
            string text = input.substring (start, pos - start);
            return new Token (TokenKind.INTEGER, text, start_line, start_column);
        }

        bool scan_decimal_digits () {
            return scan_digits_with_underscores ((c) => c.isdigit ());
        }

        bool scan_digits_with_underscores (DigitPred is_digit) {
            if (pos >= length || !is_digit (peek ())) {
                return false;
            }
            advance ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '_') {
                    if (pos + 1 >= length || !is_digit (input.get_char (pos + 1))) {
                        break;
                    }
                    advance ();
                    advance ();
                    continue;
                }
                if (is_digit (c)) {
                    advance ();
                    continue;
                }
                break;
            }
            return true;
        }

        unichar peek () {
            return input.get_char (pos);
        }

        void advance () {
            if (pos >= length) {
                return;
            }
            unichar c;
            input.get_next_char (ref pos, out c);
            if (c == '\n') {
                line++;
                column = 1;
            } else {
                column++;
            }
        }

        static bool is_bare_key_start (unichar c) {
            return c.isalpha () || c == '_' || c == '-';
        }

        static bool is_bare_key_char (unichar c) {
            return c.isalpha () || c.isdigit () || c == '_' || c == '-';
        }

        static bool is_hex_digit (unichar c) {
            return c.isdigit ()
                || (c >= 'a' && c <= 'f')
                || (c >= 'A' && c <= 'F');
        }

        static bool is_oct_digit (unichar c) {
            return c >= '0' && c <= '7';
        }

        static bool is_bin_digit (unichar c) {
            return c == '0' || c == '1';
        }
    }
}
