import 'dart:convert';
import 'vendeur_note.dart';
import '../services/georisques_service.dart';

class Estimation {
  final String id;
  final String reference;
  final DateTime createdAt;
  DateTime updatedAt;

  // Section 1 — Informations générales
  String typeId; // maison, appartement, chalet, terrain
  String motif;  // vente, succession, divorce, etc.
  DateTime dateVisite;
  // Adresse du bien
  String adresseComplete;
  String codeInsee;
  String codePostal;
  double latitude;
  double longitude;
  String commune;
  String proprietaireNom;
  String proprietaireTel;
  String proprietaireEmail;

  // Section 2 — Description
  int surfaceHabitable;
  int surfaceTerrain;
  int pieces;
  int chambres;
  String anneeConstruction;
  int etatGeneral; // 0-4
  List<String> orientations;
  List<String> vues;
  String dpeClasse;
  String chauffageType;
  List<String> revetementsol;

  // Section 3 — Annexes
  Map<String, bool> annexesActives;
  int garagePlaces;
  List<String> garageType;
  int jardinSurface;
  List<String> jardinEtat;
  Map<String, dynamic> annexesDetails;

  // Section 4 — État & équipements
  String facade;
  String toiture;
  List<String> menuiseriesType;
  List<String> vitrage;
  String chauffageEtat;
  int anneeChaudiere;
  String electricite;
  String isolation;

  // Section 2 — Prestations (notation étoiles 1-4)
  int noteCuisine;
  int noteSol;
  int noteSdb;
  int noteFenetres;
  int noteChauffage;
  int noteEtatPrestation;

  // Section 5 — Analyse marché
  List<Map<String, dynamic>> comparables;
  double dvfRadiusKm; // 0 = commune uniquement, sinon rayon en km

  // Section 6 — Estimation
  double ajustVue;
  double ajustEtat;
  double ajustDpe;
  double ajustExposition; // % orientation cardinale (N=-5% … S=+3%)
  int ajustTravaux;
  int ajustParking; // € bonus/malus stationnement (négatif = malus sans parking)
  double prixFinal;
  double fourchetteBasse;
  double fourchetteHaute;
  String conclusion;
  DateTime validiteJusquau;

  // Section 7 — Photos
  List<String> photosPaths;

  // IAL — Risques naturels & technologiques (Géorisques)
  GeorisquesData? risques;

  // Notes vocales vendeur
  VendeurNote? notesVendeur;

  // Notes par section
  Map<String, Map<String, dynamic>> notes;

  Estimation({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.updatedAt,
    this.typeId = 'maison',
    this.motif = 'Vente',
    required this.dateVisite,
    this.adresseComplete = '',
    this.codeInsee = '',
    this.codePostal = '',
    this.latitude = 0,
    this.longitude = 0,
    this.commune = '',
    this.proprietaireNom = '',
    this.proprietaireTel = '',
    this.proprietaireEmail = '',
    this.surfaceHabitable = 100,
    this.surfaceTerrain = 300,
    this.pieces = 4,
    this.chambres = 3,
    this.anneeConstruction = '1990-2000',
    this.etatGeneral = 2,
    List<String>? orientations,
    List<String>? vues,
    this.dpeClasse = 'D',
    this.chauffageType = 'Gaz naturel',
    List<String>? revetementsol,
    Map<String, bool>? annexesActives,
    this.garagePlaces = 1,
    List<String>? garageType,
    this.jardinSurface = 300,
    List<String>? jardinEtat,
    Map<String, dynamic>? annexesDetails,
    this.facade = 'Bon',
    this.toiture = 'Bon',
    List<String>? menuiseriesType,
    List<String>? vitrage,
    this.chauffageEtat = 'Bon',
    this.anneeChaudiere = 2018,
    this.electricite = 'Aux normes',
    this.isolation = 'Bonne',
    this.noteCuisine = 2,
    this.noteSol = 2,
    this.noteSdb = 2,
    this.noteFenetres = 2,
    this.noteChauffage = 2,
    this.noteEtatPrestation = 2,
    List<Map<String, dynamic>>? comparables,
    this.dvfRadiusKm = 3,
    this.ajustVue = 3,
    this.ajustEtat = 5,
    this.ajustDpe = 0,
    this.ajustExposition = 0,
    this.ajustTravaux = 0,
    this.ajustParking = 0,
    this.prixFinal = 0,
    this.fourchetteBasse = 0,
    this.fourchetteHaute = 0,
    this.conclusion = '',
    DateTime? validiteJusquau,
    List<String>? photosPaths,
    this.risques,
    this.notesVendeur,
    Map<String, Map<String, dynamic>>? notes,
  })  : orientations = orientations ?? ['S'],
        vues = vues ?? [],
        revetementsol = revetementsol ?? ['Parquet'],
        annexesActives = annexesActives ??
            {
              'garage': true,
              'terrasse': true,
              'balcon': false,
              'cave': true,
              'jardin': true,
              'piscine': false,
              'parking': false,
            },
        garageType = garageType ?? ['Intégré'],
        jardinEtat = jardinEtat ?? ['Entretenu'],
        annexesDetails = annexesDetails ?? {},
        menuiseriesType = menuiseriesType ?? ['PVC'],
        vitrage = vitrage ?? ['Double'],
        comparables = comparables ?? [],
        validiteJusquau =
            validiteJusquau ?? DateTime.now().add(const Duration(days: 365)),
        photosPaths = photosPaths ?? [],
        notes = notes ?? {};

