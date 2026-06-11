import 'dart:convert';
import 'package:uuid/uuid.dart';

class EstimationPassee {
  final String id;
  final String dateEstimation; // MM/YYYY
  String adresse;
  String codeInsee;
  String commune;
  double latitude;
  double longitude;
  String typeId;
  int surface;
  int prixEstime;
  String source; // 'pricehubble' | 'autre'
  List<String> mutationsEcartees;
  String statut; // '' | 'aucune' | 'candidats' | 'confirmee'

  EstimationPassee({
    required this.id,
    required this.dateEstimation,
    this.adresse = '',
    this.codeInsee = '',
    this.commune = '',
    this.latitude = 0,
    this.longitude = 0,
    this.typeId = 'maison',
    this.surface = 0,
    this.prixEstime = 0,
    this.source = 'pricehubble',
    this.mutationsEcartees = const [],
    this.statut = '',
  });

  factory EstimationPassee.create({required String dateEstimation}) =>
      EstimationPassee(id: const Uuid().v4(), dateEstimation: dateEstimation);

  DateTime get dateEstimationDt {
    final parts = dateEstimation.split('/');
    if (parts.length != 2) return DateTime(2020);
    return DateTime(int.tryParse(parts[1]) ?? 2020, int.tryParse(parts[0]) ?? 1);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'dateEstimation': dateEstimation,
    'adresse': adresse,
    'codeInsee': codeInsee,
    'commune': commune,
    'latitude': latitude,
    'longitude': longitude,
    'typeId': typeId,
    'surface': surface,
    'prixEstime': prixEstime,
    'source': source,
    'mutationsEcartees': jsonEncode(mutationsEcartees),
    'statut': statut,
  };

  factory EstimationPassee.fromMap(Map<String, dynamic> m) {
    List<String> dec(String? v) => v == null ? [] : List<String>.from(jsonDecode(v));
    return EstimationPassee(
      id: m['id'] as String,
      dateEstimation: m['dateEstimation'] as String? ?? '01/2020',
      adresse: m['adresse'] as String? ?? '',
      codeInsee: m['codeInsee'] as String? ?? '',
      commune: m['commune'] as String? ?? '',
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
      typeId: m['typeId'] as String? ?? 'maison',
      surface: m['surface'] as int? ?? 0,
      prixEstime: m['prixEstime'] as int? ?? 0,
      source: m['source'] as String? ?? 'pricehubble',
      mutationsEcartees: dec(m['mutationsEcartees'] as String?),
      statut: m['statut'] as String? ?? '',
    );
  }
}
