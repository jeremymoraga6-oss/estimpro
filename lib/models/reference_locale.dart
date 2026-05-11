class ReferenceLocale {
  final String id;
  final DateTime createdAt;
  String adresse;
  String commune;
  String codeInsee;
  String typeId; // maison, appartement, chalet, terrain
  int surface;
  String dpeClasse;
  int prixVente;  // prix de vente réel €
  DateTime dateVente;
  int prixEstime; // prix estimé avant vente (0 = non renseigné)
  String notes;
  String estimationId; // id de l'estimation liée ('' si aucune)

  ReferenceLocale({
    required this.id,
    required this.createdAt,
    this.adresse = '',
    this.commune = '',
    this.codeInsee = '',
    this.typeId = 'maison',
    this.surface = 100,
    this.dpeClasse = 'D',
    required this.prixVente,
    required this.dateVente,
    this.prixEstime = 0,
    this.notes = '',
    this.estimationId = '',
  });

  double get prixM2 => surface > 0 ? prixVente / surface : 0;

  // Écart % entre prix estimé et prix de vente réel (+= surestimation)
  double get ecartPct =>
      prixEstime > 0 ? (prixVente - prixEstime) / prixEstime * 100 : 0;

  bool get hasEstime => prixEstime > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'adresse': adresse,
        'commune': commune,
        'codeInsee': codeInsee,
        'typeId': typeId,
        'surface': surface,
        'dpeClasse': dpeClasse,
        'prixVente': prixVente,
        'dateVente': dateVente.toIso8601String(),
        'prixEstime': prixEstime,
        'notes': notes,
        'estimationId': estimationId,
      };

  factory ReferenceLocale.fromMap(Map<String, dynamic> m) => ReferenceLocale(
        id: m['id'],
        createdAt: DateTime.parse(m['createdAt'] as String),
        adresse: m['adresse'] as String? ?? '',
        commune: m['commune'] as String? ?? '',
        codeInsee: m['codeInsee'] as String? ?? '',
        typeId: m['typeId'] as String? ?? 'maison',
        surface: m['surface'] as int? ?? 100,
        dpeClasse: m['dpeClasse'] as String? ?? 'D',
        prixVente: m['prixVente'] as int? ?? 0,
        dateVente: DateTime.parse(
            m['dateVente'] as String? ?? DateTime.now().toIso8601String()),
        prixEstime: m['prixEstime'] as int? ?? 0,
        notes: m['notes'] as String? ?? '',
        estimationId: m['estimationId'] as String? ?? '',
      );

  // Convertit en comparable pour la section 5
  Map<String, dynamic> toComparable() => {
        'addr': adresse,
        'desc':
            '${typeId[0].toUpperCase()}${typeId.substring(1)} · $surface m²',
        'date': fmtDate(dateVente),
        'prix': prixVente.toDouble(),
        'prixM2': prixM2,
        'source': 'local',
        'refId': id,
      };

  static String fmtDate(DateTime d) {
    const months = [
      'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
