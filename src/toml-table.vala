namespace Toml {
    internal void drain_container_tree (Value root) {
        var hold = new Gee.ArrayList<Value> ();
        var queue = new Gee.ArrayList<Value> ();
        var seen = new Gee.HashSet<unowned Value> (
            (Gee.HashDataFunc<unowned Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<unowned Value>) GLib.direct_equal);
        seen.add (root);
        unowned Table? root_table = root as Table;
        if (root_table != null) {
            foreach (var key_bytes in root_table.key_bytes_list) {
                Value? child = root_table.get_bytes (key_bytes.get_data ());
                if (child is Table || child is Array) {
                    queue.add (child);
                }
            }
        } else {
            unowned Array? root_array = root as Array;
            if (root_array != null) {
                for (int i = 0; i < root_array.size; i++) {
                    Value child = root_array.get (i);
                    if (child is Table || child is Array) {
                        queue.add (child);
                    }
                }
            }
        }
        while (queue.size > 0) {
            var cur = queue.remove_at (0);
            if (!seen.add (cur)) {
                continue;
            }
            hold.add (cur);
            var table = cur as Table;
            if (table != null) {
                foreach (var key_bytes in table.key_bytes_list) {
                    Value? child = table.get_bytes (key_bytes.get_data ());
                    if (child is Table || child is Array) {
                        queue.add (child);
                    }
                }
                continue;
            }
            var array = cur as Array;
            if (array != null) {
                for (int i = 0; i < array.size; i++) {
                    Value child = array.get (i);
                    if (child is Table || child is Array) {
                        queue.add (child);
                    }
                }
            }
        }
        if (root_table != null) {
            root_table.clear_entries_for_dispose ();
        } else {
            unowned Array? root_array = root as Array;
            if (root_array != null) {
                root_array.clear_items_for_dispose ();
            }
        }
        foreach (var cur in hold) {
            var table = cur as Table;
            if (table != null) {
                table.clear_entries_for_dispose ();
                continue;
            }
            var array = cur as Array;
            if (array != null) {
                array.clear_items_for_dispose ();
            }
        }
    }

    internal bool value_reaches (Value from, Value dest) {
        if (from == dest) {
            return true;
        }
        var stack = new Gee.ArrayList<Value> ();
        var seen = new Gee.HashSet<Value> (
            (Gee.HashDataFunc<Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<Value>) GLib.direct_equal);
        stack.add (from);
        while (stack.size > 0) {
            var cur = stack.remove_at (stack.size - 1);
            if (!seen.add (cur)) {
                continue;
            }
            var table = cur as Table;
            if (table != null) {
                foreach (var key_bytes in table.key_bytes_list) {
                    Value? child = table.get_bytes (key_bytes.get_data ());
                    if (child == null) {
                        continue;
                    }
                    if (child == dest) {
                        return true;
                    }
                    if (child is Table || child is Array) {
                        stack.add (child);
                    }
                }
                continue;
            }
            var array = cur as Array;
            if (array != null) {
                for (int i = 0; i < array.size; i++) {
                    Value child = array.get (i);
                    if (child == dest) {
                        return true;
                    }
                    if (child is Table || child is Array) {
                        stack.add (child);
                    }
                }
            }
        }
        return false;
    }

    /**
     * A TOML table (key/value map) with write-style hints.
     */
    public class Table : Value {
        /** Emission style for this table. */
        public TableStyle style;

        private Gee.HashMap<string, Value> entries;
        private Gee.ArrayList<Bytes> key_bytes_order;
        private bool disposing;

        /** Create an empty table. */
        public Table () {
            kind = ValueKind.TABLE;
            style = TableStyle ();
            entries = new Gee.HashMap<string, Value> ();
            key_bytes_order = new Gee.ArrayList<Bytes> ();
            disposing = false;
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
        public new void set (string key, Value value) throws ValueError {
            set_bytes (key.data, value);
        }

        /** Set a key from raw key bytes. */
        public void set_bytes (uint8[] key_bytes, Value value) throws ValueError {
            if ((value is Table || value is Array) && value_reaches (value, this)) {
                throw new ValueError.INVALID ("cyclic DOM");
            }
            set_bytes_unchecked (key_bytes, value);
        }

        internal void set_bytes_unchecked (uint8[] key_bytes, Value value) {
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

        internal void clear_entries_for_dispose () {
            entries.clear ();
            key_bytes_order.clear ();
        }

        ~Table () {
            if (!disposing) {
                disposing = true;
                drain_container_tree (this);
            }
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
