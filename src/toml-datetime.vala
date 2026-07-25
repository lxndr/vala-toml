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
