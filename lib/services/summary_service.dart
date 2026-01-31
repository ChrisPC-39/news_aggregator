import 'package:firebase_ai/firebase_ai.dart';
import '../models/news_story_model.dart';

class SummaryService {
  /// Generates an AI summary from the articles in a [NewsStory].
  Future<String> generateSummary(NewsStory story) async {
    // 1. Format the content from your model
    // Assuming NewsStory has a list of articles with a 'content' or 'body' field
    final articleTexts = story.articles
        .map((a) => "Title: ${a.title}\nContent: ${a.content}")
        .join('\n\n---\n\n');

    final prompt = '''
Ești un editor de știri imparțial. Rezumă următoarele articole într-un singur paragraf concis, folosind un ton neutru și obiectiv.

INSTRUCȚIUNI STRICTE:
1. Limba: Răspunde exclusiv în limba română.
2. Format: Returnează doar text simplu (plain text). Nu folosi Markdown, caractere de tip bold (**), liste cu puncte sau titluri.
3. Obiectivitate: Identifică orice urmă de subiectivism sau părtinire (bias) din sursele oferite.

STRUCTURA RĂSPUNSULUI:
- Paragraful cu rezumatul.
- O linie goală.
- O listă la final unde enumeri bias-urile identificate pentru fiecare sursă în parte.

ARTICOLE DE ANALIZAT:
$articleTexts
''';

    try {
      // 2. Initialize the model (Gemini 1.5 Flash is the "small/fast" model)
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-lite'
      );

      // 3. Make the API call
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      // 4. Return the text or a fallback if empty
      return response.text ?? '';
    } catch (e) {
      // Handle potential quota or network errors
      return 'Error generating summary: $e';
    }
  }
}