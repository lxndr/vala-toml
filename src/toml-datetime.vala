namespace Toml {
    public class LocalTime {
        public int hour { get; private set; }
        public int minute { get; private set; }
        public int second { get; private set; }
        public int microsecond { get; private set; }

        public LocalTime (int hour, int minute, int second, int microsecond = 0) throws ValueError {
            if (hour < 0 || hour > 23) {
                throw new ValueError.INVALID ("hour out of range");
            }
            if (minute < 0 || minute > 59) {
                throw new ValueError.INVALID ("minute out of range");
            }
            if (second < 0 || second > 59) {
                throw new ValueError.INVALID ("second out of range");
            }
            if (microsecond < 0 || microsecond > 999999) {
                throw new ValueError.INVALID ("microsecond out of range");
            }

            this.hour = hour;
            this.minute = minute;
            this.second = second;
            this.microsecond = microsecond;
        }
    }

    public class LocalDateTime {
        public Date date { get; private set; }
        public LocalTime time { get; private set; }

        public LocalDateTime (Date date, LocalTime time) throws ValueError {
            if (!date.valid ()) {
                throw new ValueError.INVALID ("invalid date");
            }

            this.date = date;
            this.time = time;
        }
    }

    public bool local_time_equal (LocalTime a, LocalTime b) {
        return a.hour == b.hour
            && a.minute == b.minute
            && a.second == b.second
            && a.microsecond == b.microsecond;
    }

    public bool local_datetime_equal (LocalDateTime a, LocalDateTime b) {
        return a.date.get_year () == b.date.get_year ()
            && a.date.get_month () == b.date.get_month ()
            && a.date.get_day () == b.date.get_day ()
            && local_time_equal (a.time, b.time);
    }

    private class DateTimeScanner {
        private string text;
        private int pos;

        public DateTimeScanner (string text) {
            this.text = text;
            this.pos = 0;
        }

        private unichar peek () {
            return text.get_char (pos);
        }

        private void fail (string message) throws ParseError {
            throw new ParseError.FAILED (message);
        }

        private int read_digits (int count, string component) throws ParseError {
            int value = 0;
            for (int i = 0; i < count; i++) {
                if (pos >= text.length) {
                    fail ("incomplete %s".printf (component));
                }
                unichar c = peek ();
                if (c < '0' || c > '9') {
                    fail ("invalid %s".printf (component));
                }
                value = value * 10 + (int) (c - '0');
                pos++;
            }
            return value;
        }

        private void expect (unichar expected, string message) throws ParseError {
            if (pos >= text.length || peek () != expected) {
                fail (message);
            }
            pos++;
        }

        private static int days_in_month (int year, int month) {
            switch (month) {
            case 1: case 3: case 5: case 7: case 8: case 10: case 12:
                return 31;
            case 4: case 6: case 9: case 11:
                return 30;
            case 2:
                return ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) ? 29 : 28;
            default:
                return 0;
            }
        }

        public Date parse_date () throws ParseError {
            int year = read_digits (4, "year");
            expect ('-', "expected '-' after year");
            int month = read_digits (2, "month");
            expect ('-', "expected '-' after month");
            int day = read_digits (2, "day");

            if (year < 1 || month < 1 || month > 12
                || day < 1 || day > days_in_month (year, month)) {
                fail ("invalid date");
            }

            Date date = Date ();
            date.set_dmy ((DateDay) day, (DateMonth) month, (DateYear) year);
            return date;
        }

        public LocalTime parse_time () throws ParseError {
            int hour = read_digits (2, "hour");
            expect (':', "expected ':' after hour");
            int minute = read_digits (2, "minute");
            int second = 0;
            int microsecond = 0;

            if (pos < text.length && peek () == ':') {
                pos++;
                second = read_digits (2, "second");
                if (pos < text.length && peek () == '.') {
                    pos++;
                    int digits = 0;
                    while (pos < text.length) {
                        unichar c = peek ();
                        if (c < '0' || c > '9') {
                            break;
                        }
                        if (digits < 6) {
                            microsecond = microsecond * 10 + (int) (c - '0');
                        }
                        digits++;
                        pos++;
                    }
                    if (digits == 0) {
                        fail ("fractional seconds require digits");
                    }
                    while (digits < 6) {
                        microsecond *= 10;
                        digits++;
                    }
                }
            }

            if (hour > 23 || minute > 59 || second > 59) {
                fail ("invalid time");
            }

            try {
                return new LocalTime (hour, minute, second, microsecond);
            } catch (ValueError e) {
                fail (e.message);
                assert_not_reached ();
            }
        }

        public LocalDateTime parse_datetime () throws ParseError {
            Date date = parse_date ();
            if (pos >= text.length) {
                fail ("missing date-time separator");
            }
            unichar separator = peek ();
            if (separator != 'T' && separator != 't' && separator != ' ') {
                fail ("invalid date-time separator");
            }
            pos++;
            LocalTime time = parse_time ();

            try {
                return new LocalDateTime (date, time);
            } catch (ValueError e) {
                fail (e.message);
                assert_not_reached ();
            }
        }

        public TimeZone parse_offset () throws ParseError {
            if (pos >= text.length) {
                fail ("offset date-time requires an offset");
            }
            unichar marker = peek ();
            if (marker == 'Z' || marker == 'z') {
                pos++;
                return new TimeZone.utc ();
            }
            if (marker != '+' && marker != '-') {
                fail ("invalid date-time offset");
            }
            pos++;
            int hours = read_digits (2, "offset hour");
            expect (':', "expected ':' in date-time offset");
            int minutes = read_digits (2, "offset minute");
            if (hours > 23 || minutes > 59) {
                fail ("invalid date-time offset");
            }

            int seconds = (int) (
                (hours * TimeSpan.HOUR + minutes * TimeSpan.MINUTE) / TimeSpan.SECOND);
            if (marker == '-') {
                seconds = -seconds;
            }
            return new TimeZone.offset (seconds);
        }

        public void expect_end () throws ParseError {
            if (pos != text.length) {
                fail ("trailing characters in date-time");
            }
        }
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal DateTime parse_offset_datetime (string text) throws ParseError {
        var scanner = new DateTimeScanner (text);
        var local = scanner.parse_datetime ();
        var timezone = scanner.parse_offset ();
        scanner.expect_end ();
        return new DateTime (
            timezone,
            local.date.get_year (),
            local.date.get_month (),
            local.date.get_day (),
            local.time.hour,
            local.time.minute,
            local.time.second + local.time.microsecond / 1000000.0
        );
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal LocalDateTime parse_local_datetime (string text) throws ParseError {
        var scanner = new DateTimeScanner (text);
        var datetime = scanner.parse_datetime ();
        scanner.expect_end ();
        return datetime;
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal Date parse_local_date (string text) throws ParseError {
        var scanner = new DateTimeScanner (text);
        Date date = scanner.parse_date ();
        scanner.expect_end ();
        return date;
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal LocalTime parse_local_time (string text) throws ParseError {
        var scanner = new DateTimeScanner (text);
        var time = scanner.parse_time ();
        scanner.expect_end ();
        return time;
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string format_fractional_usec (int usec) {
        if (usec <= 0) {
            return "";
        }
        string s = "%06d".printf (usec);
        while (s.length > 1 && s.has_suffix ("0")) {
            s = s.substring (0, s.length - 1);
        }
        return "." + s;
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string format_local_time (LocalTime t) {
        return "%02d:%02d:%02d".printf (t.hour, t.minute, t.second)
            + format_fractional_usec (t.microsecond);
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string format_local_date (Date d) {
        return "%04d-%02d-%02d".printf (d.get_year (), d.get_month (), d.get_day ());
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string format_local_datetime (LocalDateTime ldt) {
        return format_local_date (ldt.date) + "T" + format_local_time (ldt.time);
    }

    [CCode (cheader_filename = "vala-toml-internal.h")]
    internal string format_offset_datetime (DateTime dt) {
        string datetime = "%04d-%02d-%02dT%02d:%02d:%02d".printf (
            dt.get_year (),
            dt.get_month (),
            dt.get_day_of_month (),
            dt.get_hour (),
            dt.get_minute (),
            dt.get_second ()
        ) + format_fractional_usec (dt.get_microsecond ());

        var offset = dt.get_utc_offset ();
        if (offset == 0) {
            return datetime + "Z";
        }

        int total_seconds = (int) (offset / TimeSpan.SECOND);
        bool negative = total_seconds < 0;
        int abs_seconds = negative ? -total_seconds : total_seconds;
        int hours = abs_seconds / 3600;
        int minutes = (abs_seconds % 3600) / 60;
        string sign = negative ? "-" : "+";
        return datetime + "%s%02d:%02d".printf (sign, hours, minutes);
    }
}
