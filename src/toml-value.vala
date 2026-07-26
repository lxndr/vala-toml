namespace Toml {
    /**
     * Abstract TOML value (scalar, table, or array).
     */
    public abstract class Value {
    }

    /**
     * True if {@link Bytes} data is empty or well-formed UTF-8.
     */
    internal bool bytes_utf8_valid (Bytes bytes) {
        if (bytes == null || bytes.length == 0) {
            return true;
        }
        unowned uint8[] data = bytes.get_data ();
        return ((string) data).validate (data.length);
    }

    internal string string_from_bytes (Bytes bytes) {
        if (bytes == null || bytes.length == 0) {
            return "";
        }
        unowned uint8[] data = bytes.get_data ();
        var sb = new StringBuilder ();
        sb.append_len ((string) data, data.length);
        return sb.str;
    }
}
