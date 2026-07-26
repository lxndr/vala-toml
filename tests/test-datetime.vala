using Toml;

void test_local_time_ok () {
    try {
        var t = new Toml.LocalTime (7, 32, 0, 0);
        assert (t.hour == 7);
        assert (t.minute == 32);
        assert (t.second == 0);
        assert (t.microsecond == 0);
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_local_time_rejects_bad_hour () {
    bool threw = false;
    try {
        new Toml.LocalTime (24, 0, 0);
    } catch (Toml.ValueError e) {
        threw = true;
    }
    assert (threw);
}

void test_local_time_rejects_second_60 () {
    bool threw = false;
    try {
        new Toml.LocalTime (23, 59, 60);
    } catch (Toml.ValueError e) {
        threw = true;
    }
    assert (threw);
}

void test_local_datetime_ok () {
    try {
        Date d = Date ();
        d.set_dmy ((DateDay) 27, DateMonth.MAY, (DateYear) 1979);
        var t = new Toml.LocalTime (7, 32, 0);
        var ldt = new Toml.LocalDateTime (d, t);
        assert (ldt.date.get_year () == 1979);
        assert (ldt.time.hour == 7);
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_local_datetime_rejects_invalid_date () {
    bool threw = false;
    try {
        Date d = Date ();
        d.clear ();
        new Toml.LocalDateTime (d, new Toml.LocalTime (0, 0, 0));
    } catch (Toml.ValueError e) {
        threw = true;
    }
    assert (threw);
}

void test_format_local_time_with_frac () {
    try {
        var t = new Toml.LocalTime (7, 32, 0, 999000);
        assert (Toml.format_local_time (t) == "07:32:00.999");
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_format_offset_datetime_z () {
    var tz = new TimeZone.utc ();
    var dt = new DateTime (tz, 1979, 5, 27, 7, 32, 0.0);
    assert (Toml.format_offset_datetime (dt) == "1979-05-27T07:32:00Z");
}

void test_format_offset_datetime_numeric_offset () {
    // -07:00
    var tz = new TimeZone.offset ((int) (-7 * TimeSpan.HOUR / TimeSpan.SECOND));
    var dt = new DateTime (tz, 1979, 5, 27, 0, 32, 0.0);
    assert (Toml.format_offset_datetime (dt) == "1979-05-27T00:32:00-07:00");
}

void test_format_local_datetime_uses_T () {
    try {
        Date d = Date ();
        d.set_dmy ((DateDay) 27, DateMonth.MAY, (DateYear) 1979);
        var ldt = new Toml.LocalDateTime (d, new Toml.LocalTime (7, 32, 0));
        assert (Toml.format_local_datetime (ldt) == "1979-05-27T07:32:00");
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_format_offset_datetime_positive_offset () {
    var tz = new TimeZone.offset ((int) (9 * TimeSpan.HOUR / TimeSpan.SECOND));
    var dt = new DateTime (tz, 1979, 5, 27, 16, 32, 0.0);
    assert (Toml.format_offset_datetime (dt) == "1979-05-27T16:32:00+09:00");
}

void test_parse_offset_datetime_z () {
    try {
        var dt = Toml.parse_offset_datetime ("1979-05-27T07:32:00Z");
        assert (Toml.format_offset_datetime (dt) == "1979-05-27T07:32:00Z");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_offset_datetime_space_separator () {
    try {
        var dt = Toml.parse_offset_datetime ("1979-05-27 07:32:00Z");
        assert (Toml.format_offset_datetime (dt) == "1979-05-27T07:32:00Z");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_rejects_newline_injection () {
    bool threw = false;
    try {
        Toml.parse_offset_datetime ("1970-01-01T00:00:00Z\nx = 1");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_local_time_adds_seconds_on_format_roundtrip () {
    try {
        var t = Toml.parse_local_time ("07:32");
        assert (Toml.format_local_time (t) == "07:32:00");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_frac_truncated_to_usec () {
    try {
        var t = Toml.parse_local_time ("07:32:00.1234567");
        assert (t.microsecond == 123456);
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_local_date () {
    try {
        var d = Toml.parse_local_date ("1979-05-27");
        assert (Toml.format_local_date (d) == "1979-05-27");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_local_datetime_lowercase_separator () {
    try {
        var ldt = Toml.parse_local_datetime ("1979-05-27t07:32:00.999");
        assert (Toml.format_local_datetime (ldt) == "1979-05-27T07:32:00.999");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_offset_datetime_numeric_offset () {
    try {
        var dt = Toml.parse_offset_datetime ("1979-05-27T00:32:00-07:00");
        assert (Toml.format_offset_datetime (dt) == "1979-05-27T00:32:00-07:00");
    } catch (Toml.ParseError e) {
        assert_not_reached ();
    }
}

void test_parse_offset_datetime_rejects_bad_offset () {
    bool threw = false;
    try {
        Toml.parse_offset_datetime ("1979-05-27T07:32:00+24:00");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_offset_datetime_rejects_missing_offset () {
    bool threw = false;
    try {
        Toml.parse_offset_datetime ("1979-05-27T07:32:00");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_rejects_invalid_date () {
    bool threw = false;
    try {
        Toml.parse_local_date ("1979-02-29");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_rejects_second_60 () {
    bool threw = false;
    try {
        Toml.parse_local_time ("23:59:60");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

void test_values_equal_offset_datetime_same () {
    try {
        var tz = new TimeZone.utc ();
        var dt = new DateTime (tz, 1979, 5, 27, 7, 32, 0.0);
        var a = new OffsetDateTime (dt);
        var b = new OffsetDateTime (dt);
        assert (Toml.values_equal (a, b));
    } catch (Error e) {
        assert_not_reached ();
    }
}

void test_local_time_equal_to () {
    try {
        var a = new Toml.LocalTime (7, 32, 0, 999000);
        var b = new Toml.LocalTime (7, 32, 0, 999000);
        var c = new Toml.LocalTime (7, 32, 1, 0);
        assert (a.equal_to (b));
        assert (!a.equal_to (c));
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_local_date_equal_to () {
    try {
        Date d1 = Date ();
        d1.set_dmy (27, DateMonth.MAY, 1979);
        Date d2 = Date ();
        d2.set_dmy (27, DateMonth.MAY, 1979);
        Date d3 = Date ();
        d3.set_dmy (28, DateMonth.MAY, 1979);
        var a = new Toml.LocalDate (d1);
        var b = new Toml.LocalDate (d2);
        var c = new Toml.LocalDate (d3);
        assert (a.equal_to (b));
        assert (!a.equal_to (c));
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_local_datetime_equal_to () {
    try {
        Date d = Date ();
        d.set_dmy (27, DateMonth.MAY, 1979);
        var a = new Toml.LocalDateTime (d, new Toml.LocalTime (7, 32, 0));
        var b = new Toml.LocalDateTime (d, new Toml.LocalTime (7, 32, 0));
        var c = new Toml.LocalDateTime (d, new Toml.LocalTime (8, 0, 0));
        assert (a.equal_to (b));
        assert (!a.equal_to (c));
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_offset_datetime_equal_to () {
    try {
        var tz_utc = new TimeZone.utc ();
        var tz_minus7 = new TimeZone.offset ((int) (-7 * TimeSpan.HOUR / TimeSpan.SECOND));
        var a = new Toml.OffsetDateTime (new DateTime (tz_utc, 1979, 5, 27, 7, 32, 0.0));
        var b = new Toml.OffsetDateTime (new DateTime (tz_utc, 1979, 5, 27, 7, 32, 0.0));
        var c = new Toml.OffsetDateTime (new DateTime (tz_minus7, 1979, 5, 27, 0, 32, 0.0));
        assert (a.equal_to (b));
        assert (!a.equal_to (c));
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_values_equal_offset_datetime_different_offset () {
    try {
        var tz_utc = new TimeZone.utc ();
        var tz_minus7 = new TimeZone.offset ((int) (-7 * TimeSpan.HOUR / TimeSpan.SECOND));
        var a = new OffsetDateTime (new DateTime (tz_utc, 1979, 5, 27, 7, 32, 0.0));
        var b = new OffsetDateTime (new DateTime (tz_minus7, 1979, 5, 27, 7, 32, 0.0));
        assert (!Toml.values_equal (a, b));
    } catch (Error e) {
        assert_not_reached ();
    }
}

void test_parse_rejects_trailing_junk () {
    bool threw = false;
    try {
        Toml.parse_local_datetime ("1979-05-27T07:32:00Z");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/datetime/local_time_ok", test_local_time_ok);
    Test.add_func ("/toml/datetime/local_time_rejects_bad_hour", test_local_time_rejects_bad_hour);
    Test.add_func ("/toml/datetime/local_time_rejects_second_60", test_local_time_rejects_second_60);
    Test.add_func ("/toml/datetime/local_datetime_ok", test_local_datetime_ok);
    Test.add_func ("/toml/datetime/local_datetime_rejects_invalid_date", test_local_datetime_rejects_invalid_date);
    Test.add_func ("/toml/datetime/format_local_time_with_frac", test_format_local_time_with_frac);
    Test.add_func ("/toml/datetime/format_offset_datetime_z", test_format_offset_datetime_z);
    Test.add_func ("/toml/datetime/format_offset_datetime_numeric_offset", test_format_offset_datetime_numeric_offset);
    Test.add_func ("/toml/datetime/format_local_datetime_uses_T", test_format_local_datetime_uses_T);
    Test.add_func ("/toml/datetime/format_offset_datetime_positive_offset", test_format_offset_datetime_positive_offset);
    Test.add_func ("/toml/datetime/parse_offset_datetime_z", test_parse_offset_datetime_z);
    Test.add_func ("/toml/datetime/parse_offset_datetime_space_separator", test_parse_offset_datetime_space_separator);
    Test.add_func ("/toml/datetime/parse_rejects_newline_injection", test_parse_rejects_newline_injection);
    Test.add_func ("/toml/datetime/parse_local_time_adds_seconds_on_format_roundtrip", test_parse_local_time_adds_seconds_on_format_roundtrip);
    Test.add_func ("/toml/datetime/parse_frac_truncated_to_usec", test_parse_frac_truncated_to_usec);
    Test.add_func ("/toml/datetime/parse_local_date", test_parse_local_date);
    Test.add_func ("/toml/datetime/parse_local_datetime_lowercase_separator", test_parse_local_datetime_lowercase_separator);
    Test.add_func ("/toml/datetime/parse_offset_datetime_numeric_offset", test_parse_offset_datetime_numeric_offset);
    Test.add_func ("/toml/datetime/parse_offset_datetime_rejects_bad_offset", test_parse_offset_datetime_rejects_bad_offset);
    Test.add_func ("/toml/datetime/parse_offset_datetime_rejects_missing_offset", test_parse_offset_datetime_rejects_missing_offset);
    Test.add_func ("/toml/datetime/parse_rejects_invalid_date", test_parse_rejects_invalid_date);
    Test.add_func ("/toml/datetime/parse_rejects_second_60", test_parse_rejects_second_60);
    Test.add_func ("/toml/datetime/parse_rejects_trailing_junk", test_parse_rejects_trailing_junk);
    Test.add_func ("/toml/datetime/local_time_equal_to", test_local_time_equal_to);
    Test.add_func ("/toml/datetime/local_date_equal_to", test_local_date_equal_to);
    Test.add_func ("/toml/datetime/local_datetime_equal_to", test_local_datetime_equal_to);
    Test.add_func ("/toml/datetime/offset_datetime_equal_to", test_offset_datetime_equal_to);
    Test.add_func ("/toml/datetime/values_equal_offset_datetime_same", test_values_equal_offset_datetime_same);
    Test.add_func ("/toml/datetime/values_equal_offset_datetime_different_offset", test_values_equal_offset_datetime_different_offset);
    return Test.run ();
}