  // Coefficients DPE calibrés depuis exemples terrain (Bonneville DPE F, Saint-Pierre DPE E)
  static double dpeCoefficient(String classe) {
    switch (classe.toUpperCase()) {
      case 'A': return 5.0;
      case 'B': return 3.0;
      case 'C': return 2.0;  // calibré Arenthon DPE C — atout commercial
      case 'D': return 0.0;
      case 'E': return -3.0; // calibré Saint-Pierre DPE E
      case 'F': return -5.0; // calibré Bonneville DPE F
      case 'G': return -8.0;
      default: return 0.0;
    }
  }

  double get recommendedAjustDpe => Estimation.dpeCoefficient(dpeClasse);

  // Coefficient d'exposition basé sur les orientations
  // Prend la meilleure orientation si plusieurs (ex: S + N → S=+3%)
  static double orientationCoefficient(List<String> orients) {
    const vals = {'N': -5.0, 'E': -1.0, 'O': -1.0, 'S': 3.0, 'Traversant': 1.0};
    if (orients.isEmpty) return 0.0;
    double best = -99;
    for (final o in orients) {
      final v = vals[o] ?? 0.0;
      if (v > best) best = v;
    }
    return best == -99 ? 0.0 : best;
  }

  double get recommendedAjustExposition =>
      Estimation.orientationCoefficient(orientations);

  double get scorePrestations =>
      noteCuisine * 0.15 + noteSol * 0.15 + noteSdb * 0.15 +
      noteFenetres * 0.15 + noteChauffage * 0.20 + noteEtatPrestation * 0.20;

  double get coefficientPrestations {
    final s = scorePrestations;
    if (s < 1.5) return -10;
    if (s < 2.2) return -3;
    if (s < 3.0) return 0;
    if (s <= 3.5) return 4;
    return 8;
  }

  String get labelCoefficientPrestations {
    final s = scorePrestations;
    if (s < 1.5) return 'très dégradé';
    if (s < 2.2) return 'en dessous de la moyenne';
    if (s < 3.0) return 'standard marché';
    if (s <= 3.5) return 'bonne qualité';
    return 'haut de gamme';
  }

  double get prixMoyen {
    if (comparables.isEmpty) return 3381;
    final prices = comparables
        .map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return 3381;
    prices.sort();
    return prices[prices.length ~/ 2];
  }

  double get prixM2Retenu => prixMoyen * (1 + coefficientPrestations / 100);
  double get prixBase => prixM2Retenu * surfaceHabitable;

