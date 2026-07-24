namespace Toml {
    /**
     * Discriminator for {@link Value} payloads.
     */
    public enum ValueKind {
        STRING,
        INTEGER,
        FLOAT,
        BOOLEAN,
        DATETIME,
        DATETIME_LOCAL,
        DATE_LOCAL,
        TIME_LOCAL,
        TABLE,
        ARRAY
    }

    /**
     * A TOML value (scalar, table, or array).
     */
    public class Value {
        /** Runtime kind of this value. */
        public ValueKind kind { get; protected set; }

        private uint8[]? string_bytes;
        private int64 int_value;
        private double float_value;
        private bool bool_value;

        /** Build a string value from a Vala string. */
        public static Value from_string (string v) {
            return from_string_bytes (v.data);
        }

        /** Build a string value from raw UTF-8 bytes. */
        public static Value from_string_bytes (uint8[] bytes) {
            var value = new Value ();
            value.kind = ValueKind.STRING;
            value.string_bytes = bytes_copy (bytes);
            return value;
        }

        /** Build an integer value. */
        public static Value from_integer (int64 v) {
            var value = new Value ();
            value.kind = ValueKind.INTEGER;
            value.int_value = v;
            return value;
        }

        /** Build a float value. */
        public static Value from_float (double v) {
            var value = new Value ();
            value.kind = ValueKind.FLOAT;
            value.float_value = v;
            return value;
        }

        /** Build a boolean value. */
        public static Value from_boolean (bool v) {
            var value = new Value ();
            value.kind = ValueKind.BOOLEAN;
            value.bool_value = v;
            return value;
        }

        /** Build an offset date-time value from its TOML lexical form. */
        public static Value from_datetime (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATETIME;
            value.string_bytes = v.data;
            return value;
        }

        /** Build a local date-time value from its TOML lexical form. */
        public static Value from_datetime_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATETIME_LOCAL;
            value.string_bytes = v.data;
            return value;
        }

        /** Build a local date value from its TOML lexical form. */
        public static Value from_date_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATE_LOCAL;
            value.string_bytes = v.data;
            return value;
        }

        /** Build a local time value from its TOML lexical form. */
        public static Value from_time_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.TIME_LOCAL;
            value.string_bytes = v.data;
            return value;
        }

        /**
         * Return the string payload, or null if {@link kind} is not STRING.
         */
        public string? get_string () {
            if (kind != ValueKind.STRING) {
                return null;
            }
            return string_from_bytes (string_bytes);
        }

        /**
         * Return the string payload bytes, or null if not STRING.
         */
        public uint8[]? get_string_bytes () {
            if (kind != ValueKind.STRING) {
                return null;
            }
            return string_bytes;
        }

        /** Return the integer payload, or null if not INTEGER. */
        public int64? get_integer () {
            if (kind != ValueKind.INTEGER) {
                return null;
            }
            return int_value;
        }

        /** Return the float payload, or null if not FLOAT. */
        public double? get_float () {
            if (kind != ValueKind.FLOAT) {
                return null;
            }
            return float_value;
        }

        /** Return the boolean payload, or null if not BOOLEAN. */
        public bool? get_boolean () {
            if (kind != ValueKind.BOOLEAN) {
                return null;
            }
            return bool_value;
        }

        /**
         * Return the raw lexical string for string/date-time-like kinds.
         */
        public string get_raw () {
            return string_from_bytes (string_bytes);
        }

        /**
         * Return the raw lexical bytes for string/date-time-like kinds.
         */
        public uint8[]? get_raw_bytes () {
            return string_bytes;
        }

        /** Downcast to table, or null. */
        public virtual Table? as_table () {
            return null;
        }

        /** Downcast to array, or null. */
        public virtual Array? as_array () {
            return null;
        }

        internal static uint8[] bytes_copy (uint8[] src) {
            var dst = new uint8[src.length];
            if (src.length > 0) {
                Memory.copy (dst, src, src.length);
            }
            return dst;
        }

        internal static string string_from_bytes (uint8[]? bytes) {
            if (bytes == null || bytes.length == 0) {
                return "";
            }
            var sb = new StringBuilder ();
            sb.append_len ((string) bytes, bytes.length);
            // Note: .str truncates at embedded NUL; use byte APIs when NUL matters.
            return sb.str;
        }

        internal static bool bytes_equal (uint8[]? a, uint8[]? b) {
            if (a == null || b == null) {
                return a == b;
            }
            if (a.length != b.length) {
                return false;
            }
            for (int i = 0; i < a.length; i++) {
                if (a[i] != b[i]) {
                    return false;
                }
            }
            return true;
        }
    }
}
