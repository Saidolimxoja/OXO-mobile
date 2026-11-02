import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../i18n.dart';
import '../services/crash_reporter.dart';
import '../services/session.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/check_in_flow.dart';
import 'attendance_tab.dart';
import 'home_tab.dart';
import 'jobs_tab.dart';
import 'profile_tab.dart';

/// Вкладка оболочки: экран, значок и что обновить при переходе на неё.
class _Tab {
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? onSelected;

  const _Tab(this.screen, this.icon, this.activeIcon, this.label, [this.onSelected]);
}

/// Главный экран после входа: Бош саҳифа, Давомат, Ишларим (только туманы), Профил.
///
/// При входе и при возврате в приложение, если «Келдим» сегодня ещё нужен,
/// камера открывается сама — нажимать «Келдим» не нужно.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _loading = true;
  String? _error;
  bool _backgrounded = false;
  bool _checkInOpen = false;
  final _homeKey = GlobalKey<HomeTabState>();
  final _attendanceKey = GlobalKey<AttendanceTabState>();
  final _jobsKey = GlobalKey<JobsTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Только настоящий уход в фон: системный диалог разрешения даёт лишь inactive
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed && _backgrounded && !_loading && _error == null) {
      _backgrounded = false;
      _onReturn();
    }
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
      CrashReporter.flush();
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerCheckIn());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<void> _onReturn() async {
    CrashReporter.flush();
    await Session.instance.refresh();
    if (!mounted) return;

    setState(() {});
    _homeKey.currentState?.reload();
    await _offerCheckIn();
  }

  /// Камера «Келдим» без нажатия кнопки. Не поверх формы работы и не второй раз,
  /// пока первая открыта; закрыл камеру — до следующего входа кнопка на главной.
  Future<void> _offerCheckIn() async {
    if (_checkInOpen || !_shellOnTop) return;
    _checkInOpen = true;

    try {
      final today = await MobileApi.instance.attendanceToday();
      if (!mounted || !today.needsCheckIn || !_shellOnTop) return;

      await runCheckIn(context, today, reminder: true);
      if (!mounted) return;

      _homeKey.currentState?.reload();
      _attendanceKey.currentState?.reload();
    } catch (_) {
      // Нет сети — состояние дня и кнопку «Келдим» покажет главная
    } finally {
      _checkInOpen = false;
    }
  }

  bool get _shellOnTop => mounted && (ModalRoute.isCurrentOf(context) ?? false);

  /// После добавления или удаления работы обновляются обе вкладки.
  void _jobsChanged() {
    _homeKey.currentState?.reload();
    _jobsKey.currentState?.reload();
  }

  List<_Tab> _tabs() => [
        _Tab(
          HomeTab(key: _homeKey, onJobsChanged: _jobsChanged),
          Icons.home_outlined,
          Icons.home_rounded,
          t('navHome'),
          () => _homeKey.currentState?.reload(),
        ),
        _Tab(
          AttendanceTab(key: _attendanceKey),
          Icons.fact_check_outlined,
          Icons.fact_check_rounded,
          t('navAttendance'),
          () => _attendanceKey.currentState?.reload(),
        ),
        // Ишлар ҳисоботи — только у сотрудников туманов
        if (Session.instance.reportsWork)
          _Tab(
            JobsTab(key: _jobsKey, onJobsChanged: _jobsChanged),
            Icons.assignment_outlined,
            Icons.assignment_rounded,
            t('navJobs'),
            () => _jobsKey.currentState?.reload(),
          ),
        _Tab(const ProfileTab(), Icons.person_outline_rounded, Icons.person_rounded, t('navProfile')),
      ];

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

        final tabs = _tabs();
        final index = _index.clamp(0, tabs.length - 1);

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: index,
              children: [for (final tab in tabs) tab.screen],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              border: Border(top: BorderSide(color: tone.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) {
                setState(() => _index = i);
                tabs[i].onSelected?.call();
              },
              items: [
                for (final tab in tabs)
                  BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    activeIcon: Icon(tab.activeIcon),
                    label: tab.label,
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
