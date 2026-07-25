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
}
