namespace Toml {
    // public for v1: tests link via generated .vapi, which omits `internal` types
    public class Lexer {
        private string input;
        private int pos;
        private int line;
        private int column;
        private int length;
        public bool key_mode;

        public Lexer (string input) {
            this.input = input;
            this.length = input.length;
            this.pos = 0;
            this.line = 1;
            this.column = 1;
            this.key_mode = false;
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
                // Bare CR is not a valid newline; only CRLF is accepted.
                if (pos + 1 >= length || input.get_char (pos + 1) != '\n') {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "bare carriage return"));
                }
                advance ();
                advance ();
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
                // Only combine [[ in key/header mode so nested value arrays keep single brackets.
                if (key_mode && pos < length && peek () == '[') {
                    advance ();
                    return new Token (TokenKind.DOUBLE_LBRACKET, "[[", start_line, start_column);
                }
                return new Token (TokenKind.LBRACKET, "[", start_line, start_column);
            }
            if (c == ']') {
                advance ();
                if (key_mode && pos < length && peek () == ']') {
                    advance ();
                    return new Token (TokenKind.DOUBLE_RBRACKET, "]]", start_line, start_column);
                }
                return new Token (TokenKind.RBRACKET, "]", start_line, start_column);
            }

            if (c == '"' || c == '\'') {
                return scan_string (start_line, start_column);
            }

            // In key mode, digits / '-' / '_' start bare keys (e.g. 10e3, 34-11, -key).
            if (key_mode && is_bare_key_char (c)) {
                return scan_bare_key (start_line, start_column);
            }

            if (c == '+' || c == '-' || c.isdigit ()) {
                return scan_number_or_datetime (start_line, start_column);
            }

            if (is_bare_key_start (c)) {
                return scan_ident_or_keyword (start_line, start_column);
            }

            if (is_bare_control (c)) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid control character"));
            }

            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unexpected character"));
        }

        private void skip_whitespace_and_comments () throws ParseError {
            while (pos < length) {
                unichar c = peek ();
                if (c == ' ' || c == '\t') {
                    advance ();
                    continue;
                }
                if (c == '#') {
                    advance ();
                    while (pos < length && peek () != '\n' && peek () != '\r') {
                        unichar cc = peek ();
                        if (is_bare_control (cc)) {
                            throw new ParseError.FAILED (
                                format_parse_error (line, column, "invalid control character in comment"));
                        }
                        advance ();
                    }
                    continue;
                }
                break;
            }
        }

        private static bool is_bare_control (unichar c) {
            if (c == '\t' || c == '\n' || c == '\r') {
                return false;
            }
            return c <= 0x1F || c == 0x7F;
        }

        private Token scan_string (int start_line, int start_column) throws ParseError {
            unichar quote = peek ();
            bool triple = (pos + 2 < length
                && input.get_char (pos + 1) == quote
                && input.get_char (pos + 2) == quote);

            if (triple) {
                if (key_mode) {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "multiline key"));
                }
                advance ();
                advance ();
                advance ();
                // Trim newline immediately after opening delimiter
                if (pos < length && (peek () == '\n' || peek () == '\r')) {
                    consume_newline ();
                }
                if (quote == '"') {
                    return scan_multiline_basic_string (start_line, start_column);
                }
                return scan_multiline_literal_string (start_line, start_column);
            }

            advance (); // opening quote
            if (quote == '"') {
                return scan_basic_string (start_line, start_column);
            }
            return scan_literal_string (start_line, start_column);
        }

        private Token token_from_builder (StringBuilder buf, int start_line, int start_column) {
            uint8[] bytes = buf.data[0:buf.len];
            return new Token.with_bytes (TokenKind.STRING, bytes, start_line, start_column);
        }

        private Token scan_bare_key (int start_line, int start_column) {
            int start = pos;
            while (pos < length && is_bare_key_char (peek ())) {
                advance ();
            }
            string text = input.substring (start, pos - start);
            return new Token (TokenKind.KEY, text, start_line, start_column);
        }

        private Token scan_basic_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '"') {
                    advance ();
                    return token_from_builder (buf, start_line, start_column);
                }
                if (c == '\n' || c == '\r') {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "newline in basic string"));
                }
                if (c == '\\') {
                    advance ();
                    buf.append_unichar (scan_escape (start_line, start_column));
                    continue;
                }
                if (is_disallowed_control (c, false)) {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "invalid control character in string"));
                }
                advance ();
                buf.append_unichar (c);
            }
            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unterminated string"));
        }

        private Token scan_literal_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '\'') {
                    advance ();
                    return token_from_builder (buf, start_line, start_column);
                }
                if (c == '\n' || c == '\r') {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "newline in literal string"));
                }
                if (is_disallowed_control (c, false)) {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "invalid control character in string"));
                }
                advance ();
                buf.append_unichar (c);
            }
            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unterminated string"));
        }

        private Token scan_multiline_basic_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '"') {
                    int count = count_quotes ('"');
                    if (count >= 3) {
                        // 3–5 consecutive quotes: (count-3) content quotes + closing """
                        if (count > 5) {
                            throw new ParseError.FAILED (
                                format_parse_error (line, column, "too many quotes in multiline string"));
                        }
                        for (int i = 0; i < count - 3; i++) {
                            buf.append_c ('"');
                        }
                        for (int i = 0; i < count; i++) {
                            advance ();
                        }
                        return token_from_builder (buf, start_line, start_column);
                    }
                    // 1 or 2 quotes as content
                    for (int i = 0; i < count; i++) {
                        advance ();
                        buf.append_c ('"');
                    }
                    continue;
                }
                if (c == '\\') {
                    advance ();
                    // Line-ending backslash: \ ws* newline (ws|newline)*
                    if (is_line_ending_backslash ()) {
                        skip_escaped_newline ();
                        continue;
                    }
                    buf.append_unichar (scan_escape (start_line, start_column));
                    continue;
                }
                if (c == '\n' || c == '\r') {
                    consume_newline ();
                    buf.append_c ('\n');
                    continue;
                }
                if (is_disallowed_control (c, true)) {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "invalid control character in string"));
                }
                advance ();
                buf.append_unichar (c);
            }
            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unterminated string"));
        }

        private Token scan_multiline_literal_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '\'') {
                    int count = count_quotes ('\'');
                    if (count >= 3) {
                        if (count > 5) {
                            throw new ParseError.FAILED (
                                format_parse_error (line, column, "too many quotes in multiline string"));
                        }
                        for (int i = 0; i < count - 3; i++) {
                            buf.append_c ('\'');
                        }
                        for (int i = 0; i < count; i++) {
                            advance ();
                        }
                        return token_from_builder (buf, start_line, start_column);
                    }
                    for (int i = 0; i < count; i++) {
                        advance ();
                        buf.append_c ('\'');
                    }
                    continue;
                }
                if (c == '\n' || c == '\r') {
                    consume_newline ();
                    buf.append_c ('\n');
                    continue;
                }
                if (is_disallowed_control (c, true)) {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "invalid control character in string"));
                }
                advance ();
                buf.append_unichar (c);
            }
            throw new ParseError.FAILED (
                format_parse_error (start_line, start_column, "unterminated string"));
        }

        private int count_quotes (unichar quote) {
            int count = 0;
            int i = pos;
            while (i < length && input.get_char (i) == quote) {
                count++;
                i += (int) quote.to_utf8 (null);
            }
            return count;
        }

        private bool is_line_ending_backslash () {
            // After consuming '\', check if remaining is ws* newline
            int i = pos;
            while (i < length) {
                unichar c = input.get_char (i);
                if (c == ' ' || c == '\t') {
                    i += (int) c.to_utf8 (null);
                    continue;
                }
                return c == '\n' || c == '\r';
            }
            return false;
        }

        private void skip_escaped_newline () throws ParseError {
            // Skip ws before newline
            while (pos < length && (peek () == ' ' || peek () == '\t')) {
                advance ();
            }
            if (pos >= length || (peek () != '\n' && peek () != '\r')) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid line-ending backslash"));
            }
            consume_newline ();
            // Skip ws and further newlines
            while (pos < length) {
                unichar c = peek ();
                if (c == ' ' || c == '\t') {
                    advance ();
                    continue;
                }
                if (c == '\n' || c == '\r') {
                    consume_newline ();
                    continue;
                }
                break;
            }
        }

        private void consume_newline () throws ParseError {
            if (pos >= length) {
                return;
            }
            if (peek () == '\r') {
                advance ();
                if (pos >= length || peek () != '\n') {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "bare carriage return"));
                }
                advance ();
            } else if (peek () == '\n') {
                advance ();
            }
        }

        private unichar scan_escape (int start_line, int start_column) throws ParseError {
            if (pos >= length) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "unterminated escape"));
            }
            unichar c = peek ();
            advance ();
            switch (c) {
            case 'b':
                return '\b';
            case 't':
                return '\t';
            case 'n':
                return '\n';
            case 'f':
                return '\f';
            case 'r':
                return '\r';
            case 'e':
                return 0x1B;
            case '"':
                return '"';
            case '\\':
                return '\\';
            case 'x':
                return scan_unicode_escape (2, start_line, start_column);
            case 'u':
                return scan_unicode_escape (4, start_line, start_column);
            case 'U':
                return scan_unicode_escape (8, start_line, start_column);
            default:
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid escape sequence"));
            }
        }

        private unichar scan_unicode_escape (int digits, int start_line, int start_column) throws ParseError {
            uint32 code = 0;
            for (int i = 0; i < digits; i++) {
                if (pos >= length || !is_hex_digit (peek ())) {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "invalid unicode escape"));
                }
                unichar h = peek ();
                advance ();
                code <<= 4;
                if (h.isdigit ()) {
                    code |= (uint32) (h - '0');
                } else if (h >= 'a' && h <= 'f') {
                    code |= (uint32) (h - 'a' + 10);
                } else {
                    code |= (uint32) (h - 'A' + 10);
                }
            }
            // Must be a Unicode scalar value (not surrogate)
            if (code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid unicode scalar value"));
            }
            return (unichar) code;
        }

        private static bool is_disallowed_control (unichar c, bool multiline) {
            // Tab always allowed. Multiline also allows LF/CR (handled separately as newlines).
            if (c == '\t') {
                return false;
            }
            if (multiline && (c == '\n' || c == '\r')) {
                return false;
            }
            // U+0000..U+0008, U+000A..U+001F, U+007F
            if (c <= 0x08) {
                return true;
            }
            if (c >= 0x0A && c <= 0x1F) {
                return true;
            }
            if (c == 0x7F) {
                return true;
            }
            return false;
        }

        private Token scan_ident_or_keyword (int start_line, int start_column) {
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

        private Token scan_number_or_datetime (int start_line, int start_column) throws ParseError {
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

            // 0x / 0o / 0b (unsigned only; lowercase prefix required)
            if (!signed && peek () == '0' && pos + 1 < length) {
                unichar kind = input.get_char (pos + 1);
                if (kind == 'x') {
                    return scan_prefixed_integer (start, start_line, start_column, is_hex_digit);
                }
                if (kind == 'o') {
                    return scan_prefixed_integer (start, start_line, start_column, is_oct_digit);
                }
                if (kind == 'b') {
                    return scan_prefixed_integer (start, start_line, start_column, is_bin_digit);
                }
                if (kind == 'X' || kind == 'O' || kind == 'B') {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "capitalized integer prefix"));
                }
            }

            int int_start = pos;
            if (!scan_decimal_digits ()) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid number"));
            }
            // Reject trailing underscore left unconsumed by digit scanner
            if (pos < length && peek () == '_') {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "trailing underscore in number"));
            }
            string int_digits = input.substring (int_start, pos - int_start).replace ("_", "");

            // Prefer TOML 1.1 datetime productions over integers when the shape matches
            if (!signed) {
                Token? dt = try_scan_datetime (start, start_line, start_column);
                if (dt != null) {
                    return dt;
                }
            }

            if (pos < length && (peek () == '-' || peek () == ':')) {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "invalid number"));
            }

            bool is_float = false;

            if (pos < length && peek () == '.'
                && pos + 1 < length && input.get_char (pos + 1).isdigit ()) {
                advance ();
                if (!scan_decimal_digits ()) {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "invalid float"));
                }
                if (pos < length && peek () == '_') {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "trailing underscore in number"));
                }
                is_float = true;
            }

            if (pos < length && (peek () == 'e' || peek () == 'E') && has_valid_exponent ()) {
                advance (); // e/E
                if (peek () == '+' || peek () == '-') {
                    advance ();
                }
                if (!scan_decimal_digits ()) {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "invalid float"));
                }
                if (pos < length && peek () == '_') {
                    throw new ParseError.FAILED (
                        format_parse_error (start_line, start_column, "trailing underscore in number"));
                }
                is_float = true;
            }

            // Leading zeros forbidden except for a single 0 before . / e
            if (int_digits.length > 1 && int_digits[0] == '0') {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "leading zero"));
            }

            string text = input.substring (start, pos - start);
            if (is_float) {
                return new Token (TokenKind.FLOAT, text, start_line, start_column);
            }
            return new Token (TokenKind.INTEGER, text, start_line, start_column);
        }

        // Try TOML 1.1 date/time from `start` (current pos is after the leading digit run).
        // Returns null if the digit run is not a datetime shape (caller continues as number).
        private Token? try_scan_datetime (int start, int start_line, int start_column) throws ParseError {
            string leading = input.substring (start, pos - start);
            if (leading.contains ("_")) {
                return null;
            }

            int saved = pos;

            // Local time: HH:MM[:SS[.frac]]
            if (pos < length && peek () == ':') {
                if (leading.length != 2) {
                    return null;
                }
                pos = start;
                int hour = 0;
                int minute = 0;
                int second = 0;
                if (!scan_partial_time (out hour, out minute, out second)) {
                    pos = saved;
                    return null;
                }
                validate_time_parts (hour, minute, second, start_line, start_column);
                string text = input.substring (start, pos - start);
                return new Token (TokenKind.TIME_LOCAL, text, start_line, start_column);
            }

            // Date: YYYY-MM-DD [time [offset]]
            if (pos < length && peek () == '-') {
                if (leading.length != 4) {
                    return null;
                }
                pos = start;
                int year = 0;
                int month = 0;
                int day = 0;
                if (!scan_full_date (out year, out month, out day)) {
                    pos = saved;
                    return null;
                }
                validate_date_parts (year, month, day, start_line, start_column);

                // Optional date/time separator + partial-time
                if (pos < length && is_date_time_separator (peek ())) {
                    int after_date = pos;
                    unichar sep = peek ();
                    advance ();
                    int hour = 0;
                    int minute = 0;
                    int second = 0;
                    if (scan_partial_time (out hour, out minute, out second)) {
                        validate_time_parts (hour, minute, second, start_line, start_column);
                        int oh = 0;
                        int om = 0;
                        bool has_off = scan_time_offset (start_line, start_column, out oh, out om);
                        if (has_off) {
                            if (oh > 23 || om > 59) {
                                throw new ParseError.FAILED (
                                    format_parse_error (start_line, start_column, "invalid datetime offset"));
                            }
                            string text = input.substring (start, pos - start);
                            return new Token (TokenKind.DATETIME, text, start_line, start_column);
                        }
                        string text = input.substring (start, pos - start);
                        return new Token (TokenKind.DATETIME_LOCAL, text, start_line, start_column);
                    }
                    // Separator was not followed by a valid time (e.g. space before comment)
                    pos = after_date;
                    // Space is ordinary whitespace; T/t would be an invalid continuation
                    if (sep == 'T' || sep == 't') {
                        pos = saved;
                        return null;
                    }
                }

                string text = input.substring (start, pos - start);
                return new Token (TokenKind.DATE_LOCAL, text, start_line, start_column);
            }

            return null;
        }

        private void validate_date_parts (int year, int month, int day, int line, int column) throws ParseError {
            if (month < 1 || month > 12 || day < 1 || day > days_in_month (year, month)) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid date"));
            }
        }

        private void validate_time_parts (int hour, int minute, int second, int line, int column) throws ParseError {
            if (hour > 23 || minute > 59 || second > 59) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid time"));
            }
        }

        private static int days_in_month (int year, int month) {
            switch (month) {
            case 1: case 3: case 5: case 7: case 8: case 10: case 12:
                return 31;
            case 4: case 6: case 9: case 11:
                return 30;
            case 2:
                if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
                    return 29;
                }
                return 28;
            default:
                return 0;
            }
        }

        private static bool is_date_time_separator (unichar c) {
            return c == 'T' || c == 't' || c == ' ';
        }

        private bool scan_full_date (out int year, out int month, out int day) {
            year = 0;
            month = 0;
            day = 0;
            // YYYY-MM-DD
            int y0 = pos;
            if (!consume_n_digits (4)) {
                return false;
            }
            year = int.parse (input.substring (y0, 4));
            if (pos >= length || peek () != '-') {
                return false;
            }
            advance ();
            int m0 = pos;
            if (!consume_n_digits (2)) {
                return false;
            }
            month = int.parse (input.substring (m0, 2));
            if (pos >= length || peek () != '-') {
                return false;
            }
            advance ();
            int d0 = pos;
            if (!consume_n_digits (2)) {
                return false;
            }
            day = int.parse (input.substring (d0, 2));
            return true;
        }

        private bool scan_partial_time (out int hour, out int minute, out int second) {
            hour = 0;
            minute = 0;
            second = 0;
            // HH:MM[:SS[.frac]]  (seconds optional in TOML 1.1)
            int h0 = pos;
            if (!consume_n_digits (2)) {
                return false;
            }
            hour = int.parse (input.substring (h0, 2));
            if (pos >= length || peek () != ':') {
                return false;
            }
            advance ();
            int m0 = pos;
            if (!consume_n_digits (2)) {
                return false;
            }
            minute = int.parse (input.substring (m0, 2));
            if (pos < length && peek () == ':') {
                advance ();
                int s0 = pos;
                if (!consume_n_digits (2)) {
                    return false;
                }
                second = int.parse (input.substring (s0, 2));
                if (pos < length && peek () == '.') {
                    advance ();
                    if (pos >= length || !peek ().isdigit ()) {
                        return false;
                    }
                    while (pos < length && peek ().isdigit ()) {
                        advance ();
                    }
                }
            }
            return true;
        }

        // Returns true if a complete offset was scanned, false if none present.
        // If +/− is seen, a full ±HH:MM is required — incomplete offsets throw.
        private bool scan_time_offset (int start_line, int start_column, out int oh, out int om) throws ParseError {
            oh = 0;
            om = 0;
            // Z / z / (+|-)HH:MM
            if (pos >= length) {
                return false;
            }
            unichar c = peek ();
            if (c == 'Z' || c == 'z') {
                advance ();
                return true;
            }
            if (c != '+' && c != '-') {
                return false;
            }
            int after_time = pos;
            advance ();
            int h0 = pos;
            if (!consume_n_digits (2)) {
                pos = after_time;
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "incomplete datetime offset"));
            }
            oh = int.parse (input.substring (h0, 2));
            if (pos >= length || peek () != ':') {
                pos = after_time;
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "incomplete datetime offset"));
            }
            advance ();
            int m0 = pos;
            if (!consume_n_digits (2)) {
                pos = after_time;
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "incomplete datetime offset"));
            }
            om = int.parse (input.substring (m0, 2));
            return true;
        }

        private bool consume_n_digits (int n) {
            for (int i = 0; i < n; i++) {
                if (pos >= length || !peek ().isdigit ()) {
                    return false;
                }
                advance ();
            }
            return true;
        }

        private bool has_valid_exponent () {
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

        private delegate bool DigitPred (unichar c);

        private Token scan_prefixed_integer (int start, int start_line, int start_column, DigitPred is_digit) throws ParseError {
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
            if (pos < length && peek () == '_') {
                throw new ParseError.FAILED (
                    format_parse_error (start_line, start_column, "trailing underscore in number"));
            }
            string text = input.substring (start, pos - start);
            return new Token (TokenKind.INTEGER, text, start_line, start_column);
        }

        private bool scan_decimal_digits () {
            return scan_digits_with_underscores ((c) => c.isdigit ());
        }

        private bool scan_digits_with_underscores (DigitPred is_digit) {
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

        private unichar peek () {
            return input.get_char (pos);
        }

        private void advance () {
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

        private static bool is_bare_key_start (unichar c) {
            // Bare keys are ASCII only: A-Za-z_
            return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_' || c == '-';
        }

        private static bool is_bare_key_char (unichar c) {
            return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
                || c.isdigit () || c == '_' || c == '-';
        }

        private static bool is_hex_digit (unichar c) {
            return c.isdigit ()
                || (c >= 'a' && c <= 'f')
                || (c >= 'A' && c <= 'F');
        }

        private static bool is_oct_digit (unichar c) {
            return c >= '0' && c <= '7';
        }

        private static bool is_bin_digit (unichar c) {
            return c == '0' || c == '1';
        }
    }
}
