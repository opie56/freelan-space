import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design.dart';
import 'evidence_image.dart';
import 'user_localization.dart';

class HomeSlide {
  const HomeSlide({
    required this.id,
    required this.kind,
    required this.title,
    this.image,
    this.mime,
    this.enabled = true,
  });
  final String id, kind, title;
  final Uint8List? image;
  final String? mime;
  final bool enabled;
  static const defaults = [
    HomeSlide(
      id: '00000000-0000-4000-8000-000000000001',
      kind: 'referral',
      title: 'Referral rewards',
    ),
    HomeSlide(
      id: '00000000-0000-4000-8000-000000000002',
      kind: 'earnings',
      title: 'Campaign earnings',
    ),
  ];
  static Future<HomeSlide> parse(Map<String, dynamic> row) async {
    final kind = row['kind'] as String;
    Uint8List? bytes;
    if (kind == 'image') {
      final encoded = row['image_base64'] as String;
      if (encoded.length > 699052) {
        throw const FormatException('Image too large');
      }
      bytes = base64Decode(encoded);
      await validateEvidenceImage(bytes);
    } else if (kind != 'referral' && kind != 'earnings') {
      throw const FormatException('Unknown slide');
    }
    return HomeSlide(
      id: row['id'] as String,
      kind: kind,
      title: row['title'] as String,
      image: bytes,
      mime: row['mime'] as String?,
      enabled: row['enabled'] as bool? ?? true,
    );
  }
}

class HomeSlidesGateway {
  const HomeSlidesGateway(this.client);
  final SupabaseClient client;
  Future<List<HomeSlide>> load({bool admin = false}) async {
    final rows =
        await client.rpc(admin ? 'admin_home_slides' : 'home_slides') as List;
    final slides = <HomeSlide>[];
    for (final row in rows) {
      try {
        slides.add(
          await HomeSlide.parse(Map<String, dynamic>.from(row as Map)),
        );
      } catch (_) {
        // A corrupt or unsupported image must not hide the other slides.
      }
    }
    return slides;
  }

  Future<void> add(String title, String mime, Uint8List bytes) async {
    await validateEvidenceImage(bytes);
    await client.rpc(
      'admin_add_home_slide',
      params: {
        'p_title': title,
        'p_mime': mime,
        'p_base64': base64Encode(bytes),
      },
    );
  }

  Future<void> setEnabled(HomeSlide slide, bool value) async => client.rpc(
    'admin_set_home_slide_enabled',
    params: {'p_id': slide.id, 'p_enabled': value},
  );
  Future<void> delete(HomeSlide slide) async =>
      client.rpc('admin_delete_home_slide', params: {'p_id': slide.id});
  Future<void> move(HomeSlide slide, int direction) async => client.rpc(
    'admin_move_home_slide',
    params: {'p_id': slide.id, 'p_direction': direction},
  );
}

/// Same artwork is shown on Home and exported from the administrator console.
class HomeSlideArt extends StatelessWidget {
  const HomeSlideArt({super.key, required this.slide});
  final HomeSlide slide;
  @override
  Widget build(BuildContext context) {
    if (slide.image != null) {
      return ColoredBox(
        color: const Color(0xffede8fa),
        child: Image.memory(
          slide.image!,
          semanticLabel: slide.title,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    final referral = slide.kind == 'referral';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: referral ? const Color(0xff4c1aba) : const Color(0xff163d58),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -20,
            top: -45,
            child: ExcludeSemantics(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 25,
                    color: Colors.white.withValues(alpha: .09),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        referral
                            ? userText(
                                context,
                                'Invite friends',
                                'സുഹൃത്തുക്കളെ ക്ഷണിക്കൂ',
                              )
                            : userText(
                                context,
                                'Earn from tasks',
                                'Tasks ചെയ്ത് നേടൂ',
                              ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        referral
                            ? userText(
                                context,
                                'Share your referral code and earn rewards.',
                                'Referral code share ചെയ്ത് rewards നേടൂ.',
                              )
                            : userText(
                                context,
                                'Complete campaign tasks and earn coins.',
                                'Campaign tasks ചെയ്ത് coins നേടൂ.',
                              ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xfff0e9ff),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    referral ? Icons.people_alt_rounded : Icons.toll_rounded,
                    color: referral ? Colors.white : const Color(0xffffd782),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSlideshow extends StatefulWidget {
  const HomeSlideshow({
    super.key,
    this.gateway,
    this.load,
    this.onReferral,
    this.onEarnings,
  });
  final HomeSlidesGateway? gateway;
  final Future<List<HomeSlide>> Function()? load;
  final VoidCallback? onReferral, onEarnings;
  @override
  State<HomeSlideshow> createState() => _HomeSlideshowState();
}

class _HomeSlideshowState extends State<HomeSlideshow>
    with WidgetsBindingObserver {
  late List<HomeSlide> slides;
  bool hasLoaded = false;
  final controller = PageController();
  Timer? cycle, refresh;
  int current = 0;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    slides = widget.gateway == null && widget.load == null
        ? HomeSlide.defaults
        : [];
    reload();
    cycle = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted &&
          slides.length > 1 &&
          controller.hasClients &&
          TickerMode.getValuesNotifier(context).value.enabled &&
          !MediaQuery.disableAnimationsOf(context)) {
        controller.animateToPage(
          (current + 1) % slides.length,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
    if (widget.gateway != null || widget.load != null) {
      refresh = Timer.periodic(const Duration(seconds: 60), (_) => reload());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    if (loading || (widget.load == null && widget.gateway == null)) return;
    loading = true;
    try {
      final updated = await (widget.load?.call() ?? widget.gateway!.load());
      if (!mounted) return;
      setState(() {
        slides = updated;
        current = 0;
        hasLoaded = true;
      });
      if (controller.hasClients && updated.isNotEmpty) controller.jumpToPage(0);
    } catch (_) {
      // On first load, bundled slides remain available without the service.
      if (mounted && !hasLoaded) setState(() => slides = HomeSlide.defaults);
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cycle?.cancel();
    refresh?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio:
                2.25 /
                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
            child: PageView.builder(
              controller: controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => current = i),
              itemBuilder: (context, i) {
                final s = slides[i];
                final onTap = s.kind == 'referral'
                    ? widget.onReferral
                    : s.kind == 'earnings'
                    ? widget.onEarnings
                    : null;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: HomeSlideArt(slide: s),
                  ),
                );
              },
            ),
          ),
        ),
        if (slides.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == current ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == current
                          ? growthPurple
                          : const Color(0xffd2c8e6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
