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
                return scan_string (start_line, start_column);
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

        Token scan_string (int start_line, int start_column) throws ParseError {
            unichar quote = peek ();
            bool triple = (pos + 2 < length
                && input.get_char (pos + 1) == quote
                && input.get_char (pos + 2) == quote);

            if (triple) {
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

        Token scan_basic_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '"') {
                    advance ();
                    return new Token (TokenKind.STRING, buf.str, start_line, start_column);
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

        Token scan_literal_string (int start_line, int start_column) throws ParseError {
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '\'') {
                    advance ();
                    return new Token (TokenKind.STRING, buf.str, start_line, start_column);
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

        Token scan_multiline_basic_string (int start_line, int start_column) throws ParseError {
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
                        return new Token (TokenKind.STRING, buf.str, start_line, start_column);
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

        Token scan_multiline_literal_string (int start_line, int start_column) throws ParseError {
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
                        return new Token (TokenKind.STRING, buf.str, start_line, start_column);
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

        int count_quotes (unichar quote) {
            int count = 0;
            int i = pos;
            while (i < length && input.get_char (i) == quote) {
                count++;
                i += (int) quote.to_utf8 (null);
            }
            return count;
        }

        bool is_line_ending_backslash () {
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

        void skip_escaped_newline () throws ParseError {
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

        void consume_newline () {
            if (pos >= length) {
                return;
            }
            if (peek () == '\r') {
                advance ();
                if (pos < length && peek () == '\n') {
                    advance ();
                }
            } else if (peek () == '\n') {
                advance ();
            }
        }

        unichar scan_escape (int start_line, int start_column) throws ParseError {
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

        unichar scan_unicode_escape (int digits, int start_line, int start_column) throws ParseError {
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

        static bool is_disallowed_control (unichar c, bool multiline) {
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

        // Try TOML 1.1 date/time from `start` (current pos is after the leading digit run).
        // Returns null if the digit run is not a datetime shape (caller continues as number).
        Token? try_scan_datetime (int start, int start_line, int start_column) {
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
                if (!scan_partial_time ()) {
                    pos = saved;
                    return null;
                }
                string text = input.substring (start, pos - start);
                return new Token (TokenKind.TIME_LOCAL, text, start_line, start_column);
            }

            // Date: YYYY-MM-DD [time [offset]]
            if (pos < length && peek () == '-') {
                if (leading.length != 4) {
                    return null;
                }
                pos = start;
                if (!scan_full_date ()) {
                    pos = saved;
                    return null;
                }

                // Optional date/time separator + partial-time
                if (pos < length && is_date_time_separator (peek ())) {
                    int after_date = pos;
                    unichar sep = peek ();
                    advance ();
                    if (scan_partial_time ()) {
                        if (scan_time_offset ()) {
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

        static bool is_date_time_separator (unichar c) {
            return c == 'T' || c == 't' || c == ' ';
        }

        bool scan_full_date () {
            // YYYY-MM-DD
            if (!consume_n_digits (4)) {
                return false;
            }
            if (pos >= length || peek () != '-') {
                return false;
            }
            advance ();
            if (!consume_n_digits (2)) {
                return false;
            }
            if (pos >= length || peek () != '-') {
                return false;
            }
            advance ();
            return consume_n_digits (2);
        }

        bool scan_partial_time () {
            // HH:MM[:SS[.frac]]  (seconds optional in TOML 1.1)
            if (!consume_n_digits (2)) {
                return false;
            }
            if (pos >= length || peek () != ':') {
                return false;
            }
            advance ();
            if (!consume_n_digits (2)) {
                return false;
            }
            if (pos < length && peek () == ':') {
                advance ();
                if (!consume_n_digits (2)) {
                    return false;
                }
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

        bool scan_time_offset () {
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
            advance ();
            if (!consume_n_digits (2)) {
                return false;
            }
            if (pos >= length || peek () != ':') {
                return false;
            }
            advance ();
            return consume_n_digits (2);
        }

        bool consume_n_digits (int n) {
            for (int i = 0; i < n; i++) {
                if (pos >= length || !peek ().isdigit ()) {
                    return false;
                }
                advance ();
            }
            return true;
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
