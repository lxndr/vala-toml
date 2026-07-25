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

void test_format_local_datetime_space_input_normalized_on_format_only () {
    try {
        Date d = Date ();
        d.set_dmy ((DateDay) 27, DateMonth.MAY, (DateYear) 1979);
        var ldt = new Toml.LocalDateTime (d, new Toml.LocalTime (7, 32, 0));
        assert (Toml.format_local_datetime (ldt) == "1979-05-27T07:32:00");
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
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
    Test.add_func ("/toml/datetime/format_local_datetime_space_input_normalized_on_format_only", test_format_local_datetime_space_input_normalized_on_format_only);
    return Test.run ();
}
