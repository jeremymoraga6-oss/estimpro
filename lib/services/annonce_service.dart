import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/estimation.dart';
import 'app_settings.dart';

/// Annonce immobilière générée par IA depuis les données d'une estimation.
class AnnonceImmo {
  final String titre;
  final String accroche;
  final String description;
  final List<String> pointsForts;
  final List<String> hashtags;
  final String titreAlt1;
  final String titreAlt2;
  final String versionCourte; // pour LeBonCoin (limite caractères)

  const AnnonceImmo({
    required this.titre,
    required this.accroche,
    required this.description,
    required this.pointsForts,
    required this.hashtags,
    required this.titreAlt1,
    required this.titreAlt2,
    required this.versionCourte,
  });

  factory AnnonceImmo.empty() => const AnnonceImmo(
        titre: '',
        accroche: '',
        description: '',
        pointsForts: [],
        hashtags: [],
        titreAlt1: '',
        titreAlt2: '',
        versionCourte: '',
      );

  /// Texte complet formaté pour copie/partage
  String get fullText {
    final buf = StringBuffer();
    buf.writeln(titre);
    buf.writeln();
    buf.writeln(accroche);
    buf.writeln();
    buf.writeln(description);
    if (pointsForts.isNotEmpty) {
      buf.writeln();
      for (final pf in pointsForts) {
        buf.writeln('✓ $pf');
      }
    }
    if (hashtags.isNotEmpty) {
      buf.writeln();
      buf.writeln(hashtags.join(' '));
    }
    return buf.toString().trim();
  }

  AnnonceImmo copyWith({
    String? titre,
    String? accroche,
    String? description,
    List<String>? pointsForts,
    List<String>? hashtags,
    String? titreAlt1,
    String? titreAlt2,
    String? versionCourte,
  }) =>
      AnnonceImmo(
        titre: titre ?? this.titre,
        accroche: accroche ?? this.accroche,
        description: description ?? this.description,
        pointsForts: pointsForts ?? this.pointsForts,
        hashtags: hashtags ?? this.hashtags,
        titreAlt1: titreAlt1 ?? this.titreAlt1,
        titreAlt2: titreAlt2 ?? this.titreAlt2,
        versionCourte: versionCourte ?? this.versionCourte,
      );
}

class AnnonceGenerationResult {
  final AnnonceImmo? annonce;
  final String? error;
  const AnnonceGenerationResult({this.annonce, this.error});
  bool get success => annonce != null && error == null;
}

class AnnonceService {
  static const _systemPrompt = '''Tu es un expert rédacteur d'annonces immobilières pour le marché français, spécialisé Haute-Savoie (zone Faucigny, vallée de l'Arve, proximité Genève).

Tu rédiges des annonces vendeur OPTIMISÉES SEO (mots-clés acheteurs) et PERCUTANTES (vente rapide).

Règles :
- TITRE (60-80 caractères) : type + surface + commune + atout-clé. Ex : "Maison 120 m² avec vue Mont-Blanc à Saint-Pierre-en-Faucigny"
- ACCROCHE (1 phrase, 100-150 caractères) : phrase d'impact qui donne envie de cliquer. Émotion + bénéfice concret.
- DESCRIPTION (200-400 mots, 3-4 paragraphes) :
  1. Localisation + cadre de vie (commerces, écoles, accès Genève/autoroute)
  2. Présentation du bien (pièces, distribution, prestations)
  3. Atouts différenciants (vue, exposition, terrain, calme...)
  4. CTA discret ("Visite sur RDV avec Jérémy Moraga, votre conseiller Faucigny Immobilier by Efficity")
- POINTS FORTS : 5-7 bullets courts (3-6 mots chacun), formulation marketing
- HASHTAGS : 6-8 hashtags pour réseaux sociaux (#ImmobilierFaucigny, #VueMontagne, #FrontalierGeneve...)
- TITRE_ALT_1 / TITRE_ALT_2 : 2 variantes du titre principal
- VERSION_COURTE : version 50 mots max pour LeBonCoin

Ne mentionne JAMAIS :
- Le prix (sauf si demandé explicitement)
- Le nom du propriétaire
- Une décote DPE négative (transforme en argument positif quand possible)
- Des chiffres précis du DPE/GES

Style : factuel, chaleureux, pas de superlatifs vides ("magnifique", "exceptionnel"), pas d'emojis sauf hashtags.

Format de sortie : JSON STRICT (rien d'autre, pas de markdown), structure :
{
  "titre": "...",
  "accroche": "...",
  "description": "...",
  "points_forts": ["...", "...", "..."],
  "hashtags": ["#...", "#..."],
  "titre_alt_1": "...",
  "titre_alt_2": "...",
  "version_courte": "..."
}''';

