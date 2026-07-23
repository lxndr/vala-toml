namespace Toml {
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
        case ValueKind.DATETIME:
        case ValueKind.DATETIME_LOCAL:
        case ValueKind.DATE_LOCAL:
        case ValueKind.TIME_LOCAL:
            return a.get_raw () == b.get_raw ();
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
