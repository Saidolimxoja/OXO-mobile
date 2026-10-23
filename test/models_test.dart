import 'package:flutter_test/flutter_test.dart';
import 'package:oxo_mobile/api/api_client.dart';
import 'package:oxo_mobile/api/models.dart';
import 'package:oxo_mobile/services/track_service.dart';

void main() {
  test('работа с сервера: время переводится в Ташкент, фото и вид работы читаются', () {
    final job = Job.fromJson({
      'id': 1,
      'kind': 'offline',
      'workType': {'id': 2, 'nameCyr': 'Техник ёрдам', 'nameLat': 'Texnik yordam', 'nameRu': 'Техническая помощь'},
      'orgName': '12-мактаб',
      'description': 'Принтер',
      'murojaatNo': null,
      'startedAt': '2026-10-22T05:00:00.000Z',
      'finishedAt': '2026-10-22T05:40:00.000Z',
      'workDate': '2026-10-22',
      'photos': [
        {'id': 7, 'takenAt': null, 'url': '/api/mobile/jobs/1/photos/7'},
      ],
    });

    expect(job.kind, JobKind.offline);
    expect(job.startedAt.hour, 10);
    expect(job.finishedAt.minute, 40);
    expect(job.workType!.name('uz'), 'Texnik yordam');
    expect(job.workType!.name('uzc'), 'Техник ёрдам');
    expect(job.photos.single.id, 7);
  });

  test('новая работа: пустые необязательные поля не отправляются, время в UTC', () {
    final fields = NewJob(
      kind: JobKind.online,
      workTypeId: 3,
      orgName: 'Ҳокимлик',
      description: 'AnyDesk',
      murojaatNo: '',
      startedAt: DateTime.utc(2026, 10, 22, 9),
      finishedAt: DateTime.utc(2026, 10, 22, 9, 20),
    ).toFields();

    expect(fields['kind'], 'online');
    expect(fields['workTypeId'], '3');
    expect(fields.containsKey('murojaatNo'), isFalse);
    expect(fields.containsKey('lat'), isFalse);
    expect(fields['startedAt'], '2026-10-22T09:00:00.000Z');
  });

  test('рабочее время 09:00–18:00 по Ташкенту', () {
    expect(TrackService.inWorkTime(DateTime(2026, 10, 22, 8, 59)), isFalse);
    expect(TrackService.inWorkTime(DateTime(2026, 10, 22, 9, 0)), isTrue);
    expect(TrackService.inWorkTime(DateTime(2026, 10, 22, 17, 59)), isTrue);
    expect(TrackService.inWorkTime(DateTime(2026, 10, 22, 18, 0)), isFalse);
  });

  test('сводка: процента нет без плана', () {
    final stats = Stats.fromJson({
      'date': '2026-10-24',
      'norm': 4,
      'day': {'offline': 1, 'online': 1, 'amal': 1.5, 'plan': 0, 'percent': null},
      'week': {'offline': 3, 'online': 2, 'amal': 4, 'plan': 16, 'percent': 25},
      'month': {'offline': 3, 'online': 2, 'amal': 4, 'plan': 64, 'percent': 6},
    });

    expect(stats.day.percent, isNull);
    expect(stats.day.amal, 1.5);
    expect(stats.week.percent, 25);
  });

  test('AttendanceToday: разбор полного JSON из контракта', () {
    final today = AttendanceToday.fromJson({
      'date': '2026-10-23',
      'isWorkingDay': true,
      'holiday': null,
      'workStart': '09:00',
      'workEnd': '18:00',
      'toleranceMin': 5,
      'office': {
        'name': 'Бош офис',
        'lat': 41.311081,
        'lon': 69.240562,
        'radiusM': 150,
      },
      'checkIn': {
        'at': '2026-10-23T04:12:00.000Z',
        'time': '09:12',
        'late': true,
        'lateMinutes': 12,
        'distanceM': 45,
      },
      'checkOut': {
        'at': '2026-10-23T13:05:00.000Z',
        'time': '18:05',
        'early': false,
      },
      'inside': true,
      'pairs': [
        {'in': '09:12', 'out': '12:30'},
        {'in': '13:30', 'out': null},
      ],
      'insideMinutes': 210,
      'excuse': {
        'kind': 'late',
        'reason': 'doctor',
        'dateFrom': '2026-10-23',
        'dateTo': '2026-10-23',
      },
      'canCheckIn': false,
      'canCheckOut': true,
    });

    expect(today.date, '2026-10-23');
    expect(today.isWorkingDay, isTrue);
    expect(today.holiday, isNull);
    expect(today.workStart, '09:00');
    expect(today.workEnd, '18:00');
    expect(today.toleranceMin, 5);
    expect(today.office, isNotNull);
    expect(today.office!.name, 'Бош офис');
    expect(today.office!.lat, 41.311081);
    expect(today.office!.lon, 69.240562);
    expect(today.office!.radiusM, 150);
    expect(today.checkIn, isNotNull);
    expect(today.checkIn!.time, '09:12');
    expect(today.checkIn!.late, isTrue);
    expect(today.checkIn!.lateMinutes, 12);
    expect(today.checkIn!.distanceM, 45);
    expect(today.checkOut, isNotNull);
    expect(today.checkOut!.time, '18:05');
    expect(today.checkOut!.early, isFalse);
    expect(today.inside, isTrue);
    expect(today.pairs.length, 2);
    expect(today.pairs[0].inTime, '09:12');
    expect(today.pairs[0].outTime, '12:30');
    expect(today.pairs[1].inTime, '13:30');
    expect(today.pairs[1].outTime, isNull);
    expect(today.insideMinutes, 210);
    expect(today.excuse, isNotNull);
    expect(today.excuse!.kind, 'late');
    expect(today.excuse!.reason, 'doctor');
    expect(today.canCheckIn, isFalse);
    expect(today.canCheckOut, isTrue);
  });

  test('AttendanceToday: разбор с null-полями и безопасными числами', () {
    final today = AttendanceToday.fromJson({
      'date': '2026-10-23',
      'isWorkingDay': false,
      'holiday': 'Мустақиллик куни',
      'toleranceMin': 5.0,
      'office': null,
      'checkIn': null,
      'checkOut': null,
      'inside': null,
      'pairs': null,
      'insideMinutes': 0.0,
      'excuse': null,
      'canCheckIn': true,
      'canCheckOut': false,
    });

    expect(today.isWorkingDay, isFalse);
    expect(today.holiday, 'Мустақиллик куни');
    expect(today.toleranceMin, 5);
    expect(today.office, isNull);
    expect(today.checkIn, isNull);
    expect(today.checkOut, isNull);
    expect(today.inside, isNull);
    expect(today.pairs, isEmpty);
    expect(today.insideMinutes, 0);
    expect(today.excuse, isNull);
    expect(today.canCheckIn, isTrue);
    expect(today.canCheckOut, isFalse);
  });

  test('AttendanceHistoryDay: разбор с опозданием и сабабли', () {
    final day1 = AttendanceHistoryDay.fromJson({
      'date': '2026-10-23',
      'status': 'late',
      'holiday': null,
      'checkIn': '09:15',
      'checkOut': '18:00',
      'lateMinutes': 15.0,
      'excuse': {
        'kind': 'late',
        'reason': 'traffic',
      },
    });

    expect(day1.date, '2026-10-23');
    expect(day1.status, 'late');
    expect(day1.checkIn, '09:15');
    expect(day1.checkOut, '18:00');
    expect(day1.lateMinutes, 15);
    expect(day1.excuse!.reason, 'traffic');

    final day2 = AttendanceHistoryDay.fromJson({
      'date': '2026-10-24',
      'status': 'off',
      'holiday': 'Шанба',
      'checkIn': null,
      'checkOut': null,
      'lateMinutes': 0,
      'excuse': null,
    });

    expect(day2.status, 'off');
    expect(day2.holiday, 'Шанба');
    expect(day2.checkIn, isNull);
    expect(day2.checkOut, isNull);
    expect(day2.excuse, isNull);
  });

  test('ApiException: статус, код ошибки и расстояние', () {
    final ex = ApiException('Ташқарида', 403, 'outside', 120);

    expect(ex.message, 'Ташқарида');
    expect(ex.status, 403);
    expect(ex.forbidden, isTrue);
    expect(ex.unauthorized, isFalse);
    expect(ex.code, 'outside');
    expect(ex.distanceM, 120);
  });
}
