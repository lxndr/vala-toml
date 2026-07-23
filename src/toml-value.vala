namespace Toml {
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

    public class Value : Object {
        public ValueKind kind { get; protected set; }

        private string string_value;
        private int64 int_value;
        private double float_value;
        private bool bool_value;

        public static Value from_string (string v) {
            var value = new Value ();
            value.kind = ValueKind.STRING;
            value.string_value = v;
            return value;
        }

        public static Value from_integer (int64 v) {
            var value = new Value ();
            value.kind = ValueKind.INTEGER;
            value.int_value = v;
            return value;
        }

        public static Value from_float (double v) {
            var value = new Value ();
            value.kind = ValueKind.FLOAT;
            value.float_value = v;
            return value;
        }

        public static Value from_boolean (bool v) {
            var value = new Value ();
            value.kind = ValueKind.BOOLEAN;
            value.bool_value = v;
            return value;
        }

        public static Value from_datetime (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATETIME;
            value.string_value = v;
            return value;
        }

        public static Value from_datetime_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATETIME_LOCAL;
            value.string_value = v;
            return value;
        }

        public static Value from_date_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.DATE_LOCAL;
            value.string_value = v;
            return value;
        }

        public static Value from_time_local (string v) {
            var value = new Value ();
            value.kind = ValueKind.TIME_LOCAL;
            value.string_value = v;
            return value;
        }

        public string? get_string () {
            if (kind != ValueKind.STRING) {
                return null;
            }
            return string_value;
        }

        public int64? get_integer () {
            if (kind != ValueKind.INTEGER) {
                return null;
            }
            return int_value;
        }

        public double? get_float () {
            if (kind != ValueKind.FLOAT) {
                return null;
            }
            return float_value;
        }

        public bool? get_boolean () {
            if (kind != ValueKind.BOOLEAN) {
                return null;
            }
            return bool_value;
        }

        public string get_raw () {
            return string_value;
        }

        public virtual Table? as_table () {
            return null;
        }

        public virtual Array? as_array () {
            return null;
        }
    }
}
