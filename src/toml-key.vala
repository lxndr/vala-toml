namespace Toml {
    /**
     * A TOML key (bare or quoted). Payload may contain embedded NUL.
     *
     * Prefer {@link bytes} when NUL may be present; {@link to_string}
     * truncates at the first NUL.
     */
    public class Key : Object, Gee.Hashable<Key> {
        private Bytes _bytes;

        public Key (Bytes bytes) {
            if (bytes == null) {
                _bytes = new Bytes (new uint8[0]);
            } else {
                _bytes = bytes;
            }
        }

        public Key.from_str (string s) {
            _bytes = new Bytes (s.data);
        }

        public Bytes bytes {
            get { return _bytes; }
        }

        public string to_string () {
            unowned uint8[] data = _bytes.get_data ();
            if (data.length == 0) {
                return "";
            }
            var sb = new StringBuilder ();
            sb.append_len ((string) data, data.length);
            return sb.str;
        }

        public uint hash () {
            return _bytes.hash ();
        }

        public bool equal_to (Key other) {
            return _bytes.compare (other._bytes) == 0;
        }
    }
}
