namespace Toml {
    /**
     * A TOML string value. Payload may contain embedded NUL.
     */
    public class String : Value {
        private Bytes _bytes;

        public String (Bytes bytes) {
            _bytes = bytes ?? new Bytes (new uint8[0]);
        }

        public String.from_str (string s) {
            _bytes = new Bytes (s.data);
        }

        public Bytes bytes {
            get { return _bytes; }
        }

        public string to_string () {
            return string_from_bytes (_bytes);
        }
    }
}
