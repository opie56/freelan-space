import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'evidence_image.dart';
import 'user_localization.dart';

class ScreenshotMask {
  const ScreenshotMask(this.rect, {this.blackout = false});
  final Rect rect;
  final bool blackout;
}

// Coordinates are normalized against the original image. The returned PNG is
// newly rendered; pixels outside the crop and covered by blackouts are absent.
Future<Uint8List> renderEditedScreenshot(
  Uint8List input,
  Rect crop,
  List<ScreenshotMask> masks,
) async {
  await validateEvidenceImage(input);
  final bounds = const Rect.fromLTWH(0, 0, 1, 1);
  final clipped = crop.intersect(bounds);
  if (clipped.isEmpty || clipped.width < 0.02 || clipped.height < 0.02) {
    throw const FormatException('Invalid crop');
  }
  final codec = await ui.instantiateImageCodec(
    input,
    targetWidth: 1024,
    allowUpscaling: false,
  );
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final src = Rect.fromLTRB(
        clipped.left * image.width,
        clipped.top * image.height,
        clipped.right * image.width,
        clipped.bottom * image.height,
      );
      final width = math.max(1, src.width.round()),
          height = math.max(1, src.height.round());
      final dst = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(image, src, dst, Paint());
      for (final mask in masks) {
        final region = mask.rect.intersect(clipped);
        if (region.isEmpty) continue;
        final target = Rect.fromLTRB(
          (region.left - clipped.left) * image.width,
          (region.top - clipped.top) * image.height,
          (region.right - clipped.left) * image.width,
          (region.bottom - clipped.top) * image.height,
        ).intersect(dst);
        if (target.isEmpty) continue;
        canvas.save();
        canvas.clipRect(target);
        if (mask.blackout) {
          canvas.drawRect(target, Paint()..color = const Color(0xff000000));
        } else {
          canvas.drawImageRect(
            image,
            src,
            dst,
            Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          );
        }
        canvas.restore();
      }
      final picture = recorder.endRecording();
      try {
        final output = await picture.toImage(width, height);
        try {
          final data = await output.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw const FormatException('Unable to render');
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          await validateEvidenceImage(bytes);
          return bytes;
        } finally {
          output.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class ScreenshotEditor extends StatefulWidget {
  const ScreenshotEditor({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<ScreenshotEditor> createState() => _ScreenshotEditorState();
}

class _ScreenshotEditorState extends State<ScreenshotEditor> {
  Rect crop = const Rect.fromLTWH(0, 0, 1, 1);
  final masks = <ScreenshotMask>[];
  String mode = 'crop';
  Offset? start, current;
  double ratio = 1;
  bool ready = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    readSize();
  }

  Future<void> readSize() async {
    try {
      await validateEvidenceImage(widget.bytes);
      final codec = await ui.instantiateImageCodec(
        widget.bytes,
        targetWidth: 1024,
        allowUpscaling: false,
      );
      try {
        final img = (await codec.getNextFrame()).image;
        try {
          if (mounted) {
            setState(() {
              ratio = img.width / img.height;
              ready = true;
            });
          }
        } finally {
          img.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = userText(
            context,
            'Unable to edit this image.',
            'ചിത്രം edit ചെയ്യാനാകില്ല.',
          ),
        );
      }
    }
  }

  Offset normalize(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0, 1),
    (point.dy / size.height).clamp(0, 1),
  );
  void finish() {
    if (start == null || current == null) return;
    final r = Rect.fromPoints(start!, current!);
    setState(() {
      if (r.width >= 0.02 && r.height >= 0.02) {
        if (mode == 'crop') {
          crop = r;
        } else {
          masks.add(ScreenshotMask(r, blackout: mode == 'hide'));
        }
      }
      start = null;
      current = null;
    });
  }

  Future<void> apply() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await renderEditedScreenshot(widget.bytes, crop, masks);
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = userText(
            context,
            'Unable to save this edit. Try a smaller crop.',
            'Edit save ചെയ്യാനായില്ല. ചെറിയ crop പരീക്ഷിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      userText(context, 'Edit screenshot', 'Screenshot edit ചെയ്യുക'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            userText(
              context,
              'Choose Crop, Blur or Black out, then drag over the image. Check the final preview before submitting.',
              'Crop, Blur അല്ലെങ്കിൽ Black out തിരഞ്ഞെടുത്ത് ചിത്രത്തിൽ drag ചെയ്യുക. Submit ചെയ്യുന്നതിന് മുമ്പ് preview പരിശോധിക്കുക.',
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final v in ['crop', 'blur', 'hide'])
                ChoiceChip(
                  label: Text(
                    v == 'crop'
                        ? 'Crop'
                        : v == 'blur'
                        ? 'Blur'
                        : 'Black out',
                  ),
                  selected: mode == v,
                  onSelected: busy ? null : (_) => setState(() => mode = v),
                ),
            ],
          ),
          if (ready)
            SizedBox(
              width: 420,
              child: AspectRatio(
                aspectRatio: ratio,
                child: LayoutBuilder(
                  builder: (c, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    return GestureDetector(
                      onPanStart: busy
                          ? null
                          : (d) => setState(() {
                              start = normalize(d.localPosition, size);
                              current = start;
                            }),
                      onPanUpdate: busy
                          ? null
                          : (d) => setState(
                              () => current = normalize(d.localPosition, size),
                            ),
                      onPanEnd: busy ? null : (_) => finish(),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(widget.bytes, fit: BoxFit.fill),
                          CustomPaint(
                            painter: _SelectionPainter(
                              crop,
                              masks,
                              start == null || current == null
                                  ? null
                                  : Rect.fromPoints(start!, current!),
                              mode,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (error != null) Text(error!),
          Wrap(
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(
                        () => crop = const Rect.fromLTWH(0, 0, 1, 1),
                      ),
                child: Text(userText(context, 'Reset crop', 'Crop reset')),
              ),
              TextButton(
                onPressed: busy || masks.isEmpty
                    ? null
                    : () => setState(() => masks.removeLast()),
                child: Text(userText(context, 'Undo mask', 'Mask മാറ്റുക')),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(userText(context, 'Cancel', 'റദ്ദാക്കുക')),
      ),
      FilledButton(
        onPressed: busy || !ready ? null : apply,
        child: Text(
          userText(context, 'Apply to preview', 'Preview-ൽ കാണിക്കുക'),
        ),
      ),
    ],
  );
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.crop, this.masks, this.drag, this.mode);
  final Rect crop;
  final List<ScreenshotMask> masks;
  final Rect? drag;
  final String mode;
  Rect scale(Rect r, Size s) => Rect.fromLTRB(
    r.left * s.width,
    r.top * s.height,
    r.right * s.width,
    r.bottom * s.height,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final cropRect = scale(crop, size);
    canvas.drawRect(
      cropRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.amber,
    );
    for (final m in masks) {
      canvas.drawRect(
        scale(m.rect, size),
        Paint()
          ..color = (m.blackout ? Colors.black : Colors.blueGrey).withValues(
            alpha: .65,
          ),
      );
    }
    if (drag != null) {
      canvas.drawRect(
        scale(drag!, size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = mode == 'crop' ? Colors.amber : Colors.red,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) => true;
}
