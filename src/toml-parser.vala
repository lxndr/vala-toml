namespace Toml {
    // Cap array/inline-table nesting so untrusted input cannot SIGSEGV via stack overflow.
    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal const int MAX_VALUE_NESTING = 1000;

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal class Parser {
        private Lexer lexer;
        private Token current;
        private Table root;
        private Table current_table;
        private int value_nesting = 0;
        // Tables opened via [header] (final segment of a header path)
        private Gee.HashSet<Table> explicit_tables;
        // Tables created as dotted-key / key-value intermediates (cannot be reopened via [header])
        private Gee.HashSet<Table> dotted_tables;
        // Arrays created via [[header]] (not value arrays)
        private Gee.HashSet<Array> aot_arrays;
        // Inline tables — immutable after creation
        private Gee.HashSet<Table> closed_tables;

        public Parser (string input) throws ParseError {
            lexer = new Lexer (input);
            explicit_tables = new Gee.HashSet<Table> (
                (Gee.HashDataFunc<Table>) GLib.direct_hash,
                (Gee.EqualDataFunc<Table>) GLib.direct_equal);
            dotted_tables = new Gee.HashSet<Table> (
                (Gee.HashDataFunc<Table>) GLib.direct_hash,
                (Gee.EqualDataFunc<Table>) GLib.direct_equal);
            aot_arrays = new Gee.HashSet<Array> (
                (Gee.HashDataFunc<Array>) GLib.direct_hash,
                (Gee.EqualDataFunc<Array>) GLib.direct_equal);
            closed_tables = new Gee.HashSet<Table> (
                (Gee.HashDataFunc<Table>) GLib.direct_hash,
                (Gee.EqualDataFunc<Table>) GLib.direct_equal);
            // Document body starts in key/header position
            advance_key ();
        }

        public Table parse () throws ParseError {
            root = new Table ();
            current_table = root;
            while (current.kind != TokenKind.EOF) {
                if (current.kind == TokenKind.NEWLINE) {
                    advance_key ();
                    continue;
                }
                if (current.kind == TokenKind.DOUBLE_LBRACKET) {
                    parse_array_of_tables_header ();
                } else if (current.kind == TokenKind.LBRACKET) {
                    parse_standard_table_header ();
                } else {
                    parse_key_value (current_table);
                }
                if (current.kind == TokenKind.NEWLINE) {
                    advance_key ();
                } else if (current.kind != TokenKind.EOF) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "expected newline or EOF"));
                }
            }
            return root;
        }

        private void parse_standard_table_header () throws ParseError {
            expect_key (TokenKind.LBRACKET, "expected '['");
            var path = parse_key_path ();
            expect_key (TokenKind.RBRACKET, "expected ']'");
            current_table = define_standard_table (path);
        }

        private void parse_array_of_tables_header () throws ParseError {
            expect_key (TokenKind.DOUBLE_LBRACKET, "expected '[['");
            var path = parse_key_path ();
            expect_key (TokenKind.DOUBLE_RBRACKET, "expected ']]'");
            current_table = define_array_of_tables (path);
        }

        private Table resolve_header_parent (Gee.ArrayList<Bytes> path) throws ParseError {
            Table table = root;
            for (int i = 0; i < path.size - 1; i++) {
                uint8[] key = path[i].get_data ();
                if (!table.has_bytes (key)) {
                    var child = new Table ();
                    table.set_bytes_unchecked (key, child);
                    table = child;
                    continue;
                }
                Value? existing = table.get_bytes (key);
                Table? as_table = existing.as_table ();
                if (as_table != null) {
                    if (closed_tables.contains (as_table)) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "cannot extend inline table"));
                    }
                    table = as_table;
                    continue;
                }
                Array? as_array = existing.as_array ();
                if (as_array != null) {
                    if (!aot_arrays.contains (as_array)) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "cannot extend value array"));
                    }
                    if (as_array.size == 0) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "empty array of tables"));
                    }
                    Table? last = as_array.get (as_array.size - 1).as_table ();
                    if (last == null) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "array of tables element is not a table"));
                    }
                    table = last;
                    continue;
                }
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining key as table"));
            }
            return table;
        }

        private Table define_array_of_tables (Gee.ArrayList<Bytes> path) throws ParseError {
            Table table = resolve_header_parent (path);
            uint8[] final_key = path[path.size - 1].get_data ();
            Array array;
            if (!table.has_bytes (final_key)) {
                array = new Array ();
                table.set_bytes_unchecked (final_key, array);
                aot_arrays.add (array);
            } else {
                Value? existing = table.get_bytes (final_key);
                Array? as_array = existing.as_array ();
                if (as_array == null) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "redefining key as array of tables"));
                }
                if (!aot_arrays.contains (as_array)) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "redefining value array as array of tables"));
                }
                array = as_array;
            }
            var child = new Table ();
            array.add_unchecked (child);
            explicit_tables.add (child);
            return child;
        }

        private Table define_standard_table (Gee.ArrayList<Bytes> path) throws ParseError {
            Table table = resolve_header_parent (path);
            if (closed_tables.contains (table)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "cannot extend inline table"));
            }

            uint8[] final_key = path[path.size - 1].get_data ();
            if (!table.has_bytes (final_key)) {
                var child = new Table ();
                table.set_bytes_unchecked (final_key, child);
                explicit_tables.add (child);
                return child;
            }

            Value? existing = table.get_bytes (final_key);
            Table? as_table = existing.as_table ();
            if (as_table == null) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining key as table"));
            }
            // Dotted-key / kv intermediates cannot be reopened with [header]
            if (dotted_tables.contains (as_table)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining dotted-key table"));
            }
            // TOML 1.1: may open a table previously created as a header-path intermediate
            if (explicit_tables.contains (as_table)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "redefining table"));
            }
            explicit_tables.add (as_table);
            return as_table;
        }

        private void parse_key_value (Table target) throws ParseError {
            var path = parse_key_path ();
            expect_value (TokenKind.EQUALS, "expected '='");
            Value value = parse_value ();
            insert_path (target, path, value);
        }

        private Value parse_value () throws ParseError {
            if (current.kind == TokenKind.LBRACKET || current.kind == TokenKind.LBRACE) {
                if (value_nesting >= MAX_VALUE_NESTING) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "maximum nesting depth exceeded"));
                }
                value_nesting++;
                try {
                    if (current.kind == TokenKind.LBRACKET) {
                        return parse_array ();
                    }
                    return parse_inline_table ();
                } finally {
                    value_nesting--;
                }
            }
            return parse_scalar ();
        }

        private Array parse_array () throws ParseError {
            expect_value (TokenKind.LBRACKET, "expected '['");
            var array = new Array ();
            skip_newlines_value ();
            if (current.kind == TokenKind.RBRACKET) {
                advance_value ();
                return array;
            }
            while (true) {
                skip_newlines_value ();
                array.add_unchecked (parse_value ());
                skip_newlines_value ();
                if (current.kind != TokenKind.COMMA) {
                    break;
                }
                advance_value ();
                skip_newlines_value ();
                if (current.kind == TokenKind.RBRACKET) {
                    break;
                }
            }
            expect_value (TokenKind.RBRACKET, "expected ']'");
            return array;
        }

        private Table parse_inline_table () throws ParseError {
            expect_key (TokenKind.LBRACE, "expected '{'");
            var table = new Table ();
            skip_newlines_key ();
            if (current.kind == TokenKind.RBRACE) {
                advance_value ();
                closed_tables.add (table);
                explicit_tables.add (table);
                return table;
            }
            while (true) {
                skip_newlines_key ();
                parse_key_value (table);
                skip_newlines_key ();
                if (current.kind != TokenKind.COMMA) {
                    break;
                }
                advance_key ();
                skip_newlines_key ();
                if (current.kind == TokenKind.RBRACE) {
                    break;
                }
            }
            expect_value (TokenKind.RBRACE, "expected '}'");
            closed_tables.add (table);
            explicit_tables.add (table);
            return table;
        }

        private void skip_newlines_value () throws ParseError {
            while (current.kind == TokenKind.NEWLINE) {
                advance_value ();
            }
        }

        private void skip_newlines_key () throws ParseError {
            while (current.kind == TokenKind.NEWLINE) {
                advance_key ();
            }
        }

        private Gee.ArrayList<Bytes> parse_key_path () throws ParseError {
            var path = new Gee.ArrayList<Bytes> ();
            path.add (new Bytes (parse_key_segment ()));
            while (current.kind == TokenKind.DOT) {
                advance_key ();
                path.add (new Bytes (parse_key_segment ()));
            }
            return path;
        }

        private uint8[] parse_key_segment () throws ParseError {
            if (current.kind == TokenKind.KEY) {
                uint8[] key = current.text.data;
                advance_key ();
                return key;
            }
            if (current.kind == TokenKind.STRING) {
                uint8[] key = current.bytes ?? current.text.data;
                advance_key ();
                return Value.bytes_copy (key);
            }
            throw new ParseError.FAILED (
                format_parse_error (current.line, current.column, "expected key"));
        }

        private Value parse_scalar () throws ParseError {
            switch (current.kind) {
            case TokenKind.STRING: {
                Value v;
                if (current.bytes != null) {
                    v = Value.from_string_bytes (current.bytes);
                } else {
                    v = Value.from_string (current.text);
                }
                advance_value ();
                return v;
            }
            case TokenKind.INTEGER: {
                var v = Value.from_integer (parse_integer (current.text, current.line, current.column));
                advance_value ();
                return v;
            }
            case TokenKind.FLOAT: {
                var v = Value.from_float (parse_float (current.text, current.line, current.column));
                advance_value ();
                return v;
            }
            case TokenKind.BOOLEAN: {
                var v = Value.from_boolean (current.text == "true");
                advance_value ();
                return v;
            }
            case TokenKind.OFFSET_DATETIME: {
                DateTime dt = parse_offset_datetime (current.text);
                Value v;
                try {
                    v = Value.from_offset_datetime (dt);
                } catch (ValueError e) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, e.message));
                }
                advance_value ();
                return v;
            }
            case TokenKind.LOCAL_DATETIME: {
                LocalDateTime ldt = parse_local_datetime (current.text);
                Value v;
                try {
                    v = Value.from_local_datetime (ldt);
                } catch (ValueError e) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, e.message));
                }
                advance_value ();
                return v;
            }
            case TokenKind.LOCAL_DATE: {
                Date d = parse_local_date (current.text);
                Value v;
                try {
                    v = Value.from_local_date (d);
                } catch (ValueError e) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, e.message));
                }
                advance_value ();
                return v;
            }
            case TokenKind.LOCAL_TIME: {
                LocalTime t = parse_local_time (current.text);
                Value v;
                try {
                    v = Value.from_local_time (t);
                } catch (ValueError e) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, e.message));
                }
                advance_value ();
                return v;
            }
            default:
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "expected value"));
            }
        }

        private void insert_path (Table target, Gee.ArrayList<Bytes> path, Value value) throws ParseError {
            Table table = target;
            for (int i = 0; i < path.size - 1; i++) {
                uint8[] key = path[i].get_data ();
                if (!table.has_bytes (key)) {
                    if (table != target && explicit_tables.contains (table)) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "cannot extend explicit table with dotted key"));
                    }
                    if (closed_tables.contains (table)) {
                        throw new ParseError.FAILED (
                            format_parse_error (current.line, current.column, "cannot extend inline table"));
                    }
                    var child = new Table ();
                    table.set_bytes_unchecked (key, child);
                    dotted_tables.add (child);
                    table = child;
                    continue;
                }
                Value? existing = table.get_bytes (key);
                Table? as_table = existing.as_table ();
                if (as_table == null) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "duplicate key"));
                }
                if (closed_tables.contains (as_table)) {
                    throw new ParseError.FAILED (
                        format_parse_error (current.line, current.column, "cannot extend inline table"));
                }
                // Using an existing table as a dotted-key intermediate marks it dotted
                // (unless it was already opened explicitly via [header]).
                if (!explicit_tables.contains (as_table)) {
                    dotted_tables.add (as_table);
                }
                table = as_table;
            }

            // Cannot add keys into an explicit/closed table via dotted keys from outside it
            if (table != target && (explicit_tables.contains (table) || closed_tables.contains (table))) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "cannot extend explicit table with dotted key"));
            }

            uint8[] final_key = path[path.size - 1].get_data ();
            if (table.has_bytes (final_key)) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, "duplicate key"));
            }
            table.set_bytes_unchecked (final_key, value);
        }

        private void expect_key (TokenKind kind, string message) throws ParseError {
            if (current.kind != kind) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, message));
            }
            advance_key ();
        }

        private void expect_value (TokenKind kind, string message) throws ParseError {
            if (current.kind != kind) {
                throw new ParseError.FAILED (
                    format_parse_error (current.line, current.column, message));
            }
            advance_value ();
        }

        private void advance_key () throws ParseError {
            lexer.key_mode = true;
            current = lexer.next ();
        }

        private void advance_value () throws ParseError {
            lexer.key_mode = false;
            current = lexer.next ();
        }

        private static int64 parse_integer (string text, int line, int column) throws ParseError {
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
                if (p == 'x') {
                    base_ = 16;
                    body = body.substring (2);
                } else if (p == 'o') {
                    base_ = 8;
                    body = body.substring (2);
                } else if (p == 'b') {
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

        private static double parse_float (string text, int line, int column) throws ParseError {
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
