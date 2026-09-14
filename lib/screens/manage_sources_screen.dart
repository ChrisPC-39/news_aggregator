import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../globals.dart';
import '../services/source_settings_service.dart';

/// Lets the user see every configured news source and turn individual ones
/// off. Disabled sources are skipped entirely during the next crawl, which
/// both hides their articles and cuts refresh time.
class ManageSourcesScreen extends StatefulWidget {
  const ManageSourcesScreen({super.key});

  @override
  State<ManageSourcesScreen> createState() => _ManageSourcesScreenState();
}

class _ManageSourcesScreenState extends State<ManageSourcesScreen> {
  final _settingsService = SourceSettingsService();

  late final List<MapEntry<String, String>> _sources;
  late Set<String> _disabledDomains;

  @override
  void initState() {
    super.initState();
    _sources = Globals.sourceConfigs.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    _disabledDomains = _settingsService.getDisabledSources();
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _sources.length - _disabledDomains.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Manage Sources',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(enabledCount),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _sources.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildSourceTile(_sources[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int enabledCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$enabledCount of ${_sources.length} sources enabled',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _disabledDomains.isEmpty ? null : _enableAll,
                child: const Text('Enable all'),
              ),
              TextButton(
                onPressed: _disabledDomains.length == _sources.length
                    ? null
                    : _disableAll,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                child: const Text('Disable all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(MapEntry<String, String> source) {
    final domain = _settingsService.domainFor(source.value);
    final isEnabled = !_disabledDomains.contains(domain);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isEnabled ? 0.05 : 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF8B5CF6),
            title: Text(
              source.key,
              style: GoogleFonts.lexend(
                color: isEnabled ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              domain,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isEnabled ? 0.4 : 0.25),
                fontSize: 12,
              ),
            ),
            value: isEnabled,
            onChanged: (value) => _toggle(domain, value),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(String domain, bool enabled) async {
    setState(() {
      if (enabled) {
        _disabledDomains.remove(domain);
      } else {
        _disabledDomains.add(domain);
      }
    });
    await _settingsService.setEnabled(domain, enabled);
  }

  Future<void> _enableAll() async {
    setState(() => _disabledDomains.clear());
    await _settingsService.enableAll();
  }

  Future<void> _disableAll() async {
    setState(() {
      _disabledDomains = _sources
          .map((e) => _settingsService.domainFor(e.value))
          .toSet();
    });
    await _settingsService.disableAll();
  }
}
