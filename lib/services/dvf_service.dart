import 'dart:convert';
import 'package:http/http.dart' as http;

class DvfTransaction {
  final String dateMutation;
  final double valeurFonciere;
  final String adresse;
  final String codeCommune;
  final String nomCommune;
  final String typeLocal;
  final double surfaceReelleBati;

  const DvfTransaction({
    required this.dateMutation,
    required this.valeurFonciere,
    required this.adresse,
    required this.codeCommune,
    required this.nomCommune,
    required this.typeLocal,
    required this.surfaceReelleBati,
  });

  double get prixM2 => surfaceReelleBati > 0 ? valeurFonciere / surfaceReelleBati : 0;
  String get formattedDate => _fmtDate(dateMutation);

  Map<String, dynamic> toComparable() => {
        'addr': adresse.isNotEmpty ? adresse : nomCommune,
        'desc': '$typeLocal · ${surfaceReelleBati.round()} m² · $nomCommune',
        'date': _fmtDate(dateMutation),
        'prix': valeurFonciere,
        'prixM2': prixM2.roundToDouble(),
      };

  static String _fmtDate(String iso) {
    if (iso.length < 7) return iso;
    const months = ['', 'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.'];
    final parts = iso.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    return '${months[month]} ${parts[0]}';
  }

  factory DvfTransaction.fromJson(Map<String, dynamic> j) => DvfTransaction(
        dateMutation: j['date_mutation'] as String? ?? '',
        valeurFonciere: (j['valeur_fonciere'] as num?)?.toDouble() ?? 0,
        adresse: [j['adresse_numero'], j['adresse_nom_voie']].where((v) => v != null && v.toString().isNotEmpty).join(' '),
        codeCommune: j['code_commune'] as String? ?? '',
        nomCommune: j['nom_commune'] as String? ?? '',
        typeLocal: j['type_local'] as String? ?? '',
        surfaceReelleBati: (j['surface_reelle_bati'] as num?)?.toDouble() ?? 0,
      );
}

class DvfService {
  static const _baseUrl = 'https://api.data.gouv.fr/dvf/v1/demandes-de-valeurs-foncieres/';

  // INSEE codes for Faucigny area communes
  static const faucignyInsee = [
    '74042', // Bonneville
    '74028', // Ayse
    '74081', // Cluses
    '74175', // Marignier
    '74272', // Scionzier
    '74260', // Saint-Pierre-en-Faucigny
    '74282', // Thyez
    '74177', // Marnaz
    '74271', // Scientrier
    '74085', // Contamine-sur-Arve
    '74312', // Vougy
  ];

  /// Fetches all DVF transactions for Faucigny communes.
  /// [typeLocal] : null = tous, 'Maison', 'Appartement'
  Future<List<DvfTransaction>> fetch({String? typeLocal}) async {
    final results = <DvfTransaction>[];
    for (final insee in faucignyInsee) {
      try {
        final params = <String, String>{
          'code_commune': insee,
          'ordering': '-date_mutation',
        };
        if (typeLocal != null) params['type_local'] = typeLocal;

        final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
        final resp = await http.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) continue;

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = body['results'] as List<dynamic>? ?? [];
        for (final item in list) {
          final tx = DvfTransaction.fromJson(item as Map<String, dynamic>);
          if (tx.valeurFonciere > 0 && tx.surfaceReelleBati > 0) {
            results.add(tx);
          }
        }
      } catch (_) {
        continue;
      }
    }
    // Global sort by date_mutation descending
    results.sort((a, b) => b.dateMutation.compareTo(a.dateMutation));
    return results;
  }
}
