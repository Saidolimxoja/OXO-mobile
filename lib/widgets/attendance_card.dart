import 'package:flutter/material.dart';

import '../api/models.dart';
import '../i18n.dart';
import '../theme.dart';
import 'check_in_flow.dart';

/// Карточка Давомата на главной: статус дня и отметка «Келдим» с проверкой лица.
/// Уход отдельно не отмечается: день покрывает трек 09:00–18:00.
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

  Future<void> _onCheckIn() async {
    setState(() => _loading = true);

    await runCheckIn(context, widget.today);
    if (!mounted) return;

    setState(() => _loading = false);
    // И после отказа: день мог смениться, а приход — отметиться с другой попытки
    await widget.onChanged();
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
        // Без точки офиса сервер «Келдим» не примет — вместо кнопки говорим, к кому идти
        if (today.canCheckIn && today.office == null) ...[
          _Notice(text: t('err_no_office'), color: Brand.red, icon: Icons.location_off_rounded),
        ] else if (today.canCheckIn) ...[
          GradientButton(
            label: t('checkInBtn'),
            icon: Icons.face_retouching_natural_rounded,
            onPressed: _loading ? null : _onCheckIn,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              [
                t('checkInChecks'),
                t('workStartTolerance')
                    .replaceAll('{start}', today.workStart)
                    .replaceAll('{tolerance}', '${today.toleranceMin}'),
              ].join('\n'),
              style: TextStyle(fontSize: 12.5, color: tone.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
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

/// Короткое предупреждение в карточке: цветной фон того же тона, иконка и текст.
class _Notice extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _Notice({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
