int main (string[] args) {
    try {
        var table = Toml.parse_string (read_stdin ());
        stdout.puts (Toml.table_to_tagged_json (table));
        return 0;
    } catch (Error e) {
        stderr.printf ("%s\n", e.message);
        return 1;
    }
}

string read_stdin () {
    var sb = new StringBuilder ();
    int c;
    while ((c = stdin.getc ()) != -1) {
        sb.append_c ((char) c);
    }
    return sb.str;
}
