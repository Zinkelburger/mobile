import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/common_analysis_prefs.dart';

void main() {
  group('AnalysisPrefs.boardScale', () {
    final json = AnalysisPrefs.defaults.toJson()..remove('boardScale');

    test('migrates the former small board setting', () {
      expect(AnalysisPrefs.fromJson({...json, 'smallBoard': true}).boardScale, kSmallBoardScale);
      expect(AnalysisPrefs.fromJson({...json, 'smallBoard': false}).boardScale, 1.0);
    });

    test('defaults to the full board size', () {
      expect(AnalysisPrefs.fromJson(json).boardScale, 1.0);
    });

    test('prefers the stored board scale', () {
      expect(
        AnalysisPrefs.fromJson({...json, 'smallBoard': true, 'boardScale': 0.65}).boardScale,
        0.65,
      );
    });
  });
}
