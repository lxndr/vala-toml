int main (string[] args) {
    try {
        var table = Toml.parse_string (stdin_to_string (read_stdin_bytes ()));
        stdout.puts (Toml.table_to_tagged_json (table));
        return 0;
    } catch (Error e) {
        stderr.printf ("%s\n", e.message);
        return 1;
    }
}

uint8[] read_stdin_bytes () {
    var sb = new StringBuilder ();
    int c;
    while ((c = stdin.getc ()) != -1) {
        sb.append_c ((char) c);
    }
    return sb.data[0:sb.len];
}

string stdin_to_string (uint8[] data) throws Toml.ParseError {
    for (int i = 0; i < data.length; i++) {
        if (data[i] == 0) {
            throw new Toml.ParseError.FAILED ("invalid UTF-8");
        }
    }
    if (data.length > 0 && !((string) data).validate (data.length)) {
        throw new Toml.ParseError.FAILED ("invalid UTF-8");
    }
    var sb = new StringBuilder ();
    if (data.length > 0) {
        sb.append_len ((string) data, data.length);
    }
    return sb.str;
}
