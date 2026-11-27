import 'package:flutter/material.dart';

import 'user_theme.dart';

/// Each destination has its own quiet backdrop; controls and page content remain
/// in the foreground and retain their existing semantics and interactions.
enum UserPageIdentity {
  setup(0),
  signIn(1),
  signUp(2),
  verification(3),
  recovery(4),
  blocked(5),
  home(6),
  earn(7),
  campaigns(8),
  profile(9),
  notifications(10),
  createCampaign(11),
  evidence(12),
  coinHistory(13),
  instagramAccounts(14),
  referrals(15),
  settings(16),
  submissionHistory(17),
  help(18),
  support(19),
  conversation(20),
  personalInfo(21),
  changeEmail(22),
  purchase(23),
  transfer(24),
  processing(25),
  resultSuccess(26),
  resultFailure(27),
  resultUnknown(28),
  privacy(29),
  terms(30),
  updates(31),
  mandatoryUpdate(32),
  realName(33);

  const UserPageIdentity(this.designId);
  final int designId;
}

class UserPageScaffold extends Scaffold {
  UserPageScaffold({
    super.key,
    required UserPageIdentity identity,
    required Widget body,
    bool enabled = true,
    super.appBar,
    super.bottomNavigationBar,
    super.floatingActionButton,
    super.resizeToAvoidBottomInset,
  }) : super(
         body: UserPageCanvas(
           identity: identity,
           enabled: enabled,
           child: enabled
               ? Center(
                   child: ConstrainedBox(
                     constraints: const BoxConstraints(maxWidth: 960),
                     child: body,
                   ),
                 )
               : body,
         ),
         backgroundColor: enabled ? Colors.transparent : null,
       );
}

class UserPageCanvas extends StatelessWidget {
  const UserPageCanvas({
    super.key,
    required this.identity,
    required this.child,
    this.enabled = true,
  });
  final UserPageIdentity identity;
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
                  child: CustomPaint(painter: _PagePainter(identity)),
                ),
              ),
            ),
            child,
          ],
        );
}

class _PagePainter extends CustomPainter {
  const _PagePainter(this.identity);
  final UserPageIdentity identity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = userCanvas);
    // A quiet, destination-specific orbit connects the screens to the brand.
    // Keep the reading area clear; decoration never captures interaction.
    final i = identity.designId;
    final center = Offset(size.width * .96, 18.0 + i * 2.5);
    final radius = 62.0 + i * 2.8;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xffefecf8));
    canvas.drawCircle(
      center,
      radius + 18,
      Paint()
        ..color = const Color(0xffe5e1f2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PagePainter oldDelegate) =>
      oldDelegate.identity != identity;
}
