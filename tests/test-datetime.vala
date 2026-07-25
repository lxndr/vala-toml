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

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/datetime/local_time_ok", test_local_time_ok);
    Test.add_func ("/toml/datetime/local_time_rejects_bad_hour", test_local_time_rejects_bad_hour);
    Test.add_func ("/toml/datetime/local_time_rejects_second_60", test_local_time_rejects_second_60);
    Test.add_func ("/toml/datetime/local_datetime_ok", test_local_datetime_ok);
    Test.add_func ("/toml/datetime/local_datetime_rejects_invalid_date", test_local_datetime_rejects_invalid_date);
    return Test.run ();
}
