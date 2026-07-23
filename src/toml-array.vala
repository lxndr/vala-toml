namespace Toml {
    public class Array : Value {
        public ArrayStyle style;

        private Gee.ArrayList<Value> items;

        public Array () {
            kind = ValueKind.ARRAY;
            style = ArrayStyle ();
            items = new Gee.ArrayList<Value> ();
        }

        public int size {
            get { return items.size; }
        }

        public Gee.Iterator<Value> iterator () {
            return items.iterator ();
        }

        public void add (Value value) {
            items.add (value);
        }

        public new Value get (int index) {
            return items[index];
        }

        public new void set (int index, Value value) {
            items[index] = value;
        }

        public override Array? as_array () {
            return this;
        }
    }
}
