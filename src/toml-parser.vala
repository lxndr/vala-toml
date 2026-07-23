namespace Toml {
    // public for v1: same package may expose via .vapi; parse_string is the API
    internal class Parser : Object {
        Lexer lexer;
        Token current;

        public Parser (string input) throws ParseError {
            lexer = new Lexer (input);
            current = lexer.next ();
        }

        public Table parse () throws ParseError {
            var root = new Table ();
            while (current.kind != TokenKind.EOF) {
                if (current.kind == TokenKind.NEWLINE) {
                    advance ();
                    continue;
                }
                parse_key_value (root);
                if (current.kind == TokenKind.NEWLINE) {
                    advance ();
                } else if (current.kind != TokenKind.EOF) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "expected newline or EOF"));
                }
            }
            return root;
        }

        void parse_key_value (Table root) throws ParseError {
            var path = parse_key_path ();
            expect (TokenKind.EQUALS, "expected '='");
            Value value = parse_scalar ();
            insert_path (root, path, value);
        }

        Gee.ArrayList<string> parse_key_path () throws ParseError {
            var path = new Gee.ArrayList<string> ();
            path.add (parse_key_segment ());
            while (current.kind == TokenKind.DOT) {
                advance ();
                path.add (parse_key_segment ());
            }
            return path;
        }

        string parse_key_segment () throws ParseError {
            if (current.kind == TokenKind.KEY || current.kind == TokenKind.STRING) {
                string key = current.text;
                advance ();
                return key;
            }
            // bare true/false/inf/nan may appear as KEY-like identifiers lexed as keywords
            if (current.kind == TokenKind.BOOLEAN || current.kind == TokenKind.FLOAT
                || current.kind == TokenKind.INTEGER) {
                // INTEGER cannot be a bare key; BOOLEAN/FLOAT (inf/nan) are valid bare keys in TOML
                if (current.kind == TokenKind.INTEGER) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "expected key"));
                }
                string key = current.text;
                advance ();
                return key;
            }
            throw new ParseError.FAILED (
                format_parse_error (current.line, current.column, "expected key"));
        }

        Value parse_scalar () throws ParseError {
            switch (current.kind) {
            case TokenKind.STRING: {
                var v = Value.from_string (current.text);
                advance ();
                return v;
            }
            case TokenKind.INTEGER: {
                var v = Value.from_integer (parse_integer (current.text, current.line, current.column));
                advance ();
                return v;
            }
            case TokenKind.FLOAT: {
                var v = Value.from_float (parse_float (current.text, current.line, current.column));
                advance ();
                return v;
            }
            case TokenKind.BOOLEAN: {
                var v = Value.from_boolean (current.text == "true");
                advance ();
                return v;
            }
            case TokenKind.DATETIME: {
                var v = Value.from_datetime (current.text);
                advance ();
                return v;
            }
            case TokenKind.DATETIME_LOCAL: {
                var v = Value.from_datetime_local (current.text);
                advance ();
                return v;
            }
            case TokenKind.DATE_LOCAL: {
                var v = Value.from_date_local (current.text);
                advance ();
                return v;
            }
            case TokenKind.TIME_LOCAL: {
                var v = Value.from_time_local (current.text);
                advance ();
                return v;
            }
            default:
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "expected value"));
            }
        }

        void insert_path (Table root, Gee.ArrayList<string> path, Value value) throws ParseError {
            Table table = root;
            for (int i = 0; i < path.size - 1; i++) {
                string key = path[i];
                if (!table.has (key)) {
                    var child = new Table ();
                    table.set (key, child);
                    table = child;
                    continue;
                }
                Value? existing = table.get (key);
                Table? as_table = existing.as_table ();
                if (as_table == null) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "duplicate key"));
                }
                table = as_table;
            }

            string final_key = path[path.size - 1];
            if (table.has (final_key)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "duplicate key"));
            }
            table.set (final_key, value);
        }

        void expect (TokenKind kind, string message) throws ParseError {
            if (current.kind != kind) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, message));
            }
            advance ();
        }

        void advance () throws ParseError {
            current = lexer.next ();
        }

        static int64 parse_integer (string text, int line, int column) throws ParseError {
            string cleaned = text.replace ("_", "");
            int base_ = 10;
            string body = cleaned;
            bool negative = false;

            if (body.has_prefix ("+") || body.has_prefix ("-")) {
                negative = body.has_prefix ("-");
                body = body.substring (1);
            }

            if (body.length >= 2 && body[0] == '0') {
                unichar p = body.get_char (1);
                if (p == 'x' || p == 'X') {
                    base_ = 16;
                    body = body.substring (2);
                } else if (p == 'o' || p == 'O') {
                    base_ = 8;
                    body = body.substring (2);
                } else if (p == 'b' || p == 'B') {
                    base_ = 2;
                    body = body.substring (2);
                }
            }

            uint64 u;
            if (!uint64.try_parse (body, out u, null, base_)) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid integer"));
            }
            if (negative) {
                if (u > (uint64) int64.MAX + 1) {
                    throw new ParseError.FAILED (
                        format_parse_error (line, column, "integer out of range"));
                }
                if (u == (uint64) int64.MAX + 1) {
                    return int64.MIN;
                }
                return -((int64) u);
            }
            if (u > (uint64) int64.MAX) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "integer out of range"));
            }
            return (int64) u;
        }

        static double parse_float (string text, int line, int column) throws ParseError {
            string cleaned = text.replace ("_", "");
            if (cleaned == "inf" || cleaned == "+inf") {
                return double.INFINITY;
            }
            if (cleaned == "-inf") {
                return -double.INFINITY;
            }
            if (cleaned == "nan" || cleaned == "+nan" || cleaned == "-nan") {
                return double.NAN;
            }
            double v;
            if (!double.try_parse (cleaned, out v)) {
                throw new ParseError.FAILED (
                    format_parse_error (line, column, "invalid float"));
            }
            return v;
        }
    }
}
