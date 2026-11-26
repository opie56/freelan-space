import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/retained_tab_body.dart';

void main() {
  testWidgets('tabs mount on first visit and keep data and scroll position', (
    tester,
  ) async {
    final started = <int, int>{};
    late StateSetter selectTab;
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            selectTab = setState;
            return Scaffold(
              body: RetainedTabBody(
                index: selected,
                pages: [
                  for (var i = 0; i < 4; i++)
                    _LoadedPage(i, () {
                      started.update(
                        i,
                        (count) => count + 1,
                        ifAbsent: () => 1,
                      );
                      return Future.value(i);
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(started, {0: 1});

    final home = find.byKey(const ValueKey(0));
    await tester.drag(home, const Offset(0, -400));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: home, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(position, greaterThan(0));

    for (final index in [1, 2, 3, 0, 2, 0]) {
      selectTab(() => selected = index);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(index)).hitTestable(), findsOneWidget);
    }

    final restored = tester
        .state<ScrollableState>(
          find.descendant(of: home, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(restored, position);
    expect(started, {0: 1, 1: 1, 2: 1, 3: 1});
  });
}

class _LoadedPage extends StatefulWidget {
  const _LoadedPage(this.index, this.load);
  final int index;
  final Future<int> Function() load;

  @override
  State<_LoadedPage> createState() => _LoadedPageState();
}

class _LoadedPageState extends State<_LoadedPage> {
  late final data = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: data,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();
      return ListView.builder(
        key: ValueKey(widget.index),
        itemCount: 40,
        itemExtent: 60,
        itemBuilder: (_, index) => Text('Tab ${snapshot.data}, row $index'),
      );
    },
  );
}
