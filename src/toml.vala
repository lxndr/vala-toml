namespace Toml {
    public string library_name () {
        return "vala-toml";
    }

    public Table parse_string (string text) throws ParseError {
        var parser = new Parser (text);
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
            // Copy with NUL terminator for a valid UTF-8 string view
            var buf = new uint8[len + 1];
            Memory.copy (buf, data, len);
            buf[len] = 0;
            string text = (string) buf;
            if (!text.validate ()) {
                throw new ParseError.FAILED ("invalid UTF-8");
            }
            return parse_string (text);
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
}
