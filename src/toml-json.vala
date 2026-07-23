namespace Toml {
    public string table_to_tagged_json (Table root) {
        var node = value_to_json_node (root);
        var gen = new Json.Generator ();
        gen.set_root (node);
        size_t len;
        return gen.to_data (out len);
    }

    public Table table_from_tagged_json (string json) throws Error {
        var parser = new Json.Parser ();
        parser.load_from_data (json);
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
            throw new ParseError.FAILED ("expected JSON object for table");
        }
        var value = json_node_to_value (root);
        var table = value as Table;
        if (table == null) {
            throw new ParseError.FAILED ("expected table at JSON root");
        }
        return table;
    }

    private Json.Node value_to_json_node (Value value) {
        switch (value.kind) {
        case ValueKind.TABLE:
            return table_to_json_node ((Table) value);
        case ValueKind.ARRAY:
            return array_to_json_node ((Array) value);
        default:
            return scalar_to_json_node (value);
        }
    }

    private Json.Node table_to_json_node (Table table) {
        var obj = new Json.Object ();
        foreach (var key in table.keys) {
            obj.set_member (key, value_to_json_node (table.get (key)));
        }
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.take_object (obj);
        return node;
    }

    private Json.Node array_to_json_node (Array array) {
        var arr = new Json.Array ();
        for (int i = 0; i < array.size; i++) {
            arr.add_element (value_to_json_node (array.get (i)));
        }
        var node = new Json.Node (Json.NodeType.ARRAY);
        node.take_array (arr);
        return node;
    }

    private Json.Node scalar_to_json_node (Value value) {
        string type_name;
        string encoded;
        switch (value.kind) {
        case ValueKind.STRING:
            type_name = "string";
            encoded = value.get_string ();
            break;
        case ValueKind.INTEGER:
            type_name = "integer";
            encoded = value.get_integer ().to_string ();
            break;
        case ValueKind.FLOAT:
            type_name = "float";
            encoded = encode_float (value.get_float ());
            break;
        case ValueKind.BOOLEAN:
            type_name = "bool";
            encoded = value.get_boolean () ? "true" : "false";
            break;
        case ValueKind.DATETIME:
            type_name = "datetime";
            encoded = value.get_raw ();
            break;
        case ValueKind.DATETIME_LOCAL:
            type_name = "datetime-local";
            encoded = value.get_raw ();
            break;
        case ValueKind.DATE_LOCAL:
            type_name = "date-local";
            encoded = value.get_raw ();
            break;
        case ValueKind.TIME_LOCAL:
            type_name = "time-local";
            encoded = value.get_raw ();
            break;
        default:
            assert_not_reached ();
        }

        var obj = new Json.Object ();
        obj.set_string_member ("type", type_name);
        obj.set_string_member ("value", encoded);
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.take_object (obj);
        return node;
    }

    private string encode_float (double v) {
        if (v != v) {
            return "nan";
        }
        if (v == double.INFINITY) {
            return "inf";
        }
        if (v == -double.INFINITY) {
            return "-inf";
        }
        string s = "%.15g".printf (v);
        if (s.index_of_char ('.') < 0 && s.index_of_char ('e') < 0 && s.index_of_char ('E') < 0) {
            s += ".0";
        }
        return s;
    }

    private Value json_node_to_value (Json.Node node) throws Error {
        switch (node.get_node_type ()) {
        case Json.NodeType.OBJECT:
            var obj = node.get_object ();
            if (is_tagged_scalar (obj)) {
                return tagged_scalar_from_object (obj);
            }
            return table_from_json_object (obj);
        case Json.NodeType.ARRAY:
            return array_from_json_array (node.get_array ());
        default:
            throw new ParseError.FAILED ("unexpected JSON node type");
        }
    }

    private bool is_tagged_scalar (Json.Object obj) {
        if (!obj.has_member ("type") || !obj.has_member ("value")) {
            return false;
        }
        var type_node = obj.get_member ("type");
        var value_node = obj.get_member ("value");
        if (type_node == null || value_node == null) {
            return false;
        }
        return type_node.get_node_type () == Json.NodeType.VALUE
            && value_node.get_node_type () == Json.NodeType.VALUE
            && type_node.get_value_type () == typeof (string)
            && value_node.get_value_type () == typeof (string);
    }

    private Value tagged_scalar_from_object (Json.Object obj) throws Error {
        string type_name = obj.get_string_member ("type");
        string encoded = obj.get_string_member ("value");
        switch (type_name) {
        case "string":
            return Value.from_string (encoded);
        case "integer":
            return Value.from_integer (int64.parse (encoded));
        case "float":
            return Value.from_float (decode_float (encoded));
        case "bool":
            if (encoded == "true") {
                return Value.from_boolean (true);
            }
            if (encoded == "false") {
                return Value.from_boolean (false);
            }
            throw new ParseError.FAILED ("invalid bool value: %s".printf (encoded));
        case "datetime":
            return Value.from_datetime (encoded);
        case "datetime-local":
            return Value.from_datetime_local (encoded);
        case "date-local":
            return Value.from_date_local (encoded);
        case "time-local":
            return Value.from_time_local (encoded);
        default:
            throw new ParseError.FAILED ("unknown tagged JSON type: %s".printf (type_name));
        }
    }

    private double decode_float (string encoded) throws Error {
        if (encoded == "nan" || encoded == "+nan" || encoded == "-nan") {
            return double.NAN;
        }
        if (encoded == "inf" || encoded == "+inf") {
            return double.INFINITY;
        }
        if (encoded == "-inf") {
            return -double.INFINITY;
        }
        double result;
        if (!double.try_parse (encoded, out result)) {
            throw new ParseError.FAILED ("invalid float value: %s".printf (encoded));
        }
        return result;
    }

    private Table table_from_json_object (Json.Object obj) throws Error {
        var table = new Table ();
        foreach (var key in obj.get_members ()) {
            table.set (key, json_node_to_value (obj.get_member (key)));
        }
        return table;
    }

    private Array array_from_json_array (Json.Array arr) throws Error {
        var array = new Array ();
        for (uint i = 0; i < arr.get_length (); i++) {
            array.add (json_node_to_value (arr.get_element (i)));
        }
        return array;
    }
}
