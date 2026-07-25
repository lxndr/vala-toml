namespace Toml {
    /**
     * Deep-compare two values (including nested tables and arrays).
     *
     * @return true if both are null or structurally equal
     */
    public bool values_equal (Value? a, Value? b) {
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        if (a.kind != b.kind) {
            return false;
        }

        switch (a.kind) {
        case ValueKind.STRING:
            return Value.bytes_equal (a.get_string_bytes (), b.get_string_bytes ());
        case ValueKind.OFFSET_DATETIME:
            return offset_datetime_equal (a.get_offset_datetime (), b.get_offset_datetime ());
        case ValueKind.LOCAL_DATETIME: {
            var la = a.get_local_datetime ();
            var lb = b.get_local_datetime ();
            if (la == null || lb == null) {
                return la == lb;
            }
            return local_datetime_equal (la, lb);
        }
        case ValueKind.LOCAL_DATE: {
            var da = a.get_local_date ();
            var db = b.get_local_date ();
            if (da == null || db == null) {
                return da == db;
            }
            return da.compare (db) == 0;
        }
        case ValueKind.LOCAL_TIME: {
            var ta = a.get_local_time ();
            var tb = b.get_local_time ();
            if (ta == null || tb == null) {
                return ta == tb;
            }
            return local_time_equal (ta, tb);
        }
        case ValueKind.INTEGER:
            return a.get_integer () == b.get_integer ();
        case ValueKind.FLOAT:
            return a.get_float () == b.get_float ();
        case ValueKind.BOOLEAN:
            return a.get_boolean () == b.get_boolean ();
        case ValueKind.TABLE:
            return tables_equal (a.as_table (), b.as_table ());
        case ValueKind.ARRAY:
            return arrays_equal (a.as_array (), b.as_array ());
        }

        return false;
    }

    private bool tables_equal (Table? a, Table? b) {
        if (a == null || b == null) {
            return a == b;
        }
        if (a.size != b.size) {
            return false;
        }
        for (int i = 0; i < a.key_bytes_list.size; i++) {
            uint8[] kb = a.key_bytes_list[i].get_data ();
            if (!b.has_bytes (kb)) {
                return false;
            }
            if (!values_equal (a.get_bytes (kb), b.get_bytes (kb))) {
                return false;
            }
        }
        return true;
    }

    private bool arrays_equal (Array? a, Array? b) {
        if (a == null || b == null) {
            return a == b;
        }
        if (a.size != b.size) {
            return false;
        }
        for (int i = 0; i < a.size; i++) {
            if (!values_equal (a.get (i), b.get (i))) {
                return false;
            }
        }
        return true;
    }
}
