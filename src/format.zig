const std = @import("std");

pub const Layout = "01/02 03:04:05PM '06 -0700"; // The reference time, in numerical order.
pub const ANSIC = "Mon Jan _2 15:04:05 2006";
pub const UnixDate = "Mon Jan _2 15:04:05 MST 2006";
pub const RubyDate = "Mon Jan 02 15:04:05 -0700 2006";
pub const RFC822 = "02 Jan 06 15:04 MST";
pub const RFC822Z = "02 Jan 06 15:04 -0700"; // RFC822 with numeric zone
pub const RFC850 = "Monday, 02-Jan-06 15:04:05 MST";
pub const RFC1123 = "Mon, 02 Jan 2006 15:04:05 MST";
pub const RFC1123Z = "Mon, 02 Jan 2006 15:04:05 -0700"; // RFC1123 with numeric zone
pub const RFC3339 = "2006-01-02T15:04:05Z07:00";
pub const RFC3339Nano = "2006-01-02T15:04:05.999999999Z07:00";
pub const Kitchen = "3:04PM";

// Handy time stamps.
pub const Stamp = "Jan _2 15:04:05";
pub const StampMilli = "Jan _2 15:04:05.000";
pub const StampMicro = "Jan _2 15:04:05.000000";
pub const StampNano = "Jan _2 15:04:05.000000000";
pub const DateTime = "2006-01-02 15:04:05";
pub const DateOnly = "2006-01-02";
pub const TimeOnly = "15:04:05";

pub const stdLongMonth = 1 + stdNeedDate; // "January"
pub const stdMonth = 2 + stdNeedDate; // "Jan"
pub const stdNumMonth = 3 + stdNeedDate; // "1"
pub const stdZeroMonth = 4 + stdNeedDate; // "01"
pub const stdLongWeekDay = 5 + stdNeedDate; // "Monday"
pub const stdWeekDay = 6 + stdNeedDate; // "Mon"
pub const stdDay = 7 + stdNeedDate; // "2"
pub const stdUnderDay = 8 + stdNeedDate; // "_2"
pub const stdZeroDay = 9 + stdNeedDate; // "02"
pub const stdUnderYearDay = 10 + stdNeedDate; // "__2"
pub const stdZeroYearDay = 11 + stdNeedDate; // "002"
pub const stdHour = 12 + stdNeedClock; // "15"
pub const stdHour12 = 13 + stdNeedClock; // "3"
pub const stdZeroHour12 = 14 + stdNeedClock; // "03"
pub const stdMinute = 15 + stdNeedClock; // "4"
pub const stdZeroMinute = 16 + stdNeedClock; // "04"
pub const stdSecond = 17 + stdNeedClock; // "5"
pub const stdZeroSecond = 18 + stdNeedClock; // "05"
pub const stdLongYear = 19 + stdNeedDate; // "2006"
pub const stdYear = 20 + stdNeedDate; // "06"
pub const stdPM = 21 + stdNeedClock; // "PM"
pub const stdpm = 22 + stdNeedClock; // "pm"
pub const stdTZ = 23; // "MST"
pub const stdISO8601TZ = 24; // "Z0700"  // prints Z for UTC
pub const stdISO8601SecondsTZ = 25; // "Z070000"
pub const stdISO8601ShortTZ = 26; // "Z07"
pub const stdISO8601ColonTZ = 27; // "Z07:00" // prints Z for UTC
pub const stdISO8601ColonSecondsTZ = 28; // "Z07:00:00"
pub const stdNumTZ = 29; // "-0700"  // always numeric
pub const stdNumSecondsTz = 30; // "-070000"
pub const stdNumShortTZ = 31; // "-07"    // always numeric
pub const stdNumColonTZ = 32; // "-07:00" // always numeric
pub const stdNumColonSecondsTZ = 33; // "-07:00:00"
pub const stdFracSecond0 = 34; // ".0", ".00", ... , trailing zeros included
pub const stdFracSecond9 = 35; // ".9", ".99", ..., trailing zeros omitted

pub const stdNeedDate = 1 << 8; // need month, day, year
pub const stdNeedClock = 2 << 8; // need hour, minute, second
pub const stdArgShift = 16; // extra argument in high bits, above low stdArgShift
pub const stdSeparatorShift = 28; // extra argument in high 4 bits for fractional second separators
pub const stdMask = 1 << stdArgShift - 1; // mask out argument

// std0x records the std values for "01", "02", ..., "06".
const std0x = [6]i32{ stdZeroMonth, stdZeroDay, stdZeroHour12, stdZeroMinute, stdZeroSecond, stdYear };
