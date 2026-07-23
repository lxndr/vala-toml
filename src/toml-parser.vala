namespace Toml {
    // public for v1: same package may expose via .vapi; parse_string is the API
    internal class Parser : Object {
        Lexer lexer;
        Token current;
        Table root;
        Table current_table;
        // Tables opened via [header] (not merely created as dotted-key intermediates)
        Gee.HashSet<Table> explicit_tables;

        public Parser (string input) throws ParseError {
            lexer = new Lexer (input);
            current = lexer.next ();
            explicit_tables = new Gee.HashSet<Table> (
                (Gee.HashDataFunc<Table>) GLib.direct_hash,
                (Gee.EqualDataFunc<Table>) GLib.direct_equal);
        }

        public Table parse () throws ParseError {
            root = new Table ();
            current_table = root;
            while (current.kind != TokenKind.EOF) {
                if (current.kind == TokenKind.NEWLINE) {
                    advance ();
                    continue;
                }
                if (current.kind == TokenKind.LBRACKET) {
                    parse_standard_table_header ();
                } else {
                    parse_key_value (current_table);
                }
                if (current.kind == TokenKind.NEWLINE) {
                    advance ();
                } else if (current.kind != TokenKind.EOF) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "expected newline or EOF"));
                }
            }
            return root;
        }

        void parse_standard_table_header () throws ParseError {
            expect (TokenKind.LBRACKET, "expected '['");
            var path = parse_key_path ();
            expect (TokenKind.RBRACKET, "expected ']'");
            current_table = define_standard_table (path);
        }

        Table define_standard_table (Gee.ArrayList<string> path) throws ParseError {
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
                        format_parse_error (current.line, current.column, "redefining key as table"));
                }
                table = as_table;
            }

            string final_key = path[path.size - 1];
            if (!table.has (final_key)) {
                var child = new Table ();
                table.set (final_key, child);
                explicit_tables.add (child);
                return child;
            }

            Value? existing = table.get (final_key);
            Table? as_table = existing.as_table ();
            if (as_table == null) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining key as table"));
            }
            // TOML 1.1: may open a table previously created as an implicit intermediate
            if (explicit_tables.contains (as_table)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining table"));
            }
            explicit_tables.add (as_table);
            return as_table;
        }

        void parse_key_value (Table target) throws ParseError {
            var path = parse_key_path ();
            expect (TokenKind.EQUALS, "expected '='");
            Value value = parse_scalar ();
            insert_path (target, path, value);
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
            // Lexer may emit BOOLEAN/FLOAT/INTEGER/DATE_LOCAL for bare-key-shaped text
            // (true, inf, 123, 1979-05-27). Accept when text is a valid bare key [A-Za-z0-9_-]+.
            if ((current.kind == TokenKind.BOOLEAN || current.kind == TokenKind.FLOAT
                 || current.kind == TokenKind.INTEGER || current.kind == TokenKind.DATE_LOCAL)
                && is_bare_key_text (current.text)) {
                string key = current.text;
                advance ();
                return key;
            }
            throw new ParseError.FAILED (
                format_parse_error (current.line, current.column, "expected key"));
        }

        static bool is_bare_key_text (string text) {
            if (text.length == 0) {
                return false;
            }
            for (int i = 0; i < text.length; ) {
                unichar c;
                if (!text.get_next_char (ref i, out c)) {
                    return false;
                }
                if (!(c.isalpha () || c.isdigit () || c == '_' || c == '-')) {
                    return false;
                }
            }
            return true;
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

        void insert_path (Table target, Gee.ArrayList<string> path, Value value) throws ParseError {
            Table table = target;
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
