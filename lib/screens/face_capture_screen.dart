import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../services/check_in_service.dart';
import '../services/crash_reporter.dart';
import '../theme.dart';

/// Что с лицом прямо сейчас; [ok] — лицо в овале, человек моргнул, можно снимать.
enum FaceHint { starting, noFace, manyFaces, closer, farther, center, straight, blink, eyes, ok }

/// Селфи и место для «Келдим».
class CheckInCapture {
  final File selfie;
  final Position position;
  final CaptureMode mode;

  const CheckInCapture(this.selfie, this.position, this.mode);
}

/// Сколько держать лицо ровно после моргания, прежде чем снимок сделается сам.
const _holdStill = Duration(milliseconds: 300);

/// Если за это время распознавание не обработало ни одного кадра, появляется кнопка
/// снимка. Автомат при этом продолжает работать: на медленном телефоне первый кадр
/// распознаётся поздно, но распознаётся.
const _detectTimeout = Duration(seconds: 12);

/// Лицо ровно в овале столько, а моргание не распознано (очки, блики) — появляется
/// кнопка: человек не застревает, а снимок помечается manual и виден кадру.
const _blinkTimeout = Duration(seconds: 8);

/// Пауза перед новым замером GPS, пока точка не годится для «Келдим».
const _relocateAfter = Duration(seconds: 3);

/// Второе лицо считается, если оно не меньше этой доли самого крупного — как на сервере.
const _secondFaceShare = 0.5;

/// Ширина лица в кадре: меньше — далеко, больше — слишком близко.
const _minFaceWidth = 0.3;
const _maxFaceWidth = 0.8;

/// Насколько центр лица может уйти от центра овала.
const _maxShiftX = 0.15;
const _minCenterY = 0.28;
const _maxCenterY = 0.62;

/// Поворот головы и наклон, при которых лицо ещё «прямо», градусы.
const _maxTurnDeg = 15.0;

/// Моргание — простая проверка, что перед камерой живой человек, а не фото:
/// оба глаза закрыты (ниже первого порога), затем открыты (выше второго).
const _eyeClosedMax = 0.3;
const _eyeOpenMin = 0.6;

/// Камера «Келдим»: своя камера с овалом, место по GPS определяется параллельно.
/// Снимок делается сам, когда в овале одно лицо, оно смотрит прямо, человек моргнул
/// и точка GPS годится (в радиусе офиса, точная, не подменённая). Галерея не принимается.
/// Возвращает [CheckInCapture] или null, если человек закрыл экран.
class FaceCaptureScreen extends StatefulWidget {
  final AttendanceOffice? office;

  /// Экран открылся сам при входе: «Келдим» сегодня ещё не отмечен.
  final bool reminder;

