namespace Toml {
    public class Table : Value {
        public TableStyle style { get; set; }

        private Gee.HashMap<string, Value> entries;
        private Gee.ArrayList<Bytes> key_bytes_order;

        public Table () {
            Object ();
            kind = ValueKind.TABLE;
            style = new TableStyle ();
            entries = new Gee.HashMap<string, Value> ();
            key_bytes_order = new Gee.ArrayList<Bytes> ();
        }

        public int size {
            get { return key_bytes_order.size; }
        }

        public Gee.List<string> keys {
            owned get {
                var list = new Gee.ArrayList<string> ();
                foreach (var kb in key_bytes_order) {
                    list.add (Value.string_from_bytes (kb.get_data ()));
                }
                return list;
            }
        }

        internal Gee.List<Bytes> key_bytes_list {
            get { return key_bytes_order; }
        }

        public new void set (string key, Value value) {
            set_bytes (key.data, value);
        }

        public void set_bytes (uint8[] key_bytes, Value value) {
            string map_key = map_key_from_bytes (key_bytes);
            if (!entries.has_key (map_key)) {
                key_bytes_order.add (new Bytes (Value.bytes_copy (key_bytes)));
            }
            entries[map_key] = value;
        }

        public new Value? get (string key) {
            return entries[map_key_from_bytes (key.data)];
        }

        public Value? get_bytes (uint8[] key_bytes) {
            return entries[map_key_from_bytes (key_bytes)];
        }

        public bool unset (string key) {
            string map_key = map_key_from_bytes (key.data);
            if (!entries.unset (map_key)) {
                return false;
            }
            for (int i = 0; i < key_bytes_order.size; i++) {
                if (map_key_from_bytes (key_bytes_order[i].get_data ()) == map_key) {
                    key_bytes_order.remove_at (i);
                    break;
                }
            }
            return true;
        }

        public bool has (string key) {
            return entries.has_key (map_key_from_bytes (key.data));
        }

        public bool has_bytes (uint8[] key_bytes) {
            return entries.has_key (map_key_from_bytes (key_bytes));
        }

        public override Table? as_table () {
            return this;
        }

        internal static string map_key_from_bytes (uint8[] bytes) {
            var hex = new StringBuilder ();
            for (int i = 0; i < bytes.length; i++) {
                hex.append_printf ("%02x", bytes[i]);
            }
            return hex.str;
        }
    }
}
