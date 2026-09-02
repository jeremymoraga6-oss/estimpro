import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/reference_locale.dart';
import 'base_locale_service.dart';
import 'database_service.dart';
import 'dvf_service.dart';
import 'estimation_passee_service.dart';
import 'geo_service.dart';

class CandidatVente {
  final DvfTransaction mutation;
  final double distanceM;
  final double scorePct;
  final List<String> criteres;
  const CandidatVente({
    required this.mutation,
    required this.distanceM,
    required this.scorePct,
    required this.criteres,
  });
}

class SuiviVentesService {
  static final SuiviVentesService _instance = SuiviVentesService._internal();
  factory SuiviVentesService() => _instance;
  SuiviVentesService._internal();

  /// Generates a stable id for a DVF transaction to track rejections.
  static String txId(DvfTransaction tx) =>
      '${tx.dateMutation}_${tx.adresse}_${tx.valeurFonciere.round()}';

  /// Converts app typeId to DVF typeLocal string.
  static String? _dvfType(String typeId) {
    switch (typeId) {
      case 'maison':
      case 'chalet':
        return 'Maison';
      case 'appartement':
        return 'Appartement';
      default:
        return null;
    }
  }

  /// Searches for matching DVF transactions for a given estimation location.
  Future<List<CandidatVente>> chercherCandidats({
    required double lat,
    required double lon,
    required String codeInsee,
    required String typeId,
    required int surface,
    required DateTime dateEstimation,
    required List<String> exclureIds,
  }) async {
    if (codeInsee.isEmpty || lat == 0 || lon == 0) return [];

    final result = await DvfService().fetch(codeInsee: codeInsee);
    if (result.transactions.isEmpty) return [];

    final dvfType = _dvfType(typeId);
    final candidats = <CandidatVente>[];

    for (final tx in result.transactions) {
      if (tx.dateMutation.isEmpty) continue;
      DateTime txDate;
      try {
        txDate = DateTime.parse(tx.dateMutation);
      } catch (_) {
        continue;
      }
      if (!txDate.isAfter(dateEstimation)) continue;
      if (dvfType != null && tx.typeLocal != dvfType) continue;
      if (exclureIds.contains(txId(tx))) continue;
      if (tx.latitude == 0 || tx.longitude == 0) continue;

      final distM = GeoService.haversineKm(lat, lon, tx.latitude, tx.longitude) * 1000;
      if (distM > 150) continue;

      if (surface > 0 && tx.surfaceReelleBati > 0) {
        final gap = ((tx.surfaceReelleBati - surface) / surface).abs();
        if (gap > 0.20) continue;
      }

      final criteres = <String>[];
      int score = 0;

      // Distance
      if (distM < 30) {
        score += 50;
        criteres.add('Très proche (${distM.round()} m)');
      } else if (distM < 75) {
        score += 35;
        criteres.add('Proche (${distM.round()} m)');
      } else {
        score += 15;
        criteres.add('Dans le périmètre (${distM.round()} m)');
      }

      // Surface
      if (surface > 0 && tx.surfaceReelleBati > 0) {
        final gap = ((tx.surfaceReelleBati - surface) / surface).abs();
        if (gap <= 0.05) {
          score += 30;
          criteres.add('Surface identique (${tx.surfaceReelleBati.round()} m²)');
        } else if (gap <= 0.12) {
          score += 20;
          criteres.add('Surface proche (${tx.surfaceReelleBati.round()} m²)');
        } else {
          score += 8;
          criteres.add('Surface similaire (${tx.surfaceReelleBati.round()} m²)');
        }
      }

      // Delay
      final months = txDate.difference(dateEstimation).inDays / 30.0;
      if (months <= 18) {
        score += 10;
        criteres.add('Vendu ${months.round()} mois après l\'estimation');
      }

      // Type
      if (dvfType != null && tx.typeLocal == dvfType) {
        score += 10;
        criteres.add('Type correspondant');
      }

      if (score < 40) continue;
      candidats.add(CandidatVente(
        mutation: tx,
        distanceM: distM,
        scorePct: score.clamp(0, 100).toDouble(),
        criteres: criteres,
      ));
    }

    candidats.sort((a, b) => b.scorePct.compareTo(a.scorePct));
    return candidats.take(5).toList();
  }

  /// Confirms a match and creates a dvf-backfill entry in the base locale.
  Future<void> confirmerVente({
    required String estimationId,
    required String adresse,
    required String commune,
    required String codeInsee,
    required String typeId,
    required int prixEstime,
    required CandidatVente candidat,
  }) async {
    final ref = ReferenceLocale(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      adresse: adresse.isNotEmpty ? adresse : candidat.mutation.adresse,
      commune: commune,
      codeInsee: codeInsee,
      typeId: typeId,
      surface: candidat.mutation.surfaceReelleBati.round(),
      dpeClasse: 'NC',
      prixVente: candidat.mutation.valeurFonciere.round(),
      dateVente: DateTime.tryParse(candidat.mutation.dateMutation) ?? DateTime.now(),
      prixEstime: prixEstime,
      notes: 'Backfill DVF — ${candidat.criteres.join(" · ")}',
      estimationId: estimationId,
      source: 'dvf-backfill',
    );
    await BaseLocaleService().save(ref);
  }

