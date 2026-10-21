import 'package:alumni_system/shared/widgets/user/portal_floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _navHeight = 84.0;

/// A tab page as the shell lays it out: `extendBody` puts the nav height in
/// the bottom padding, and the nav fade sits over the body.
Widget _tab({int items = 30}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(400, 800),
        padding: EdgeInsets.only(bottom: _navHeight),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (context) => CustomScrollView(
                  slivers: [
                    const PortalFloatingFilterHeader(
                      child: SizedBox(
                        key: Key('filter-card'),
                        height: 60,
                        child: Text('Search'),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: items,
                      itemBuilder: (_, i) => SizedBox(
                        key: Key('item-$i'),
                        height: 80,
                        child: Text('Item $i'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: PortalFloating.bottomClearance(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PortalNavFade(navHeight: _navHeight),
            ),
          ],
        ),
      ),
    ),
  );
}

PortalFloatingCard _card(WidgetTester tester) =>
    tester.widget(find.byType(PortalFloatingCard));

void main() {
  testWidgets('filter card stays pinned and lifts once content scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_tab());

    final top = tester.getTopLeft(find.byKey(const Key('filter-card'))).dy;
    expect(_card(tester).lifted, isFalse);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const Key('filter-card'))).dy, top);
    expect(_card(tester).lifted, isTrue);
    expect(find.text('Item 0'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(_card(tester).lifted, isFalse);
  });

  testWidgets('last item scrolls fully above the nav bar and fade', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_tab(items: 12));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final lastBottom = tester
        .getBottomLeft(find.byKey(const Key('item-11')))
        .dy;
    final fadeTop = tester.getTopLeft(find.byType(PortalNavFade)).dy;
    expect(lastBottom, lessThanOrEqualTo(fadeTop));
  });

  testWidgets('nav fade is purely visual', (tester) async {
    await tester.pumpWidget(_tab());
    final fade = tester.getSize(find.byType(PortalNavFade));
    expect(fade.height, _navHeight);
    expect(
      find.descendant(
        of: find.byType(PortalNavFade),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nav pill is opaque white with shadow below it', (tester) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: const ColoredBox(
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: 300,
                height: 64,
                child: PortalFrostedPill(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);

    final pill = tester.getRect(find.byType(PortalFrostedPill));
    final (bytes, width) = (await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await render.toImage();
      return (await img.toByteData(), img.width);
    }))!;
    int red(Offset p) =>
        bytes!.getUint8((p.dy.round() * width + p.dx.round()) * 4);

    for (final dy in [pill.top + 4, pill.center.dy, pill.bottom - 8]) {
      expect(red(Offset(pill.center.dx, dy)), greaterThanOrEqualTo(252));
    }
    expect(red(Offset(pill.center.dx, pill.bottom + 6)), lessThan(245));
  });
}
