import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../services/session.dart';
import '../services/track_service.dart';
import '../theme.dart';
import '../widgets/attendance_card.dart';
import '../widgets/job_tile.dart';
import 'job_form_screen.dart';

/// Бош саҳифа: кто я и какой сегодня день, норма, состояние трека,
/// кнопка «Иш қўшиш» и сегодняшние работы.
class HomeTab extends StatefulWidget {
  final VoidCallback onJobsChanged;
  const HomeTab({super.key, required this.onJobsChanged});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  Stats? _stats;
  List<Job> _jobs = [];
  AttendanceToday? _attendance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final today = ymd(tashkentNow());
    final reportsWork = Session.instance.reportsWork;
    setState(() => _error = null);
    try {
      final api = MobileApi.instance;
      final results = await Future.wait<Object>([
        api.attendanceToday(),
        if (reportsWork) api.stats(today),
        if (reportsWork) api.jobs(today),
      ]);
      if (!mounted) return;
      setState(() {
        _attendance = results[0] as AttendanceToday;
        _stats = reportsWork ? results[1] as Stats : null;
        _jobs = reportsWork ? results[2] as List<Job> : [];
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

  Future<void> _addJob() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const JobFormScreen()),
    );
    if (added == true) widget.onJobsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;
    final reportsWork = Session.instance.reportsWork;
    final tone = Tone.of(context);

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (me != null) _header(me),
          const SizedBox(height: 14),
          if (_attendance != null) ...[
            AttendanceCard(today: _attendance!, onChanged: reload),
            const SizedBox(height: 14),
          ],
          const _TrackStatus(),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppCard(child: Text(_error!, style: const TextStyle(color: Brand.red)))
          else if (_stats != null)
            _statsCard(_stats!, tone),
          // Ишлар ҳисоботи — только у сотрудников туманов; у вилоята и республики главная — Давомат
          if (reportsWork) ...[
            const SizedBox(height: 16),
            GradientButton(label: t('addJob'), icon: Icons.add_rounded, onPressed: _addJob),
            const SizedBox(height: 22),
            SectionTitle(t('todayJobs')),
            if (!_loading && _jobs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text(t('noJobs'), style: TextStyle(color: tone.muted))),
              ),
            for (final job in _jobs)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: JobTile(job: job)),
          ],
        ],
      ),
    );
  }

  Widget _header(Me me) {
    final today = me.today;
    final status = today.isWorkingDay ? t('workDay') : (today.holiday ?? t('dayOff'));

    return BrandPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('hello'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(me.employee.fullName,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          if (me.employee.post.isNotEmpty)
            Text(me.employee.post, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                today.isWorkingDay ? Icons.work_outline_rounded : Icons.weekend_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${today.date.split('-').reversed.join('.')} · $status',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard(Stats s, Tone tone) {
    final day = s.day;
    final progress = day.plan > 0 ? (day.amal / day.plan).clamp(0.0, 1.0) : 0.0;
    final color = _tone(day.percent);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${t('norm')}: ${s.norm}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              StatusPill(day.percent == null ? '—' : '${day.percent}%', color: color),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: color,
              backgroundColor: tone.sunken,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${t('today')}: ${fmtUnits(day.amal)} / ${fmtUnits(day.plan)} · '
            '${t('kindOffline')} ${day.offline} · ${t('kindOnline')} ${day.online}',
            style: TextStyle(fontSize: 13, color: tone.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _period(t('week'), s.week, tone)),
              const SizedBox(width: 10),
              Expanded(child: _period(t('month'), s.month, tone)),
            ],
          ),
          const SizedBox(height: 8),
          Text(t('unitsHint'), style: TextStyle(fontSize: 12, color: tone.muted)),
        ],
      ),
    );
  }

  Widget _period(String label, PeriodStats p, Tone tone) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: tone.sunken, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: tone.muted)),
            const SizedBox(height: 2),
            Text('${fmtUnits(p.amal)} / ${fmtUnits(p.plan)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(p.percent == null ? '—' : '${p.percent}%',
                style: TextStyle(fontSize: 12.5, color: _tone(p.percent), fontWeight: FontWeight.w700)),
          ],
        ),
      );

  /// Те же пороги, что в веб-отчёте: < 50 красный, < 80 жёлтый, иначе зелёный.
  static Color _tone(int? percent) {
    if (percent == null) return Brand.mutedLight;
    if (percent < 50) return Brand.red;
    if (percent < 80) return Brand.amber;
    return Brand.green;
  }
}

class _TrackStatus extends StatelessWidget {
  const _TrackStatus();

  @override
  Widget build(BuildContext context) {
    final track = TrackService.instance;
    return AnimatedBuilder(
      animation: track,
      builder: (context, _) {
        final tone = Tone.of(context);
        final (icon, color, text) = !track.enabled
            ? (Icons.location_off_rounded, Brand.red, t('trackOff'))
            : track.collecting
                ? (Icons.my_location_rounded, Brand.green, t('trackOn'))
                : (Icons.location_searching_rounded, Brand.mutedLight, t('trackIdle'));
        final sent = track.lastSentAt;

        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              IconChip(icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (track.pending > 0 || sent != null)
                      Text(
                        [
                          if (track.pending > 0) '${track.pending} ${t('trackPending')}',
                          if (sent != null) '${t('lastSent')} ${hm(sent)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: tone.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
