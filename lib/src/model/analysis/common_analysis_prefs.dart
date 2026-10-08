/// Interface for Analysis's prefs.
abstract class CommonAnalysisPrefs() {
  /// Whether to show the best move arrows.
  bool get showBestMoveArrow;

  /// Whether to show the annotations.
  bool get showAnnotations;
}

/// The smallest size, as a fraction of the full board size, the analysis board can be shrunk to.
const kMinBoardScale = 0.5;

/// The board size used by the former "small board" setting, and by default on tablets.
const kSmallBoardScale = 0.8;

/// Reads the `boardScale` preference, falling back to the `smallBoard` switch it replaced.
Object? readBoardScale(Map<dynamic, dynamic> json, String key) =>
    json[key] ?? (json['smallBoard'] == true ? kSmallBoardScale : 1.0);