  double get prixCalcule {
    final totalPct = ajustVue + ajustEtat + ajustDpe + ajustExposition;
    final impact = prixBase * totalPct / 100 - ajustTravaux + ajustParking;
    final raw = prixBase + impact;
    return (raw / 1000).round() * 1000;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'typeId': typeId,
        'motif': motif,
        'dateVisite': dateVisite.toIso8601String(),
        'adresseComplete': adresseComplete,
        'codeInsee': codeInsee,
        'codePostal': codePostal,
        'latitude': latitude,
        'longitude': longitude,
        'commune': commune,
        'proprietaireNom': proprietaireNom,
        'proprietaireTel': proprietaireTel,
        'proprietaireEmail': proprietaireEmail,
        'surfaceHabitable': surfaceHabitable,
        'surfaceTerrain': surfaceTerrain,
        'pieces': pieces,
        'chambres': chambres,
        'anneeConstruction': anneeConstruction,
        'etatGeneral': etatGeneral,
        'orientations': jsonEncode(orientations),
        'vues': jsonEncode(vues),
        'dpeClasse': dpeClasse,
        'chauffageType': chauffageType,
        'revetementsol': jsonEncode(revetementsol),
        'annexesActives': jsonEncode(annexesActives),
        'garagePlaces': garagePlaces,
        'garageType': jsonEncode(garageType),
        'jardinSurface': jardinSurface,
        'jardinEtat': jsonEncode(jardinEtat),
        'annexesDetails': jsonEncode(annexesDetails),
        'facade': facade,
        'toiture': toiture,
        'menuiseriesType': jsonEncode(menuiseriesType),
        'vitrage': jsonEncode(vitrage),
        'chauffageEtat': chauffageEtat,
        'anneeChaudiere': anneeChaudiere,
        'electricite': electricite,
        'isolation': isolation,
        'noteCuisine': noteCuisine,
        'noteSol': noteSol,
        'noteSdb': noteSdb,
        'noteFenetres': noteFenetres,
        'noteChauffage': noteChauffage,
        'noteEtatPrestation': noteEtatPrestation,
        'comparables': jsonEncode(comparables),
        'dvfRadiusKm': dvfRadiusKm,
        'ajustVue': ajustVue,
        'ajustEtat': ajustEtat,
        'ajustDpe': ajustDpe,
        'ajustExposition': ajustExposition,
        'ajustTravaux': ajustTravaux,
        'ajustParking': ajustParking,
        'prixFinal': prixFinal,
        'fourchetteBasse': fourchetteBasse,
        'fourchetteHaute': fourchetteHaute,
        'conclusion': conclusion,
        'validiteJusquau': validiteJusquau.toIso8601String(),
        'photosPaths': jsonEncode(photosPaths),
        'risques': risques != null ? jsonEncode(risques!.toMap()) : null,
        'notesVendeur': notesVendeur != null ? jsonEncode(notesVendeur!.toMap()) : null,
        'notes': jsonEncode(notes),
      };