  /// Génère une annonce immobilière à partir d'une estimation.
  /// Renvoie un résultat avec annonce ou erreur.
  Future<AnnonceGenerationResult> generate(Estimation e) async {
    final key = AppSettings.instance.anthropicKey;
    if (key.isEmpty) {
      return const AnnonceGenerationResult(
        error: 'Clé API Anthropic manquante. Configure-la dans Profil.',
      );
    }

    final fiche = _buildFiche(e);

    try {
      final resp = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-sonnet-4-6',
              'max_tokens': 2048,
              'system': _systemPrompt,
              'messages': [
                {'role': 'user', 'content': fiche},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode == 401) {
        return const AnnonceGenerationResult(error: 'Clé API invalide. Vérifie-la dans Profil.');
      }
      if (resp.statusCode == 529 || resp.statusCode == 503) {
        return const AnnonceGenerationResult(error: 'API Anthropic surchargée. Réessaie dans quelques secondes.');
      }
      if (resp.statusCode != 200) {
        return AnnonceGenerationResult(error: 'Erreur API (${resp.statusCode})');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = (body['content'] as List).first['text'] as String;
      final clean = raw
          .replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true), '')
          .trim();
      final j = jsonDecode(clean) as Map<String, dynamic>;

      return AnnonceGenerationResult(
        annonce: AnnonceImmo(
          titre: (j['titre'] as String?) ?? '',
          accroche: (j['accroche'] as String?) ?? '',
          description: (j['description'] as String?) ?? '',
          pointsForts: _toStrList(j['points_forts']),
          hashtags: _toStrList(j['hashtags']),
          titreAlt1: (j['titre_alt_1'] as String?) ?? '',
          titreAlt2: (j['titre_alt_2'] as String?) ?? '',
          versionCourte: (j['version_courte'] as String?) ?? '',
        ),
      );
    } catch (e) {
      debugPrint('[Annonce] error: $e');
      return AnnonceGenerationResult(error: 'Erreur : ${e.toString().split(':').last.trim()}');
    }
  }

  static List<String> _toStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [v.toString()];
  }

  /// Sérialise les données de l'estimation en fiche texte pour l'IA.
  String _buildFiche(Estimation e) {
    final buf = StringBuffer();
    buf.writeln('# Fiche bien à vendre');
    buf.writeln();

    // Localisation
    buf.writeln('## Localisation');
    if (e.commune.isNotEmpty) buf.writeln('- Commune : ${e.commune}');
    if (e.codePostal.isNotEmpty) buf.writeln('- Code postal : ${e.codePostal}');
    buf.writeln('- Secteur : Faucigny / Vallée de l\'Arve / Haute-Savoie');
    buf.writeln();

    // Type & surface
    buf.writeln('## Type & surface');
    buf.writeln('- Type : ${e.typeId}');
    buf.writeln('- Surface habitable : ${e.surfaceHabitable} m²');
    if (e.nbPieces > 0) buf.writeln('- Nombre de pièces : ${e.nbPieces}');
    if (e.nbChambres > 0) buf.writeln('- Nombre de chambres : ${e.nbChambres}');
    if (e.surfaceTerrain > 0) buf.writeln('- Surface terrain : ${e.surfaceTerrain} m²');
    if (e.surfaceBalcon > 0) buf.writeln('- Balcon : ${e.surfaceBalcon} m²');
    if (e.surfaceTerrasse > 0) buf.writeln('- Terrasse : ${e.surfaceTerrasse} m²');
    if (e.surfaceCave > 0) buf.writeln('- Cave : ${e.surfaceCave} m²');
    if (e.anneeConstruction.isNotEmpty) buf.writeln('- Année construction : ${e.anneeConstruction}');
    buf.writeln();

    // Étage / appartement
    if (e.typeId == 'appartement') {
      buf.writeln('## Appartement');
      buf.writeln('- Étage : ${e.etage}${e.dernierEtage ? " (dernier étage)" : ""}');
      buf.writeln('- Ascenseur : ${e.ascenseur ? "oui" : "non"}');
      if (e.chargesCopro > 0) buf.writeln('- Charges copropriété : ${e.chargesCopro} €/an');
      buf.writeln();
    }

    // Diagnostics
    buf.writeln('## Diagnostics');
    buf.writeln('- Classe DPE : ${e.dpeClasse}');
    if (e.dpeGes.isNotEmpty) buf.writeln('- Classe GES : ${e.dpeGes}');
    buf.writeln();

    // Prestations
    buf.writeln('## État & prestations (notes 1-4)');
    buf.writeln('- État général : ${e.noteEtatPrestation}/4');
    buf.writeln('- Cuisine : ${e.noteCuisine}/4');
    buf.writeln('- Sol : ${e.noteSol}/4');
    buf.writeln('- Salle de bain : ${e.noteSdb}/4');
    buf.writeln('- Fenêtres / menuiseries : ${e.noteFenetres}/4');
    buf.writeln('- Chauffage : ${e.noteChauffage}/4');
    if (e.isolation.isNotEmpty) buf.writeln('- Isolation : ${e.isolation}');
    buf.writeln();

    // Exposition / vue
    buf.writeln('## Exposition & vue');
    if (e.orientations.isNotEmpty) buf.writeln('- Orientations : ${e.orientations.join(", ")}');
    if (e.ajustVue > 0) buf.writeln('- Vue dégagée / atout commercial');
    if (e.ajustEnvironnement < 0) {
      buf.writeln('- Environnement avec nuisances (route/voie ferrée/industrie) — à NE PAS mentionner négativement');
    }
    buf.writeln();

    // Annexes
    buf.writeln('## Annexes & équipements');
    if (e.annexesActives['piscine'] == true) buf.writeln('- Piscine');
    if (e.annexesActives['garage'] == true) buf.writeln('- Garage');
    if (e.annexesActives['parking'] == true) buf.writeln('- Place de parking');
    if (e.annexesActives['cave'] == true) buf.writeln('- Cave');
    if (e.annexesActives['jardin'] == true) buf.writeln('- Jardin');
    if (e.annexesActives['cheminee'] == true) buf.writeln('- Cheminée');
    if (e.ajustParking < 0) {
      buf.writeln('- Sans parking — à NE PAS mentionner');
    }
    buf.writeln();

    // Note vendeur (points forts/faibles déclarés)
    final note = e.notesVendeur;
    if (note != null) {
      if (note.pointsForts.isNotEmpty) {
        buf.writeln('## Points forts déclarés par le vendeur');
        for (final p in note.pointsForts) {
          buf.writeln('- $p');
        }
        buf.writeln();
      }
      if (note.travauxDeclares.isNotEmpty) {
        buf.writeln('## Travaux mentionnés');
        buf.writeln(note.travauxDeclares);
        buf.writeln();
      }
    }

    // Occupation
    if (!e.libreOccupation) {
      buf.writeln('## Occupation');
      buf.writeln('- Bien loué (mentionner "occupé" ou "investissement locatif")');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln('Génère l\'annonce maintenant.');
    return buf.toString();
  }
}
