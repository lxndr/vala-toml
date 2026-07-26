namespace Toml {
    public class LocalTime : Value {
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

        public bool equal_to (LocalTime other) {
            return this.hour == other.hour
                && this.minute == other.minute
                && this.second == other.second
                && this.microsecond == other.microsecond;
        }
    }
}
