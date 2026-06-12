class PathologieItem {
  final String id;
  final String libelle;
  final String aideMemo;
  final int provisionBasse;
  final int provisionHaute;
  int etat;       // 0 = non vérifié, 1 = OK, 2 = à surveiller, 3 = défaut constaté
  String note;
  int provision;  // € retenus (0 si non applicable)

  PathologieItem({
    required this.id,
    required this.libelle,
    required this.aideMemo,
    required this.provisionBasse,
    required this.provisionHaute,
    this.etat = 0,
    this.note = '',
    this.provision = 0,
  });

  bool get verifie => etat > 0;
  bool get signale => etat == 2 || etat == 3;
  bool get defaut => etat == 3;

  Map<String, dynamic> toMap() => {
    'id': id,
    'libelle': libelle,
    'aideMemo': aideMemo,
    'provisionBasse': provisionBasse,
    'provisionHaute': provisionHaute,
    'etat': etat,
    'note': note,
    'provision': provision,
  };

  factory PathologieItem.fromMap(Map<String, dynamic> m) => PathologieItem(
    id: m['id'] as String? ?? '',
    libelle: m['libelle'] as String? ?? '',
    aideMemo: m['aideMemo'] as String? ?? '',
    provisionBasse: m['provisionBasse'] as int? ?? 0,
    provisionHaute: m['provisionHaute'] as int? ?? 0,
    etat: m['etat'] as int? ?? 0,
    note: m['note'] as String? ?? '',
    provision: m['provision'] as int? ?? 0,
  );

  PathologieItem copyWith({int? etat, String? note, int? provision}) => PathologieItem(
    id: id,
    libelle: libelle,
    aideMemo: aideMemo,
    provisionBasse: provisionBasse,
    provisionHaute: provisionHaute,
    etat: etat ?? this.etat,
    note: note ?? this.note,
    provision: provision ?? this.provision,
  );
}

/// Factory — retourne une liste fraîche et mutable des 13 points du référentiel Moraga.
List<PathologieItem> buildPathologiesReferentiel() => [
  PathologieItem(
    id: 'fissures_structurelles',
    libelle: 'Fissures structurelles',
    aideMemo: '> 2 mm, en escalier, traversantes, lézardes d\'angle. Vérifier façades, refends, soubassement.',
    provisionBasse: 8000, provisionHaute: 25000,
  ),
  PathologieItem(
    id: 'fissures_superficielles',
    libelle: 'Fissures superficielles',
    aideMemo: 'Faïençage, microfissures d\'enduit < 0,2 mm. Inspecter enduits intérieurs et extérieurs.',
    provisionBasse: 0, provisionHaute: 2000,
  ),
  PathologieItem(
    id: 'humidite_murs_bas',
    libelle: 'Humidité murs bas',
    aideMemo: 'Remontées capillaires, salpêtre, plinthes décollées. Tester au bas des murs du vide sanitaire.',
    provisionBasse: 4000, provisionHaute: 12000,
  ),
  PathologieItem(
    id: 'infiltrations_plafonds',
    libelle: 'Infiltrations / traces plafonds',
    aideMemo: 'Auréoles, cloques, odeur de moisi. Vérifier au droit des points d\'eau et sous toiture.',
    provisionBasse: 1500, provisionHaute: 8000,
  ),
  PathologieItem(
    id: 'ventilation',
    libelle: 'Ventilation',
    aideMemo: 'VMC absente ou hors service, condensation, moisissures d\'angle. Chercher bouche VMC cuisine + SDB.',
    provisionBasse: 1500, provisionHaute: 4000,
  ),
  PathologieItem(
    id: 'couverture',
    libelle: 'Couverture',
    aideMemo: 'Tuiles/ardoises déplacées, mousse dense, faîtage fissuré. Observer depuis l\'extérieur ou fenêtre de toit.',
    provisionBasse: 8000, provisionHaute: 20000,
  ),
  PathologieItem(
    id: 'zinguerie_gouttieres',
    libelle: 'Zinguerie / gouttières',
    aideMemo: 'Percées, débordements visibles, descentes déformées. Traces de coulures sous la gouttière.',
    provisionBasse: 1000, provisionHaute: 3000,
  ),
  PathologieItem(
    id: 'charpente',
    libelle: 'Charpente',
    aideMemo: 'Flèche visible, vrillettes/capricorne (sciure fine), humidité bois > 18 %. Inspecter les combles.',
    provisionBasse: 5000, provisionHaute: 30000,
  ),
  PathologieItem(
    id: 'tableau_electrique',
    libelle: 'Tableau électrique',
    aideMemo: 'Fusibles porcelaine, absence de diff. 30 mA, câblage aluminium. Vérifier tableau et compteur.',
    provisionBasse: 2000, provisionHaute: 8000,
  ),
  PathologieItem(
    id: 'plomberie',
    libelle: 'Plomberie',
    aideMemo: 'Plomb/acier d\'origine, pression faible, ballon > 15 ans. Observer sous évier, tester les robinets.',
    provisionBasse: 2000, provisionHaute: 10000,
  ),
  PathologieItem(
    id: 'menuiseries',
    libelle: 'Menuiseries',
    aideMemo: 'Simple vitrage, condensation inter-vitres, étanchéité défaillante. Tester chaque ouvrant.',
    provisionBasse: 4000, provisionHaute: 15000,
  ),
  PathologieItem(
    id: 'facades_enduits',
    libelle: 'Façades / enduits',
    aideMemo: 'Décollements, cloquage généralisé, fissures longitudinales. Percuter : son creux = décollement.',
    provisionBasse: 5000, provisionHaute: 18000,
  ),
  PathologieItem(
    id: 'assainissement',
    libelle: 'Assainissement (non collectif)',
    aideMemo: 'Conformité SPANC, odeurs, fosses hors sol, installation > 30 ans. Demander rapport SPANC.',
    provisionBasse: 8000, provisionHaute: 15000,
  ),
];
