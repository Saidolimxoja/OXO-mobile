import 'package:flutter_test/flutter_test.dart';
import 'package:oxo_mobile/api/models.dart';
import 'package:oxo_mobile/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Session.clearLocal сбрасывает буфер трека и данные сотрудника', () async {
    SharedPreferences.setMockInitialValues({
      'track_buffer': '[{"t":"2026-11-12T09:00:00Z","lat":41.311,"lon":69.279}]',
    });

    Session.instance.me = Me.fromJson({
      'employee': {'code': 'emp1', 'fullName': 'Test Employee'},
      'today': {'date': '2026-11-12', 'isWorkingDay': true},
    });

    expect(Session.instance.me, isNotNull);

    await Session.instance.clearLocal();

    final prefs = await SharedPreferences.getInstance();

    expect(prefs.containsKey('track_buffer'), isFalse);
    expect(Session.instance.me, isNull);
    expect(Session.instance.workTypes, isEmpty);
  });
}
