import 'dart:convert';
import 'dart:math' as math;
import 'vendeur_note.dart';
import 'carnet_note.dart';
import 'pathologie_item.dart';
import '../services/georisques_service.dart';
import '../services/gares_service.dart';

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

  // ── LOT 1 — Juridique & mandat ──────────────────────────────────
  String referenceCadastrale; // section + parcelle (ex: "AB 123")
  String typeMandat;          // 'Simple' | 'Exclusif' | 'Semi-exclusif'
  int dureeMandatMois;        // durée du mandat en mois
  String honorairesACharge;   // 'Vendeur' | 'Acquéreur'

  // Copropriété (loi ALUR) — pertinent si lot de copropriété
  bool enCopropriete;
  String syndicNom;
  int nombreLots;             // nombre de lots dans la copropriété
  int tantiemes;              // quote-part en tantièmes/millièmes
  int fondsTravaux;           // fonds de travaux ALUR (€)
  bool coproProceduresEnCours; // procédure judiciaire / impayés en cours
  int surfaceCarrez;          // surface loi Carrez (m²) — obligatoire copro

  // ── LOT 2 — Détail technique & équipements ──────────────────────
  int nbSallesBain;           // nombre de salles de bain (avec baignoire)
  int nbSallesEau;            // nombre de salles d'eau (douche)
  int nbWc;                   // nombre de WC
  String typeCuisine;         // '' | 'Équipée' | 'Aménagée' | 'Ouverte' | 'Séparée'
  String combles;             // '' | 'Aménagés' | 'Aménageables' | 'Perdus' | 'Aucun'
  String assainissement;      // '' | 'Collectif' | 'Individuel conforme' | 'Individuel non conforme'
  bool fibreOptique;          // éligibilité / raccordement fibre
  List<String> equipements;   // climatisation, cheminée, photovoltaïque, borne VE…

  // ── Terrain (spécifique au typeId == 'terrain') ─────────────────
  String zonePlu;             // zone PLU : 'UA' | 'UB' | 'AU' | '1AU' | 'A' | 'N' | ''
  List<String> viabilisation; // 'Eau' | 'Électricité' | 'Assainissement' | 'Gaz' | 'Fibre'
  String terrainAcces;        // 'Voie publique' | 'Chemin privé' | 'Impasse' | ''
  String terrainPente;        // 'Plat' | 'Légère pente' | 'Forte pente' | ''
  String terrainForme;        // 'Rectangulaire' | 'Irrégulière' | 'En drapeau' | ''
  double terrainCos;          // COS/CES — coefficient d'occupation des sols (0 = non précisé)
  String terrainServitudes;   // servitudes, contraintes (texte libre)

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
  bool parcelleDivisible;     // parcelle potentiellement divisible (→ 280 €/m² au lieu de 100 €/m²)

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
  double ajustCalibration;   // % appliqué depuis la base locale
  int calibrationNbVentes;   // nb ventes ayant servi au calcul
  String calibrationScope;   // 'commune' | 'globale' | ''
  // ── Tendance marché & actualisation des comparables ──────────────────────────
  double tauxEvolutionAnnuel;   // %/an calculé via DvfTrend (0 = inconnu)
  bool actualisationActive;     // toggle utilisateur (défaut true)
  String trendInfo;             // ex: '2022→2025 · 142 ventes'
  double prixFinal;
  double fourchetteBasse;
  double fourchetteHaute;
  String conclusion;
  String prochainesEtapes;   // plan d'action 3 étapes — affiché en synthèse PDF
  DateTime validiteJusquau;

  // Section 7 — Photos
  List<String> photosPaths;

  // IAL — Risques naturels & technologiques (Géorisques)
  GeorisquesData? risques;

  // Notes vocales vendeur
  VendeurNote? notesVendeur;

  // Historique des modifications de prix (négociation)
  List<Map<String, dynamic>> historique;

  // Détail surfaces par pièce [{nom: 'Séjour', surface: 30.0}, ...]
  List<Map<String, dynamic>> piecesSurfaces;

  // Observations libres section 1
  String observationsBien;

  // Carnet de visite : liste des notes multi-sections
  List<CarnetNote> carnetNotes;

  // Suivi ventes DVF — backfill calibration
  List<String> mutationsEcartees; // ids DVF rejetés manuellement
  String suiviVenteStatut;        // '' | 'aucune' | 'candidats' | 'confirmee'

  // Ajustements micro-locaux
  double ajustEpoque;   // % époque de construction (hors DPE)
  double ajustGare;     // % proximité gare Léman Express
  double ajustRisques;  // % décote géorisques (≤ 0)

  // Checklist pathologies bâti
  List<PathologieItem> pathologies;       // liste des 13 points (vide = non initialisée)
  int pathologiesLastReport;              // dernier total reporté dans ajustTravaux (pour diff.)

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
    this.referenceCadastrale = '',
    this.typeMandat = 'Simple',
    this.dureeMandatMois = 3,
    this.honorairesACharge = 'Vendeur',
    this.enCopropriete = false,
    this.syndicNom = '',
    this.nombreLots = 0,
    this.tantiemes = 0,
    this.fondsTravaux = 0,
    this.coproProceduresEnCours = false,
    this.surfaceCarrez = 0,
    this.nbSallesBain = 0,
    this.nbSallesEau = 0,
    this.nbWc = 0,
    this.typeCuisine = '',
    this.combles = '',
    this.assainissement = '',
    this.fibreOptique = false,
    List<String>? equipements,
    this.zonePlu = '',
    List<String>? viabilisation,
    this.terrainAcces = '',
    this.terrainPente = '',
    this.terrainForme = '',
    this.terrainCos = 0.0,
    this.terrainServitudes = '',
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
    this.ajustConjoncture = -1, // marché Haute-Savoie 2026 : légère hausse, défaut prudent
    this.terrainConstructibleM2 = 0,
    this.parcelleDivisible = false,
    this.ajustTravaux = 0,
    this.ajustParking = 0,
    this.ajustPiscine = 0,
    this.ajustCalibration = 0,
    this.calibrationNbVentes = 0,
    this.calibrationScope = '',
    this.tauxEvolutionAnnuel = 0,
    this.actualisationActive = true,
    this.trendInfo = '',
    this.prixFinal = 0,
    this.fourchetteBasse = 0,
    this.fourchetteHaute = 0,
    this.conclusion = '',
    this.prochainesEtapes = '',
    DateTime? validiteJusquau,
    List<String>? photosPaths,
    this.risques,
    this.notesVendeur,
    List<Map<String, dynamic>>? historique,
    List<Map<String, dynamic>>? piecesSurfaces,
    this.observationsBien = '',
    List<CarnetNote>? carnetNotes,
    List<String>? mutationsEcartees,
    this.suiviVenteStatut = '',
    this.ajustEpoque = 0,
    this.ajustGare = 0,
    this.ajustRisques = 0,
    List<PathologieItem>? pathologies,
    this.pathologiesLastReport = 0,
    Map<String, bool>? documentsChecked,
  })  : pathologies = pathologies ?? [],
        historique = historique ?? [],
        equipements = equipements ?? [],
        viabilisation = viabilisation ?? [],
        piecesSurfaces = piecesSurfaces ?? [],
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
        carnetNotes = carnetNotes ?? [],
        mutationsEcartees = mutationsEcartees ?? [],
        diagnostics = diagnostics ?? {},
        documentsChecked = documentsChecked ?? {};

  // Surface pondérée : balcon×40%, cave×20%, terrasse×50%
  // Plafonds métier (FNAIM 2026) : balcon 12 m², cave 15 m², terrasse 20 m²
  // Au-delà du plafond, les m² supplémentaires ne sont plus pondérés.
  double get surfacePonderee {
    final b = math.min(surfaceBalcon, 12);
    final c = math.min(surfaceCave, 15);
    final t = math.min(surfaceTerrasse, 20);
    return surfaceHabitable + b * 0.4 + c * 0.2 + t * 0.5;
  }

  // Coefficients DPE — calibrés sur l'étude Notaires de France 2024
  // (les maisons subissent une décote plus forte que les appartements en F/G)
  static double dpeCoefficient(String classe, {String typeId = 'maison'}) {
    final isAppt = typeId == 'appartement';
    switch (classe.toUpperCase()) {
      case 'A': return isAppt ? 4.0 : 6.0;
      case 'B': return isAppt ? 2.0 : 4.0;
      case 'C': return 2.0;
      case 'D': return 0.0;
      case 'E': return -3.0;
      case 'F': return isAppt ? -7.0 : -12.0;  // NdF 2024 : appt -7, maison -16 (modulé)
      case 'G': return isAppt ? -10.0 : -18.0; // NdF 2024 : appt -10, maison -22 (modulé)
      default: return 0.0;
    }
  }

  double get recommendedAjustDpe => Estimation.dpeCoefficient(dpeClasse, typeId: typeId);

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

  /// Extrait l'année représentative de anneeConstruction.
  /// Gère : entier pur, plages "XXXX-YYYY", "Avant XXXX", "Après XXXX".
  int? get _anneeInt {
    final s = anneeConstruction.trim();
    final lc = s.toLowerCase();
    // "Avant XXXX" → XXXX - 1
    final avantMatch = RegExp(r'avant\s+(\d{4})', caseSensitive: false).firstMatch(lc);
    if (avantMatch != null) {
      final y = int.tryParse(avantMatch.group(1)!);
      return y != null ? y - 1 : null;
    }
    // "Après XXXX" / "Apres XXXX" → XXXX + 1
    final apresMatch = RegExp(r'apr[eè]s\s+(\d{4})', caseSensitive: false).firstMatch(lc);
    if (apresMatch != null) {
      final y = int.tryParse(apresMatch.group(1)!);
      return y != null ? y + 1 : null;
    }
    // Entier pur
    final n = int.tryParse(s);
    if (n != null) return n;
    // Plage "XXXX-YYYY" → prend la première année
    final rangeMatch = RegExp(r'(\d{4})').firstMatch(s);
    return rangeMatch != null ? int.tryParse(rangeMatch.group(1)!) : null;
  }

  double get recommendedAjustEpoque {
    final annee = _anneeInt;
    if (annee == null) return 0.0;
    if (annee <= 1948) return 0.0;
    if (annee <= 1974) return -3.0;
    if (annee <= 1989) return -1.0;
    if (annee <= 2005) return 0.0;
    if (annee <= 2012) return 1.0;
    if (annee <= 2021) return 2.0;
    return 3.0;
  }

  String get labelEpoque {
    final annee = _anneeInt;
    if (annee == null) return 'Année non renseignée';
    if (annee <= 1948) return 'Bâti ancien : caractère et vétusté s\'équilibrent — préciser via l\'état';
    if (annee <= 1974) return 'Construction d\'après-guerre : isolation et réseaux d\'origine faibles';
    if (annee <= 1989) return 'Premières RT : isolation partielle';
    if (annee <= 2005) return 'Standard correct';
    if (annee <= 2012) return 'RT 2005 : bonne performance thermique';
    if (annee <= 2021) return 'RT 2012 : très bonne isolation';
    return 'RE 2020 : recherché, charges faibles';
  }

  double get recommendedAjustGare {
    if (latitude == 0 || longitude == 0) return 0.0;
    final proche = GaresService.garePlusProche(latitude, longitude);
    if (proche == null) return 0.0;
    if (proche.distanceM < 800) return 3.0;
    if (proche.distanceM < 1500) return 1.5;
    return 0.0;
  }

  String get labelGare {
    if (latitude == 0 || longitude == 0) return 'Géolocalisation requise';
    final proche = GaresService.garePlusProche(latitude, longitude);
    if (proche == null) return '';
    final d = proche.distanceM.round();
    if (proche.distanceM < 800) return 'À $d m de la gare ${proche.gare.nom} — Léman Express direct Genève';
    if (proche.distanceM < 1500) return 'À $d m de la gare ${proche.gare.nom} — Léman Express';
    return 'Gare la plus proche : ${proche.gare.nom} ($d m)';
  }

  double get recommendedAjustRisques {
    final r = risques;
    if (r == null || !r.hasData) return 0.0;
    double total = 0.0;
    // Inondation (PPRI/PPRN)
    final hasInond = r.risquesNaturels.any((s) => s.toLowerCase().contains('inond'));
    if (hasInond) total -= 5.0;
    // Argile
    final argile = r.niveauArgile.toLowerCase();
    if (argile.contains('fort')) total -= 2.0;
    else if (argile.contains('moyen')) total -= 1.0;
    // Cap à -6%
    return total.clamp(-6.0, 0.0);
  }

  /// Liste des libellés retenus pour l'ajustement risques.
  List<String> get labelRisques {
    final r = risques;
    if (r == null || !r.hasData) return [];
    final items = <String>[];
    final hasInond = r.risquesNaturels.any((s) => s.toLowerCase().contains('inond'));
    if (hasInond) items.add('Zone inondable (PPRI/PPRN) : −5 %');
    final argile = r.niveauArgile.toLowerCase();
    if (argile.contains('fort')) items.add('Argiles fort (RGA) : −2 %');
    else if (argile.contains('moyen')) items.add('Argiles moyen (RGA) : −1 %');
    if (r.potentielRadon.toLowerCase().contains('important')) items.add('Radon zone 3 — informatif');
    return items;
  }

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

  // Fallback prix m² si aucun comparable DVF disponible.
  // 4200 EUR/m² = moyenne pondérée Faucigny 2026 :
  // - Bonneville centre : 3800-4200/m²
  // - Saint-Pierre-en-Faucigny : 4500-5000/m²
  // - Communes plus rurales (Ayse, Marignier) : 3500-4000/m²
  // Volontairement légèrement bas pour ne pas surévaluer en l'absence de comparable.
  static const double _fallbackPrixM2 = 4200;

  /// Prix m² brut (médiane sans actualisation temporelle).
  double get prixMoyenBrut {
    if (comparables.isEmpty) return _fallbackPrixM2;
    final prices = comparables
        .map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return _fallbackPrixM2;
    prices.sort();
    return prices[prices.length ~/ 2];
  }

  /// Actualise un comparable au prix d'aujourd'hui selon la tendance communale.
  double _prixM2Actualise(Map<String, dynamic> c) {
    final brut = (c['prixM2'] as num?)?.toDouble() ?? 0;
    if (brut <= 0) return 0;
    if (!actualisationActive || tauxEvolutionAnnuel == 0) return brut;
    DateTime? d;
    final iso = c['dateIso']?.toString();
    if (iso != null && iso.length >= 7) {
      d = DateTime.tryParse(iso.length == 7 ? '$iso-01' : iso);
    }
    if (d == null) {
      final match = RegExp(r'(20\d{2})').firstMatch(c['date']?.toString() ?? '');
      if (match != null) d = DateTime(int.parse(match.group(1)!), 6);
    }
    if (d == null) return brut;
    final annees =
        (DateTime.now().difference(d).inDays / 365.25).clamp(0.0, 4.0);
    return brut * math.pow(1 + tauxEvolutionAnnuel / 100, annees);
  }

  /// Prix m² médian actualisé à aujourd'hui (utilisé pour le calcul du prix de base).
  double get prixMoyen {
    if (comparables.isEmpty) return _fallbackPrixM2;
    final prices = comparables.map(_prixM2Actualise).where((p) => p > 0).toList();
    if (prices.isEmpty) return _fallbackPrixM2;
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

  // Pour un terrain : le prix/m² DVF est direct (pas de coefficient prestations).
  double get prixM2Retenu => typeId == 'terrain'
      ? prixFondamentalM2
      : prixFondamentalM2 * (1 + coefficientPrestations / 100);
  // Pour un terrain : surface × prix/m² terrain (pas de surface pondérée).
  double get prixBase => typeId == 'terrain'
      ? prixM2Retenu * surfaceTerrain
      : prixM2Retenu * surfacePonderee;

  // Décote grande surface : -1% par 10 m² au-delà de 120 m², plafonnée à -8%
  // Basée sur la surface pondérée (annexes incluses)
  double get decoteSurface =>
      surfacePonderee <= 120 ? 0.0 : ((-(surfacePonderee - 120) / 10)).clamp(-8.0, 0.0);

  // Ajustement étage appartement : RDC=-5%, rez-de-jardin=0%, intermédiaire=0%, dernier+ascenseur=+3%, dernier sans=+1%
  // Un rez-de-jardin (RDC avec jardin privatif actif) neutralise la décote RDC.
  double get ajustEtageAuto {
    if (typeId != 'appartement') return 0.0;
    if (etage == 0) {
      final hasJardin = (annexesActives['jardin'] ?? false) && jardinSurface > 0;
      return hasJardin ? 0.0 : -5.0;
    }
    if (dernierEtage) return ascenseur ? 3.0 : 1.0;
    return 0.0;
  }

  // Décote charges copropriété : -1% par 500€ au-delà de 2 000€/an, plafonnée à -6%
  double get decoteCharges {
    if (typeId != 'appartement' || chargesCopro <= 2000) return 0.0;
    return (-(chargesCopro - 2000) / 500).clamp(-6.0, 0.0);
  }

  /// Décote locative modulée selon la situation occupationnelle.
  /// - Libre : 0%
  /// - Bail commercial : −25%
  /// - Congé locataire : −3% (bien quasi libre, sans condition de date)
  /// - Fin bail ≤ 12 mois (MM/YYYY) : −6%
  /// - Bail meublé : −8%
  /// - Bail vide standard : −12%
  double get decoteOccupation {
    if (libreOccupation) return 0.0;
    if (typeBail == 'Commercial') return -25.0;
    if (congeLocataire) return -3.0;
    if (dateFinBail.isNotEmpty) {
      final mtch = RegExp(r'^(\d{1,2})/(\d{4})$').firstMatch(dateFinBail);
      if (mtch != null) {
        final fin = DateTime(int.parse(mtch.group(2)!), int.parse(mtch.group(1)!));
        if (fin.difference(DateTime.now()).inDays <= 365) return -6.0;
      }
    }
    if (typeBail == 'Meublé') return -8.0;
    return -12.0;
  }

  /// Libellé lisible de la situation locative pour l'UI.
  String get labelOccupation {
    if (libreOccupation) return 'Bien libre';
    final pct = decoteOccupation.toInt();
    if (typeBail == 'Commercial') return 'Bail commercial ($pct%)';
    if (congeLocataire) return 'Congé donné ($pct%)';
    if (decoteOccupation == -6.0) return 'Fin bail ≤ 12 mois ($pct%)';
    if (typeBail == 'Meublé') return 'Bail meublé ($pct%)';
    return 'Bail vide standard ($pct%)';
  }

  /// Valorisation recommandée du stationnement (€) selon le type et le nombre de places.
  /// Plafond : 3 places valorisées. Types : 'Intégré'/'Box fermé' → 15 000 €, 'Séparé' → 10 000 €, autre → 6 000 €.
  int get recommendedAjustParking {
    final hasGarage = annexesActives['garage'] ?? false;
    final hasParking = annexesActives['parking'] ?? false;
    if (!hasGarage && !hasParking) return 0;
    final places = garagePlaces.clamp(0, 3);
    if (places == 0) return 0;
    final types = garageType.map((t) => t.toLowerCase()).toList();
    if (types.any((t) => t.contains('intégré') || t.contains('box'))) return places * 15000;
    if (types.any((t) => t.contains('séparé') || t.contains('separe'))) return places * 10000;
    return places * 6000;
  }

  // Prime terrain : valorise les m² au-delà de 500 m² standard (inclus dans le prix/m² DVF)
  // Constructible : 100 €/m² | Divisible constructible : 280 €/m² | Non-constructible : 8 €/m²
  static const _seuilTerrain = 500;
  static const _tauxConstructible = 100.0;
  static const _tauxConstructibleDivisible = 280.0; // terrain à bâtir détachable
  static const _tauxNonConstructible = 8.0;

  double get primeTerrain {
    if (typeId == 'appartement' || typeId == 'terrain' || surfaceTerrain <= _seuilTerrain) return 0;
    final excedent = surfaceTerrain - _seuilTerrain;
    final constructible = terrainConstructibleM2.clamp(0, excedent);
    final nonConstructible = excedent - constructible;
    final tauxConstr = parcelleDivisible ? _tauxConstructibleDivisible : _tauxConstructible;
    return constructible * tauxConstr + nonConstructible * _tauxNonConstructible;
  }

  double get prixMandat => (prixCalcule * (1 + margeNegociation / 100) / 1000).round() * 1000;

  // Calcul net vendeur réel et coût acquéreur
  double get fraisAgenceEstimes => prixMandat * tauxAgence / 100;
  double get fraisNotaireAcquereur => prixMandat * 0.08;
  double get budgetTotalAcquereur => prixMandat + fraisNotaireAcquereur;

  /// Somme de tous les ajustements en % (hors corrections monétaires travaux/parking/piscine).
  double get totalPctAjustements =>
      ajustVue + ajustEtat + ajustDpe + ajustExposition +
      ajustEnvironnement + ajustConjoncture + decoteSurface + decoteOccupation +
      ajustEtageAuto + decoteCharges + ajustCalibration +
      ajustEpoque + ajustGare + ajustRisques;

  double get prixCalcule {
    final impact = prixBase * totalPctAjustements / 100 - ajustTravaux + ajustParking + ajustPiscine + primeTerrain;
    final raw = prixBase + impact;
    return (raw / 1000).round() * 1000;
  }

  /// Alias lisible pour le prix arrondi au millier le plus proche.
  double get prixArrondi => prixCalcule;

  // ── Fourchette dynamique & indice de confiance ───────────────────────────

  /// Dispersion relative (IQR/médiane) des prix m² actualisés, en %.
  double get dispersionComparables {
    final prices =
        comparables.map(_prixM2Actualise).where((p) => p > 0).toList()..sort();
    if (prices.length < 3) return 0;
    double q(double p) {
      final pos = (prices.length - 1) * p;
      final lo = pos.floor(), hi = pos.ceil();
      return lo == hi
          ? prices[lo]
          : prices[lo] + (prices[hi] - prices[lo]) * (pos - lo);
    }
    final med = q(0.5);
    return med > 0 ? (q(0.75) - q(0.25)) / med * 100 : 0;
  }

  /// Largeur de fourchette auto (%) — remplace le ±5% figé.
  double get fourchettePctAuto {
    final n = comparables.length;
    final d = dispersionComparables;
    if (d > 25 || n < 3) return 8;
    if (d > 18) return 6;
    if (n >= 8 && d < 10) return 3;
    if (n >= 5 && d < 18) return 4;
    return 5;
  }

  /// Fourchette basse dynamique (respecte la saisie manuelle si renseignée).
  double get fourchetteBasseDyn => fourchetteBasse > 0
      ? fourchetteBasse
      : (prixCalcule * (1 - fourchettePctAuto / 100) / 1000).round() * 1000.0;

  /// Fourchette haute dynamique (respecte la saisie manuelle si renseignée).
  double get fourchetteHauteDyn => fourchetteHaute > 0
      ? fourchetteHaute
      : (prixCalcule * (1 + fourchettePctAuto / 100) / 1000).round() * 1000.0;

  /// Score de confiance /100.
  int get scoreConfiance {
    final n = comparables.length;
    final d = dispersionComparables;
    // Critère 1 : nb comparables (/40)
    int s = n >= 10 ? 40 : n >= 6 ? 30 : n >= 3 ? 18 : n >= 1 ? 8 : 0;
    // Critère 2 : dispersion (/30) — seulement si ≥ 3 comparables
    if (n >= 3) {
      s += d < 10 ? 30 : d < 18 ? 20 : d < 25 ? 10 : 5;
    }
    // Critère 3 : tendance marché (+15)
    if (tauxEvolutionAnnuel != 0 || trendInfo.isNotEmpty) s += 15;
    // Critère 4 : calibration locale (+15)
    if (calibrationNbVentes >= 3) s += 15;
    return s.clamp(0, 100);
  }

  /// Niveau de confiance lisible.
  String get niveauConfiance =>
      scoreConfiance >= 75 ? 'Élevée' : scoreConfiance >= 45 ? 'Bonne' : 'Indicative';

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
        'referenceCadastrale': referenceCadastrale,
        'typeMandat': typeMandat,
        'dureeMandatMois': dureeMandatMois,
        'honorairesACharge': honorairesACharge,
        'enCopropriete': enCopropriete ? 1 : 0,
        'syndicNom': syndicNom,
        'nombreLots': nombreLots,
        'tantiemes': tantiemes,
        'fondsTravaux': fondsTravaux,
        'coproProceduresEnCours': coproProceduresEnCours ? 1 : 0,
        'surfaceCarrez': surfaceCarrez,
        'nbSallesBain': nbSallesBain,
        'nbSallesEau': nbSallesEau,
        'nbWc': nbWc,
        'typeCuisine': typeCuisine,
        'combles': combles,
        'assainissement': assainissement,
        'fibreOptique': fibreOptique ? 1 : 0,
        'equipements': jsonEncode(equipements),
        'zonePlu': zonePlu,
        'viabilisation': jsonEncode(viabilisation),
        'terrainAcces': terrainAcces,
        'terrainPente': terrainPente,
        'terrainForme': terrainForme,
        'terrainCos': terrainCos,
        'terrainServitudes': terrainServitudes,
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
        'parcelleDivisible': parcelleDivisible ? 1 : 0,
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
        'ajustCalibration': ajustCalibration,
        'calibrationNbVentes': calibrationNbVentes,
        'calibrationScope': calibrationScope,
        'tauxEvolutionAnnuel': tauxEvolutionAnnuel,
        'actualisationActive': actualisationActive ? 1 : 0,
        'trendInfo': trendInfo,
        'prixFinal': prixFinal,
        'fourchetteBasse': fourchetteBasse,
        'fourchetteHaute': fourchetteHaute,
        'conclusion': conclusion,
        'prochainesEtapes': prochainesEtapes,
        'validiteJusquau': validiteJusquau.toIso8601String(),
        'photosPaths': jsonEncode(photosPaths),
        'risques': risques != null ? jsonEncode(risques!.toMap()) : null,
        'notesVendeur': notesVendeur != null ? jsonEncode(notesVendeur!.toMap()) : null,
        'historique': jsonEncode(historique),
        'piecesSurfaces': jsonEncode(piecesSurfaces),
        'observationsBien': observationsBien,
        'carnetNotes': jsonEncode(carnetNotes.map((n) => n.toMap()).toList()),
        'mutationsEcartees': jsonEncode(mutationsEcartees),
        'suiviVenteStatut': suiviVenteStatut,
        'ajustEpoque': ajustEpoque,
        'ajustGare': ajustGare,
        'ajustRisques': ajustRisques,
        'pathologies': jsonEncode(pathologies.map((p) => p.toMap()).toList()),
        'pathologiesLastReport': pathologiesLastReport,
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
      referenceCadastrale: m['referenceCadastrale'] as String? ?? '',
      typeMandat: m['typeMandat'] as String? ?? 'Simple',
      dureeMandatMois: m['dureeMandatMois'] as int? ?? 3,
      honorairesACharge: m['honorairesACharge'] as String? ?? 'Vendeur',
      enCopropriete: (m['enCopropriete'] as int? ?? 0) == 1,
      syndicNom: m['syndicNom'] as String? ?? '',
      nombreLots: m['nombreLots'] as int? ?? 0,
      tantiemes: m['tantiemes'] as int? ?? 0,
      fondsTravaux: m['fondsTravaux'] as int? ?? 0,
      coproProceduresEnCours: (m['coproProceduresEnCours'] as int? ?? 0) == 1,
      surfaceCarrez: m['surfaceCarrez'] as int? ?? 0,
      nbSallesBain: m['nbSallesBain'] as int? ?? 0,
      nbSallesEau: m['nbSallesEau'] as int? ?? 0,
      nbWc: m['nbWc'] as int? ?? 0,
      typeCuisine: m['typeCuisine'] as String? ?? '',
      combles: m['combles'] as String? ?? '',
      assainissement: m['assainissement'] as String? ?? '',
      fibreOptique: (m['fibreOptique'] as int? ?? 0) == 1,
      equipements: decodeStrList(m['equipements']),
      zonePlu: m['zonePlu'] as String? ?? '',
      viabilisation: decodeStrList(m['viabilisation']),
      terrainAcces: m['terrainAcces'] as String? ?? '',
      terrainPente: m['terrainPente'] as String? ?? '',
      terrainForme: m['terrainForme'] as String? ?? '',
      terrainCos: (m['terrainCos'] as num?)?.toDouble() ?? 0.0,
      terrainServitudes: m['terrainServitudes'] as String? ?? '',
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
      parcelleDivisible: (m['parcelleDivisible'] as int? ?? 0) == 1,
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
      ajustCalibration: (m['ajustCalibration'] as num?)?.toDouble() ?? 0,
      calibrationNbVentes: m['calibrationNbVentes'] as int? ?? 0,
      calibrationScope: m['calibrationScope'] as String? ?? '',
      tauxEvolutionAnnuel: (m['tauxEvolutionAnnuel'] as num?)?.toDouble() ?? 0,
      actualisationActive: (m['actualisationActive'] as int? ?? 1) == 1,
      trendInfo: m['trendInfo'] as String? ?? '',
      prixFinal: (m['prixFinal'] as num?)?.toDouble() ?? 0,
      fourchetteBasse: (m['fourchetteBasse'] as num?)?.toDouble() ?? 0,
      fourchetteHaute: (m['fourchetteHaute'] as num?)?.toDouble() ?? 0,
      conclusion: m['conclusion'] ?? '',
      prochainesEtapes: m['prochainesEtapes'] as String? ?? '',
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
      piecesSurfaces: m['piecesSurfaces'] != null
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(m['piecesSurfaces']) as List).map((e) => Map<String, dynamic>.from(e)))
          : [],
      historique: m['historique'] != null
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(m['historique']) as List).map((e) => Map<String, dynamic>.from(e)))
          : [],
      observationsBien: m['observationsBien'] as String? ?? _migrateObservations(m['notes'] as String?),
      carnetNotes: _migrateCarnetNotes(m['carnetNotes'] as String?, m['notes'] as String?),
      mutationsEcartees: decodeStrList(m['mutationsEcartees']),
      suiviVenteStatut: m['suiviVenteStatut'] as String? ?? '',
      ajustEpoque: (m['ajustEpoque'] as num?)?.toDouble() ?? 0,
      ajustGare: (m['ajustGare'] as num?)?.toDouble() ?? 0,
      ajustRisques: (m['ajustRisques'] as num?)?.toDouble() ?? 0,
      pathologies: m['pathologies'] != null
          ? List<PathologieItem>.from(
              (jsonDecode(m['pathologies'] as String) as List)
                  .map((e) => PathologieItem.fromMap(Map<String, dynamic>.from(e as Map))))
          : [],
      pathologiesLastReport: m['pathologiesLastReport'] as int? ?? 0,
    );
  }

  /// Migration : lit observations générales depuis l'ancienne map notes.
  static String _migrateObservations(String? oldNotesJson) {
    if (oldNotesJson == null) return '';
    try {
      final old = jsonDecode(oldNotesJson) as Map;
      return (old['section1'] as Map?)?['general'] as String? ?? '';
    } catch (_) { return ''; }
  }

  /// Migration : convertit l'ancienne map notes[sectionX][text] en carnetNotes.
  static List<CarnetNote> _migrateCarnetNotes(
      String? newJson, String? oldNotesJson) {
    // Nouveau format
    if (newJson != null) {
      try {
        final list = jsonDecode(newJson) as List;
        return list
            .map((x) => CarnetNote.fromMap(Map<String, dynamic>.from(x as Map)))
            .toList();
      } catch (_) { return []; }
    }
    // Migration depuis l'ancien format
    if (oldNotesJson == null) return [];
    final notes = <CarnetNote>[];
    try {
      final old = jsonDecode(oldNotesJson) as Map;
      old.forEach((section, data) {
        if (data is Map) {
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) {
            notes.add(CarnetNote(
              id: '${section}_migrated',
              timestamp: DateTime.now(),
              sectionOrigine: section as String,
              texte: text,
            ));
          }
        }
      });
    } catch (_) {}
    return notes;
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
    String? referenceCadastrale,
    String? typeMandat,
    int? dureeMandatMois,
    String? honorairesACharge,
    bool? enCopropriete,
    String? syndicNom,
    int? nombreLots,
    int? tantiemes,
    int? fondsTravaux,
    bool? coproProceduresEnCours,
    int? surfaceCarrez,
    int? nbSallesBain,
    int? nbSallesEau,
    int? nbWc,
    String? typeCuisine,
    String? combles,
    String? assainissement,
    bool? fibreOptique,
    List<String>? equipements,
    String? zonePlu,
    List<String>? viabilisation,
    String? terrainAcces,
    String? terrainPente,
    String? terrainForme,
    double? terrainCos,
    String? terrainServitudes,
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
    bool? parcelleDivisible,
    int? ajustTravaux,
    int? ajustParking,
    int? ajustPiscine,
    double? ajustCalibration,
    int? calibrationNbVentes,
    String? calibrationScope,
    double? tauxEvolutionAnnuel,
    bool? actualisationActive,
    String? trendInfo,
    double? prixFinal,
    double? fourchetteBasse,
    double? fourchetteHaute,
    String? conclusion,
    String? prochainesEtapes,
    DateTime? validiteJusquau,
    List<String>? photosPaths,
    GeorisquesData? risques,
    bool clearRisques = false,
    VendeurNote? notesVendeur,
    bool clearNotesVendeur = false,
    List<Map<String, dynamic>>? historique,
    List<Map<String, dynamic>>? piecesSurfaces,
    String? observationsBien,
    List<CarnetNote>? carnetNotes,
    List<String>? mutationsEcartees,
    String? suiviVenteStatut,
    double? ajustEpoque,
    double? ajustGare,
    double? ajustRisques,
    List<PathologieItem>? pathologies,
    int? pathologiesLastReport,
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
      referenceCadastrale: referenceCadastrale ?? this.referenceCadastrale,
      typeMandat: typeMandat ?? this.typeMandat,
      dureeMandatMois: dureeMandatMois ?? this.dureeMandatMois,
      honorairesACharge: honorairesACharge ?? this.honorairesACharge,
      enCopropriete: enCopropriete ?? this.enCopropriete,
      syndicNom: syndicNom ?? this.syndicNom,
      nombreLots: nombreLots ?? this.nombreLots,
      tantiemes: tantiemes ?? this.tantiemes,
      fondsTravaux: fondsTravaux ?? this.fondsTravaux,
      coproProceduresEnCours: coproProceduresEnCours ?? this.coproProceduresEnCours,
      surfaceCarrez: surfaceCarrez ?? this.surfaceCarrez,
      nbSallesBain: nbSallesBain ?? this.nbSallesBain,
      nbSallesEau: nbSallesEau ?? this.nbSallesEau,
      nbWc: nbWc ?? this.nbWc,
      typeCuisine: typeCuisine ?? this.typeCuisine,
      combles: combles ?? this.combles,
      assainissement: assainissement ?? this.assainissement,
      fibreOptique: fibreOptique ?? this.fibreOptique,
      equipements: equipements ?? List.from(this.equipements),
      zonePlu: zonePlu ?? this.zonePlu,
      viabilisation: viabilisation ?? List.from(this.viabilisation),
      terrainAcces: terrainAcces ?? this.terrainAcces,
      terrainPente: terrainPente ?? this.terrainPente,
      terrainForme: terrainForme ?? this.terrainForme,
      terrainCos: terrainCos ?? this.terrainCos,
      terrainServitudes: terrainServitudes ?? this.terrainServitudes,
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
      parcelleDivisible: parcelleDivisible ?? this.parcelleDivisible,
      ajustTravaux: ajustTravaux ?? this.ajustTravaux,
      ajustParking: ajustParking ?? this.ajustParking,
      ajustPiscine: ajustPiscine ?? this.ajustPiscine,
      ajustCalibration: ajustCalibration ?? this.ajustCalibration,
      calibrationNbVentes: calibrationNbVentes ?? this.calibrationNbVentes,
      calibrationScope: calibrationScope ?? this.calibrationScope,
      tauxEvolutionAnnuel: tauxEvolutionAnnuel ?? this.tauxEvolutionAnnuel,
      actualisationActive: actualisationActive ?? this.actualisationActive,
      trendInfo: trendInfo ?? this.trendInfo,
      prixFinal: prixFinal ?? this.prixFinal,
      fourchetteBasse: fourchetteBasse ?? this.fourchetteBasse,
      fourchetteHaute: fourchetteHaute ?? this.fourchetteHaute,
      conclusion: conclusion ?? this.conclusion,
      prochainesEtapes: prochainesEtapes ?? this.prochainesEtapes,
      validiteJusquau: validiteJusquau ?? this.validiteJusquau,
      photosPaths: photosPaths ?? List.from(this.photosPaths),
      risques: clearRisques ? null : (risques ?? this.risques),
      notesVendeur: clearNotesVendeur ? null : (notesVendeur ?? this.notesVendeur),
      historique: historique ?? List.from(this.historique),
      piecesSurfaces: piecesSurfaces ?? List.from(this.piecesSurfaces),
      observationsBien: observationsBien ?? this.observationsBien,
      carnetNotes: carnetNotes != null ? List.from(carnetNotes) : List.from(this.carnetNotes),
      mutationsEcartees: mutationsEcartees != null ? List.from(mutationsEcartees) : List.from(this.mutationsEcartees),
      suiviVenteStatut: suiviVenteStatut ?? this.suiviVenteStatut,
      ajustEpoque: ajustEpoque ?? this.ajustEpoque,
      ajustGare: ajustGare ?? this.ajustGare,
      ajustRisques: ajustRisques ?? this.ajustRisques,
      pathologies: pathologies != null ? List.from(pathologies) : List.from(this.pathologies),
      pathologiesLastReport: pathologiesLastReport ?? this.pathologiesLastReport,
    );
    return copy;
  }
}
