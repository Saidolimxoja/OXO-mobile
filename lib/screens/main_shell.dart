import 'package:flutter/material.dart';

import '../i18n.dart';
import '../services/session.dart';
import '../settings.dart';
import '../theme.dart';
import 'attendance_tab.dart';
import 'home_tab.dart';
import 'jobs_tab.dart';
import 'profile_tab.dart';

/// Главный экран после входа: Бош саҳифа, Ишларим, Профил.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _loading = true;
  String? _error;
  final _homeKey = GlobalKey<HomeTabState>();
  final _attendanceKey = GlobalKey<AttendanceTabState>();
  final _jobsKey = GlobalKey<JobsTabState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Session.instance.load();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  /// После добавления или удаления работы обновляются обе вкладки.
  void _jobsChanged() {
    _homeKey.currentState?.reload();
    _jobsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final tone = Tone.of(context);
        if (_loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (_error != null) return _errorScreen(tone);

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                HomeTab(key: _homeKey, onJobsChanged: _jobsChanged),
                AttendanceTab(key: _attendanceKey),
                JobsTab(key: _jobsKey, onJobsChanged: _jobsChanged),
                const ProfileTab(),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              border: Border(top: BorderSide(color: tone.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) {
                setState(() => _index = i);
                if (i == 0) _homeKey.currentState?.reload();
                if (i == 1) _attendanceKey.currentState?.reload();
                if (i == 2) _jobsKey.currentState?.reload();
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home_rounded),
                  label: t('navHome'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.fact_check_outlined),
                  activeIcon: const Icon(Icons.fact_check_rounded),
                  label: t('navAttendance'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.assignment_outlined),
                  activeIcon: const Icon(Icons.assignment_rounded),
                  label: t('navJobs'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline_rounded),
                  activeIcon: const Icon(Icons.person_rounded),
                  label: t('navProfile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _errorScreen(Tone tone) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 56, color: tone.muted),
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t('retry')),
                ),
              ],
            ),
          ),
        ),
      );
}
