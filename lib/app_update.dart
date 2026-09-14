class AppUpdate {
  final String version;
  final String date;
  final List<String> changes;

  AppUpdate({required this.version, required this.date, required this.changes});
}

final List<AppUpdate> changelogData = [
  AppUpdate(
    version: "v1.1.0",
    date: "Sep 2026",
    changes: [
      "Timeouts on news sources (10 seconds)",
      "New similarity threshold default: 0.3%"
    ],
  ),
  AppUpdate(
    version: "v1.0.0",
    date: "Mar 2026",
    changes: [
      "Display bookmarks in separate screen",
      "Improve performance when refreshing",
      "Add better highlights in drawer"
    ],
  ),
  AppUpdate(
    version: "v1.0.0-RC1",
    date: "Feb 2026",
    changes: [
      "Custom thresholds",
      "Hive fix for running in isolate",
      "Improve AI generated summaries"
    ],
  ),
  AppUpdate(
    version: "v0.1.1-BETA",
    date: "Jan 2026",
    changes: [
      "Major UI overhaul",
      "Added ability to bookmark stories (synced with account)",
    ],
  ),
  AppUpdate(
    version: "v0.1.0-BETA",
    date: "Jan 2026",
    changes: [
      "Firebase authentication",
      "Update scoring service to V3 (Inverted index)",
    ],
  ),
];
