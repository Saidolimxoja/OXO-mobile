import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/feedback.dart';

/// Новая работа на сегодня: на выезде (с местом) или удалённо, 1–4 фото.
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key});

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  static const _defaultDuration = Duration(minutes: 30);
  static const _photoMaxWidth = 1600.0;
  static const _photoQuality = 75;

  final _org = TextEditingController();
  final _description = TextEditingController();
  final _murojaat = TextEditingController();
  final _applicant = TextEditingController();
  final _applicantPhone = TextEditingController();
  final _picker = ImagePicker();

  JobKind _kind = JobKind.offline;
  int? _workTypeId;
  late TimeOfDay _started;
  late TimeOfDay _finished;
  final List<File> _photos = [];

  double? _lat;
  double? _lon;
  String? _address;
  String? _placeError;
  bool _locating = false;
  bool _sending = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final now = tashkentNow();
    _finished = TimeOfDay.fromDateTime(now);
    _started = TimeOfDay.fromDateTime(now.subtract(_defaultDuration));
    _locate();
  }

  @override
  void dispose() {
    for (final c in [_org, _description, _murojaat, _applicant, _applicantPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _placeError = null;
    });

    final result = await LocationService.current();
    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _locating = false;
        _placeError = _problemText(result.problem!);
      });
      return;
    }

    final pos = result.position!;
    setState(() {
      _lat = pos.latitude;
      _lon = pos.longitude;
    });
    try {
      final address = await MobileApi.instance.geocode(pos.latitude, pos.longitude);
      if (mounted) setState(() => _address = address);
    } catch (_) {
      // адрес не обязателен — сервер дозаполнит его сам
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static String _problemText(LocationProblem p) => switch (p) {
        LocationProblem.serviceOff => t('gpsOff'),
        LocationProblem.denied => t('gpsDenied'),
        LocationProblem.deniedForever => t('gpsDeniedForever'),
        LocationProblem.unavailable => t('gpsUnavailable'),
      };

  Future<void> _addPhoto(ImageSource source) async {
    if (_photos.length >= AppConfig.maxJobPhotos) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: _photoMaxWidth,
      imageQuality: _photoQuality,
    );
    if (picked != null && mounted) setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _started : _finished,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => start ? _started = picked : _finished = picked);
  }

  /// Время сегодняшнего дня по Ташкенту → момент (UTC) для сервера.
  DateTime _moment(TimeOfDay time) {
    final now = tashkentNow();
    return DateTime.utc(now.year, now.month, now.day, time.hour, time.minute)
        .subtract(AppConfig.tashkentOffset);
  }

  String? _validate() {
    if (_workTypeId == null) return t('chooseWorkType');
    if (_org.text.trim().isEmpty || _description.text.trim().isEmpty) return t('required');

    final started = _moment(_started);
    final finished = _moment(_finished);
    if (finished.isBefore(started)) return t('timeOrder');
    if (finished.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 2)))) return t('timeFuture');

    if (_kind == JobKind.offline && (_lat == null || _lon == null)) return t('needPlace');
    if (_photos.length < AppConfig.minJobPhotos) return t('needPhoto');

    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final problem = _validate();
    if (problem != null) {
      showError(context, problem);
      return;
    }

    setState(() => _sending = true);
    try {
      final job = NewJob(
        kind: _kind,
        workTypeId: _workTypeId!,
        orgName: _org.text.trim(),
        description: _description.text.trim(),
        murojaatNo: _murojaat.text.trim(),
        applicantName: _applicant.text.trim(),
        applicantPhone: _applicantPhone.text.trim(),
        address: _address,
        lat: _lat,
        lon: _lon,
        startedAt: _moment(_started),
        finishedAt: _moment(_finished),
      );
      await MobileApi.instance.createJob(job, _photos);
      if (!mounted) return;
      showOk(context, t('sent'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final lang = AppSettings.instance.lang;
    final types = Session.instance.workTypes;

    return Scaffold(
      appBar: AppBar(title: Text(t('newJob'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SegmentedButton<JobKind>(
              segments: [
                ButtonSegment(
                  value: JobKind.offline,
                  icon: const Icon(Icons.place_rounded),
                  label: Text(t('kindOffline')),
                ),
                ButtonSegment(
                  value: JobKind.online,
                  icon: const Icon(Icons.call_rounded),
                  label: Text(t('kindOnline')),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            if (_kind == JobKind.online)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(t('kindOnlineHint'), style: TextStyle(fontSize: 12.5, color: tone.muted)),
              ),
            const SizedBox(height: 16),
            _label(t('workType'), tone),
            DropdownButtonFormField<int>(
              initialValue: _workTypeId,
              isExpanded: true,
              hint: Text(t('chooseWorkType')),
              items: [
                for (final w in types) DropdownMenuItem(value: w.id, child: Text(w.name(lang))),
              ],
              onChanged: (v) => setState(() => _workTypeId = v),
              decoration: InputDecoration(
                errorText: _submitted && _workTypeId == null ? t('required') : null,
              ),
            ),
            const SizedBox(height: 14),
            _field(_org, t('orgName'), tone, required: true),
            _field(_description, t('description'), tone, required: true, lines: 3),
            _field(_murojaat, '${t('murojaatNo')} (${t('optional')})', tone),
            _field(_applicant, '${t('applicantName')} (${t('optional')})', tone),
            _field(_applicantPhone, '${t('applicantPhone')} (${t('optional')})', tone,
                keyboard: TextInputType.phone),
            Row(
              children: [
                Expanded(child: _timeBox(t('started'), _started, () => _pickTime(true), tone)),
                const SizedBox(width: 10),
                Expanded(child: _timeBox(t('finished'), _finished, () => _pickTime(false), tone)),
              ],
            ),
            const SizedBox(height: 16),
            _placeCard(tone),
            const SizedBox(height: 16),
            _photosCard(tone),
            const SizedBox(height: 22),
            _sending
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(label: t('send'), icon: Icons.send_rounded, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Tone tone) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone.muted)),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    Tone tone, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) {
    final missing = required && _submitted && controller.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(required ? '$label *' : label, tone),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines,
            keyboardType: keyboard,
            onChanged: (_) => _submitted ? setState(() {}) : null,
            decoration: InputDecoration(errorText: missing ? t('required') : null),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, TimeOfDay time, VoidCallback onTap, Tone tone) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, tone),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      );

  Widget _placeCard(Tone tone) {
    final needed = _kind == JobKind.offline;
    final String text;
    if (_locating) {
      text = t('placeDetecting');
    } else if (_placeError != null) {
      text = _placeError!;
    } else {
      text = _address ??
          (_lat != null ? '${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}' : '—');
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconChip(
            Icons.my_location_rounded,
            color: _placeError != null && needed ? Brand.red : Brand.indigo,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(needed ? '${t('place')} *' : t('place'),
                    style: TextStyle(fontSize: 12.5, color: tone.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextButton(onPressed: _locating ? null : _locate, child: Text(t('placeRefresh'))),
        ],
      ),
    );
  }

  Widget _photosCard(Tone tone) {
    final canAdd = _photos.length < AppConfig.maxJobPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('${t('photos')} * · ${_photos.length} / ${AppConfig.maxJobPhotos}', tone),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photos[i], width: 84, height: 84, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (canAdd) ...[
              _photoButton(Icons.photo_camera_rounded, t('camera'), () => _addPhoto(ImageSource.camera), tone),
              _photoButton(Icons.photo_library_rounded, t('gallery'), () => _addPhoto(ImageSource.gallery), tone),
            ],
          ],
        ),
        if (_submitted && _photos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(t('needPhoto'), style: const TextStyle(color: Brand.red, fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _photoButton(IconData icon, String label, VoidCallback onTap, Tone tone) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: tone.sunken,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tone.muted),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11.5, color: tone.muted)),
            ],
          ),
        ),
      );
}
