final class EverTTL {
  const EverTTL(this.value);

  factory EverTTL.seconds(int seconds) => EverTTL(Duration(seconds: seconds));
  factory EverTTL.minutes(int minutes) => EverTTL(Duration(minutes: minutes));
  factory EverTTL.hours(int hours) => EverTTL(Duration(hours: hours));
  factory EverTTL.days(int days) => EverTTL(Duration(days: days));
  factory EverTTL.weeks(int weeks) => EverTTL(Duration(days: weeks * 7));
  factory EverTTL.months(int months) => EverTTL(Duration(days: months * 30));
  factory EverTTL.years(int years) => EverTTL(Duration(days: years * 365));

  final Duration value;
}
