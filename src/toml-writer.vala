namespace Toml {
    internal class Writer {
        private WriteOptions options;
        private StringBuilder buf;

        public Writer (WriteOptions? options) {
            this.options = options ?? WriteOptions ();
            this.buf = new StringBuilder ();
        }

        public string emit (Table root) throws WriteError {
            buf = new StringBuilder ();
            emit_table_body (root, new Gee.ArrayList<Bytes> ());
            return buf.str;
        }

        private int resolve_indent (int node_indent) {
            return node_indent >= 0 ? node_indent : options.indent;
        }

        private void append_spaces (int n) {
            for (int i = 0; i < n; i++) {
                buf.append_c (' ');
            }
        }

        private void emit_table_body (Table table, Gee.ArrayList<Bytes> path) throws WriteError {
            var nested = new Gee.ArrayList<Bytes> ();
            for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                Bytes key_b = table.key_bytes_list[ki];
                uint8[] key = key_b.get_data ();
                var value = table.get_bytes (key);
                var as_table = value as Table;
                if (as_table != null && !as_table.style.inline) {
                    if (table.style.dotted_keys && is_dotted_eligible (as_table)) {
                        var prefix = new Gee.ArrayList<Bytes> ();
                        prefix.add (key_b);
                        emit_dotted_leaves (prefix, as_table);
                        continue;
                    }
                    nested.add (key_b);
                    continue;
                }
                var as_array = value as Array;
                if (as_array != null && is_array_of_tables (as_array) && !as_array.style.inline) {
                    nested.add (key_b);
                    continue;
                }
                emit_key_bytes (key);
                buf.append (" = ");
                emit_value (value, 0);
                buf.append_c ('\n');
            }

            foreach (var key_b in nested) {
                uint8[] key = key_b.get_data ();
                var value = table.get_bytes (key);
                var as_table = value as Table;
                if (as_table != null) {
                    var child_path = append_path (path, key_b);
                    emit_table_header (child_path);
                    emit_table_body (as_table, child_path);
                    continue;
                }
                var as_array = value as Array;
                if (as_array != null) {
                    emit_array_of_tables (as_array, append_path (path, key_b));
                }
            }
        }

        private bool is_dotted_eligible (Table table) {
            if (table.size == 0) {
                return false;
            }
            for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                Bytes key_b = table.key_bytes_list[ki];
                uint8[] key = key_b.get_data ();
                var value = table.get_bytes (key);
                var child = value as Table;
                if (child != null && !child.style.inline) {
                    if (!is_dotted_eligible (child)) {
                        return false;
                    }
                    continue;
                }
                var arr = value as Array;
                if (arr != null && is_array_of_tables (arr) && !arr.style.inline) {
                    return false;
                }
            }
            return true;
        }

        private void emit_dotted_leaves (Gee.ArrayList<Bytes> prefix, Table table) throws WriteError {
            for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                Bytes key_b = table.key_bytes_list[ki];
                uint8[] key = key_b.get_data ();
                var value = table.get_bytes (key);
                var child = value as Table;
                if (child != null && !child.style.inline) {
                    emit_dotted_leaves (append_path (prefix, key_b), child);
                    continue;
                }
                emit_key_path (append_path (prefix, key_b));
                buf.append (" = ");
                emit_value (value, 0);
                buf.append_c ('\n');
            }
        }

        private void emit_array_of_tables (Array array, Gee.ArrayList<Bytes> path) throws WriteError {
            for (int i = 0; i < array.size; i++) {
                var elem = array.get (i) as Table;
                if (elem == null) {
                    throw new WriteError.FAILED ("array-of-tables element is not a table");
                }
                emit_aot_header (path);
                emit_table_body (elem, path);
            }
        }

        private bool is_array_of_tables (Array array) {
            if (array.size == 0) {
                return false;
            }
            for (int i = 0; i < array.size; i++) {
                if (!(array.get (i) is Table)) {
                    return false;
                }
            }
            return true;
        }

        private void emit_table_header (Gee.ArrayList<Bytes> path) {
            buf.append_c ('[');
            emit_key_path (path);
            buf.append ("]\n");
        }

        private void emit_aot_header (Gee.ArrayList<Bytes> path) {
            buf.append ("[[");
            emit_key_path (path);
            buf.append ("]]\n");
        }

        private void emit_key_path (Gee.ArrayList<Bytes> path) {
            for (int i = 0; i < path.size; i++) {
                if (i > 0) {
                    buf.append_c ('.');
                }
                emit_key_bytes (path[i].get_data ());
            }
        }

        private Gee.ArrayList<Bytes> append_path (Gee.ArrayList<Bytes> path, Bytes key) {
            var next = new Gee.ArrayList<Bytes> ();
            foreach (var p in path) {
                next.add (p);
            }
            next.add (key);
            return next;
        }

        private void emit_key_bytes (uint8[] key) {
            if (is_bare_key_bytes (key)) {
                buf.append_len ((string) key, key.length);
            } else {
                emit_basic_string_bytes (key);
            }
        }

        private bool is_bare_key_bytes (uint8[] key) {
            if (key.length == 0) {
                return false;
            }
            for (int i = 0; i < key.length; i++) {
                uint8 c = key[i];
                if (!((c >= 'A' && c <= 'Z') ||
                      (c >= 'a' && c <= 'z') ||
                      (c >= '0' && c <= '9') ||
                      c == '_' || c == '-')) {
                    return false;
                }
            }
            return true;
        }

        private void emit_value (Value value, int base_indent) throws WriteError {
            switch (value.kind) {
            case ValueKind.STRING:
                emit_basic_string_bytes (value.get_string_bytes ());
                break;
            case ValueKind.INTEGER:
                buf.append (value.get_integer ().to_string ());
                break;
            case ValueKind.FLOAT:
                emit_float (value.get_float ());
                break;
            case ValueKind.BOOLEAN:
                buf.append (value.get_boolean () ? "true" : "false");
                break;
            case ValueKind.OFFSET_DATETIME: {
                var dt = value.get_offset_datetime ();
                assert (dt != null);
                buf.append (format_offset_datetime (dt));
                break;
            }
            case ValueKind.LOCAL_DATETIME: {
                var ldt = value.get_local_datetime ();
                assert (ldt != null);
                buf.append (format_local_datetime (ldt));
                break;
            }
            case ValueKind.LOCAL_DATE: {
                var d = value.get_local_date ();
                assert (d != null);
                buf.append (format_local_date (d));
                break;
            }
            case ValueKind.LOCAL_TIME: {
                var t = value.get_local_time ();
                assert (t != null);
                buf.append (format_local_time (t));
                break;
            }
            case ValueKind.TABLE:
                emit_inline_table ((Table) value, base_indent);
                break;
            case ValueKind.ARRAY:
                emit_inline_array ((Array) value, base_indent);
                break;
            default:
                throw new WriteError.FAILED ("unsupported value kind");
            }
        }

        private void validate_inline_table (Table table) throws WriteError {
            for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                Bytes key_b = table.key_bytes_list[ki];
                uint8[] key = key_b.get_data ();
                var value = table.get_bytes (key);
                var arr = value as Array;
                if (arr != null && is_array_of_tables (arr) && !arr.style.inline) {
                    throw new WriteError.FAILED ("inline table cannot contain array-of-tables");
                }
                var child = value as Table;
                if (child != null) {
                    validate_inline_table (child);
                }
            }
        }

        private void emit_inline_table (Table table, int base_indent) throws WriteError {
            validate_inline_table (table);

            if (!table.style.multiline) {
                buf.append ("{ ");
                bool first = true;
                for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                    uint8[] key = table.key_bytes_list[ki].get_data ();
                    if (!first) {
                        buf.append (", ");
                    }
                    first = false;
                    emit_key_bytes (key);
                    buf.append (" = ");
                    emit_value (table.get_bytes (key), base_indent);
                }
                buf.append (" }");
                return;
            }

            int ind = resolve_indent (table.style.indent);
            buf.append ("{\n");
            bool first_ml = true;
            for (int ki = 0; ki < table.key_bytes_list.size; ki++) {
                uint8[] key = table.key_bytes_list[ki].get_data ();
                if (!first_ml) {
                    buf.append (",\n");
                }
                first_ml = false;
                append_spaces (base_indent + ind);
                emit_key_bytes (key);
                buf.append (" = ");
                emit_value (table.get_bytes (key), base_indent + ind);
            }
            buf.append_c ('\n');
            append_spaces (base_indent);
            buf.append_c ('}');
        }

        private bool array_has_table_element (Array array) {
            for (int i = 0; i < array.size; i++) {
                if (array.get (i) is Table) {
                    return true;
                }
            }
            return false;
        }

        private void emit_inline_array (Array array, int base_indent) throws WriteError {
            // Nested non-inline AoT inside a value-position array is illegal.
            if (is_array_of_tables (array) && !array.style.inline) {
                throw new WriteError.FAILED ("array-of-tables cannot be emitted in value position without inline style");
            }

            if (array.style.multiline) {
                int ind = resolve_indent (array.style.indent);
                buf.append ("[\n");
                for (int i = 0; i < array.size; i++) {
                    if (i > 0) {
                        buf.append (",\n");
                    }
                    append_spaces (base_indent + ind);
                    emit_value (array.get (i), base_indent + ind);
                }
                buf.append_c ('\n');
                append_spaces (base_indent);
                buf.append_c (']');
                return;
            }

            bool spaced = array_has_table_element (array);
            buf.append_c ('[');
            if (spaced && array.size > 0) {
                buf.append_c (' ');
            }
            for (int i = 0; i < array.size; i++) {
                if (i > 0) {
                    buf.append (", ");
                }
                emit_value (array.get (i), base_indent);
            }
            if (spaced && array.size > 0) {
                buf.append_c (' ');
            }
            buf.append_c (']');
        }

        private void emit_float (double v) {
            if (v != v) {
                buf.append ("nan");
                return;
            }
            if (v == double.INFINITY) {
                buf.append ("inf");
                return;
            }
            if (v == -double.INFINITY) {
                buf.append ("-inf");
                return;
            }
            double abs = (v < 0.0) ? -v : v;
            if (abs <= 9007199254740991.0 && v == (double) ((int64) v)) {
                buf.append ("%.0f".printf (v));
                buf.append (".0");
                return;
            }
            // Round-trip precision for IEEE754 binary64
            string s = "%.17g".printf (v);
            if (s.index_of_char ('.') < 0 && s.index_of_char ('e') < 0 && s.index_of_char ('E') < 0) {
                s += ".0";
            }
            buf.append (s);
        }

        private void emit_basic_string_bytes (uint8[]? bytes) {
            buf.append_c ('"');
            if (bytes != null) {
                int i = 0;
                while (i < bytes.length) {
                    unichar c;
                    int n = utf8_next (bytes, i, out c);
                    if (n <= 0) {
                        buf.append_printf ("\\u%04x", bytes[i]);
                        i++;
                        continue;
                    }
                    i += n;
                    switch (c) {
                    case '"':
                        buf.append ("\\\"");
                        break;
                    case '\\':
                        buf.append ("\\\\");
                        break;
                    case '\b':
                        buf.append ("\\b");
                        break;
                    case '\f':
                        buf.append ("\\f");
                        break;
                    case '\n':
                        buf.append ("\\n");
                        break;
                    case '\r':
                        buf.append ("\\r");
                        break;
                    case '\t':
                        buf.append ("\\t");
                        break;
                    case 0:
                        buf.append ("\\u0000");
                        break;
                    default:
                        if (c < 0x20 || c == 0x7f) {
                            buf.append_printf ("\\u%04x", c);
                        } else {
                            buf.append_unichar (c);
                        }
                        break;
                    }
                }
            }
            buf.append_c ('"');
        }

        private static int utf8_next (uint8[] bytes, int i, out unichar c) {
            c = 0;
            if (i >= bytes.length) {
                return 0;
            }
            uint8 b0 = bytes[i];
            if (b0 < 0x80) {
                c = b0;
                return 1;
            }
            if ((b0 & 0xE0) == 0xC0 && i + 1 < bytes.length) {
                c = ((unichar) (b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
                return 2;
            }
            if ((b0 & 0xF0) == 0xE0 && i + 2 < bytes.length) {
                c = ((unichar) (b0 & 0x0F) << 12)
                    | ((unichar) (bytes[i + 1] & 0x3F) << 6)
                    | (bytes[i + 2] & 0x3F);
                return 3;
            }
            if ((b0 & 0xF8) == 0xF0 && i + 3 < bytes.length) {
                c = ((unichar) (b0 & 0x07) << 18)
                    | ((unichar) (bytes[i + 1] & 0x3F) << 12)
                    | ((unichar) (bytes[i + 2] & 0x3F) << 6)
                    | (bytes[i + 3] & 0x3F);
                return 4;
            }
            return -1;
        }
    }
}
