import 'package:flutter/material.dart';

/// Stable accents and geometry distinguish destinations while keeping controls
/// consistent throughout the Windows console.
enum AdminDestination {
  setup(0, 0xff5552b7),
  signIn(1, 0xff6134ad),
  dashboard(2, 0xff5a36ad),
  actions(3, 0xff247b88),
  campaigns(4, 0xff98528d),
  submissions(5, 0xff3a6eab),
  coins(6, 0xffa47528),
  overview(7, 0xff4664b2),
  activity(8, 0xff3d8370),
  reports(9, 0xff5a72aa),
  alerts(10, 0xffac6c36),
  roles(11, 0xff7554a6),
  userDetails(12, 0xff397e95),
  desktop(13, 0xff59488a),
  releases(14, 0xff5341ad),
  notifications(15, 0xff287788),
  tickets(16, 0xff3c8096),
  inbox(17, 0xff596ca3),
  campaignReports(18, 0xffa26062),
  adjustments(19, 0xff9c7830),
  alertSettings(20, 0xffa76d3d),
  trends(21, 0xff3c8372),
  notes(22, 0xff85713c),
  security(23, 0xff715298),
  conversation(24, 0xff397991);

  const AdminDestination(this.designId, this.hex);
  final int designId, hex;
  Color get accent => Color(hex);
}

class AdminDestinationScaffold extends Scaffold {
  AdminDestinationScaffold({
    super.key,
    required AdminDestination destination,
    required Widget body,
    double minBodyHeight = 0,
    super.appBar,
    super.floatingActionButton,
    super.bottomNavigationBar,
  }) : super(
         backgroundColor: Colors.transparent,
         body: AdminDestinationCanvas(
           destination: destination,
           child: minBodyHeight == 0
               ? body
               : _ShortAdminViewport(minHeight: minBodyHeight, child: body),
         ),
       );
}

/// Show a draggable thumb wherever an admin page has more content to scroll.
class AdminScrollBehavior extends MaterialScrollBehavior {
  const AdminScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => Scrollbar(
    controller: details.controller,
    thumbVisibility: true,
    child: child,
  );
}

/// Give pages with fixed filters and a flexible results list enough room to
/// lay out. The surrounding page only scrolls in a short window.
class _ShortAdminViewport extends StatelessWidget {
  const _ShortAdminViewport({required this.minHeight, required this.child});
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final short = constraints.maxHeight < minHeight;
      return SingleChildScrollView(
        primary: false,
        physics: short ? null : const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: short ? minHeight : constraints.maxHeight,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: short ? 12 : 0),
            child: child,
          ),
        ),
      );
    },
  );
}

class AdminDestinationCanvas extends StatelessWidget {
  const AdminDestinationCanvas({
    super.key,
    required this.destination,
    required this.child,
    this.enabled = true,
  });
  final AdminDestination destination;
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => !enabled
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(painter: _DestinationArt(destination)),
                ),
              ),
            ),
            child,
          ],
        );
}

class _DestinationArt extends CustomPainter {
  const _DestinationArt(this.destination);
  final AdminDestination destination;
  @override
  void paint(Canvas canvas, Size size) {
    final accent = destination.accent;
    final i = destination.designId;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, accent, .035)!,
            Color.lerp(Colors.white, accent, .095)!,
          ],
        ).createShader(rect),
    );
    final fill = Paint()..color = accent.withValues(alpha: .065);
    final line = Paint()
      ..color = accent.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = size.width, h = size.height;
    final right = i.isEven;
    final x = right ? w : 0.0;
    switch (i % 6) {
      case 0:
        for (var n = 0; n < 4; n++) {
          canvas.drawCircle(Offset(x, h * .14), 80 + n * 46, line);
        }
        canvas.drawCircle(Offset(w * .75, h), w * .2, fill);
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(w * .5, 0)
            ..lineTo(w * .15, h * .3)
            ..lineTo(0, h * .3)
            ..close(),
          fill,
        );
        canvas.drawLine(Offset(w * .6, 0), Offset(w * .2, h * .3), line);
      case 2:
        for (var n = 0; n < 6; n++) {
          canvas.drawLine(
            Offset(x, h * .08 + n * 25),
            Offset(right ? w * .6 : w * .4, n * 25),
            line,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .65, h * .7, w * .3, h * .22),
            const Radius.circular(32),
          ),
          fill,
        );
      case 3:
        for (var row = 0; row < 5; row++) {
          for (var col = 0; col < 9; col++) {
            canvas.drawCircle(
              Offset(right ? w - 24 - col * 20 : 24 + col * 20, 24 + row * 20),
              2,
              fill,
            );
          }
        }
        canvas.drawCircle(Offset(x, h * .8), 120, line);
      case 4:
        final path = Path()
          ..moveTo(0, h * .12)
          ..quadraticBezierTo(w * .5, -h * .04, w, h * .1)
          ..lineTo(w, 0)
          ..lineTo(0, 0)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawLine(Offset(0, h * .14), Offset(w, h * .12), line);
      case 5:
        for (var n = 0; n < 3; n++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                right ? w - 180 + n * 28 : -60 + n * 28,
                -65 + n * 24,
                170,
                150,
              ),
              const Radius.circular(36),
            ),
            n == 0 ? fill : line,
          );
        }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 5, h),
      Paint()..color = accent.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _DestinationArt oldDelegate) =>
      oldDelegate.destination != destination;
}
