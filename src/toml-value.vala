namespace Toml {
    /**
     * Discriminator for {@link Value} payloads.
     */
    public enum ValueKind {
        STRING,
        INTEGER,
        FLOAT,
        BOOLEAN,
        OFFSET_DATETIME,
        LOCAL_DATETIME,
        LOCAL_DATE,
        LOCAL_TIME,
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
        private DateTime? offset_datetime;
        private LocalDateTime? local_datetime;
        private Date local_date;
        private bool local_date_set;
        private LocalTime? local_time;

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

        /** Build an offset date-time value from a timezone-aware {@link DateTime}. */
        public static Value from_offset_datetime (DateTime dt) throws ValueError {
            if (dt == null) {
                throw new ValueError.INVALID ("offset date-time is null");
            }
            if (dt.get_timezone () == null) {
                throw new ValueError.INVALID ("offset date-time requires a timezone");
            }
            var value = new Value ();
            value.kind = ValueKind.OFFSET_DATETIME;
            value.offset_datetime = dt;
            return value;
        }

        /** Build a local date-time value. */
        public static Value from_local_datetime (LocalDateTime v) throws ValueError {
            if (v == null) {
                throw new ValueError.INVALID ("local date-time is null");
            }
            var value = new Value ();
            value.kind = ValueKind.LOCAL_DATETIME;
            value.local_datetime = v;
            return value;
        }

        /** Build a local date value; requires a valid {@link Date}. */
        public static Value from_local_date (Date d) throws ValueError {
            if (!d.valid ()) {
                throw new ValueError.INVALID ("invalid date");
            }
            var value = new Value ();
            value.kind = ValueKind.LOCAL_DATE;
            value.local_date = d;
            value.local_date_set = true;
            return value;
        }

        /** Build a local time value. */
        public static Value from_local_time (LocalTime t) throws ValueError {
            if (t == null) {
                throw new ValueError.INVALID ("local time is null");
            }
            var value = new Value ();
            value.kind = ValueKind.LOCAL_TIME;
            value.local_time = t;
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

        /** Return the offset date-time payload, or null if not OFFSET_DATETIME. */
        public DateTime? get_offset_datetime () {
            if (kind != ValueKind.OFFSET_DATETIME) {
                return null;
            }
            return offset_datetime;
        }

        /** Return the local date-time payload, or null if not LOCAL_DATETIME. */
        public LocalDateTime? get_local_datetime () {
            if (kind != ValueKind.LOCAL_DATETIME) {
                return null;
            }
            return local_datetime;
        }

        /** Return the local date payload, or null if not LOCAL_DATE. */
        public Date? get_local_date () {
            if (kind != ValueKind.LOCAL_DATE || !local_date_set) {
                return null;
            }
            return local_date;
        }

        /** Return the local time payload, or null if not LOCAL_TIME. */
        [CCode (cname = "toml_value_get_toml_local_time")]
        public LocalTime? get_local_time () {
            if (kind != ValueKind.LOCAL_TIME) {
                return null;
            }
            return local_time;
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
