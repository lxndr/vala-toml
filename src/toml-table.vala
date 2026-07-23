namespace Toml {
    public class Table : Value {
        public TableStyle style { get; set; }

        private Gee.HashMap<string, Value> entries;
        private Gee.ArrayList<string> key_order;

        public Table () {
            Object ();
            kind = ValueKind.TABLE;
            style = new TableStyle ();
            entries = new Gee.HashMap<string, Value> ();
            key_order = new Gee.ArrayList<string> ();
        }

        public int size {
            get { return key_order.size; }
        }

        public Gee.List<string> keys {
            get { return key_order; }
        }

        public new void set (string key, Value value) {
            if (!entries.has_key (key)) {
                key_order.add (key);
            }
            entries[key] = value;
        }

        public new Value? get (string key) {
            return entries[key];
        }

        public bool unset (string key) {
            if (!entries.unset (key)) {
                return false;
            }
            key_order.remove (key);
            return true;
        }

        public bool has (string key) {
            return entries.has_key (key);
        }

        public override Table? as_table () {
            return this;
        }
    }
}
