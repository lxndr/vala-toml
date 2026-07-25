namespace Toml {
    /**
     * A TOML array with write-style hints.
     */
    public class Array : Value {
        /** Emission style for this array. */
        public ArrayStyle style;

        private Gee.ArrayList<Value> items;

        /** Create an empty array. */
        public Array () {
            kind = ValueKind.ARRAY;
            style = ArrayStyle ();
            items = new Gee.ArrayList<Value> ();
        }

        /** Number of elements. */
        public int size {
            get { return items.size; }
        }

        /** Iterate elements in order. */
        public Gee.Iterator<Value> iterator () {
            return items.iterator ();
        }

        /** Append a value. */
        public void add (Value value) throws ValueError {
            if ((value is Table || value is Array) && value_reaches (value, this)) {
                throw new ValueError.INVALID ("cyclic DOM");
            }
            add_unchecked (value);
        }

        internal void add_unchecked (Value value) {
            items.add (value);
        }

        /** Get element by index. */
        public new Value get (int index) {
            return items[index];
        }

        /** Replace element by index. */
        public new void set (int index, Value value) throws ValueError {
            if ((value is Table || value is Array) && value_reaches (value, this)) {
                throw new ValueError.INVALID ("cyclic DOM");
            }
            items[index] = value;
        }

        public override Array? as_array () {
            return this;
        }
    }
}
