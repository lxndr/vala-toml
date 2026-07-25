namespace Toml {
    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string table_to_tagged_json (Table root) throws WriteError {
        return new TaggedJsonEncoder ().encode (root);
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal Table table_from_tagged_json (string json) throws Error {
        var p = new TaggedJsonParser (json);
        return p.parse_table ();
    }

    private class TaggedJsonEncoder {
        private StringBuilder sb;
        private int json_depth;
        private Gee.HashSet<Value> active;

        public string encode (Table root) throws WriteError {
            sb = new StringBuilder ();
            json_depth = 0;
            active = new Gee.HashSet<Value> (
                (Gee.HashDataFunc<Value>) GLib.direct_hash,
                (Gee.EqualDataFunc<Value>) GLib.direct_equal);
            append_value (root);
            return sb.str;
        }

        private void enter_container (Value node) throws WriteError {
            if (active.contains (node)) {
                throw new WriteError.FAILED ("cyclic DOM");
            }
            if (json_depth >= MAX_VALUE_NESTING) {
                throw new WriteError.FAILED ("maximum nesting depth exceeded");
            }
            active.add (node);
            json_depth++;
        }

        private void leave_container (Value node) {
            active.remove (node);
            json_depth--;
        }

        private void append_value (Value value) throws WriteError {
            switch (value.kind) {
            case ValueKind.TABLE:
                append_table ((Table) value);
                break;
            case ValueKind.ARRAY:
                append_array ((Array) value);
                break;
            default:
                append_scalar (value);
                break;
            }
        }

        private void append_table (Table table) throws WriteError {
            enter_container (table);
            try {
                sb.append_c ('{');
                bool first = true;
                for (int i = 0; i < table.key_bytes_list.size; i++) {
                    if (!first) {
                        sb.append_c (',');
                    }
                    first = false;
                    uint8[] kb = table.key_bytes_list[i].get_data ();
                    append_json_string_bytes (sb, kb);
                    sb.append_c (':');
                    append_value (table.get_bytes (kb));
                }
                sb.append_c ('}');
            } finally {
                leave_container (table);
            }
        }

        private void append_array (Array array) throws WriteError {
            enter_container (array);
            try {
                sb.append_c ('[');
                for (int i = 0; i < array.size; i++) {
                    if (i > 0) {
                        sb.append_c (',');
                    }
                    append_value (array.get (i));
                }
                sb.append_c (']');
            } finally {
                leave_container (array);
            }
        }

        private void append_scalar (Value value) {
            string type_name;
            switch (value.kind) {
            case ValueKind.STRING:
                type_name = "string";
                sb.append ("{\"type\":");
                append_json_string_text (sb, type_name);
                sb.append (",\"value\":");
                append_json_string_bytes (sb, value.get_string_bytes ());
                sb.append_c ('}');
                return;
            case ValueKind.INTEGER:
                type_name = "integer";
                append_tagged (sb, type_name, value.get_integer ().to_string ());
                return;
            case ValueKind.FLOAT:
                type_name = "float";
                append_tagged (sb, type_name, encode_float (value.get_float ()));
                return;
            case ValueKind.BOOLEAN:
                type_name = "bool";
                append_tagged (sb, type_name, value.get_boolean () ? "true" : "false");
                return;
            case ValueKind.OFFSET_DATETIME: {
                type_name = "datetime";
                var dt = value.get_offset_datetime ();
                assert (dt != null);
                append_tagged (sb, type_name, format_offset_datetime (dt));
                return;
            }
            case ValueKind.LOCAL_DATETIME: {
                type_name = "datetime-local";
                var ldt = value.get_local_datetime ();
                assert (ldt != null);
                append_tagged (sb, type_name, format_local_datetime (ldt));
                return;
            }
            case ValueKind.LOCAL_DATE: {
                type_name = "date-local";
                var d = value.get_local_date ();
                assert (d != null);
                append_tagged (sb, type_name, format_local_date (d));
                return;
            }
            case ValueKind.LOCAL_TIME: {
                type_name = "time-local";
                var t = value.get_local_time ();
                assert (t != null);
                append_tagged (sb, type_name, format_local_time (t));
                return;
            }
            default:
                assert_not_reached ();
            }
        }
    }

    private void append_tagged (StringBuilder sb, string type_name, string encoded) {
        sb.append ("{\"type\":");
        append_json_string_text (sb, type_name);
        sb.append (",\"value\":");
        append_json_string_text (sb, encoded);
        sb.append_c ('}');
    }

    private void append_json_string_text (StringBuilder sb, string s) {
        append_json_string_bytes (sb, s.data);
    }

    private void append_json_string_bytes (StringBuilder sb, uint8[]? bytes) {
        sb.append_c ('"');
        if (bytes != null) {
            int i = 0;
            while (i < bytes.length) {
                uint8 b = bytes[i];
                if (b == 0) {
                    sb.append ("\\u0000");
                    i++;
                    continue;
                }
                if (b == '"') {
                    sb.append ("\\\"");
                    i++;
                    continue;
                }
                if (b == '\\') {
                    sb.append ("\\\\");
                    i++;
                    continue;
                }
                if (b == '\b') {
                    sb.append ("\\b");
                    i++;
                    continue;
                }
                if (b == '\f') {
                    sb.append ("\\f");
                    i++;
                    continue;
                }
                if (b == '\n') {
                    sb.append ("\\n");
                    i++;
                    continue;
                }
                if (b == '\r') {
                    sb.append ("\\r");
                    i++;
                    continue;
                }
                if (b == '\t') {
                    sb.append ("\\t");
                    i++;
                    continue;
                }
                if (b < 0x20 || b == 0x7f) {
                    sb.append_printf ("\\u%04x", b);
                    i++;
                    continue;
                }
                if (b < 0x80) {
                    sb.append_c ((char) b);
                    i++;
                    continue;
                }
                // Copy one UTF-8 sequence as-is
                int n = 1;
                if ((b & 0xE0) == 0xC0) {
                    n = 2;
                } else if ((b & 0xF0) == 0xE0) {
                    n = 3;
                } else if ((b & 0xF8) == 0xF0) {
                    n = 4;
                }
                if (i + n > bytes.length) {
                    sb.append_printf ("\\u%04x", b);
                    i++;
                    continue;
                }
                for (int k = 0; k < n; k++) {
                    sb.append_c ((char) bytes[i + k]);
                }
                i += n;
            }
        }
        sb.append_c ('"');
    }

    private string encode_float (double v) {
        if (v != v) {
            return "nan";
        }
        if (v == double.INFINITY) {
            return "inf";
        }
        if (v == -double.INFINITY) {
            return "-inf";
        }
        // Integer-valued floats in the safe range: emit without fraction
        double abs = (v < 0.0) ? -v : v;
        if (abs <= 9007199254740991.0 && v == (double) ((int64) v)) {
            return "%.0f".printf (v);
        }
        // Round-trip precision for IEEE754 binary64
        string s = "%.17g".printf (v);
        if (s.index_of_char ('.') < 0 && s.index_of_char ('e') < 0 && s.index_of_char ('E') < 0) {
            s += ".0";
        }
        return s;
    }

    // Minimal tagged-JSON parser that preserves embedded NUL in strings.
    private class TaggedJsonParser {
        private string input;
        private int pos;
        private int length;
        private int nest_depth;

        public TaggedJsonParser (string input) {
            this.input = input;
            this.length = input.length;
            this.pos = 0;
        }

        public Table parse_table () throws Error {
            skip_ws ();
            var v = parse_value ();
            skip_ws ();
            if (pos < length) {
                throw new ParseError.FAILED ("trailing JSON");
            }
            var table = v as Table;
            if (table == null) {
                throw new ParseError.FAILED ("expected JSON object for table");
            }
            return table;
        }

        private Value parse_value () throws Error {
            skip_ws ();
            if (pos >= length) {
                throw new ParseError.FAILED ("unexpected end of JSON");
            }
            unichar c = peek ();
            if (c == '{' || c == '[') {
                if (nest_depth >= MAX_VALUE_NESTING) {
                    throw new ParseError.FAILED ("maximum nesting depth exceeded");
                }
                nest_depth++;
                try {
                    if (c == '{') {
                        return parse_object ();
                    }
                    return parse_array ();
                } finally {
                    nest_depth--;
                }
            }
            throw new ParseError.FAILED ("unexpected JSON value");
        }

        private Value parse_object () throws Error {
            expect ('{');
            skip_ws ();
            var keys = new Gee.HashMap<string, Value> ();
            var key_bytes = new Gee.HashMap<string, Bytes> ();
            if (peek () == '}') {
                advance ();
                return new Table ();
            }
            while (true) {
                skip_ws ();
                uint8[] kb = parse_string_bytes ();
                string map_key = Table.map_key_from_bytes (kb);
                skip_ws ();
                expect (':');
                skip_ws ();
                Value val;
                if (peek () == '"') {
                    uint8[] bytes = parse_string_bytes ();
                    val = Value.from_string_bytes (bytes);
                } else {
                    val = parse_value ();
                }
                keys[map_key] = val;
                key_bytes[map_key] = new Bytes (kb);
                skip_ws ();
                if (peek () == ',') {
                    advance ();
                    continue;
                }
                break;
            }
            expect ('}');

            string type_mk = Table.map_key_from_bytes ("type".data);
            string value_mk = Table.map_key_from_bytes ("value".data);
            if (keys.size == 2 && keys.has_key (type_mk) && keys.has_key (value_mk)) {
                var type_v = keys[type_mk];
                var value_v = keys[value_mk];
                if (type_v.kind == ValueKind.STRING && value_v.kind == ValueKind.STRING) {
                    return tagged_from (type_v.get_string (), value_v.get_string_bytes ());
                }
            }

            var table = new Table ();
            foreach (var mk in keys.keys) {
                // Nested tables from JSON are value-position / inline
                var child = keys[mk] as Table;
                if (child != null) {
                    child.style.inline = true;
                }
                table.set_bytes (key_bytes[mk].get_data (), keys[mk]);
            }
            return table;
        }

        private Value parse_array () throws Error {
            expect ('[');
            var array = new Array ();
            // JSON-imported arrays are always value-position (inline), never header AoT.
            array.style.inline = true;
            skip_ws ();
            if (peek () == ']') {
                advance ();
                return array;
            }
            while (true) {
                var elem = parse_value ();
                var child_table = elem as Table;
                if (child_table != null) {
                    child_table.style.inline = true;
                }
                array.add (elem);
                skip_ws ();
                if (peek () == ',') {
                    advance ();
                    skip_ws ();
                    continue;
                }
                break;
            }
            expect (']');
            return array;
        }

        private Value tagged_from (string type_name, uint8[]? encoded_bytes) throws Error {
            string encoded = Value.string_from_bytes (encoded_bytes);
            switch (type_name) {
            case "string":
                return Value.from_string_bytes (encoded_bytes ?? new uint8[0]);
            case "integer":
                return Value.from_integer (int64.parse (encoded));
            case "float":
                return Value.from_float (decode_float (encoded));
            case "bool":
                if (encoded == "true") {
                    return Value.from_boolean (true);
                }
                if (encoded == "false") {
                    return Value.from_boolean (false);
                }
                throw new ParseError.FAILED ("invalid bool value: %s".printf (encoded));
            case "datetime":
                try {
                    return Value.from_offset_datetime (parse_offset_datetime (encoded));
                } catch (ValueError e) {
                    throw new ParseError.FAILED (e.message);
                }
            case "datetime-local":
                try {
                    return Value.from_local_datetime (parse_local_datetime (encoded));
                } catch (ValueError e) {
                    throw new ParseError.FAILED (e.message);
                }
            case "date-local":
                try {
                    return Value.from_local_date (parse_local_date (encoded));
                } catch (ValueError e) {
                    throw new ParseError.FAILED (e.message);
                }
            case "time-local":
                try {
                    return Value.from_local_time (parse_local_time (encoded));
                } catch (ValueError e) {
                    throw new ParseError.FAILED (e.message);
                }
            default:
                throw new ParseError.FAILED ("unknown tagged JSON type: %s".printf (type_name));
            }
        }

        private double decode_float (string encoded) throws Error {
            if (encoded == "nan" || encoded == "+nan" || encoded == "-nan") {
                return double.NAN;
            }
            if (encoded == "inf" || encoded == "+inf") {
                return double.INFINITY;
            }
            if (encoded == "-inf") {
                return -double.INFINITY;
            }
            double result;
            if (!double.try_parse (encoded, out result)) {
                throw new ParseError.FAILED ("invalid float value: %s".printf (encoded));
            }
            return result;
        }

        private uint8[] parse_string_bytes () throws Error {
            expect ('"');
            var buf = new StringBuilder ();
            while (pos < length) {
                unichar c = peek ();
                if (c == '"') {
                    advance ();
                    return buf.data[0:buf.len];
                }
                if (c == '\\') {
                    advance ();
                    if (pos >= length) {
                        throw new ParseError.FAILED ("unterminated JSON escape");
                    }
                    unichar e = peek ();
                    advance ();
                    switch (e) {
                    case '"': case '\\': case '/':
                        buf.append_unichar (e);
                        break;
                    case 'b':
                        buf.append_c ('\b');
                        break;
                    case 'f':
                        buf.append_c ('\f');
                        break;
                    case 'n':
                        buf.append_c ('\n');
                        break;
                    case 'r':
                        buf.append_c ('\r');
                        break;
                    case 't':
                        buf.append_c ('\t');
                        break;
                    case 'u':
                        buf.append_unichar (parse_json_unicode ());
                        break;
                    default:
                        throw new ParseError.FAILED ("invalid JSON escape");
                    }
                    continue;
                }
                if (c < 0x20) {
                    throw new ParseError.FAILED ("raw control in JSON string");
                }
                advance ();
                buf.append_unichar (c);
            }
            throw new ParseError.FAILED ("unterminated JSON string");
        }

        private unichar parse_json_unicode () throws Error {
            uint32 code = 0;
            for (int i = 0; i < 4; i++) {
                if (pos >= length) {
                    throw new ParseError.FAILED ("invalid JSON unicode escape");
                }
                unichar h = peek ();
                advance ();
                code <<= 4;
                if (h.isdigit ()) {
                    code |= (uint32) (h - '0');
                } else if (h >= 'a' && h <= 'f') {
                    code |= (uint32) (h - 'a' + 10);
                } else if (h >= 'A' && h <= 'F') {
                    code |= (uint32) (h - 'A' + 10);
                } else {
                    throw new ParseError.FAILED ("invalid JSON unicode escape");
                }
            }
            return (unichar) code;
        }

        private void skip_ws () {
            while (pos < length) {
                unichar c = peek ();
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                    advance ();
                    continue;
                }
                break;
            }
        }

        private void expect (unichar c) throws Error {
            skip_ws ();
            if (pos >= length || peek () != c) {
                throw new ParseError.FAILED ("expected '%s'".printf (c.to_string ()));
            }
            advance ();
        }

        private unichar peek () {
            return input.get_char (pos);
        }

        private void advance () {
            unichar c;
            input.get_next_char (ref pos, out c);
        }
    }
}
