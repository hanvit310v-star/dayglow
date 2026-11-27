// 화면 문구 · 영어 날짜 형식 — 버튼·제목·날짜는 영어로 (모던한 느낌)
// 긴 안내 문장(권한·오류·개인정보)은 이해하기 쉽게 한국어로 둠
// 다른 언어를 추가하려면 이 파일을 기준으로 나누면 돼요
import '../core/calendar_logic.dart';

const weekdayShortEn = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const weekdayTitleEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const weekdayLongEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const monthLongEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 'Nov 26'
String enMonthDay(String ds) {
  final d = parseYmd(ds);
  return '${monthShortEn[d.month - 1]} ${d.day}';
}

/// 'Nov 26, 2026'
String enFullDate(DateTime d) => '${monthShortEn[d.month - 1]} ${d.day}, ${d.year}';

/// 'Thu, Nov 26'
String enDayLabel(String ds) => '${weekdayTitleEn[weekdayIndex(parseYmd(ds))]}, ${enMonthDay(ds)}';
