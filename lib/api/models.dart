import '../config.dart';

/// Момент из ISO-строки сервера → время Ташкента.
DateTime toTashkent(String iso) => DateTime.parse(iso).toUtc().add(AppConfig.tashkentOffset);

double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

class Employee {
  final String code;
  final String fullName;
  final String post;
  final String phone;

  Employee.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        fullName = j['fullName'] as String? ?? '',
        post = j['post'] as String? ?? '',
        phone = j['phone'] as String? ?? '';
}

class Office {
  final int id;
  final String name;
  final double? lat;
  final double? lon;
  final int radiusM;

  Office.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        name = j['name'] as String? ?? '',
        lat = _num(j['lat']),
        lon = _num(j['lon']),
        radiusM = (j['radiusM'] as num?)?.toInt() ?? 100;
}

class Today {
  final String date;
  final bool isWorkingDay;
  final String? holiday;

  Today.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String,
        isWorkingDay = j['isWorkingDay'] as bool? ?? false,
        holiday = j['holiday'] as String?;
}

class Me {
  final Employee employee;
  final Office? office;
  final Today today;

  Me.fromJson(Map<String, dynamic> j)
      : employee = Employee.fromJson(j['employee'] as Map<String, dynamic>),
        office = j['department'] == null
            ? null
            : Office.fromJson(j['department'] as Map<String, dynamic>),
        today = Today.fromJson(j['today'] as Map<String, dynamic>);
}

class CalendarDay {
  final String date;
  final bool isWorkingDay;
  final String? holiday;

  CalendarDay.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String,
        isWorkingDay = j['isWorkingDay'] as bool? ?? false,
        holiday = j['holiday'] as String?;
}

class WorkType {
  final int id;
  final String nameCyr;
  final String nameLat;
  final String nameRu;

  WorkType.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        nameCyr = j['nameCyr'] as String? ?? '',
        nameLat = j['nameLat'] as String? ?? '',
        nameRu = j['nameRu'] as String? ?? '';

  /// Название на языке приложения; пустой перевод — кириллица.
  String name(String lang) {
    if (lang == 'ru' && nameRu.isNotEmpty) return nameRu;
    if (lang == 'uz' && nameLat.isNotEmpty) return nameLat;
    return nameCyr;
  }
}

enum JobKind { offline, online }

class JobPhoto {
  final int id;
  final String url;

  JobPhoto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        url = j['url'] as String;
}

class Job {
  final int id;
  final JobKind kind;
  final WorkType? workType;
  final String orgName;
  final String description;
  final String? murojaatNo;
  final String? applicantName;
  final String? applicantPhone;
  final String? address;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String workDate;
  final List<JobPhoto> photos;

  Job.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        kind = j['kind'] == 'online' ? JobKind.online : JobKind.offline,
        workType = j['workType'] is Map<String, dynamic>
            ? WorkType.fromJson(j['workType'] as Map<String, dynamic>)
            : null,
        orgName = j['orgName'] as String? ?? '',
        description = j['description'] as String? ?? '',
        murojaatNo = j['murojaatNo'] as String?,
        applicantName = j['applicantName'] as String?,
        applicantPhone = j['applicantPhone'] as String?,
        address = j['address'] as String?,
        startedAt = toTashkent(j['startedAt'] as String),
        finishedAt = toTashkent(j['finishedAt'] as String),
        workDate = j['workDate'] as String? ?? '',
        photos = ((j['photos'] as List?) ?? [])
            .map((p) => JobPhoto.fromJson(p as Map<String, dynamic>))
            .toList();
}

class PeriodStats {
  final int offline;
  final int online;
  final double amal;
  final double plan;
  final int? percent;

  PeriodStats.fromJson(Map<String, dynamic> j)
      : offline = (j['offline'] as num?)?.toInt() ?? 0,
        online = (j['online'] as num?)?.toInt() ?? 0,
        amal = (j['amal'] as num?)?.toDouble() ?? 0,
        plan = (j['plan'] as num?)?.toDouble() ?? 0,
        percent = (j['percent'] as num?)?.toInt();
}

class Stats {
  final int norm;
  final PeriodStats day;
  final PeriodStats week;
  final PeriodStats month;

  Stats.fromJson(Map<String, dynamic> j)
      : norm = (j['norm'] as num?)?.toInt() ?? 0,
        day = PeriodStats.fromJson(j['day'] as Map<String, dynamic>),
        week = PeriodStats.fromJson(j['week'] as Map<String, dynamic>),
        month = PeriodStats.fromJson(j['month'] as Map<String, dynamic>);
}

/// Новая работа для отправки на сервер.
class NewJob {
  final JobKind kind;
  final int workTypeId;
  final String orgName;
  final String description;
  final String? murojaatNo;
  final String? applicantName;
  final String? applicantPhone;
  final String? address;
  final double? lat;
  final double? lon;
  final DateTime startedAt;
  final DateTime finishedAt;

  const NewJob({
    required this.kind,
    required this.workTypeId,
    required this.orgName,
    required this.description,
    this.murojaatNo,
    this.applicantName,
    this.applicantPhone,
    this.address,
    this.lat,
    this.lon,
    required this.startedAt,
    required this.finishedAt,
  });

