import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:news_aggregator/services/crawler_service.dart';

import 'news_results_page.dart';

void main() {
  runApp(const NewsAggregatorApp());
}

class NewsAggregatorApp extends StatelessWidget {
  const NewsAggregatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchSettingsPage();
  }
}

class SearchSettingsPage extends StatefulWidget {
  const SearchSettingsPage({super.key});

  @override
  State<SearchSettingsPage> createState() => _SearchSettingsPageState();
}

class _SearchSettingsPageState extends State<SearchSettingsPage> {
  // Controllers for text fields
  final _qController = TextEditingController();
  final _sourcesController = TextEditingController();
  final _domainsController = TextEditingController();
  final _excludeDomainsController = TextEditingController();
  final _pageSizeController = TextEditingController(text: '10');
  final _pageController = TextEditingController(text: '1');

  // State for checkboxes
  final Map<String, bool> _searchInOptions = {
    'title': false,
    'description': false,
    'content': false,
  };

  // State for dates
  DateTime _fromDate = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day - 7);
  DateTime _toDate = DateTime.now();

  // State for dropdowns
  String _language = 'ro';
  String _sortBy = 'publishedAt';

  final _formKey = GlobalKey<FormState>();

  // Date format for display
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> _selectDateTime(BuildContext context, bool isFromDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          (isFromDate ? _fromDate : _toDate) ?? DateTime.now()),
    );

    if (pickedTime == null) return;

    setState(() {
      final selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (isFromDate) {
        _fromDate = selectedDateTime;
      } else {
        _toDate = selectedDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Search Settings'),
        backgroundColor: Theme
            .of(context)
            .primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Search Query'),
              TextFormField(
                controller: _qController,
                decoration: const InputDecoration(
                  labelText: 'Keywords (q)',
                  hintText: '+bitcoin AND (ethereum OR litecoin)',
                  helperText: 'Keywords or phrases to search for. Use " " for exact match, + for must-have, - for must-not.',
                  helperMaxLines: 3,
                ),
                maxLength: 500,
              ),
              const SizedBox(height: 24),

              _buildExpansionTile(
                title: 'Advanced Search Options',
                children: [
                  _buildSectionTitle('Search In'),
                  ..._searchInOptions.keys.map((String key) {
                    return CheckboxListTile(
                      title: Text(key),
                      value: _searchInOptions[key],
                      onChanged: (bool? value) {
                        setState(() {
                          _searchInOptions[key] = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Sources and Domains'),
                  TextFormField(
                    controller: _sourcesController,
                    decoration: const InputDecoration(
                      labelText: 'Sources',
                      hintText: 'bbc-news,techcrunch',
                      helperText: 'A comma-separated string of source identifiers (max 20).',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _domainsController,
                    decoration: const InputDecoration(
                      labelText: 'Domains',
                      hintText: 'bbc.co.uk,techcrunch.com',
                      helperText: 'Comma-separated domains to restrict the search to.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _excludeDomainsController,
                    decoration: const InputDecoration(
                      labelText: 'Exclude Domains',
                      hintText: 'engadget.com',
                      helperText: 'Comma-separated domains to remove from results.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildExpansionTile(
                title: 'Date, Language, and Sorting',
                initiallyExpanded: true,
                children: [
                  _buildSectionTitle('Date Range'),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'From',
                          ),
                          child: Text(
                            _fromDate != null
                                ? _dateFormat.format(_fromDate!)
                                : 'Not Set',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDateTime(context, true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'To',
                          ),
                          child: Text(
                            _toDate != null
                                ? _dateFormat.format(_toDate!)
                                : 'Not Set',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDateTime(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Language'),
                  DropdownButtonFormField<String>(
                    value: _language,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                    ),
                    hint: const Text('Select Language'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _language = newValue!;
                      });
                    },
                    items: [
                      'en',
                      'ro'
                    ]
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Sort By'),
                  DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _sortBy = newValue!;
                      });
                    },
                    items: ['relevancy', 'popularity', 'publishedAt']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildExpansionTile(
                title: 'Pagination',
                children: [
                  _buildSectionTitle('Pagination'),
                  TextFormField(
                    controller: _pageSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Page Size',
                      helperText: 'Number of results per page (Default: 100, Max: 100).',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pageController,
                    decoration: const InputDecoration(
                      labelText: 'Page',
                      helperText: 'Use this to page through the results (Default: 1).',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Apply Filters'),
                  onPressed: () {
                    final String searchIn = _searchInOptions.entries
                        .where((entry) => entry.value)
                        .map((entry) => entry.key)
                        .join(',');

                    final Map<String, dynamic> searchParams = {
                      'q': _qController.text,
                      'searchIn': searchIn,
                      'sources': _sourcesController.text,
                      'domains': _domainsController.text,
                      'excludeDomains': _excludeDomainsController.text,
                      'from': _fromDate,
                      'to': _toDate,
                      'language': _language,
                      'sortBy': _sortBy,
                      'pageSize': _pageSizeController.text,
                      'page': _pageController.text,
                    };

                    // 2. Navigate to the results page, passing the parameters
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsResultsPage(searchParams: searchParams),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: Theme
                        .of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    backgroundColor: Theme
                        .of(context)
                        .primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme
            .of(context)
            .textTheme
            .titleLarge
            ?.copyWith(
          color: Theme
              .of(context)
              .primaryColor,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildExpansionTile({required String title, required List<
      Widget> children, bool initiallyExpanded = false}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: initiallyExpanded,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qController.dispose();
    _sourcesController.dispose();
    _domainsController.dispose();
    _excludeDomainsController.dispose();
    _pageSizeController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
