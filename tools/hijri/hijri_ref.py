"""مرجع التقويم الهجري الجدولي (Python). يُنقل حرفياً إلى lib/core/calendar/hijri_calendar.dart.

التقويم الجدولي (حسابي): دورة ٣٠ سنة فيها ١١ سنة كبيسة (٢،٥،٧،١٠،١٣،١٦،١٨،٢١،٢٤،٢٦،٢٩)،
الأشهر ٣٠/٢٩ بالتناوب، وذو الحجة ٣٠ في الكبيسة. ليس رصداً للهلال ولا هو جدول أم القرى الرسمي.
قد يختلف عنهما يوماً أو يومين. نعتمد العصر الفلكي (الخميس ١٥ يوليو ٦٢٢ جوليان) لأنه الأقرب لأم القرى
في العينة المنشورة (٧ من ١١ تاريخاً متطابقة تماماً والباقي بفارق يوم)، مقابل ٥ من ١١ للعصر المدني.
"""
import math

# رقم اليوم الجولياني (JDN) ليوم 1 محرم 1 هـ. المدني (الجمعة) = 1948440، الفلكي (الخميس) = 1948439.
EPOCH_CIVIL = 1948440
EPOCH_ASTRONOMICAL = 1948439
EPOCH = EPOCH_ASTRONOMICAL
LEAP_YEARS_IN_CYCLE = (2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29)
MONTHS_AR = ("محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
             "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة")
MAX_OFFSET_DAYS = 3


def gregorian_to_jdn(y, m, d):
    a = (14 - m) // 12
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    return d + (153 * mm + 2) // 5 + 365 * yy + yy // 4 - yy // 100 + yy // 400 - 32045


def jdn_to_gregorian(jdn):
    a = jdn + 32044
    b = (4 * a + 3) // 146097
    c = a - 146097 * b // 4
    d = (4 * c + 3) // 1461
    e = c - 1461 * d // 4
    m = (5 * e + 2) // 153
    day = e - (153 * m + 2) // 5 + 1
    month = m + 3 - 12 * (m // 10)
    year = 100 * b + d - 4800 + m // 10
    return year, month, day


def is_leap(year):
    return (14 + 11 * year) % 30 < 11


def month_length(year, month):
    if month % 2 == 1:
        return 30
    if month == 12 and is_leap(year):
        return 30
    return 29


def islamic_to_jdn(y, m, d, epoch=None):
    ep = EPOCH if epoch is None else epoch
    return d + math.ceil(29.5 * (m - 1)) + (y - 1) * 354 + (3 + 11 * y) // 30 + ep - 1


def jdn_to_islamic(jdn, epoch=None):
    ep = EPOCH if epoch is None else epoch
    if jdn < ep:
        raise ValueError("التاريخ قبل بداية التقويم الهجري")
    y = (30 * (jdn - ep) + 10646) // 10631
    m = min(12, math.ceil((jdn - (29 + islamic_to_jdn(y, 1, 1, ep))) / 29.5) + 1)
    d = jdn - islamic_to_jdn(y, m, 1, ep) + 1
    return y, m, d


def hijri_from_gregorian(y, m, d, offset_days=0):
    """التاريخ الهجري ليوم ميلادي، مع تصحيح يدوي بالأيام (موجب = تقديم)."""
    return jdn_to_islamic(gregorian_to_jdn(y, m, d) + offset_days)


def gregorian_from_hijri(y, m, d, offset_days=0):
    return jdn_to_gregorian(islamic_to_jdn(y, m, d) - offset_days)
