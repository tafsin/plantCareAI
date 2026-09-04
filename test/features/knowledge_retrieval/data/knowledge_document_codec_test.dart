import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/data/models/knowledge_document_codec.dart';

void main() {
  test('parses a valid chunk without exposing Firestore types', () {
    final chunk = KnowledgeDocumentCodec.chunk('chunk-1', _chunkData());
    expect(chunk.canonicalPlantKey, 'tomato');
    expect(chunk.symptomKeywords, ['yellowing']);
  });

  test('rejects malformed and unsupported chunk documents', () {
    expect(
      () => KnowledgeDocumentCodec.chunk(
        'chunk-1',
        _chunkData()..remove('title'),
      ),
      throwsFormatException,
    );
    expect(
      () => KnowledgeDocumentCodec.chunk(
        'chunk-1',
        _chunkData()..['datasetVersion'] = 'future-v2',
      ),
      throwsFormatException,
    );
    expect(
      () => KnowledgeDocumentCodec.chunk(
        'chunk-1',
        _chunkData()..['schemaVersion'] = 2,
      ),
      throwsFormatException,
    );
  });

  test('batch parsing excludes malformed chunks and retains valid ones', () {
    final result = KnowledgeDocumentCodec.chunks({
      'valid': _chunkData(),
      'malformed': _chunkData()..remove('content'),
      'future': _chunkData()..['schemaVersion'] = 2,
    });
    expect(result.items.map((item) => item.id), ['valid']);
    expect(result.warnings, hasLength(2));
  });

  test('accepts only validated HTTPS source URLs', () {
    final source = KnowledgeDocumentCodec.source('source-1', _sourceData());
    expect(source.url, 'https://example.edu/reference');
    expect(
      () => KnowledgeDocumentCodec.source(
        'source-1',
        _sourceData()..['url'] = 'http://example.edu/reference',
      ),
      throwsFormatException,
    );
    expect(
      () => KnowledgeDocumentCodec.source(
        'source-1',
        _sourceData()..['url'] = 'javascript:alert(1)',
      ),
      throwsFormatException,
    );
  });

  test('batch source parsing reports missing and malformed records', () {
    final result = KnowledgeDocumentCodec.sources({
      'valid': _sourceData(),
      'missing': null,
      'malformed': _sourceData()..['url'] = 'http://example.edu',
    });
    expect(result.items.map((item) => item.id), ['valid']);
    expect(result.warnings, hasLength(2));
  });
}

Map<String, dynamic> _chunkData() => {
  'schemaVersion': 1,
  'canonicalPlantKey': 'tomato',
  'commonName': 'Tomato',
  'scientificName': 'Solanum lycopersicum',
  'aliases': ['Tomato'],
  'category': 'fungal_disease',
  'issueKey': 'yellow_leaf',
  'environment': ['outdoor'],
  'affectedParts': ['leaf'],
  'growthStages': ['mature'],
  'symptomKeywords': ['yellowing'],
  'title': 'Yellow leaf reference',
  'content': List.filled(120, 'A').join(),
  'cautions': ['This is not a confirmed diagnosis.'],
  'sourceIds': ['source_1'],
  'reviewStatus': 'reviewed',
  'datasetVersion': '2026-09-03-v1',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3)),
};

Map<String, dynamic> _sourceData() => {
  'schemaVersion': 1,
  'title': 'Plant reference',
  'publisher': 'University Extension',
  'url': 'https://example.edu/reference',
  'accessedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 3)),
  'sourceType': 'university_extension',
  'datasetVersion': '2026-09-03-v1',
};
