/// A class representing the time-to-live (TTL) for a cache entry.
///
/// This class encapsulates a [Duration] object that represents the lifespan
/// of a cache entry. Once the TTL expires, the cache entry is considered stale
/// and can be recomputed or removed.
///
/// The class provides several factory constructors to create a TTL from
/// different time units such as seconds, minutes, hours, days, weeks, months,
/// and years. This makes it easy to specify the TTL in the unit that best
/// matches the desired cache duration.
///
/// Example:
/// ```dart
/// var ttlInSeconds = EverTTL.seconds(30); // TTL of 30 seconds
/// var ttlInDays = EverTTL.days(1); // TTL of 1 day
/// ```
///
/// The actual duration of months and years is approximated to 30 and 365 days
/// respectively, which may not accurately reflect the exact duration due to
/// variations in month lengths and leap years.
final class EverTTL {
  /// Constructs a [EverTTL] instance with a given [Duration].
  const EverTTL(this.value);

  /// Creates a [EverTTL] instance representing a number of days.
  factory EverTTL.days(int days) => EverTTL(Duration(days: days));

  /// Creates a [EverTTL] instance representing a number of hours.
  factory EverTTL.hours(int hours) => EverTTL(Duration(hours: hours));

  /// Creates a [EverTTL] instance representing a number of minutes.
  factory EverTTL.minutes(int minutes) => EverTTL(Duration(minutes: minutes));

  /// Creates a [EverTTL] instance representing a number of months.
  /// Assumes an average month duration of 30 days.
  factory EverTTL.months(int months) => EverTTL(Duration(days: months * 30));

  /// Creates a [EverTTL] instance representing a number of seconds.
  factory EverTTL.seconds(int seconds) => EverTTL(Duration(seconds: seconds));

  /// Creates a [EverTTL] instance representing a number of weeks.
  factory EverTTL.weeks(int weeks) => EverTTL(Duration(days: weeks * 7));

  /// Creates a [EverTTL] instance representing a number of years.
  /// Assumes a year duration of 365 days.
  factory EverTTL.years(int years) => EverTTL(Duration(days: years * 365));

  /// The duration of the TTL.
  final Duration value;
}
