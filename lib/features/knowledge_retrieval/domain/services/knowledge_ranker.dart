import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract final class KnowledgeRankingConfig {
  static const symptomPhrase = 12;
  static const symptomToken = 3;
  static const affectedPart = 5;
  static const environment = 3;
  static const growthStage = 2;
  static const category = 2;
  static const caution = 1;
  static const minimumScore = 14;
  static const maximumResults = 5;
}

final class KnowledgeRanker {
  const KnowledgeRanker();

  List<RankedKnowledgeMatch> rank({
    required String canonicalPlantKey,
    required Plant plant,
    required PlantObservation observation,
    required List<KnowledgeChunk> chunks,
  }) {
    final corpus = _tokens(
      [
        ...observation.observations.map((item) => item.type.name),
        ...observation.observations.map((item) => item.description),
        observation.distribution,
        observation.severity.name,
        ...observation.imageQuality.issues.map((item) => item.name),
      ].join(' '),
    );
    final orderedCorpus = _tokenList(
      [
        ...observation.observations.map((item) => item.type.name),
        ...observation.observations.map((item) => item.description),
        observation.distribution,
        observation.severity.name,
        ...observation.imageQuality.issues.map((item) => item.name),
      ].join(' '),
    );
    final parts = observation.affectedParts
        .map((item) => _snakeName(item.name))
        .toSet();
    final relevantCategories = _relevantCategories(observation);
    final needsCaution =
        !observation.imageQuality.usable ||
        observation.imageQuality.issues.isNotEmpty ||
        observation.severity == ObservationSeverity.severe ||
        observation.severity == ObservationSeverity.unclear;

    final matches = <RankedKnowledgeMatch>[];
    for (final chunk in chunks) {
      if (chunk.canonicalPlantKey != canonicalPlantKey) continue;
      var score = 0;
      final reasons = <String>[];
      for (final keyword in chunk.symptomKeywords) {
        final phrase = _tokenList(keyword.replaceAll('_', ' '));
        if (phrase.isEmpty) continue;
        if (_containsPhrase(orderedCorpus, phrase)) {
          score += KnowledgeRankingConfig.symptomPhrase;
          reasons.add('matched symptom: ${phrase.join(' ')}');
        } else {
          final overlap = phrase.toSet().intersection(corpus);
          if (overlap.isNotEmpty) {
            score += overlap.length * KnowledgeRankingConfig.symptomToken;
            reasons.add('related symptom terms: ${overlap.toList()..sort()}');
          }
        }
      }
      final matchedParts = chunk.affectedParts.toSet().intersection(parts);
      if (matchedParts.isNotEmpty) {
        score += matchedParts.length * KnowledgeRankingConfig.affectedPart;
        reasons.add('matched part: ${matchedParts.toList()..sort()}');
      }
      if (chunk.environment.contains(plant.environment.name)) {
        score += KnowledgeRankingConfig.environment;
        reasons.add('applies ${plant.environment.name}s');
      }
      if (chunk.growthStages.contains(plant.growthStage.name)) {
        score += KnowledgeRankingConfig.growthStage;
        reasons.add('matches ${plant.growthStage.name} growth stage');
      }
      if (relevantCategories.contains(chunk.category)) {
        score += KnowledgeRankingConfig.category;
        reasons.add('category relates to the visible observation');
      }
      if (needsCaution && chunk.cautions.isNotEmpty) {
        score += KnowledgeRankingConfig.caution;
        reasons.add('includes relevant caution');
      }
      if (score >= KnowledgeRankingConfig.minimumScore) {
        matches.add(
          RankedKnowledgeMatch(
            chunk: chunk,
            score: score,
            matchedSignals: reasons,
          ),
        );
      }
    }
    matches.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final title = left.chunk.title.compareTo(right.chunk.title);
      return title != 0 ? title : left.chunk.id.compareTo(right.chunk.id);
    });
    return matches.take(KnowledgeRankingConfig.maximumResults).toList();
  }

  Set<String> _relevantCategories(PlantObservation observation) {
    final result = <String>{};
    for (final item in observation.observations) {
      switch (item.type) {
        case VisualObservationType.insects:
        case VisualObservationType.webbing:
        case VisualObservationType.holes:
        case VisualObservationType.residue:
          result.add('pests');
        case VisualObservationType.spots:
        case VisualObservationType.lesions:
        case VisualObservationType.moldLikeGrowth:
          result.addAll(const {
            'fungal_disease',
            'bacterial_disease',
            'viral_disease',
          });
        case VisualObservationType.wilting:
          result.addAll(const {'overwatering', 'underwatering'});
        default:
          break;
      }
    }
    return result;
  }

  bool _containsPhrase(List<String> corpus, List<String> phrase) {
    if (phrase.length > corpus.length) return false;
    for (var index = 0; index <= corpus.length - phrase.length; index++) {
      var matches = true;
      for (var offset = 0; offset < phrase.length; offset++) {
        if (corpus[index + offset] != phrase[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  Set<String> _tokens(String value) => _tokenList(value).toSet();

  List<String> _tokenList(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map(_singular)
      .toList(growable: false);

  String _singular(String token) {
    const irregular = {'leaves': 'leaf'};
    if (irregular.containsKey(token)) return irregular[token]!;
    if (token.length > 4 && token.endsWith('ies')) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.length > 4 && token.endsWith('s') && !token.endsWith('ss')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  String _snakeName(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .toLowerCase();
}
