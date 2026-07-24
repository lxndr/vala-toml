namespace Toml {
    /**
     * Parse TOML text into a DOM table.
     *
     * @param text UTF-8 TOML source
     * @return root table
     * @throws ParseError if the source is invalid
     */
    public Table parse_string (string text) throws ParseError {
        validate_source_bytes (text.data);
        var parser = new Parser (text);
        return parser.parse ();
    }

    /**
     * Parse TOML bytes into a DOM table.
     *
     * @param data UTF-8 TOML source bytes (no embedded NUL required for Vala string bridging)
     * @return root table
     * @throws ParseError if the source is invalid
     */
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

    /**
     * Read an entire stream and parse it as TOML.
     *
     * @param stream source stream
     * @return root table
     * @throws ParseError on invalid TOML or I/O failure wrapped as ParseError
     */
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

    /**
     * Serialize a table to a TOML string.
     *
     * @param root table to emit
     * @param options writer options, or null for defaults
     * @return TOML text
     * @throws WriteError if the DOM cannot be emitted
     */
    public string write_string (Table root, WriteOptions? options = null) throws WriteError {
        var writer = new Writer (options);
        return writer.emit (root);
    }

    /**
     * Serialize a table to an output stream.
     *
     * @param root table to emit
     * @param stream destination
     * @param options writer options, or null for defaults
     * @throws WriteError if emission or writing fails
     */
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
