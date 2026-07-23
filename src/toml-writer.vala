namespace Toml {
    internal class Writer {
        private WriteOptions options;
        private StringBuilder buf;

        public Writer (WriteOptions? options) {
            this.options = options ?? new WriteOptions ();
            this.buf = new StringBuilder ();
        }

        public string emit (Table root) throws WriteError {
            buf = new StringBuilder ();
            emit_table_body (root, new string[0]);
            return buf.str;
        }

        void emit_table_body (Table table, string[] path) throws WriteError {
            // Key/values first (scalars, arrays, inline tables), then nested standard tables.
            var nested = new Gee.ArrayList<string> ();

            foreach (var key in table.keys) {
                var value = table.get (key);
                var as_table = value as Table;
                if (as_table != null && !as_table.style.inline) {
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
                emit_value (value);
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
        }

        void emit_array_of_tables (Array array, string[] path) throws WriteError {
            for (int i = 0; i < array.size; i++) {
                var elem = array.get (i) as Table;
                if (elem == null) {
                    throw new WriteError.FAILED ("array-of-tables element is not a table");
                }
                emit_aot_header (path);
                emit_table_body (elem, path);
            }
        }

        bool is_array_of_tables (Array array) {
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

        void emit_table_header (string[] path) {
            buf.append_c ('[');
            emit_key_path (path);
            buf.append ("]\n");
        }

        void emit_aot_header (string[] path) {
            buf.append ("[[");
            emit_key_path (path);
            buf.append ("]]\n");
        }

        void emit_key_path (string[] path) {
            for (int i = 0; i < path.length; i++) {
                if (i > 0) {
                    buf.append_c ('.');
                }
                emit_key (path[i]);
            }
        }

        string[] append_path (string[] path, string key) {
            var next = new string[path.length + 1];
            for (int i = 0; i < path.length; i++) {
                next[i] = path[i];
            }
            next[path.length] = key;
            return next;
        }

        void emit_key (string key) {
            if (is_bare_key (key)) {
                buf.append (key);
            } else {
                emit_basic_string (key);
            }
        }

        bool is_bare_key (string key) {
            if (key.length == 0) {
                return false;
            }
            for (int i = 0; i < key.length; i++) {
                unichar c = key.get_char (i);
                if (!((c >= 'A' && c <= 'Z') ||
                      (c >= 'a' && c <= 'z') ||
                      (c >= '0' && c <= '9') ||
                      c == '_' || c == '-')) {
                    return false;
                }
            }
            return true;
        }

        void emit_value (Value value) throws WriteError {
            switch (value.kind) {
            case ValueKind.STRING:
                emit_basic_string (value.get_string ());
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
            case ValueKind.DATETIME:
            case ValueKind.DATETIME_LOCAL:
            case ValueKind.DATE_LOCAL:
            case ValueKind.TIME_LOCAL:
                buf.append (value.get_raw ());
                break;
            case ValueKind.TABLE:
                emit_inline_table ((Table) value);
                break;
            case ValueKind.ARRAY:
                emit_inline_array ((Array) value);
                break;
            default:
                throw new WriteError.FAILED ("unsupported value kind");
            }
        }

        void emit_inline_table (Table table) throws WriteError {
            buf.append ("{ ");
            bool first = true;
            foreach (var key in table.keys) {
                if (!first) {
                    buf.append (", ");
                }
                first = false;
                emit_key (key);
                buf.append (" = ");
                emit_value (table.get (key));
            }
            buf.append (" }");
        }

        void emit_inline_array (Array array) throws WriteError {
            buf.append_c ('[');
            for (int i = 0; i < array.size; i++) {
                if (i > 0) {
                    buf.append (", ");
                }
                emit_value (array.get (i));
            }
            buf.append_c (']');
        }

        void emit_float (double v) {
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
            // Ensure a decimal point for TOML floats (integers need ".0").
            string s = "%.15g".printf (v);
            if (s.index_of_char ('.') < 0 && s.index_of_char ('e') < 0 && s.index_of_char ('E') < 0) {
                s += ".0";
            }
            buf.append (s);
        }

        void emit_basic_string (string s) {
            buf.append_c ('"');
            int i = 0;
            unichar c;
            while (s.get_next_char (ref i, out c)) {
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
                default:
                    if (c < 0x20 || c == 0x7f) {
                        buf.append_printf ("\\u%04x", c);
                    } else {
                        buf.append_unichar (c);
                    }
                    break;
                }
            }
            buf.append_c ('"');
        }
    }
}
