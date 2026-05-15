import 'dart:convert';

class Facture {
  final String id;
  final String numero;       // ex. "2025-001"
  final DateTime date;
  final String estimationId;
  final String clientNom;
  final String clientAdresse;
  final String clientVille;
  final String objet;
  final double montantHT;
  final double tauxTva;      // 20.0
  final String statut;       // 'en_attente' | 'payee'

  const Facture({
    required this.id,
    required this.numero,
    required this.date,
    required this.estimationId,
    required this.clientNom,
    required this.clientAdresse,
    required this.clientVille,
    this.objet = 'Estimation de valeur venale d\'un Bien immobilier',
    required this.montantHT,
    this.tauxTva = 20.0,
    this.statut = 'en_attente',
  });

  double get montantTva  => double.parse((montantHT * tauxTva / 100).toStringAsFixed(2));
  double get montantTtc  => double.parse((montantHT + montantTva).toStringAsFixed(2));

  Facture copyWith({String? statut}) => Facture(
    id: id, numero: numero, date: date, estimationId: estimationId,
    clientNom: clientNom, clientAdresse: clientAdresse, clientVille: clientVille,
    objet: objet, montantHT: montantHT, tauxTva: tauxTva,
    statut: statut ?? this.statut,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'numero': numero, 'date': date.toIso8601String(),
    'estimationId': estimationId, 'clientNom': clientNom,
    'clientAdresse': clientAdresse, 'clientVille': clientVille,
    'objet': objet, 'montantHT': montantHT, 'tauxTva': tauxTva, 'statut': statut,
  };

  factory Facture.fromMap(Map<String, dynamic> m) => Facture(
    id: m['id'] ?? '',
    numero: m['numero'] ?? '',
    date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
    estimationId: m['estimationId'] ?? '',
    clientNom: m['clientNom'] ?? '',
    clientAdresse: m['clientAdresse'] ?? '',
    clientVille: m['clientVille'] ?? '',
    objet: m['objet'] ?? 'Estimation de valeur venale d\'un Bien immobilier',
    montantHT: (m['montantHT'] as num?)?.toDouble() ?? 166.67,
    tauxTva: (m['tauxTva'] as num?)?.toDouble() ?? 20.0,
    statut: m['statut'] ?? 'en_attente',
  );

  String toJson() => jsonEncode(toMap());
  factory Facture.fromJson(String s) => Facture.fromMap(jsonDecode(s));
}
