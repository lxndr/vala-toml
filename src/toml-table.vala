namespace Toml {
    /**
     * A TOML table (key/value map) with write-style hints.
     */
    public class Table : Value {
        /** Emission style for this table. */
        public TableStyle style;

        private Gee.HashMap<string, Value> entries;
        private Gee.ArrayList<Bytes> key_bytes_order;

        /** Create an empty table. */
        public Table () {
            kind = ValueKind.TABLE;
            style = TableStyle ();
            entries = new Gee.HashMap<string, Value> ();
            key_bytes_order = new Gee.ArrayList<Bytes> ();
        }

        /** Number of keys. */
        public int size {
            get { return key_bytes_order.size; }
        }

        /** Keys in insertion order (decoded as strings). */
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

        /** Set a key from a Vala string. */
        public new void set (string key, Value value) {
            set_bytes (key.data, value);
        }

        /** Set a key from raw key bytes. */
        public void set_bytes (uint8[] key_bytes, Value value) {
            string map_key = map_key_from_bytes (key_bytes);
            if (!entries.has_key (map_key)) {
                key_bytes_order.add (new Bytes (Value.bytes_copy (key_bytes)));
            }
            entries[map_key] = value;
        }

        /** Get a value by string key, or null. */
        public new Value? get (string key) {
            return entries[map_key_from_bytes (key.data)];
        }

        /** Get a value by raw key bytes, or null. */
        public Value? get_bytes (uint8[] key_bytes) {
            return entries[map_key_from_bytes (key_bytes)];
        }

        /**
         * Remove a key.
         *
         * @return true if the key existed
         */
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

        /** Whether a string key exists. */
        public bool has (string key) {
            return entries.has_key (map_key_from_bytes (key.data));
        }

        /** Whether a raw-bytes key exists. */
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
