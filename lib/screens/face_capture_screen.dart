import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../api/models.dart';
import '../i18n.dart';
import '../theme.dart';

/// Что мешает снимку прямо сейчас; [ok] — лицо в овале, можно снимать;
/// [manual] — распознавание на этом телефоне не заработало, снимок кнопкой.
enum FaceHint { starting, noFace, manyFaces, closer, farther, center, straight, eyes, ok, manual }

/// Сколько держать лицо ровно, прежде чем снимок сделается сам.
const _holdStill = Duration(milliseconds: 500);

/// Если за это время ни один кадр не распознан, камера переходит на снимок
/// кнопкой: лицо всё равно сверяет сервер, а человек не застревает на экране.
const _detectTimeout = Duration(seconds: 4);

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

/// Ниже этой вероятности глаз считается закрытым.
const _eyeOpenMin = 0.5;

/// Селфи для «Келдим»: своя камера с овалом, снимок делается сам, когда в
/// овале одно лицо, оно смотрит прямо и глаза открыты. Галерея не принимается.
/// Возвращает файл снимка или null, если человек закрыл экран.
class FaceCaptureScreen extends StatefulWidget {
  final Position position;
  final AttendanceOffice? office;

  const FaceCaptureScreen({super.key, required this.position, this.office});

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
  bool _busy = false;
  bool _capturing = false;
  bool _detected = false;
  Timer? _detectWatch;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  @override
  void dispose() {
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
      _detectWatch = Timer(_detectTimeout, _fallBackToManual);
    } catch (_) {
      if (mounted) setState(() => _error = t('cameraUnavailable'));
    }
  }

  Future<void> _fallBackToManual() async {
    final camera = _camera;
    if (_detected || !mounted || camera == null) return;

    setState(() => _hint = FaceHint.manual);
    if (camera.value.isStreamingImages) await camera.stopImageStream();
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (_busy || _capturing || _hint == FaceHint.manual) return;
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

      setState(() => _hint = hint);

      if (hint == FaceHint.ok) {
        _okSince ??= DateTime.now();
        if (DateTime.now().difference(_okSince!) >= _holdStill) await _capture();
      } else {
        _okSince = null;
      }
    } catch (_) {
      // Пропущенный кадр не страшен: следующий придёт через доли секунды
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
    if (faces.isEmpty) return FaceHint.noFace;

    final main = faces.reduce((a, b) => a.boundingBox.height >= b.boundingBox.height ? a : b);
    final big = faces.where((f) => f.boundingBox.height >= main.boundingBox.height * _secondFaceShare);

    if (big.length > 1) return FaceHint.manyFaces;

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

    final left = main.leftEyeOpenProbability;
    final right = main.rightEyeOpenProbability;

    if ((left != null && left < _eyeOpenMin) || (right != null && right < _eyeOpenMin)) return FaceHint.eyes;

    return FaceHint.ok;
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _capturing) return;

    setState(() => _capturing = true);

    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      final shot = await camera.takePicture();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(File(shot.path));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _okSince = null;
      });
      if (_hint != FaceHint.manual) await camera.startImageStream(_onFrame);
    }
  }

  String get _hintText => _capturing
      ? t('faceCapturing')
      : switch (_hint) {
        FaceHint.starting => t('faceStarting'),
        FaceHint.noFace => t('faceNotFound'),
        FaceHint.manyFaces => t('faceOnlyOne'),
        FaceHint.closer => t('faceCloser'),
        FaceHint.farther => t('faceFarther'),
        FaceHint.center => t('faceCenter'),
        FaceHint.straight => t('faceStraight'),
        FaceHint.eyes => t('faceEyes'),
        FaceHint.ok => t('faceHold'),
        FaceHint.manual => t('faceManual'),
      };

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = _hint == FaceHint.ok || _capturing;
    // Кнопка только на телефонах, где распознавание не заработало; обычно снимок делается сам
    final manual = _hint == FaceHint.manual;

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
                const Spacer(),
                if (_error != null)
                  _Banner(text: _error!, color: Brand.red)
                else
                  _Banner(text: _hintText, color: ready ? Brand.green : Colors.black54),
                const SizedBox(height: 12),
                _PlaceChip(position: widget.position, office: widget.office),
                if (manual) ...[
                  const SizedBox(height: 20),
                  _Shutter(enabled: !_capturing, busy: _capturing, onPressed: _capture),
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

/// Где человек относительно офиса: «Объект ёнидасиз · 10 м · GPS ±4 м».
class _PlaceChip extends StatelessWidget {
  final Position position;
  final AttendanceOffice? office;

  const _PlaceChip({required this.position, required this.office});

  @override
  Widget build(BuildContext context) {
    final office = this.office;
    final accuracy = 'GPS ±${position.accuracy.round()} ${t('metersUnit')}';

    if (office == null) return _chip(Icons.location_on_outlined, accuracy, Colors.white24);

    final meters = Geolocator.distanceBetween(position.latitude, position.longitude, office.lat, office.lon).round();
    final near = meters <= office.radiusM;
    final text = near
        ? '${t('nearOffice')} · $meters ${t('metersUnit')} · $accuracy'
        : '${t('farFromOffice').replaceAll('{m}', '$meters')} · $accuracy';

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

/// Кнопка затвора — только когда распознавание на этом телефоне не заработало.
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
