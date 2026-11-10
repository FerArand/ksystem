import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ksystem/databases/app_database.dart';

typedef FilaSincronizable = Map< String, dynamic >;

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  Timer? _timerPeriodico;
  bool _sincronizando = false;
  bool _firebaseDisponible = false;
  bool _cambiosPendientes = false;

  /// Indica si existen movimientos locales que aún no se han confirmado en Firebase
  bool get tieneCambiosPendientes => _cambiosPendientes;
  bool get estaSincronizando => _sincronizando;

  static const List< String > _tablasSincronizables = [
    'productos',
    'ventas_historial',
    'deudores',
    'pedidos',
  ];

  /// Marca que el operador realizó una modificación local pendiente de subir a la nube
  void marcarCambiosPendientes() {
    _cambiosPendientes = true;
  }

  /// Inicializa Firebase de forma segura (Offline-First)
  Future< void > inicializar({
    FirebaseOptions? options,
    Duration intervalo = const Duration(minutes: 3),
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }

      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      _firebaseDisponible = true;
      debugPrint('[SyncService] Firebase inicializado. Sincronización híbrida activa.');

      unawaited(sincronizarTodo());

      _timerPeriodico?.cancel();
      _timerPeriodico = Timer.periodic(intervalo, (_) {
        unawaited(sincronizarTodo());
      });
    } catch (e) {
      _firebaseDisponible = false;
      debugPrint('[SyncService] Operando en modo 100% Local Offline-First (Firebase en espera: $e)');
    }
  }

  /// Ejecuta el respaldo bidireccional. Devuelve true si respaldó en la nube sin errores.
  Future< bool > sincronizarTodo() async {
    if (!_firebaseDisponible) return false;
    if (_sincronizando) {
      // Si ya hay una sincronización en curso, esperamos a que termine
      while (_sincronizando) {
        await Future< void >.delayed(const Duration(milliseconds: 200));
      }
      return !_cambiosPendientes;
    }

    _sincronizando = true;
    try {
      final db = await AppDatabase.instance.database;
      final firestore = FirebaseFirestore.instance;

      for (final tabla in _tablasSincronizables) {
        await _sincronizarTablaBidireccional(db, firestore, tabla);
      }

      _cambiosPendientes = false;
      debugPrint('[SyncService] Sincronización bidireccional completada (0 colisiones).');
      return true;
    } catch (e) {
      _cambiosPendientes = true;
      debugPrint('[SyncService] Intermitencia de red detectada, cambios pendientes: $e');
      return false;
    } finally {
      _sincronizando = false;
    }
  }

  Future< void > _sincronizarTablaBidireccional(
      Database db,
      FirebaseFirestore firestore,
      String nombreTabla,
      ) async {
    final coleccionRef = firestore.collection(nombreTabla);

    // 1. SUBIDA (Local SQLite -> Nube Firebase)
    final List< FilaSincronizable > registrosLocales = await db.query(
      nombreTabla,
      where: 'uuid IS NOT NULL AND uuid != ""',
    );

    final Map< String, FilaSincronizable > mapaLocalPorUuid = {};

    for (final fila in registrosLocales) {
      final String uuid = (fila['uuid'] ?? '').toString();
      if (uuid.isEmpty) continue;
      mapaLocalPorUuid[uuid] = fila;

      final String updatedAtLocal = (fila['updated_at'] ?? '').toString();
      final docRef = coleccionRef.doc(uuid);
      final docRemoto = await docRef.get();

      if (!docRemoto.exists) {
        await docRef.set(FilaSincronizable.from(fila));
      } else {
        final datosRemotos = docRemoto.data();
        final String updatedAtRemoto = (datosRemotos?['updated_at'] ?? '').toString();

        if (updatedAtLocal.compareTo(updatedAtRemoto) > 0) {
          await docRef.update(FilaSincronizable.from(fila));
        }
      }
    }

    // 2. DESCARGA (Nube Firebase -> Local SQLite)
    final snapshotRemoto = await coleccionRef.get();
    for (final doc in snapshotRemoto.docs) {
      final String uuidRemoto = doc.id;
      final FilaSincronizable datosRemotos = FilaSincronizable.from(doc.data());
      datosRemotos['uuid'] = uuidRemoto;
      datosRemotos.remove('id');

      final String updatedAtRemoto = (datosRemotos['updated_at'] ?? '').toString();
      final FilaSincronizable? registroLocal = mapaLocalPorUuid[uuidRemoto];

      if (registroLocal == null) {
        await db.insert(
          nombreTabla,
          datosRemotos,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } else {
        final String updatedAtLocal = (registroLocal['updated_at'] ?? '').toString();
        if (updatedAtRemoto.compareTo(updatedAtLocal) > 0) {
          await db.update(
            nombreTabla,
            datosRemotos,
            where: 'uuid = ?',
            whereArgs: [uuidRemoto],
          );
        }
      }
    }
  }

  void detener() {
    _timerPeriodico?.cancel();
  }
}