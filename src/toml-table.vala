namespace Toml {
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
                foreach (var key in table.key_order_list) {
                    Value? child = table.get (key);
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

        private Gee.HashMap<Key?, Value> entries;
        private Gee.ArrayList<Key?> key_order;

        /** Create an empty table. */
        public Table () {
            style = TableStyle ();
            entries = new Gee.HashMap<Key?, Value> (
                (k) => k.hash (),
                (a, b) => a.equal_to (b));
            key_order = new Gee.ArrayList<Key?> ((a, b) => a.equal_to (b));
        }

        /** Number of keys. */
        public int size {
            get { return key_order.size; }
        }

        /** Keys in insertion order. */
        public Gee.List<Key?> keys {
            owned get {
                var list = new Gee.ArrayList<Key?> ((a, b) => a.equal_to (b));
                foreach (var key in key_order) {
                    list.add (key);
                }
                return list;
            }
        }

        internal Gee.List<Key?> key_order_list {
            get { return key_order; }
        }

        public new void set (Key key, Value value) throws ValueError {
            if ((value is Table || value is Array) && value_reaches (value, this)) {
                throw new ValueError.INVALID ("cyclic DOM");
            }
            set_unchecked (key, value);
        }

        internal void set_unchecked (Key key, Value value) {
            if (!entries.has_key (key)) {
                key_order.add (key);
            }
            entries[key] = value;
        }

        public new Value? get (Key key) {
            return entries[key];
        }

        /**
         * Remove a key.
         *
         * @return true if the key existed
         */
        public bool unset (Key key) {
            if (!entries.unset (key)) {
                return false;
            }
            for (int i = 0; i < key_order.size; i++) {
                if (key_order[i].equal_to (key)) {
                    key_order.remove_at (i);
                    break;
                }
            }
            return true;
        }

        public bool has (Key key) {
            return entries.has_key (key);
        }
    }
}
