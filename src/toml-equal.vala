namespace Toml {
    /**
     * Deep-compare two values (including nested tables and arrays).
     *
     * @return true if both are null or structurally equal
     */
    public bool values_equal (Value? a, Value? b) {
        var active = new Gee.HashSet<Value> (
            (Gee.HashDataFunc<Value>) GLib.direct_hash,
            (Gee.EqualDataFunc<Value>) GLib.direct_equal);
        return values_equal_inner (a, b, active);
    }

    private bool values_equal_inner (Value? a, Value? b, Gee.HashSet<Value> active) {
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        var sa = a as String; var sb = b as String;
        if (sa != null || sb != null) return sa != null && sb != null && sa.bytes.compare (sb.bytes) == 0;
        var ia = a as Integer; var ib = b as Integer;
        if (ia != null || ib != null) return ia != null && ib != null && ia.value == ib.value;
        var fa = a as Float; var fb = b as Float;
        if (fa != null || fb != null) return fa != null && fb != null && fa.value == fb.value;
        var ba = a as Boolean; var bb = b as Boolean;
        if (ba != null || bb != null) return ba != null && bb != null && ba.value == bb.value;
        var oa = a as OffsetDateTime; var ob = b as OffsetDateTime;
        if (oa != null || ob != null) return oa != null && ob != null && oa.equal_to (ob);
        var lda = a as LocalDateTime; var ldb = b as LocalDateTime;
        if (lda != null || ldb != null) return lda != null && ldb != null && lda.equal_to (ldb);
        var da = a as LocalDate; var db = b as LocalDate;
        if (da != null || db != null) return da != null && db != null && da.equal_to (db);
        var ta = a as LocalTime; var tb = b as LocalTime;
        if (ta != null || tb != null) return ta != null && tb != null && ta.equal_to (tb);
        var taba = a as Table; var tabb = b as Table;
        if (taba != null || tabb != null) return taba != null && tabb != null && tables_equal (taba, tabb, active);
        var arra = a as Array; var arrb = b as Array;
        if (arra != null || arrb != null) return arra != null && arrb != null && arrays_equal (arra, arrb, active);
        return false;
    }

    private bool tables_equal (Table? a, Table? b, Gee.HashSet<Value> active) {
        if (a == null || b == null) {
            return a == b;
        }
        if (active.contains (a) || active.contains (b)) {
            return false;
        }
        active.add (a);
        active.add (b);
        try {
            if (a.size != b.size) {
                return false;
            }
            foreach (var key in a.keys) {
                if (!b.has (key)) {
                    return false;
                }
                if (!values_equal_inner (a.get (key), b.get (key), active)) {
                    return false;
                }
            }
            return true;
        } finally {
            active.remove (a);
            active.remove (b);
        }
    }

    private bool arrays_equal (Array? a, Array? b, Gee.HashSet<Value> active) {
        if (a == null || b == null) {
            return a == b;
        }
        if (active.contains (a) || active.contains (b)) {
            return false;
        }
        active.add (a);
        active.add (b);
        try {
            if (a.size != b.size) {
                return false;
            }
            for (int i = 0; i < a.size; i++) {
                if (!values_equal_inner (a.get (i), b.get (i), active)) {
                    return false;
                }
            }
            return true;
        } finally {
            active.remove (a);
            active.remove (b);
        }
    }
}
