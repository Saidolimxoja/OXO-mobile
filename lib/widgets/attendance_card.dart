import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../services/check_in_service.dart';
import '../theme.dart';
import 'feedback.dart';

/// Карточка Давомата на главной: статус дня, отметка «Келдим» и «Кетдим».
class AttendanceCard extends StatefulWidget {
  final AttendanceToday today;
  final Future<void> Function() onChanged;

  const AttendanceCard({
    super.key,
    required this.today,
    required this.onChanged,
  });

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  bool _loading = false;
  String? _stepMessage;

  Future<void> _onCheckIn() async {
    setState(() {
      _loading = true;
      _stepMessage = t('locatingPlace');
    });

    try {
      final pos = await CheckInService.getFreshPosition();
      if (!mounted) return;

      setState(() {
        _stepMessage = null;
      });

      final selfie = await CheckInService.pickFrontSelfie();
      if (selfie == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _stepMessage = null;
          });
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _loading = true;
        _stepMessage = t('sending');
      });

      await MobileApi.instance.checkIn(selfie, pos);
      if (!mounted) return;

      showOk(context, t('checkInSuccess'));
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(e);
      if (mounted) {
        await widget.onChanged();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _stepMessage = null;
        });
      }
    }
  }

  Future<void> _onCheckOut() async {
    final now = tashkentNow();
    final minutes = now.hour * 60 + now.minute;

    if (minutes < AppConfig.workEndMinutes) {
      final confirmed = await confirm(
        context,
        t('checkOutConfirm'),
        yes: t('yes'),
        no: t('no'),
      );

      if (!confirmed) return;
    }

    setState(() {
      _loading = true;
      _stepMessage = t('sending');
    });

    try {
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      await MobileApi.instance.checkOut(pos);
      if (!mounted) return;

      showOk(context, t('checkOutSuccess'));
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(e);
      if (mounted) {
        await widget.onChanged();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _stepMessage = null;
        });
      }
    }
  }

  Future<void> _showErrorDialog(Object e) async {
    String message;

    if (e is ApiException) {
      if (e.message == 'network') {
        message = t('networkError');
      } else if (e.code == 'outside' && e.distanceM != null) {
        if (!e.message.contains('${e.distanceM}')) {
          message = '${e.message}\n${t('distanceLabel')}: ${e.distanceM} ${t('metersUnit')}';
        } else {
          message = e.message;
        }
      } else {
        message = e.message;
      }
    } else if (e is CheckInException) {
      message = e.message;
    } else {
      message = e.toString();
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatPairs(List<AttendancePair> pairs) {
    final shown = pairs.take(4).map((p) => '${p.inTime} → ${p.outTime ?? '…'}').toList();
    var result = shown.join(', ');

    if (pairs.length > 4) {
      result += ', +${pairs.length - 4}';
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final today = widget.today;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(Icons.fact_check_rounded, color: Brand.indigo, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('attendance'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!today.isWorkingDay)
            _buildDayOff(tone, today)
          else if (today.checkIn == null)
            _buildBeforeCheckIn(tone, today)
          else
            _buildAfterCheckIn(tone, today),
          if (_loading && _stepMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  _stepMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: tone.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayOff(Tone tone, AttendanceToday today) {
    final holidayText = today.holiday != null && today.holiday!.isNotEmpty
        ? today.holiday!
        : t('holidayToday');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.sunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, color: tone.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              holidayText,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: tone.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeCheckIn(Tone tone, AttendanceToday today) {
    final hasExcuse = today.excuse != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasExcuse) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Brand.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Brand.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${t('excusedStatus')}: ${attendanceReasonText(today.excuse!.reason)}',
                    style: const TextStyle(
                      color: Brand.amber,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (today.canCheckIn) const SizedBox(height: 12),
        ],
        if (today.canCheckIn) ...[
          GradientButton(
            label: t('checkInBtn'),
            icon: Icons.camera_alt_rounded,
            onPressed: _loading ? null : _onCheckIn,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              t('workStartTolerance')
                  .replaceAll('{start}', today.workStart)
                  .replaceAll('{tolerance}', '${today.toleranceMin}'),
              style: TextStyle(fontSize: 12.5, color: tone.muted),
              textAlign: TextAlign.center,
            ),
          ),
          if (today.office == null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                t('noOfficeLocation'),
                style: TextStyle(fontSize: 12, color: tone.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ] else if (!hasExcuse) ...[
          StatusPill(
            t('notCheckedInToday'),
            color: Brand.red,
            icon: Icons.cancel_outlined,
          ),
        ],
      ],
    );
  }

  Widget _buildAfterCheckIn(Tone tone, AttendanceToday today) {
    final checkIn = today.checkIn!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!checkIn.late)
              StatusPill(
                t('checkedInOnTime').replaceAll('{time}', checkIn.time),
                color: Brand.green,
                icon: Icons.check_circle_outline_rounded,
              )
            else
              StatusPill(
                t('checkedInLate')
                    .replaceAll('{time}', checkIn.time)
                    .replaceAll('{minutes}', '${checkIn.lateMinutes}'),
                color: Brand.red,
                icon: Icons.schedule_rounded,
              ),
            const Spacer(),
            if (today.inside != null)
              StatusPill(
                today.inside! ? t('insideOffice') : t('outsideOffice'),
                color: today.inside! ? Brand.green : Brand.amber,
                icon: today.inside!
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${t('inBuilding')}: ${formatDurationMinutes(today.insideMinutes)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        if (today.pairs.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _formatPairs(today.pairs),
            style: TextStyle(fontSize: 13, color: tone.muted),
          ),
        ],
        if (today.canCheckOut) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loading ? null : _onCheckOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text(t('checkOutBtn')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Brand.indigo, width: 1.5),
              foregroundColor: Brand.indigo,
            ),
          ),
        ],
        if (today.checkOut != null) ...[
          const SizedBox(height: 12),
          StatusPill(
            today.checkOut!.early
                ? '${t('checkOut')} ${today.checkOut!.time} (${t('earlyDeparture')})'
                : '${t('checkOut')} ${today.checkOut!.time}',
            color: today.checkOut!.early ? Brand.amber : Brand.green,
            icon: Icons.logout_rounded,
          ),
        ],
      ],
    );
  }
}
