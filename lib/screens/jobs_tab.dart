import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import '../widgets/job_tile.dart';

/// Ишларим: работы за выбранный день; сегодняшние можно удалить.
class JobsTab extends StatefulWidget {
  final VoidCallback onJobsChanged;
  const JobsTab({super.key, required this.onJobsChanged});

  @override
  State<JobsTab> createState() => JobsTabState();
}

class JobsTabState extends State<JobsTab> {
  /// Сколько дней назад можно посмотреть свои работы.
  static const _historyDays = 90;

  late DateTime _date;
  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = tashkentNow();
    reload();
  }

  bool get _isToday => ymd(_date) == ymd(tashkentNow());

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await MobileApi.instance.jobs(ymd(_date));
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
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

  Future<void> _pickDate() async {
    final now = tashkentNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: _historyDays)),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await reload();
  }

  Future<void> _delete(Job job) async {
    if (!await confirm(context, t('deleteAsk'), yes: t('yes'), no: t('no'))) return;
    try {
      await MobileApi.instance.deleteJob(job.id);
      if (!mounted) return;
      showOk(context, t('deleted'));
      widget.onJobsChanged();
    } catch (e) {
      if (mounted) showError(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final offline = _jobs.where((j) => j.kind == JobKind.offline).length;
    final online = _jobs.length - offline;
    final units = offline + online / 2;

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          AppCard(
            onTap: _pickDate,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const IconChip(Icons.calendar_month_rounded, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isToday ? '${t('today')} · ${_dmy(_date)}' : _dmy(_date),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: tone.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 2),
              child: Text(
                '${t('kindOffline')}: $offline · ${t('kindOnline')}: $online · ${t('done')}: ${fmtUnits(units)}',
                style: TextStyle(color: tone.muted, fontSize: 13),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppCard(child: Text(_error!, style: const TextStyle(color: Brand.red)))
          else if (_jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text(t('noJobs'), style: TextStyle(color: tone.muted))),
            )
          else
            for (final job in _jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: JobTile(job: job, onDelete: _isToday ? () => _delete(job) : null),
              ),
        ],
      ),
    );
  }

  static String _dmy(DateTime d) => ymd(d).split('-').reversed.join('.');
}