  const FaceCaptureScreen({super.key, this.office, this.reminder = false});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _camera;
  CameraDescription? _lens;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
  );

  FaceHint _hint = FaceHint.starting;
  DateTime? _okSince;
  DateTime? _alignedSince;
  bool _busy = false;
  bool _capturing = false;
  bool _detected = false;
  bool _manualAllowed = false;
  bool _detectErrorReported = false;
  bool _eyesClosedSeen = false;
  bool _blinked = false;
  Timer? _detectWatch;
  String? _cameraError;

  bool _alive = true;
  Position? _position;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
    _locate();
  }

  @override
  void dispose() {
    _alive = false;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _detectWatch?.cancel();
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final lens = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        lens,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }

      _lens = lens;
      setState(() => _camera = camera);
      await camera.startImageStream(_onFrame);
      _detectWatch = Timer(_detectTimeout, _allowManual);
    } catch (e, stack) {
      CrashReporter.record(e, stack);
      if (mounted) setState(() => _cameraError = t('cameraUnavailable'));
    }
  }

  void _allowManual() {
    if (_detected || !mounted) return;

    setState(() => _manualAllowed = true);
  }

  /// Точка GPS для «Келдим»; пока она не годится, замер повторяется — человек
  /// может дойти до офиса или выйти к окну, не закрывая камеру.
  Future<void> _locate() async {
    setState(() => _gpsError = null);

    while (_alive && !_capturing) {
      try {
        final position = await CheckInService.getFreshPosition();
        if (!_alive) return;

        setState(() => _position = position);
        if (_placeReady) return;
      } on CheckInException catch (e) {
        if (_alive) setState(() => _gpsError = e.message);
        return;
      }

      await Future<void>.delayed(_relocateAfter);
    }
  }

  int? get _distanceM {
    final position = _position;
    final office = widget.office;
    if (position == null || office == null) return null;

    return Geolocator.distanceBetween(position.latitude, position.longitude, office.lat, office.lon).round();
  }

  bool get _farFromOffice {
    final distance = _distanceM;
    final office = widget.office;

    return distance != null && office != null && distance > office.radiusM + AppConfig.checkInGpsMarginM;
  }

  bool get _lowAccuracy => (_position?.accuracy ?? 0) > AppConfig.checkInMaxAccuracyM;

  /// Сервер такую точку примет: есть, не подменена, точная и у офиса.
  bool get _placeReady =>
      _position != null && !_position!.isMocked && !_lowAccuracy && !_farFromOffice;

  Future<void> _onFrame(CameraImage frame) async {
    if (_busy || _capturing) return;
    _busy = true;

    try {
      final input = _toInputImage(frame);
      if (input == null) return;

      final faces = await _detector.processImage(input);
      _detected = true;
      // Для 90/270° кадр сенсора лежит на боку: ширина и высота меняются местами
      final upright = _sideways ? Size(frame.height.toDouble(), frame.width.toDouble()) : Size(frame.width.toDouble(), frame.height.toDouble());
      final hint = _judge(faces, upright);

      if (!mounted) return;

      final aligned = hint == FaceHint.blink || hint == FaceHint.eyes || hint == FaceHint.ok;

      _alignedSince = aligned ? (_alignedSince ?? DateTime.now()) : null;
      setState(() {
        _hint = hint;
        if (hint == FaceHint.blink && DateTime.now().difference(_alignedSince!) >= _blinkTimeout) {
          _manualAllowed = true;
        }
      });

      if (hint == FaceHint.ok && _placeReady) {
        _okSince ??= DateTime.now();
        if (DateTime.now().difference(_okSince!) >= _holdStill) await _capture(CaptureMode.auto);
      } else {
        _okSince = null;
      }
    } catch (e, stack) {
      // Пропущенный кадр не страшен, но если распознавание падает на этом телефоне,
      // автоснимок здесь не работает — о первой такой ошибке узнаём из отчёта
      if (!_detectErrorReported) {
        _detectErrorReported = true;
        CrashReporter.record(e, stack);
      }
    } finally {
      _busy = false;
    }
  }

  bool get _sideways => (_lens?.sensorOrientation ?? 0) % 180 == 90;

  InputImage? _toInputImage(CameraImage frame) {
    final lens = _lens;
    final rotation = lens == null ? null : InputImageRotationValue.fromRawValue(lens.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);

    if (rotation == null || format == null || format != InputImageFormat.nv21 || frame.planes.length != 1) {
      return null;
    }

    final plane = frame.planes.first;
    // CameraX отдаёт NV21 с хвостом нулей, когда у строк сенсора есть отступ;
    // ML Kit такой буфер не принимает — нужен ровно width × height × 1,5 байта
    final size = frame.width * frame.height * 3 ~/ 2;

    if (plane.bytes.length < size) return null;

    return InputImage.fromBytes(
      bytes: plane.bytes.length == size ? plane.bytes : Uint8List.sublistView(plane.bytes, 0, size),
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  FaceHint _judge(List<Face> faces, Size upright) {
    final main = faces.isEmpty
        ? null
        : faces.reduce((a, b) => a.boundingBox.height >= b.boundingBox.height ? a : b);
    final crowd = main != null &&
        faces.where((f) => f.boundingBox.height >= main.boundingBox.height * _secondFaceShare).length > 1;

    // Лицо ушло из кадра или появилось второе — моргание засчитывается заново
    if (main == null || crowd) {
      _eyesClosedSeen = false;
      _blinked = false;
      return main == null ? FaceHint.noFace : FaceHint.manyFaces;
    }

    final box = main.boundingBox;
    final width = box.width / upright.width;

    if (width < _minFaceWidth) return FaceHint.closer;
    if (width > _maxFaceWidth) return FaceHint.farther;

    final cx = box.center.dx / upright.width;
    final cy = box.center.dy / upright.height;

    if ((cx - 0.5).abs() > _maxShiftX || cy < _minCenterY || cy > _maxCenterY) return FaceHint.center;

    if ((main.headEulerAngleY ?? 0).abs() > _maxTurnDeg || (main.headEulerAngleZ ?? 0).abs() > _maxTurnDeg) {
      return FaceHint.straight;
    }

    return _eyes(main.leftEyeOpenProbability, main.rightEyeOpenProbability);
  }

  FaceHint _eyes(double? left, double? right) {
    // Глаза на этом телефоне не распознаются — моргание не проверить, сверку лица делает сервер
    if (left == null || right == null) return FaceHint.ok;

    final closed = left < _eyeClosedMax && right < _eyeClosedMax;
    final open = left > _eyeOpenMin && right > _eyeOpenMin;

    if (!_blinked) {
      if (closed) _eyesClosedSeen = true;
      if (open && _eyesClosedSeen) _blinked = true;

      return _blinked ? FaceHint.ok : FaceHint.blink;
    }

    return open ? FaceHint.ok : FaceHint.eyes;
  }

  Future<void> _capture(CaptureMode mode) async {
    final camera = _camera;
    final position = _position;
    if (camera == null || position == null || _capturing) return;

    setState(() => _capturing = true);

    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      final shot = await camera.takePicture();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(CheckInCapture(File(shot.path), position, mode));
    } catch (e, stack) {
      CrashReporter.record(e, stack);
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _okSince = null;
      });
      await camera.startImageStream(_onFrame);
    }
  }

  /// Что мешает «Келдим» прямо сейчас. Место важнее лица: у дома моргать бесполезно.
  (String, Color) get _banner {
    if (_cameraError != null) return (_cameraError!, Brand.red);
    if (_capturing) return (t('faceCapturing'), Brand.green);
    if (_gpsError != null) return (_gpsError!, Brand.red);
    if (_position?.isMocked ?? false) return (t('gpsMocked'), Brand.red);
    if (_farFromOffice) return (t('checkInOnlyAtOffice'), Brand.amber);

    final faceReady = _hint == FaceHint.ok;

    if (faceReady && _position == null) return (t('locatingPlace'), Colors.black54);
    if (faceReady && _lowAccuracy) return (t('gpsLowAccuracy'), Brand.amber);
    if (_manualAllowed && !_detected) return (t('faceManual'), Colors.black54);

    final text = switch (_hint) {
      FaceHint.starting => t('faceStarting'),
      FaceHint.noFace => t('faceNotFound'),
      FaceHint.manyFaces => t('faceOnlyOne'),
      FaceHint.closer => t('faceCloser'),
      FaceHint.farther => t('faceFarther'),
      FaceHint.center => t('faceCenter'),
      FaceHint.straight => t('faceStraight'),
      FaceHint.blink => t('faceBlink'),
      FaceHint.eyes => t('faceEyes'),
      FaceHint.ok => t('faceHold'),
    };

    return (text, faceReady ? Brand.green : Colors.black54);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = (_hint == FaceHint.ok && _placeReady) || _capturing;
    final (bannerText, bannerColor) = _banner;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized) _Preview(camera: camera),
          CustomPaint(painter: _OvalMask(ready: ready)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => Navigator.of(context).pop()),
                if (widget.reminder) ...[
                  const SizedBox(height: 10),
                  _Reminder(text: t('checkInReminder')),
                ],
                const Spacer(),
                _Banner(text: bannerText, color: bannerColor),
                const SizedBox(height: 12),
                _PlaceChip(position: _position, distanceM: _distanceM, office: widget.office),
                if (_gpsError != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _locate,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(t('retry'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
                // Запасная кнопка — только где распознавание или моргание не сработало; обычно снимок делается сам
                if (_manualAllowed) ...[
                  const SizedBox(height: 20),
                  _Shutter(
                    enabled: !_capturing && _placeReady,
                    busy: _capturing,
                    onPressed: () => _capture(CaptureMode.manual),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Превью фронтальной камеры на весь экран (обрезка по краям, без полос).
class _Preview extends StatelessWidget {
  final CameraController camera;

  const _Preview({required this.camera});

  @override
  Widget build(BuildContext context) {
    final size = camera.value.previewSize;

    if (size == null) return CameraPreview(camera);

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // previewSize дан в ориентации сенсора — в портрете стороны меняются
          width: size.height,
          height: size.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}

/// Затемнение вокруг овала и сам овал: белый, а когда можно снимать — зелёный.
class _OvalMask extends CustomPainter {
  final bool ready;

  _OvalMask({required this.ready});

  static Rect ovalOf(Size size) {
    final width = size.width * 0.68;

    return Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.42), width: width, height: width * 1.32);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = ovalOf(size);
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = ready ? Brand.green : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_OvalMask old) => old.ready != ready;
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;

  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            tooltip: t('cancel'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('selfieTitle'),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('selfieSub'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Почему камера открылась сама: «Келдим» сегодня ещё не отмечен.
class _Reminder extends StatelessWidget {
  final String text;

  const _Reminder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Brand.amber.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Подсказка над кнопкой: что поправить, чтобы снимок сделался.
class _Banner extends StatelessWidget {
  final String text;
  final Color color;

  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Где человек относительно офиса: «Офисдасиз · 10 м · GPS ±4 м».
class _PlaceChip extends StatelessWidget {
  final Position? position;
  final int? distanceM;
  final AttendanceOffice? office;

  const _PlaceChip({required this.position, required this.distanceM, required this.office});

  @override
  Widget build(BuildContext context) {
    final position = this.position;
    final office = this.office;
    final distance = distanceM;

    if (position == null) return _chip(Icons.location_searching_rounded, t('locatingPlace'), Colors.white24);

    final accuracy = 'GPS ±${position.accuracy.round()} ${t('metersUnit')}';

    if (office == null || distance == null) return _chip(Icons.location_on_outlined, accuracy, Colors.white24);

    final near = distance <= office.radiusM + AppConfig.checkInGpsMarginM;
    final text = near
        ? '${t('nearOffice')} · $distance ${t('metersUnit')} · $accuracy'
        : '${t('farFromOffice').replaceAll('{m}', '$distance')} · $accuracy';

    return _chip(
      near ? Icons.check_circle_rounded : Icons.location_off_rounded,
      text,
      near ? Brand.green.withValues(alpha: 0.85) : Brand.amber.withValues(alpha: 0.9),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка затвора — только когда автоснимок на этом телефоне или у этого человека не сработал.
class _Shutter extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  const _Shutter({required this.enabled, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: t('takeSelfie'),
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled || busy ? 1 : 0.45,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Brand.navy),
                      )
                    : const Icon(Icons.photo_camera_rounded, color: Brand.navy, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
