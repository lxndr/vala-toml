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
        int i = 0;
        while (i < data.length) {
            uint8 b0 = data[i];
            if (b0 < 0x80) {
                i++;
                continue;
            }
            if ((b0 & 0xE0) == 0xC0) {
                if (i + 1 >= data.length || (data[i + 1] & 0xC0) != 0x80) {
                    return false;
                }
                unichar c = ((unichar) (b0 & 0x1F) << 6) | (data[i + 1] & 0x3F);
                if (c < 0x80) {
                    return false;
                }
                i += 2;
                continue;
            }
            if ((b0 & 0xF0) == 0xE0) {
                if (i + 2 >= data.length
                    || (data[i + 1] & 0xC0) != 0x80
                    || (data[i + 2] & 0xC0) != 0x80) {
                    return false;
                }
                unichar c = ((unichar) (b0 & 0x0F) << 12)
                    | ((unichar) (data[i + 1] & 0x3F) << 6)
                    | (data[i + 2] & 0x3F);
                if (c < 0x800 || (c >= 0xD800 && c <= 0xDFFF)) {
                    return false;
                }
                i += 3;
                continue;
            }
            if ((b0 & 0xF8) == 0xF0) {
                if (i + 3 >= data.length
                    || (data[i + 1] & 0xC0) != 0x80
                    || (data[i + 2] & 0xC0) != 0x80
                    || (data[i + 3] & 0xC0) != 0x80) {
                    return false;
                }
                unichar c = ((unichar) (b0 & 0x07) << 18)
                    | ((unichar) (data[i + 1] & 0x3F) << 12)
                    | ((unichar) (data[i + 2] & 0x3F) << 6)
                    | (data[i + 3] & 0x3F);
                if (c < 0x10000 || c > 0x10FFFF) {
                    return false;
                }
                i += 4;
                continue;
            }
            return false;
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
