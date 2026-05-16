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
  int surfaceBalcon;
  int surfaceCave;
  int surfaceTerrasse;
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
  bool ascenseur;        // présence ascenseur (appartement)
  bool libreOccupation;  // bien libre (vs loué → décote 10-15%)
  int loyerMensuel;      // loyer mensuel CC si loué (€)
  String typeBail;       // 'Vide', 'Meublé', 'Commercial'
  String dateFinBail;    // MM/YYYY
  bool congeLocataire;   // congé déjà donné au locataire
  int etage;             // n° d'étage (0 = RDC), appartement uniquement
  bool dernierEtage;     // dernier étage de l'immeuble
  int chargesCopro;      // charges copropriété €/an (décote auto si >2 000€)
  int taxeFonciere;      // taxe foncière €/an
  int taxeHabitation;    // taxe d'habitation €/an (résidence secondaire / pro)

  // Résidence & plus-value
  bool residencePrincipale; // résidence principale → exonération plus-value
  int prixAchat;            // prix d'achat €
  int anneeAchat;           // année d'acquisition

  // Diagnostics obligatoires (statut: 'valide'|'a_refaire'|'absent'|'nc', date: 'YYYY')
  Map<String, Map<String, String>> diagnostics;

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
  // Synthèse pondérée
  double prixPricehubble; // estimation PH en € (0 = non renseigné)
  double prixAnnonces;    // estimation annonces en € (0 = non renseigné)
  int ponderationDvf;     // poids DVF en %
  int ponderationPh;      // poids PriceHubble en %
  int ponderationAnnonces; // poids Annonces en %

  // Terrain — valorisation excédentaire
  int terrainConstructibleM2; // m² du terrain jugés constructibles (0 = non précisé)

  // Section 6 — Estimation
  double margeNegociation; // % marge pour prix de mandat (défaut 10%)
  double tauxAgence;       // % honoraires agence (défaut 5%) pour calcul net vendeur
  double ajustVue;
  double ajustEtat;
  double ajustDpe;
  double ajustExposition;    // % orientation cardinale (N=-5% … S=+3%)
  double ajustEnvironnement; // % bruit/nuisances (0 à -12%) — route, voie ferrée, industrie
  double ajustConjoncture;   // % contexte marché (-8% à +2%, défaut -3% contexte 2024-25)
  int ajustTravaux;
  int ajustParking; // € bonus/malus stationnement (négatif = malus sans parking)
  int ajustPiscine; // € prime piscine (calibrée 10 000–20 000€ selon état)
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

  // Historique des modifications de prix (négociation)
  List<Map<String, dynamic>> historique;

  // Notes par section
  Map<String, Map<String, dynamic>> notes;

  // Documents cochés pour la mise en vente
  Map<String, bool> documentsChecked;

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
    this.surfaceBalcon = 0,
    this.surfaceCave = 0,
    this.surfaceTerrasse = 0,
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
    this.ascenseur = false,
    this.libreOccupation = true,
    this.loyerMensuel = 0,
    this.typeBail = 'Vide',
    this.dateFinBail = '',
    this.congeLocataire = false,
    this.etage = 0,
    this.dernierEtage = false,
    this.chargesCopro = 0,
    this.taxeFonciere = 0,
    this.taxeHabitation = 0,
    this.residencePrincipale = true,
    this.prixAchat = 0,
    this.anneeAchat = 0,
    Map<String, Map<String, String>>? diagnostics,
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
    this.prixPricehubble = 0,
    this.prixAnnonces = 0,
    this.ponderationDvf = 45,
    this.ponderationPh = 40,
    this.ponderationAnnonces = 15,
    this.margeNegociation = 10,
    this.tauxAgence = 5.0,
    this.ajustVue = 0,
    this.ajustEtat = 0,
    this.ajustDpe = 0,
    this.ajustExposition = 0,
    this.ajustEnvironnement = 0,
    this.ajustConjoncture = -3,
    this.terrainConstructibleM2 = 0,
    this.ajustTravaux = 0,
    this.ajustParking = 0,
    this.ajustPiscine = 0,
    this.prixFinal = 0,
    this.fourchetteBasse = 0,
    this.fourchetteHaute = 0,
    this.conclusion = '',
    DateTime? validiteJusquau,
    List<String>? photosPaths,
    this.risques,
    this.notesVendeur,
    List<Map<String, dynamic>>? historique,
    Map<String, Map<String, dynamic>>? notes,
    Map<String, bool>? documentsChecked,
  })  : historique = historique ?? [],
        orientations = orientations ?? ['S'],
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
        notes = notes ?? {},
        diagnostics = diagnostics ?? {},
        documentsChecked = documentsChecked ?? {};

  // Surface pondérée : balcon×50%, cave×20%, terrasse×30%
  double get surfacePonderee =>
      surfaceHabitable + surfaceBalcon * 0.5 + surfaceCave * 0.2 + surfaceTerrasse * 0.3;

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
    const vals = {
      'N': -5.0, 'NO': -3.0, 'NE': -3.0,
      'E': -1.0, 'O': -1.0,
      'SE': 1.5, 'SO': 1.5,
      'S': 3.0, 'Traversant': 1.0,
    };
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

  double get prixFondamentalM2 {
    final dvfM2 = prixMoyen;
    final hasPh = prixPricehubble > 0 && surfaceHabitable > 0;
    final hasAnn = prixAnnonces > 0 && surfaceHabitable > 0;
    if (!hasPh && !hasAnn) return dvfM2;
    final phM2 = hasPh ? prixPricehubble / surfaceHabitable : 0.0;
    final annM2 = hasAnn ? prixAnnonces / surfaceHabitable : 0.0;
    double sumW = ponderationDvf.toDouble();
    double sumV = dvfM2 * ponderationDvf;
    if (hasPh) { sumW += ponderationPh; sumV += phM2 * ponderationPh; }
    if (hasAnn) { sumW += ponderationAnnonces; sumV += annM2 * ponderationAnnonces; }
    return sumW > 0 ? sumV / sumW : dvfM2;
  }

  double get prixM2Retenu => prixFondamentalM2 * (1 + coefficientPrestations / 100);
  double get prixBase => prixM2Retenu * surfacePonderee;

  // Décote grande surface : -1% par 10 m² au-delà de 120 m², plafonnée à -8%
  // Basée sur la surface pondérée (annexes incluses)
  double get decoteSurface =>
      surfacePonderee <= 120 ? 0.0 : ((-(surfacePonderee - 120) / 10)).clamp(-8.0, 0.0);

  // Ajustement étage appartement : RDC=-5%, intermédiaire=0%, dernier+ascenseur=+3%, dernier sans=+1%
  double get ajustEtageAuto {
    if (typeId != 'appartement') return 0.0;
    if (etage == 0) return -5.0;
    if (dernierEtage) return ascenseur ? 3.0 : 1.0;
    return 0.0;
  }

  // Décote charges copropriété : -1% par 500€ au-delà de 2 000€/an, plafonnée à -6%
  double get decoteCharges {
    if (typeId != 'appartement' || chargesCopro <= 2000) return 0.0;
    return (-(chargesCopro - 2000) / 500).clamp(-6.0, 0.0);
  }

  // Prime terrain : valorise les m² au-delà de 500 m² standard (inclus dans le prix/m² DVF)
  // Constructible : 80 €/m² | Non-constructible : 8 €/m² (calibré marché 74, avec décote liquidité)
  static const _seuilTerrain = 500;
  static const _tauxConstructible = 100.0;
  static const _tauxNonConstructible = 8.0;

  double get primeTerrain {
    if (typeId == 'appartement' || surfaceTerrain <= _seuilTerrain) return 0;
    final excedent = surfaceTerrain - _seuilTerrain;
    final constructible = terrainConstructibleM2.clamp(0, excedent);
    final nonConstructible = excedent - constructible;
    return constructible * _tauxConstructible + nonConstructible * _tauxNonConstructible;
  }

  double get prixMandat => (prixCalcule * (1 + margeNegociation / 100) / 1000).round() * 1000;

  // Calcul net vendeur réel et coût acquéreur
  double get fraisAgenceEstimes => prixMandat * tauxAgence / 100;
  double get fraisNotaireAcquereur => prixMandat * 0.08;
  double get budgetTotalAcquereur => prixMandat + fraisNotaireAcquereur;

  double get prixCalcule {
    final occupPct = libreOccupation ? 0.0 : -12.0;
    final totalPct = ajustVue + ajustEtat + ajustDpe + ajustExposition +
        ajustEnvironnement + ajustConjoncture + decoteSurface + occupPct +
        ajustEtageAuto + decoteCharges;
    final impact = prixBase * totalPct / 100 - ajustTravaux + ajustParking + ajustPiscine + primeTerrain;
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
        'surfaceBalcon': surfaceBalcon,
        'surfaceCave': surfaceCave,
        'surfaceTerrasse': surfaceTerrasse,
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
        'ascenseur': ascenseur ? 1 : 0,
        'libreOccupation': libreOccupation ? 1 : 0,
        'loyerMensuel': loyerMensuel,
        'typeBail': typeBail,
        'dateFinBail': dateFinBail,
        'congeLocataire': congeLocataire ? 1 : 0,
        'etage': etage,
        'dernierEtage': dernierEtage ? 1 : 0,
        'chargesCopro': chargesCopro,
        'taxeFonciere': taxeFonciere,
        'taxeHabitation': taxeHabitation,
        'residencePrincipale': residencePrincipale ? 1 : 0,
        'prixAchat': prixAchat,
        'anneeAchat': anneeAchat,
        'diagnostics': jsonEncode(diagnostics),
        'documentsChecked': jsonEncode(documentsChecked),
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
        'prixPricehubble': prixPricehubble,
        'prixAnnonces': prixAnnonces,
        'ponderationDvf': ponderationDvf,
        'ponderationPh': ponderationPh,
        'ponderationAnnonces': ponderationAnnonces,
        'terrainConstructibleM2': terrainConstructibleM2,
        'margeNegociation': margeNegociation,
        'tauxAgence': tauxAgence,
        'ajustVue': ajustVue,
        'ajustEtat': ajustEtat,
        'ajustDpe': ajustDpe,
        'ajustExposition': ajustExposition,
        'ajustEnvironnement': ajustEnvironnement,
        'ajustConjoncture': ajustConjoncture,
        'ajustTravaux': ajustTravaux,
        'ajustParking': ajustParking,
        'ajustPiscine': ajustPiscine,
        'prixFinal': prixFinal,
        'fourchetteBasse': fourchetteBasse,
        'fourchetteHaute': fourchetteHaute,
        'conclusion': conclusion,
        'validiteJusquau': validiteJusquau.toIso8601String(),
        'photosPaths': jsonEncode(photosPaths),
        'risques': risques != null ? jsonEncode(risques!.toMap()) : null,
        'notesVendeur': notesVendeur != null ? jsonEncode(notesVendeur!.toMap()) : null,
        'historique': jsonEncode(historique),
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
      surfaceBalcon: m['surfaceBalcon'] as int? ?? 0,
      surfaceCave: m['surfaceCave'] as int? ?? 0,
      surfaceTerrasse: m['surfaceTerrasse'] as int? ?? 0,
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
      ascenseur: (m['ascenseur'] as int? ?? 0) == 1,
      libreOccupation: (m['libreOccupation'] as int? ?? 1) == 1,
      loyerMensuel: m['loyerMensuel'] as int? ?? 0,
      typeBail: m['typeBail'] as String? ?? 'Vide',
      dateFinBail: m['dateFinBail'] as String? ?? '',
      congeLocataire: (m['congeLocataire'] as int? ?? 0) == 1,
      etage: m['etage'] as int? ?? 0,
      dernierEtage: (m['dernierEtage'] as int? ?? 0) == 1,
      chargesCopro: m['chargesCopro'] as int? ?? 0,
      taxeFonciere: m['taxeFonciere'] as int? ?? 0,
      taxeHabitation: m['taxeHabitation'] as int? ?? 0,
      residencePrincipale: (m['residencePrincipale'] as int? ?? 1) == 1,
      prixAchat: m['prixAchat'] as int? ?? 0,
      anneeAchat: m['anneeAchat'] as int? ?? 0,
      diagnostics: m['diagnostics'] != null
          ? Map<String, Map<String, String>>.from(
              (jsonDecode(m['diagnostics']) as Map).map(
                (k, v) => MapEntry(k, Map<String, String>.from(v)),
              ))
          : {},
      documentsChecked: m['documentsChecked'] != null
          ? Map<String, bool>.from(jsonDecode(m['documentsChecked']))
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
      prixPricehubble: (m['prixPricehubble'] as num?)?.toDouble() ?? 0,
      prixAnnonces: (m['prixAnnonces'] as num?)?.toDouble() ?? 0,
      ponderationDvf: m['ponderationDvf'] as int? ?? 45,
      ponderationPh: m['ponderationPh'] as int? ?? 40,
      ponderationAnnonces: m['ponderationAnnonces'] as int? ?? 15,
      terrainConstructibleM2: m['terrainConstructibleM2'] as int? ?? 0,
      margeNegociation: (m['margeNegociation'] as num?)?.toDouble() ?? 10,
      tauxAgence: (m['tauxAgence'] as num?)?.toDouble() ?? 5.0,
      ajustVue: (m['ajustVue'] as num?)?.toDouble() ?? 0,
      ajustEtat: (m['ajustEtat'] as num?)?.toDouble() ?? 0,
      ajustDpe: (m['ajustDpe'] as num?)?.toDouble() ?? 0,
      ajustExposition: (m['ajustExposition'] as num?)?.toDouble() ?? 0,
      ajustEnvironnement: (m['ajustEnvironnement'] as num?)?.toDouble() ?? 0,
      ajustConjoncture: (m['ajustConjoncture'] as num?)?.toDouble() ?? -3,
      ajustTravaux: m['ajustTravaux'] ?? 0,
      ajustParking: m['ajustParking'] as int? ?? 0,
      ajustPiscine: m['ajustPiscine'] as int? ?? 0,
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
      historique: m['historique'] != null
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(m['historique']) as List).map((e) => Map<String, dynamic>.from(e)))
          : [],
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
    int? surfaceBalcon,
    int? surfaceCave,
    int? surfaceTerrasse,
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
    bool? ascenseur,
    bool? libreOccupation,
    int? loyerMensuel,
    String? typeBail,
    String? dateFinBail,
    bool? congeLocataire,
    int? etage,
    bool? dernierEtage,
    int? chargesCopro,
    int? taxeFonciere,
    int? taxeHabitation,
    bool? residencePrincipale,
    int? prixAchat,
    int? anneeAchat,
    Map<String, Map<String, String>>? diagnostics,
    Map<String, bool>? documentsChecked,
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
    double? prixPricehubble,
    double? prixAnnonces,
    int? ponderationDvf,
    int? ponderationPh,
    int? ponderationAnnonces,
    double? margeNegociation,
    double? tauxAgence,
    double? ajustVue,
    double? ajustEtat,
    double? ajustDpe,
    double? ajustExposition,
    double? ajustEnvironnement,
    double? ajustConjoncture,
    int? terrainConstructibleM2,
    int? ajustTravaux,
    int? ajustParking,
    int? ajustPiscine,
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
    List<Map<String, dynamic>>? historique,
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
      surfaceBalcon: surfaceBalcon ?? this.surfaceBalcon,
      surfaceCave: surfaceCave ?? this.surfaceCave,
      surfaceTerrasse: surfaceTerrasse ?? this.surfaceTerrasse,
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
      ascenseur: ascenseur ?? this.ascenseur,
      libreOccupation: libreOccupation ?? this.libreOccupation,
      loyerMensuel: loyerMensuel ?? this.loyerMensuel,
      typeBail: typeBail ?? this.typeBail,
      dateFinBail: dateFinBail ?? this.dateFinBail,
      congeLocataire: congeLocataire ?? this.congeLocataire,
      etage: etage ?? this.etage,
      dernierEtage: dernierEtage ?? this.dernierEtage,
      chargesCopro: chargesCopro ?? this.chargesCopro,
      taxeFonciere: taxeFonciere ?? this.taxeFonciere,
      taxeHabitation: taxeHabitation ?? this.taxeHabitation,
      residencePrincipale: residencePrincipale ?? this.residencePrincipale,
      prixAchat: prixAchat ?? this.prixAchat,
      anneeAchat: anneeAchat ?? this.anneeAchat,
      diagnostics: diagnostics ?? Map.from(this.diagnostics),
      documentsChecked: documentsChecked ?? Map.from(this.documentsChecked),
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
      prixPricehubble: prixPricehubble ?? this.prixPricehubble,
      prixAnnonces: prixAnnonces ?? this.prixAnnonces,
      ponderationDvf: ponderationDvf ?? this.ponderationDvf,
      ponderationPh: ponderationPh ?? this.ponderationPh,
      ponderationAnnonces: ponderationAnnonces ?? this.ponderationAnnonces,
      margeNegociation: margeNegociation ?? this.margeNegociation,
      tauxAgence: tauxAgence ?? this.tauxAgence,
      ajustVue: ajustVue ?? this.ajustVue,
      ajustEtat: ajustEtat ?? this.ajustEtat,
      ajustDpe: ajustDpe ?? this.ajustDpe,
      ajustExposition: ajustExposition ?? this.ajustExposition,
      ajustEnvironnement: ajustEnvironnement ?? this.ajustEnvironnement,
      ajustConjoncture: ajustConjoncture ?? this.ajustConjoncture,
      terrainConstructibleM2: terrainConstructibleM2 ?? this.terrainConstructibleM2,
      ajustTravaux: ajustTravaux ?? this.ajustTravaux,
      ajustParking: ajustParking ?? this.ajustParking,
      ajustPiscine: ajustPiscine ?? this.ajustPiscine,
      prixFinal: prixFinal ?? this.prixFinal,
      fourchetteBasse: fourchetteBasse ?? this.fourchetteBasse,
      fourchetteHaute: fourchetteHaute ?? this.fourchetteHaute,
      conclusion: conclusion ?? this.conclusion,
      validiteJusquau: validiteJusquau ?? this.validiteJusquau,
      photosPaths: photosPaths ?? List.from(this.photosPaths),
      risques: clearRisques ? null : (risques ?? this.risques),
      notesVendeur: clearNotesVendeur ? null : (notesVendeur ?? this.notesVendeur),
      historique: historique ?? List.from(this.historique),
      notes: notes ?? Map.from(this.notes),
    );
    return copy;
  }
}
