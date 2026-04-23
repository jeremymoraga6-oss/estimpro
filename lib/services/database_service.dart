import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/estimation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'estimpro.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE estimations (
            id TEXT PRIMARY KEY,
            reference TEXT,
            createdAt TEXT,
            updatedAt TEXT,
            typeId TEXT,
            motif TEXT,
            dateVisite TEXT,
            proprietaireNom TEXT,
            proprietaireTel TEXT,
            proprietaireEmail TEXT,
            surfaceHabitable INTEGER,
            surfaceTerrain INTEGER,
            pieces INTEGER,
            chambres INTEGER,
            anneeConstruction TEXT,
            etatGeneral INTEGER,
            orientations TEXT,
            vues TEXT,
            dpeClasse TEXT,
            chauffageType TEXT,
            revetementsol TEXT,
            annexesActives TEXT,
            garagePlaces INTEGER,
            garageType TEXT,
            jardinSurface INTEGER,
            jardinEtat TEXT,
            annexesDetails TEXT,
            facade TEXT,
            toiture TEXT,
            menuiseriesType TEXT,
            vitrage TEXT,
            chauffageEtat TEXT,
            anneeChaudiere INTEGER,
            electricite TEXT,
            isolation TEXT,
            comparables TEXT,
            ajustVue REAL,
            ajustEtat REAL,
            ajustDpe REAL,
            ajustTravaux INTEGER,
            prixFinal REAL,
            fourchetteBasse REAL,
            fourchetteHaute REAL,
            conclusion TEXT,
            validiteJusquau TEXT,
            photosPaths TEXT,
            notes TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveEstimation(Estimation e) async {
    final db = await database;
    await db.insert(
      'estimations',
      e.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Estimation>> loadAll() async {
    final db = await database;
    final rows = await db.query('estimations', orderBy: 'updatedAt DESC');
    return rows.map(Estimation.fromMap).toList();
  }

  Future<Estimation?> loadById(String id) async {
    final db = await database;
    final rows = await db.query('estimations', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Estimation.fromMap(rows.first);
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('estimations', where: 'id = ?', whereArgs: [id]);
  }
}
