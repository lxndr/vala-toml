namespace Toml {
    public string library_name () {
        return "vala-toml";
    }

    public Table parse_string (string text) throws ParseError {
        validate_source_bytes (text.data);
        var parser = new Parser (text);
        return parser.parse ();
    }

    public Table parse_bytes (uint8[] data) throws ParseError {
        validate_source_bytes (data);
        // Source bytes must not contain embedded NUL (controls rejected). Safe as Vala string.
        var sb = new StringBuilder ();
        if (data.length > 0) {
            sb.append_len ((string) data, data.length);
        }
        var parser = new Parser (sb.str);
        return parser.parse ();
    }

    public Table parse (InputStream stream) throws ParseError {
        try {
            var mos = new MemoryOutputStream.resizable ();
            mos.splice (stream, OutputStreamSpliceFlags.CLOSE_SOURCE);
            mos.close ();
            size_t len = mos.get_data_size ();
            if (len == 0) {
                return parse_string ("");
            }
            unowned uint8[] data = mos.get_data ();
            var copy = new uint8[len];
            Memory.copy (copy, data, len);
            return parse_bytes (copy);
        } catch (ParseError e) {
            throw e;
        } catch (Error e) {
            throw new ParseError.FAILED (e.message);
        }
    }

    public string write_string (Table root, WriteOptions? options = null) throws WriteError {
        var writer = new Writer (options);
        return writer.emit (root);
    }

    public void write (Table root, OutputStream stream, WriteOptions? options = null) throws WriteError {
        string text = write_string (root, options);
        try {
            size_t written;
            stream.write_all (text.data, out written);
        } catch (Error e) {
            throw new WriteError.FAILED (e.message);
        }
    }

    private void validate_source_bytes (uint8[] data) throws ParseError {
        if (data.length == 0) {
            return;
        }
        char* end;
        if (!((string) data).validate (data.length, out end)) {
            throw new ParseError.FAILED ("invalid UTF-8");
        }
        int i = 0;
        while (i < data.length) {
            uint8 b = data[i];
            if (b == (uint8) '\t' || b == (uint8) '\n') {
                i++;
                continue;
            }
            if (b == (uint8) '\r') {
                if (i + 1 >= data.length || data[i + 1] != (uint8) '\n') {
                    throw new ParseError.FAILED ("bare carriage return");
                }
                i += 2;
                continue;
            }
            if (b < 0x20 || b == 0x7F) {
                throw new ParseError.FAILED ("invalid control character");
            }
            i++;
        }
    }
}
