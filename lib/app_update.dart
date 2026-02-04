class AppUpdate {
  final String version;
  final String date;
  final List<String> changes;

  AppUpdate({required this.version, required this.date, required this.changes});
}

final List<AppUpdate> changelogData = [
  AppUpdate(
    version: "v0.1.1-BETA",
    date: "Jan 2026",
    changes: [
      "Major UI overhaul",
      "Added ability to bookmark stories (synced with account)",
      "Bug fixes",
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
