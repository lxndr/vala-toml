namespace Toml {
    /**
     * Abstract TOML value (scalar, table, or array).
     */
    public abstract class Value {
    }

    [CCode (cname = "g_utf8_validate_len")]
    private static extern bool utf8_validate_len (
        [CCode (type = "const gchar*", array_length = false)] uint8* str,
        size_t max_len,
        [CCode (type = "const gchar**")] void* end);

    /**
     * True if {@link Bytes} data is empty or well-formed UTF-8.
     * Embedded NUL bytes are allowed; each non-NUL run is validated separately.
     */
    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal bool bytes_utf8_valid (Bytes bytes) {
        if (bytes == null || bytes.length == 0) {
            return true;
        }
        unowned uint8[] data = bytes.get_data ();
        int i = 0;
        while (i < data.length) {
            if (data[i] == 0) {
                i++;
                continue;
            }
            int start = i;
            while (i < data.length && data[i] != 0) {
                i++;
            }
            size_t len = (size_t) (i - start);
            if (!utf8_validate_len (&data[start], len, null)) {
                return false;
            }
        }
        return true;
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
