import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/mobile_api.dart';
import '../api/models.dart';
import '../i18n.dart';
import '../screens/face_capture_screen.dart';
import 'feedback.dart';

/// «Келдим» целиком: камера с овалом (место по GPS ищется там же), отправка селфи,
/// итог. Один сценарий и для кнопки на главной, и для камеры, открытой при входе.
/// true — приход отмечен; false — человек закрыл камеру или сервер отказал.
Future<bool> runCheckIn(BuildContext context, AttendanceToday today, {bool reminder = false}) async {
  final capture = await Navigator.of(context).push<CheckInCapture>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FaceCaptureScreen(office: today.office, reminder: reminder),
    ),
  );

  if (capture == null || !context.mounted) return false;

  final navigator = Navigator.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _Sending(text: t('sending'))),
  );

  try {
    await MobileApi.instance.checkIn(capture.selfie, capture.position, capture.mode);
    navigator.pop();
    if (context.mounted) showOk(context, t('checkInSuccess'));

    return true;
  } catch (e) {
    navigator.pop();
    if (context.mounted) await _showError(context, e);

    return false;
  }
}

Future<void> _showError(BuildContext context, Object e) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(_errorMessage(e), style: const TextStyle(fontSize: 15)),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

String _errorMessage(Object e) {
  if (e is! ApiException) return e.toString();
  if (e.message == 'network') return t('networkError');

  final known = e.code == null ? null : checkInErrorText(e.code!);
  if (known != null) return known;

  if (e.code == 'outside' && e.distanceM != null && !e.message.contains('${e.distanceM}')) {
    return '${e.message}\n${t('distanceLabel')}: ${e.distanceM} ${t('metersUnit')}';
  }

  return e.message;
}

class _Sending extends StatelessWidget {
  final String text;

  const _Sending({required this.text});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
