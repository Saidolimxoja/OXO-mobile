import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';

/// Вкладка «Давомат»: переключатель месяца, сводка за месяц и история дней.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => AttendanceTabState();
}

class AttendanceTabState extends State<AttendanceTab> {
  late DateTime _selectedMonth;
  List<AttendanceHistoryDay> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = tashkentNow();
    _selectedMonth = DateTime(now.year, now.month, 1);
    reload();
  }

  DateTime get _currentMonth {
    final now = tashkentNow();
    return DateTime(now.year, now.month, 1);
  }

  bool get _canGoNext => _selectedMonth.isBefore(_currentMonth);

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    reload();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = tashkentNow();
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final to = lastDay.isAfter(today) ? today : lastDay;

    try {
      final days = await MobileApi.instance.attendanceHistory(ymd(from), ymd(to));
      if (!mounted) return;

      setState(() {
        _days = days;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);

    final presentCount = _days
        .where((d) => d.status == 'present' || d.status == 'late' || d.checkIn != null)
        .length;
    final lateCount = _days.where((d) => d.status == 'late').length;
    final unexcusedAbsentCount =
        _days.where((d) => d.status == 'absent' && d.excuse == null).length;

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _buildMonthSwitcher(tone),
          const SizedBox(height: 14),
          _buildMonthSummary(tone, presentCount, lateCount, unexcusedAbsentCount),
          const SizedBox(height: 18),
          SectionTitle(t('attendance')),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppCard(child: Text(_error!, style: const TextStyle(color: Brand.red)))
          else if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  t('noAttendanceHistory'),
                  style: TextStyle(color: tone.muted, fontSize: 14.5),
                ),
              ),
            )
          else
            for (final day in _days)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildDayCard(tone, day),
              ),
        ],
      ),
    );
  }

  Widget _buildMonthSwitcher(Tone tone) {
    final title = '${monthName(_selectedMonth.month)} ${_selectedMonth.year}';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: _loading ? null : _prevMonth,
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: (_loading || !_canGoNext) ? null : _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSummary(
    Tone tone,
    int present,
    int late,
    int unexcusedAbsent,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('monthSummary'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tone.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCol(
                  title: t('summaryPresent'),
                  value: '$present',
                  color: Brand.green,
                ),
              ),
              Container(width: 1, height: 36, color: tone.border),
              Expanded(
                child: _buildStatCol(
                  title: t('summaryLate'),
                  value: '$late',
                  color: Brand.amber,
                ),
              ),
              Container(width: 1, height: 36, color: tone.border),
              Expanded(
                child: _buildStatCol(
                  title: t('summaryAbsent'),
                  value: '$unexcusedAbsent',
                  color: Brand.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDayCard(Tone tone, AttendanceHistoryDay day) {
    final parsed = DateTime.tryParse(day.date);
    String dateTitle = day.date;

    if (parsed != null) {
      final mName = monthName(parsed.month).toLowerCase();
      final wName = weekdayName(parsed.weekday);
      dateTitle = '${parsed.day} $mName, $wName';
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              _buildStatusPill(tone, day),
            ],
          ),
          if (day.excuse != null && day.status == 'late') ...[
            const SizedBox(height: 6),
            Text(
              '${t('excusedStatus')}: ${attendanceReasonText(day.excuse!.reason)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Brand.amber,
              ),
            ),
          ],
          if (day.checkIn != null || day.checkOut != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (day.checkIn != null) ...[
                  Icon(Icons.login_rounded, size: 15, color: tone.muted),
                  const SizedBox(width: 5),
                  Text(
                    '${t('historyCheckIn')}: ${day.checkIn}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tone.muted,
                    ),
                  ),
                ],
                if (day.checkIn != null && day.checkOut != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('·', style: TextStyle(color: tone.muted)),
                  ),
                if (day.checkOut != null) ...[
                  Icon(Icons.logout_rounded, size: 15, color: tone.muted),
                  const SizedBox(width: 5),
                  Text(
                    '${t('historyCheckOut')}: ${day.checkOut}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(Tone tone, AttendanceHistoryDay day) {
    if (day.status == 'off') {
      final holidayText = day.holiday != null && day.holiday!.isNotEmpty
          ? day.holiday!
          : t('statusOff');
      return StatusPill(holidayText, color: tone.muted);
    }

    if (day.status == 'absent' && day.excuse != null) {
      return StatusPill(
        '${t('excusedStatus')}: ${attendanceReasonText(day.excuse!.reason)}',
        color: Brand.amber,
        icon: Icons.info_outline_rounded,
      );
    }

    if (day.status == 'late') {
      return StatusPill(
        '${t('statusLate')} ${day.lateMinutes} ${t('minutes')}',
        color: Brand.red,
        icon: Icons.schedule_rounded,
      );
    }

    if (day.status == 'absent') {
      return StatusPill(
        t('statusAbsent'),
        color: Brand.red,
        icon: Icons.cancel_outlined,
      );
    }

    return StatusPill(
      t('statusPresent'),
      color: Brand.green,
      icon: Icons.check_circle_outline_rounded,
    );
  }
}
