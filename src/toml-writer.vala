namespace Toml {
    internal class Writer {
        private WriteOptions options;
        private StringBuilder buf;
        private int emit_depth;
        private Gee.HashSet<Value> active;

        public Writer (WriteOptions? options) {
            this.options = options ?? WriteOptions ();
            this.buf = new StringBuilder ();
        }

        public string emit (Table root) throws WriteError {
            buf = new StringBuilder ();
            emit_depth = 0;
            active = new Gee.HashSet<Value> (
                (Gee.HashDataFunc<Value>) GLib.direct_hash,
                (Gee.EqualDataFunc<Value>) GLib.direct_equal);
            emit_table_body (root, new Gee.ArrayList<Key?> ());
            return buf.str;
        }

        private void enter_container (Value node) throws WriteError {
            if (active.contains (node)) {
                throw new WriteError.FAILED ("cyclic DOM");
            }
            if (emit_depth >= MAX_VALUE_DEPTH) {
                throw new WriteError.FAILED ("maximum nesting depth exceeded");
            }
            active.add (node);
            emit_depth++;
        }

        private void leave_container (Value node) {
            active.remove (node);
            emit_depth--;
        }

        private int resolve_indent (int node_indent) {
            return node_indent >= 0 ? node_indent : options.indent;
        }

        private void append_spaces (int n) {
            for (int i = 0; i < n; i++) {
                buf.append_c (' ');
            }
        }

        private void emit_table_body (Table table, Gee.ArrayList<Key?> path) throws WriteError {
            enter_container (table);
            try {
            var nested = new Gee.ArrayList<Key?> ();
            foreach (var key in table.key_order_list) {
                var value = table.get (key);
                var as_table = value as Table;
                if (as_table != null && !as_table.style.inline) {
                    if (table.style.dotted_keys && is_dotted_eligible (as_table)) {
                        var prefix = new Gee.ArrayList<Key?> ();
                        prefix.add (key);
                        emit_dotted_leaves (prefix, as_table);
                        continue;
                    }
                    nested.add (key);
                    continue;
                }
                var as_array = value as Array;
                if (as_array != null && is_array_of_tables (as_array) && !as_array.style.inline) {
                    nested.add (key);
                    continue;
                }
                emit_key (key);
                buf.append (" = ");
                emit_value (value, 0);
                buf.append_c ('\n');
            }

            foreach (var key in nested) {
                var value = table.get (key);
                var as_table = value as Table;
                if (as_table != null) {
                var child_path = append_path (path, key);
                    emit_table_header (child_path);
                    emit_table_body (as_table, child_path);
                    continue;
                }
                var as_array = value as Array;
                if (as_array != null) {
                    emit_array_of_tables (as_array, append_path (path, key));
                }
            }
            } finally {
                leave_container (table);
            }
        }

        private bool is_dotted_eligible (Table table) throws WriteError {
            enter_container (table);
            try {
                if (table.size == 0) {
                    return false;
                }
                foreach (var key in table.key_order_list) {
                    var value = table.get (key);
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
            } finally {
                leave_container (table);
            }
        }

        private void emit_dotted_leaves (Gee.ArrayList<Key?> prefix, Table table) throws WriteError {
            enter_container (table);
            try {
            foreach (var key in table.key_order_list) {
                var value = table.get (key);
                var child = value as Table;
                if (child != null && !child.style.inline) {
                    emit_dotted_leaves (append_path (prefix, key), child);
                    continue;
                }
                emit_key_path (append_path (prefix, key));
                buf.append (" = ");
                emit_value (value, 0);
                buf.append_c ('\n');
            }
            } finally {
                leave_container (table);
            }
        }

        private void emit_array_of_tables (Array array, Gee.ArrayList<Key?> path) throws WriteError {
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

        private void emit_table_header (Gee.ArrayList<Key?> path) throws WriteError {
            buf.append_c ('[');
            emit_key_path (path);
            buf.append ("]\n");
        }

        private void emit_aot_header (Gee.ArrayList<Key?> path) throws WriteError {
            buf.append ("[[");
            emit_key_path (path);
            buf.append ("]]\n");
        }

        private void emit_key_path (Gee.ArrayList<Key?> path) throws WriteError {
            for (int i = 0; i < path.size; i++) {
                if (i > 0) {
                    buf.append_c ('.');
                }
                emit_key (path[i]);
            }
        }

        private Gee.ArrayList<Key?> append_path (Gee.ArrayList<Key?> path, Key key) {
            var next = new Gee.ArrayList<Key?> ();
            foreach (var p in path) {
                next.add (p);
            }
            next.add (key);
            return next;
        }

        private void require_utf8 (Bytes bytes, string what) throws WriteError {
            if (!bytes_utf8_valid (bytes)) {
                throw new WriteError.FAILED ("invalid UTF-8 in " + what);
            }
        }

        private void emit_key (Key key) throws WriteError {
            require_utf8 (key.bytes, "key");
            unowned uint8[] data = key.bytes.get_data ();
            if (is_bare_key_bytes (data)) {
                buf.append_len ((string) data, data.length);
            } else {
                emit_basic_string_bytes (data);
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
            var s = value as String;
            if (s != null) { require_utf8 (s.bytes, "string"); emit_basic_string_bytes (s.bytes.get_data ()); return; }
            var i = value as Integer;
            if (i != null) { buf.append (i.value.to_string ()); return; }
            var f = value as Float;
            if (f != null) { emit_float (f.value); return; }
            var b = value as Boolean;
            if (b != null) { buf.append (b.value ? "true" : "false"); return; }
            var odt = value as OffsetDateTime;
            if (odt != null) { buf.append (format_offset_datetime (odt.value)); return; }
            var ldt = value as LocalDateTime;
            if (ldt != null) { buf.append (format_local_datetime (ldt)); return; }
            var ld = value as LocalDate;
            if (ld != null) { buf.append (format_local_date (ld.value)); return; }
            var lt = value as LocalTime;
            if (lt != null) { buf.append (format_local_time (lt)); return; }
            var table = value as Table;
            if (table != null) { emit_inline_table (table, base_indent); return; }
            var array = value as Array;
            if (array != null) { emit_inline_array (array, base_indent); return; }
            throw new WriteError.FAILED ("unsupported value type");
        }

        private void validate_inline_table (Table table) throws WriteError {
            foreach (var key in table.key_order_list) {
                var value = table.get (key);
                var arr = value as Array;
                if (arr != null && is_array_of_tables (arr) && !arr.style.inline) {
                    throw new WriteError.FAILED ("inline table cannot contain array-of-tables");
                }
                var child = value as Table;
                if (child != null) {
                    enter_container (child);
                    try {
                        validate_inline_table (child);
                    } finally {
                        leave_container (child);
                    }
                }
            }
        }

        private void emit_inline_table (Table table, int base_indent) throws WriteError {
            enter_container (table);
            try {
            validate_inline_table (table);

            if (!table.style.multiline) {
                buf.append ("{ ");
                bool first = true;
                foreach (var key in table.key_order_list) {
                    if (!first) {
                        buf.append (", ");
                    }
                    first = false;
                    emit_key (key);
                    buf.append (" = ");
                    emit_value (table.get (key), base_indent);
                }
                buf.append (" }");
                return;
            }

            int ind = resolve_indent (table.style.indent);
            buf.append ("{\n");
            bool first_ml = true;
            foreach (var key in table.key_order_list) {
                if (!first_ml) {
                    buf.append (",\n");
                }
                first_ml = false;
                append_spaces (base_indent + ind);
                emit_key (key);
                buf.append (" = ");
                emit_value (table.get (key), base_indent + ind);
            }
            buf.append_c ('\n');
            append_spaces (base_indent);
            buf.append_c ('}');
            } finally {
                leave_container (table);
            }
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
            enter_container (array);
            try {
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
            } finally {
                leave_container (array);
            }
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
