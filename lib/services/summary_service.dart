import 'package:firebase_ai/firebase_ai.dart';
import '../models/news_story_model.dart';

class SummaryService {
  /// Generates an AI summary from the articles in a [NewsStory].
  Future<String> generateSummary(String combinedContent) async {
    final prompt = '''
Ești un editor de știri imparțial. Rezumă următoarele articole într-un singur paragraf concis, folosind un ton neutru și obiectiv.

INSTRUCȚIUNI STRICTE:
1. Limba: Răspunde exclusiv în limba română.
2. Format: Returnează text sub forma de markdown pentru a afisa continutul intr-un mod cat mai usor de citit de utilizatori.
3. Obiectivitate: Identifică orice urmă de subiectivism sau părtinire (bias) din sursele oferite.

STRUCTURA RĂSPUNSULUI:
- Paragraful cu rezumatul plain text.
- O linie goală.
- O listă la final unde enumeri bias-urile identificate pentru fiecare sursă în parte, intr-o lista sub forma de bullet points.

ARTICOLE DE ANALIZAT:
$combinedContent
''';

    try {
      final model = FirebaseAI.googleAI().generativeModel(
          model: 'gemini-2.5-flash-lite'
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      return response.text ?? '';
    } catch (e) {
      return 'Error generating summary: $e';
    }
  }
}