  factory Estimation.fromMap(Map<String, dynamic> m) {
    List<String> decodeStrList(String? v) =>
        v == null ? [] : List<String>.from(jsonDecode(v));
    Map<String, bool> decodeBoolMap(String? v) =>
        v == null ? {} : Map<String, bool>.from(jsonDecode(v));

    return Estimation(
      id: m['id'],
      reference: m['reference'],
      createdAt: DateTime.parse(m['createdAt']),
      updatedAt: DateTime.parse(m['updatedAt']),
      typeId: m['typeId'] ?? 'maison',
      motif: m['motif'] ?? 'Vente',
      dateVisite: DateTime.parse(m['dateVisite']),
      adresseComplete: m['adresseComplete'] as String? ?? '',
      codeInsee: m['codeInsee'] as String? ?? '',
      codePostal: m['codePostal'] as String? ?? '',
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
      commune: m['commune'] as String? ?? '',
      proprietaireNom: m['proprietaireNom'] ?? '',
      proprietaireTel: m['proprietaireTel'] ?? '',
      proprietaireEmail: m['proprietaireEmail'] ?? '',
      surfaceHabitable: m['surfaceHabitable'] ?? 100,
      surfaceTerrain: m['surfaceTerrain'] ?? 300,
      pieces: m['pieces'] ?? 4,
      chambres: m['chambres'] ?? 3,
      anneeConstruction: m['anneeConstruction'] ?? '1990-2000',
      etatGeneral: m['etatGeneral'] ?? 2,
      orientations: decodeStrList(m['orientations']),
      vues: decodeStrList(m['vues']),
      dpeClasse: m['dpeClasse'] ?? 'D',
      chauffageType: m['chauffageType'] ?? 'Gaz naturel',
      revetementsol: decodeStrList(m['revetementsol']),
      annexesActives: decodeBoolMap(m['annexesActives']),
      garagePlaces: m['garagePlaces'] ?? 1,
      garageType: decodeStrList(m['garageType']),
      jardinSurface: m['jardinSurface'] ?? 300,
      jardinEtat: decodeStrList(m['jardinEtat']),
      annexesDetails: m['annexesDetails'] != null
          ? Map<String, dynamic>.from(jsonDecode(m['annexesDetails']))
          : {},
      facade: m['facade'] ?? 'Bon',
      toiture: m['toiture'] ?? 'Bon',
      menuiseriesType: decodeStrList(m['menuiseriesType']),
      vitrage: decodeStrList(m['vitrage']),
      chauffageEtat: m['chauffageEtat'] ?? 'Bon',
      anneeChaudiere: m['anneeChaudiere'] ?? 2018,
      electricite: m['electricite'] ?? 'Aux normes',
      isolation: m['isolation'] ?? 'Bonne',
      noteCuisine: m['noteCuisine'] as int? ?? 2,
      noteSol: m['noteSol'] as int? ?? 2,
      noteSdb: m['noteSdb'] as int? ?? 2,
      noteFenetres: m['noteFenetres'] as int? ?? 2,
      noteChauffage: m['noteChauffage'] as int? ?? 2,
      noteEtatPrestation: m['noteEtatPrestation'] as int? ?? 2,
      comparables: m['comparables'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(m['comparables']))
          : [],
      dvfRadiusKm: (m['dvfRadiusKm'] as num?)?.toDouble() ?? 3,
      ajustVue: (m['ajustVue'] as num?)?.toDouble() ?? 3,
      ajustEtat: (m['ajustEtat'] as num?)?.toDouble() ?? 5,
      ajustDpe: (m['ajustDpe'] as num?)?.toDouble() ?? 0,
      ajustExposition: (m['ajustExposition'] as num?)?.toDouble() ?? 0,
      ajustTravaux: m['ajustTravaux'] ?? 0,
      ajustParking: m['ajustParking'] as int? ?? 0,
      prixFinal: (m['prixFinal'] as num?)?.toDouble() ?? 0,
      fourchetteBasse: (m['fourchetteBasse'] as num?)?.toDouble() ?? 0,
      fourchetteHaute: (m['fourchetteHaute'] as num?)?.toDouble() ?? 0,
      conclusion: m['conclusion'] ?? '',
      validiteJusquau: DateTime.parse(
          m['validiteJusquau'] ?? DateTime.now().toIso8601String()),
      photosPaths: decodeStrList(m['photosPaths']),
      risques: m['risques'] != null
          ? GeorisquesData.fromMap(
              Map<String, dynamic>.from(jsonDecode(m['risques'] as String)))
          : null,
      notesVendeur: m['notesVendeur'] != null
          ? VendeurNote.fromMap(
              Map<String, dynamic>.from(jsonDecode(m['notesVendeur'] as String)))
          : null,
      notes: m['notes'] != null
          ? Map<String, Map<String, dynamic>>.from(
              (jsonDecode(m['notes']) as Map).map(
                (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
              ),
            )
          : {},
    );
  }

  Estimation copyWith({
    String? typeId,
    String? motif,
    DateTime? dateVisite,
    String? adresseComplete,
    String? codeInsee,
    String? codePostal,
    double? latitude,
    double? longitude,
    String? commune,
    String? proprietaireNom,
    String? proprietaireTel,
    String? proprietaireEmail,
    int? surfaceHabitable,
    int? surfaceTerrain,
    int? pieces,
    int? chambres,
    String? anneeConstruction,
    int? etatGeneral,
    List<String>? orientations,
    List<String>? vues,
    String? dpeClasse,
    String? chauffageType,
    List<String>? revetementsol,
    Map<String, bool>? annexesActives,
    int? garagePlaces,
    List<String>? garageType,
    int? jardinSurface,
    List<String>? jardinEtat,
    Map<String, dynamic>? annexesDetails,
    String? facade,
    String? toiture,
    List<String>? menuiseriesType,
    List<String>? vitrage,
    String? chauffageEtat,
    int? anneeChaudiere,
    String? electricite,
    String? isolation,
    int? noteCuisine,
    int? noteSol,
    int? noteSdb,
    int? noteFenetres,
    int? noteChauffage,
    int? noteEtatPrestation,
    List<Map<String, dynamic>>? comparables,
    double? dvfRadiusKm,
    double? ajustVue,
    double? ajustEtat,
    double? ajustDpe,
    double? ajustExposition,
    int? ajustTravaux,
    int? ajustParking,
    double? prixFinal,
    double? fourchetteBasse,
    double? fourchetteHaute,
    String? conclusion,
    DateTime? validiteJusquau,
    List<String>? photosPaths,
    GeorisquesData? risques,
    bool clearRisques = false,
    VendeurNote? notesVendeur,
    bool clearNotesVendeur = false,
    Map<String, Map<String, dynamic>>? notes,
  }) {
    final copy = Estimation(
      id: id,
      reference: reference,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      typeId: typeId ?? this.typeId,
      motif: motif ?? this.motif,
      dateVisite: dateVisite ?? this.dateVisite,
      adresseComplete: adresseComplete ?? this.adresseComplete,
      codeInsee: codeInsee ?? this.codeInsee,
      codePostal: codePostal ?? this.codePostal,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      commune: commune ?? this.commune,
      proprietaireNom: proprietaireNom ?? this.proprietaireNom,
      proprietaireTel: proprietaireTel ?? this.proprietaireTel,
      proprietaireEmail: proprietaireEmail ?? this.proprietaireEmail,
      surfaceHabitable: surfaceHabitable ?? this.surfaceHabitable,
      surfaceTerrain: surfaceTerrain ?? this.surfaceTerrain,
      pieces: pieces ?? this.pieces,
      chambres: chambres ?? this.chambres,
      anneeConstruction: anneeConstruction ?? this.anneeConstruction,
      etatGeneral: etatGeneral ?? this.etatGeneral,
      orientations: orientations ?? List.from(this.orientations),
      vues: vues ?? List.from(this.vues),
      dpeClasse: dpeClasse ?? this.dpeClasse,
      chauffageType: chauffageType ?? this.chauffageType,
      revetementsol: revetementsol ?? List.from(this.revetementsol),
      annexesActives: annexesActives ?? Map.from(this.annexesActives),
      garagePlaces: garagePlaces ?? this.garagePlaces,
      garageType: garageType ?? List.from(this.garageType),
      jardinSurface: jardinSurface ?? this.jardinSurface,
      jardinEtat: jardinEtat ?? List.from(this.jardinEtat),
      annexesDetails: annexesDetails ?? Map.from(this.annexesDetails),
      facade: facade ?? this.facade,
      toiture: toiture ?? this.toiture,
      menuiseriesType: menuiseriesType ?? List.from(this.menuiseriesType),
      vitrage: vitrage ?? List.from(this.vitrage),
      chauffageEtat: chauffageEtat ?? this.chauffageEtat,
      anneeChaudiere: anneeChaudiere ?? this.anneeChaudiere,
      electricite: electricite ?? this.electricite,
      isolation: isolation ?? this.isolation,
      noteCuisine: noteCuisine ?? this.noteCuisine,
      noteSol: noteSol ?? this.noteSol,
      noteSdb: noteSdb ?? this.noteSdb,
      noteFenetres: noteFenetres ?? this.noteFenetres,
      noteChauffage: noteChauffage ?? this.noteChauffage,
      noteEtatPrestation: noteEtatPrestation ?? this.noteEtatPrestation,
      comparables: comparables ?? List.from(this.comparables),
      dvfRadiusKm: dvfRadiusKm ?? this.dvfRadiusKm,
      ajustVue: ajustVue ?? this.ajustVue,
      ajustEtat: ajustEtat ?? this.ajustEtat,
      ajustDpe: ajustDpe ?? this.ajustDpe,
      ajustExposition: ajustExposition ?? this.ajustExposition,
      ajustTravaux: ajustTravaux ?? this.ajustTravaux,
      ajustParking: ajustParking ?? this.ajustParking,
      prixFinal: prixFinal ?? this.prixFinal,
      fourchetteBasse: fourchetteBasse ?? this.fourchetteBasse,
      fourchetteHaute: fourchetteHaute ?? this.fourchetteHaute,
      conclusion: conclusion ?? this.conclusion,
      validiteJusquau: validiteJusquau ?? this.validiteJusquau,
      photosPaths: photosPaths ?? List.from(this.photosPaths),
      risques: clearRisques ? null : (risques ?? this.risques),
      notesVendeur: clearNotesVendeur ? null : (notesVendeur ?? this.notesVendeur),
      notes: notes ?? Map.from(this.notes),
    );
    return copy;
  }
}