  Map<String, String> toFields() => {
        'kind': kind.name,
        'workTypeId': '$workTypeId',
        'orgName': orgName,
        'description': description,
        if (murojaatNo != null && murojaatNo!.isNotEmpty) 'murojaatNo': murojaatNo!,
        if (applicantName != null && applicantName!.isNotEmpty) 'applicantName': applicantName!,
        if (applicantPhone != null && applicantPhone!.isNotEmpty) 'applicantPhone': applicantPhone!,
        if (address != null && address!.isNotEmpty) 'address': address!,
        if (lat != null) 'lat': '$lat',
        if (lon != null) 'lon': '$lon',
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
      };
}

class AttendanceOffice {
  final String name;
  final double lat;
  final double lon;
  final int radiusM;

  AttendanceOffice.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String? ?? '',
        lat = (j['lat'] as num?)?.toDouble() ?? 0.0,
        lon = (j['lon'] as num?)?.toDouble() ?? 0.0,
        radiusM = (j['radiusM'] as num?)?.toInt() ?? 100;
}

class AttendanceCheckIn {
  final String at;
  final String time;
  final bool late;
  final int lateMinutes;
  final int? distanceM;

  AttendanceCheckIn.fromJson(Map<String, dynamic> j)
      : at = j['at'] as String? ?? '',
        time = j['time'] as String? ?? '',
        late = j['late'] as bool? ?? false,
        lateMinutes = (j['lateMinutes'] as num?)?.toInt() ?? 0,
        distanceM = (j['distanceM'] as num?)?.toInt();
}

class AttendanceCheckOut {
  final String at;
  final String time;
  final bool early;

  AttendanceCheckOut.fromJson(Map<String, dynamic> j)
      : at = j['at'] as String? ?? '',
        time = j['time'] as String? ?? '',
        early = j['early'] as bool? ?? false;
}

class AttendancePair {
  final String inTime;
  final String? outTime;

  AttendancePair.fromJson(Map<String, dynamic> j)
      : inTime = (j['in'] ?? j['inTime']) as String? ?? '',
        outTime = (j['out'] ?? j['outTime']) as String?;
}

class AttendanceExcuse {
  final String kind;
  final String reason;
  final String? dateFrom;
  final String? dateTo;

  AttendanceExcuse.fromJson(Map<String, dynamic> j)
      : kind = j['kind'] as String? ?? '',
        reason = j['reason'] as String? ?? '',
        dateFrom = j['dateFrom'] as String?,
        dateTo = j['dateTo'] as String?;
}

class AttendanceToday {
  final String date;
  final bool isWorkingDay;
  final String? holiday;
  final String workStart;
  final String workEnd;
  final int toleranceMin;
  final AttendanceOffice? office;
  final AttendanceCheckIn? checkIn;
  final AttendanceCheckOut? checkOut;
  final bool? inside;
  final List<AttendancePair> pairs;
  final int insideMinutes;
  final AttendanceExcuse? excuse;
  final bool canCheckIn;
  final bool canCheckOut;

  AttendanceToday.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String? ?? '',
        isWorkingDay = j['isWorkingDay'] as bool? ?? false,
        holiday = j['holiday'] as String?,
        workStart = j['workStart'] as String? ?? '09:00',
        workEnd = j['workEnd'] as String? ?? '18:00',
        toleranceMin = (j['toleranceMin'] as num?)?.toInt() ?? 5,
        office = j['office'] is Map<String, dynamic>
            ? AttendanceOffice.fromJson(j['office'] as Map<String, dynamic>)
            : null,
        checkIn = j['checkIn'] is Map<String, dynamic>
            ? AttendanceCheckIn.fromJson(j['checkIn'] as Map<String, dynamic>)
            : null,
        checkOut = j['checkOut'] is Map<String, dynamic>
            ? AttendanceCheckOut.fromJson(j['checkOut'] as Map<String, dynamic>)
            : null,
        inside = j['inside'] as bool?,
        pairs = ((j['pairs'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AttendancePair.fromJson)
            .toList(),
        insideMinutes = (j['insideMinutes'] as num?)?.toInt() ?? 0,
        excuse = j['excuse'] is Map<String, dynamic>
            ? AttendanceExcuse.fromJson(j['excuse'] as Map<String, dynamic>)
            : null,
        canCheckIn = j['canCheckIn'] as bool? ?? false,
        canCheckOut = j['canCheckOut'] as bool? ?? false;
}

class AttendanceHistoryDay {
  final String date;
  final String status;
  final String? holiday;
  final String? checkIn;
  final String? checkOut;
  final int lateMinutes;
  final AttendanceExcuse? excuse;

  AttendanceHistoryDay.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String? ?? '',
        status = j['status'] as String? ?? '',
        holiday = j['holiday'] as String?,
        checkIn = j['checkIn'] as String?,
        checkOut = j['checkOut'] as String?,
        lateMinutes = (j['lateMinutes'] as num?)?.toInt() ?? 0,
        excuse = j['excuse'] is Map<String, dynamic>
            ? AttendanceExcuse.fromJson(j['excuse'] as Map<String, dynamic>)
            : null;
}
