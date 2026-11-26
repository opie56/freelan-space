import 'package:flutter/material.dart';

/// Mount each tab on its first visit and retain it for the current shell.
class RetainedTabBody extends StatefulWidget {
  const RetainedTabBody({super.key, required this.index, required this.pages});

  final int index;
  final List<Widget> pages;

  @override
  State<RetainedTabBody> createState() => _RetainedTabBodyState();
}

class _RetainedTabBodyState extends State<RetainedTabBody> {
  late final visited = <int>{widget.index};

  @override
  void didUpdateWidget(covariant RetainedTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: widget.index,
    sizing: StackFit.expand,
    children: [
      for (var i = 0; i < widget.pages.length; i++)
        if (visited.contains(i))
          TickerMode(
            enabled: i == widget.index,
            child: ExcludeFocus(
              excluding: i != widget.index,
              child: PrimaryScrollController.none(child: widget.pages[i]),
            ),
          )
        else
          const SizedBox.shrink(),
    ],
  );
}
