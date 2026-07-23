int main (string[] args) {
    try {
        var table = Toml.table_from_tagged_json (read_stdin ());
        stdout.puts (Toml.write_string (table));
        return 0;
    } catch (Error e) {
        stderr.printf ("%s\n", e.message);
        return 1;
    }
}

string read_stdin () {
    var sb = new StringBuilder ();
    int c;
    while ((c = stdin.getc ()) >= 0) {
        sb.append_c ((char) c);
    }
    return sb.str;
}
