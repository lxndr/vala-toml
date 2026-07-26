namespace Toml {
    // Reads TomlValue.ref_count without taking an extra strong ref.
    [CCode (cname = "toml_value_peek_ref_count")]
    internal static extern int value_peek_ref_count (Value v);

    /*
     * Clear containers exclusively owned by the dying subgraph.
     *
     * Collect every reachable container (strong-held), count internal
     * child-container edges among them, then treat a node as shared when
     * ref_count - 2(hold + classify temp) - internal_edges > 0. Shared
     * seeds and their transitive descendants within the seen set are
     * preserved. Clear only non-preserved nodes. Root is always cleared.
     */
    internal void drain_container_tree (Value root) {
        var hold = new Gee.ArrayList<Value> ();
        var queue = new Gee.ArrayList<Value> ();
        var seen = new Gee.HashSet<unowned Value> (
            (Gee.HashDataFunc<unowned Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<unowned Value>) GLib.direct_equal);
        seen.add (root);
        // Dying root is already at ref_count 0 in finalize — do not hold it.
        if (value_peek_ref_count (root) > 0) {
            hold.add (root);
        }
        drain_collect_children (root, hold, queue, seen);
        while (queue.size > 0) {
            var cur = queue.remove_at (0);
            drain_collect_children (cur, hold, queue, seen);
        }

        var edge_count = new Gee.HashMap<unowned Value, int> (
            (Gee.HashDataFunc<unowned Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<unowned Value>) GLib.direct_equal);
        drain_count_edges_from (root, seen, edge_count);
        foreach (var cur in hold) {
            if (cur == root) {
                continue;
            }
            drain_count_edges_from (cur, seen, edge_count);
        }

        // Nodes with live external owners, plus all their descendants in the
        // seen set, must not be cleared (nested containers under a shared
        // DAG node are exclusive by edge-count but still live).
        var preserve = new Gee.HashSet<unowned Value> (
            (Gee.HashDataFunc<unowned Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<unowned Value>) GLib.direct_equal);
        var seed_queue = new Gee.ArrayList<unowned Value> ();
        foreach (var cur in hold) {
            if (cur == root) {
                continue;
            }
            int edges = 0;
            if (edge_count.has_key (cur)) {
                edges = edge_count[cur];
            }
            // hold + foreach-owned temporary each contribute one strong ref.
            int external = value_peek_ref_count (cur) - 2 - edges;
            if (external > 0) {
                if (preserve.add (cur)) {
                    seed_queue.add (cur);
                }
            }
        }
        while (seed_queue.size > 0) {
            unowned Value seed = seed_queue.remove_at (0);
            drain_enqueue_seen_children (seed, seen, preserve, seed_queue);
        }

        foreach (var cur in hold) {
            if (cur == root) {
                continue;
            }
            if (!preserve.contains (cur)) {
                drain_clear_container (cur);
            }
        }
        drain_clear_container (root);
    }

    private void drain_clear_container (Value node) {
        // Use unowned casts: root is already at ref_count 0 in finalize; an
        // owned `as` would ref/unref and re-enter finalize mid-drain.
        unowned Table? table = node as Table;
        if (table != null) {
            table.clear_entries_for_dispose ();
            return;
        }
        unowned Array? array = node as Array;
        if (array != null) {
            array.clear_items_for_dispose ();
        }
    }

    private void drain_collect_child (Value? child,
                                      Gee.ArrayList<Value> hold,
                                      Gee.ArrayList<Value> queue,
                                      Gee.HashSet<unowned Value> seen) {
        if (child == null || !(child is Table || child is Array)) {
            return;
        }
        if (!seen.add (child)) {
            return;
        }
        hold.add (child);
        queue.add (child);
    }

    private void drain_collect_children (Value cur,
                                         Gee.ArrayList<Value> hold,
                                         Gee.ArrayList<Value> queue,
                                         Gee.HashSet<unowned Value> seen) {
        unowned Table? table = cur as Table;
        if (table != null) {
            foreach (var key in table.key_order_list) {
                drain_collect_child (table.get (key),
                                     hold, queue, seen);
            }
            return;
        }
        unowned Array? array = cur as Array;
        if (array != null) {
            for (int i = 0; i < array.size; i++) {
                drain_collect_child (array.get (i), hold, queue, seen);
            }
        }
    }

    private void drain_count_child_edge (Value? child,
                                         Gee.HashSet<unowned Value> seen,
                                         Gee.HashMap<unowned Value, int> edge_count) {
        if (child == null || !(child is Table || child is Array)) {
            return;
        }
        if (!seen.contains (child)) {
            return;
        }
        int n = 0;
        if (edge_count.has_key (child)) {
            n = edge_count[child];
        }
        edge_count[child] = n + 1;
    }

    private void drain_count_edges_from (Value cur,
                                         Gee.HashSet<unowned Value> seen,
                                         Gee.HashMap<unowned Value, int> edge_count) {
        unowned Table? table = cur as Table;
        if (table != null) {
            foreach (var key in table.key_order_list) {
                drain_count_child_edge (table.get (key),
                                        seen, edge_count);
            }
            return;
        }
        unowned Array? array = cur as Array;
        if (array != null) {
            for (int i = 0; i < array.size; i++) {
                drain_count_child_edge (array.get (i), seen, edge_count);
            }
        }
    }

    private void drain_enqueue_seen_child (Value? child,
                                           Gee.HashSet<unowned Value> seen,
                                           Gee.HashSet<unowned Value> preserve,
                                           Gee.ArrayList<unowned Value> seed_queue) {
        if (child == null || !(child is Table || child is Array)) {
            return;
        }
        if (!seen.contains (child)) {
            return;
        }
        if (preserve.add (child)) {
            seed_queue.add (child);
        }
    }

    private void drain_enqueue_seen_children (Value cur,
                                             Gee.HashSet<unowned Value> seen,
                                             Gee.HashSet<unowned Value> preserve,
                                             Gee.ArrayList<unowned Value> seed_queue) {
        unowned Table? table = cur as Table;
        if (table != null) {
            foreach (var key in table.key_order_list) {
                drain_enqueue_seen_child (table.get (key),
                                          seen, preserve, seed_queue);
            }
            return;
        }
        unowned Array? array = cur as Array;
        if (array != null) {
            for (int i = 0; i < array.size; i++) {
                drain_enqueue_seen_child (array.get (i), seen, preserve, seed_queue);
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
        private bool disposing;

        /** Create an empty table. */
        public Table () {
            style = TableStyle ();
            entries = new Gee.HashMap<Key?, Value> (
                (k) => k.hash (),
                (a, b) => a.equal_to (b));
            key_order = new Gee.ArrayList<Key?> ((a, b) => a.equal_to (b));
            disposing = false;
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

        internal void clear_entries_for_dispose () {
            entries.clear ();
            key_order.clear ();
        }

        ~Table () {
            if (!disposing) {
                disposing = true;
                drain_container_tree (this);
            }
        }
    }
}
