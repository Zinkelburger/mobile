import 'dart:convert';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/common_analysis_prefs.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_layout.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_helpers.dart';
import '../../test_provider_scope.dart';

void main() {
  testWidgets('board background size should match board size on all surfaces', (
    WidgetTester tester,
  ) async {
    for (final surface in kTestSurfaces) {
      final app = await makeTestProviderScope(
        key: ValueKey(surface),
        tester,
        child: MaterialApp(
          home: DefaultTabController(
            length: 1,
            child: AnalysisLayout(
              pov: Side.white,
              sideToMove: Side.white,
              boardBuilder: (context, boardSize, boardRadius) {
                return StaticChessboard(
                  size: boardSize,
                  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
                  orientation: Side.white,
                );
              },
              bottomBar: const SizedBox(height: kBottomBarHeight),
              children: const [Center(child: Text('Analysis tab'))],
            ),
          ),
        ),
        surfaceSize: surface,
      );
      await tester.pumpWidget(app);

      final backgroundSize = tester.getSize(find.byType(SolidColorChessboardBackground));

      expect(
        backgroundSize.width,
        backgroundSize.height,
        reason: 'Board background size is square on $surface',
      );

      final boardSize = tester.getSize(find.byType(StaticChessboard));

      expect(boardSize.width, boardSize.height, reason: 'Board size is square on $surface');

      expect(
        boardSize,
        backgroundSize,
        reason: 'Board size should match background size on $surface',
      );
    }
  }, variant: kPlatformVariant);

  testWidgets('board size and table side size should be harmonious on all surfaces', (
    WidgetTester tester,
  ) async {
    for (final surface in kTestSurfaces) {
      final app = await makeTestProviderScope(
        key: ValueKey(surface),
        tester,
        child: MaterialApp(
          home: DefaultTabController(
            length: 1,
            child: AnalysisLayout(
              pov: Side.white,
              sideToMove: Side.white,
              boardBuilder: (context, boardSize, boardRadius) {
                return StaticChessboard(
                  size: boardSize,
                  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
                  orientation: Side.white,
                );
              },
              bottomBar: const SizedBox(height: kBottomBarHeight),
              children: const [Center(child: Text('Analysis tab'))],
            ),
          ),
        ),
        surfaceSize: surface,
      );
      await tester.pumpWidget(app);

      final isPortrait = surface.aspectRatio < 1.0;
      final isTablet = surface.shortestSide > 600;
      final boardSize = tester.getSize(find.byType(StaticChessboard));

      if (isPortrait) {
        final expectedBoardSize = isTablet ? surface.width - 32.0 : surface.width;
        expect(
          boardSize,
          Size(expectedBoardSize, expectedBoardSize),
          reason: 'Board size should match surface width on $surface',
        );
      } else {
        final tabBarViewSize = tester.getSize(find.byType(TabBarView));
        final goldenBoardSize = (surface.longestSide / kGoldenRatio) - 32.0;
        final defaultBoardSize = surface.shortestSide - kBottomBarHeight - 32.0;
        final minBoardSize = min(goldenBoardSize, defaultBoardSize);
        final maxBoardSize = max(goldenBoardSize, defaultBoardSize);
        // TabBarView is inside a Card so we need to account for its padding
        const cardPadding = 8.0;
        final minSideWidth = min(
          surface.longestSide - goldenBoardSize - 16.0 * 3 - cardPadding,
          250.0,
        );
        expect(
          boardSize.width,
          greaterThanOrEqualTo(minBoardSize),
          reason: 'Board size should be at least $minBoardSize on $surface',
        );
        expect(
          boardSize.width,
          lessThanOrEqualTo(maxBoardSize),
          reason: 'Board size should be at most $maxBoardSize on $surface',
        );
        expect(
          tabBarViewSize.width,
          greaterThanOrEqualTo(minSideWidth),
          reason: 'Tab bar view width should be at least $minSideWidth on $surface',
        );
      }
    }
  }, variant: kPlatformVariant);

  testWidgets('Landscape board position', (WidgetTester tester) async {
    for (final boardPosition in LandscapeBoardPosition.values) {
      const tabletSurface = Size(1280, 800);
      final app = await makeTestProviderScope(
        key: ValueKey(boardPosition),
        tester,
        child: MaterialApp(
          home: DefaultTabController(
            length: 1,
            child: AnalysisLayout(
              pov: Side.white,
              sideToMove: Side.white,
              boardBuilder: (context, boardSize, boardRadius) {
                return StaticChessboard(
                  size: boardSize,
                  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
                  orientation: Side.white,
                );
              },
              bottomBar: const SizedBox(height: kBottomBarHeight),
              children: const [Center(child: Text('Analysis tab'))],
            ),
          ),
        ),
        defaultPreferences: {
          PrefCategory.board.storageKey: jsonEncode(
            BoardPrefs.defaults.copyWith(landscapeBoardPosition: boardPosition).toJson(),
          ),
        },
        surfaceSize: tabletSurface,
      );
      await tester.pumpWidget(app);

      final boardTopLeft = tester.getTopLeft(find.byType(StaticChessboard));
      final tabBarTopLeft = tester.getTopLeft(find.byType(TabBarView));

      expect(
        tabBarTopLeft.dx,
        boardPosition == LandscapeBoardPosition.left
            ? greaterThan(boardTopLeft.dx)
            : lessThan(boardTopLeft.dx),
      );
    }
  }, variant: kPlatformVariant);

  group('board resize handle', () {
    const surface = Size(390, 844);
    final handle = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Board size',
    );

    Future<Widget> makeLayout(
      WidgetTester tester, {
      required double boardScale,
      ValueChanged<double>? onBoardScaleChanged,
    }) {
      return makeTestProviderScope(
        tester,
        surfaceSize: surface,
        child: MaterialApp(
          home: DefaultTabController(
            length: 1,
            child: AnalysisLayout(
              pov: Side.white,
              sideToMove: Side.white,
              boardScale: boardScale,
              onBoardScaleChanged: onBoardScaleChanged,
              boardBuilder: (context, boardSize, boardRadius) =>
                  StaticChessboard(size: boardSize, fen: kInitialFEN, orientation: Side.white),
              children: const [Center(child: Text('Analysis tab'))],
            ),
          ),
        ),
      );
    }

    testWidgets('is hidden when the board cannot be resized', (tester) async {
      await tester.pumpWidget(await makeLayout(tester, boardScale: 1.0));

      expect(handle, findsNothing);
    });

    testWidgets('dragging up shrinks the board and reports the scale once released', (
      tester,
    ) async {
      final reported = <double>[];
      await tester.pumpWidget(
        await makeLayout(tester, boardScale: 1.0, onBoardScaleChanged: reported.add),
      );

      expect(tester.getSize(find.byType(StaticChessboard)).width, surface.width);

      final gesture = await tester.startGesture(tester.getCenter(handle));
      // move past the drag slop first, so the following moves translate 1:1 into board size
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -78));
      await tester.pump();

      // the board follows the finger during the drag, without saving anything yet
      expect(tester.getSize(find.byType(StaticChessboard)).width, lessThan(surface.width));
      expect(reported, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(reported, hasLength(1));
      expect(reported.single, lessThan(1.0));
      expect(reported.single, greaterThan(kMinBoardScale));
    });

    testWidgets('cannot shrink the board below the minimum scale', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(
        await makeLayout(tester, boardScale: 1.0, onBoardScaleChanged: reported.add),
      );

      await tester.drag(handle, const Offset(0, -600));
      await tester.pump();

      expect(reported.single, kMinBoardScale);
    });

    testWidgets('renders the board at the given scale', (tester) async {
      await tester.pumpWidget(
        await makeLayout(tester, boardScale: kSmallBoardScale, onBoardScaleChanged: (_) {}),
      );

      expect(
        tester.getSize(find.byType(StaticChessboard)).width,
        moreOrLessEquals(surface.width * kSmallBoardScale),
      );
    });
  });
}
