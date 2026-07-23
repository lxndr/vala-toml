int main (string[] args) {
    try {
        var table = Toml.parse_bytes (read_stdin_bytes ());
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