  /// Batch scan all eligible estimations. Returns total candidates found and
  /// number of estimations whose statut was updated.
  Future<({int totalCandidats, int nbMisAJour})> scanAll() async {
    final estimations = await DatabaseService().loadAll();
    final passees = await EstimationPasseeService().loadAll();
    final db = DatabaseService();
    final svc = EstimationPasseeService();

    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    int totalCandidats = 0;
    int nbMisAJour = 0;

    // Cache DVF fetches by codeInsee
    final cache = <String, List<DvfTransaction>>{};
    Future<List<DvfTransaction>> fetchCommune(String code) async {
      if (cache.containsKey(code)) return cache[code]!;
      try {
        final r = await DvfService().fetch(codeInsee: code);
        cache[code] = r.transactions;
        return r.transactions;
      } catch (e) {
        debugPrint('[SuiviVentes] fetch error for $code: $e');
        cache[code] = [];
        return [];
      }
    }

    for (final e in estimations) {
      if (e.suiviVenteStatut == 'confirmee') continue;
      if (e.codeInsee.isEmpty || e.latitude == 0) continue;
      if (e.prixFinal <= 0) continue;
      if (!e.createdAt.isBefore(cutoff)) continue;

      final allTx = await fetchCommune(e.codeInsee);
      final dvfType = _dvfType(e.typeId);
      int found = 0;

      for (final tx in allTx) {
        if (tx.dateMutation.isEmpty) continue;
        DateTime txDate;
        try {
          txDate = DateTime.parse(tx.dateMutation);
        } catch (_) {
          continue;
        }
        if (!txDate.isAfter(e.createdAt)) continue;
        if (dvfType != null && tx.typeLocal != dvfType) continue;
        if (e.mutationsEcartees.contains(txId(tx))) continue;
        if (tx.latitude == 0 || tx.longitude == 0) continue;
        final distM = GeoService.haversineKm(e.latitude, e.longitude, tx.latitude, tx.longitude) * 1000;
        if (distM > 150) continue;
        if (e.surfaceHabitable > 0 && tx.surfaceReelleBati > 0) {
          final gap = ((tx.surfaceReelleBati - e.surfaceHabitable) / e.surfaceHabitable).abs();
          if (gap > 0.20) continue;
        }
        found++;
      }

      if (found > 0) {
        totalCandidats += found;
        if (e.suiviVenteStatut != 'candidats') {
          await db.saveEstimation(e.copyWith(suiviVenteStatut: 'candidats'));
          nbMisAJour++;
        }
      } else if (e.suiviVenteStatut == '') {
        await db.saveEstimation(e.copyWith(suiviVenteStatut: 'aucune'));
      }
    }

    for (final ep in passees) {
      if (ep.statut == 'confirmee') continue;
      if (ep.codeInsee.isEmpty || ep.latitude == 0) continue;
      if (!ep.dateEstimationDt.isBefore(cutoff)) continue;

      final allTx = await fetchCommune(ep.codeInsee);
      final dvfType = _dvfType(ep.typeId);
      int found = 0;

      for (final tx in allTx) {
        if (tx.dateMutation.isEmpty) continue;
        DateTime txDate;
        try {
          txDate = DateTime.parse(tx.dateMutation);
        } catch (_) {
          continue;
        }
        if (!txDate.isAfter(ep.dateEstimationDt)) continue;
        if (dvfType != null && tx.typeLocal != dvfType) continue;
        if (ep.mutationsEcartees.contains(txId(tx))) continue;
        if (tx.latitude == 0 || tx.longitude == 0) continue;
        final distM = GeoService.haversineKm(ep.latitude, ep.longitude, tx.latitude, tx.longitude) * 1000;
        if (distM > 150) continue;
        if (ep.surface > 0 && tx.surfaceReelleBati > 0) {
          final gap = ((tx.surfaceReelleBati - ep.surface) / ep.surface).abs();
          if (gap > 0.20) continue;
        }
        found++;
      }

      if (found > 0) {
        totalCandidats += found;
        if (ep.statut != 'candidats') {
          ep.statut = 'candidats';
          await svc.save(ep);
          nbMisAJour++;
        }
      } else if (ep.statut == '') {
        ep.statut = 'aucune';
        await svc.save(ep);
      }
    }

    return (totalCandidats: totalCandidats, nbMisAJour: nbMisAJour);
  }
}
