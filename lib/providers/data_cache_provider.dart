import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/doctor_model.dart';
import '../models/room_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Caches doctors, patients (users with role patient), rooms, and user display names.
/// Listens to Firestore streams and updates cache when data changes so screens
/// can show cached data immediately and only reload when data actually changes.
class DataCacheProvider with ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<DoctorModel> _doctors = [];
  List<UserModel> _users = [];
  List<RoomModel> _rooms = [];
  List<ServiceModel> _services = [];
  final Map<String, String> _userNames = {};
  final Map<String, List<DoctorAvailabilityModel>> _doctorAvailability = {};

  bool _doctorsLoading = true;
  bool _usersLoading = true;
  bool _roomsLoading = true;
  bool _servicesLoading = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _doctorsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roomsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;

  List<DoctorModel> get doctors => List.unmodifiable(_doctors);
  List<UserModel> get users => List.unmodifiable(_users);
  List<UserModel> get patients => List.unmodifiable(_users.where((u) => u.roles.contains('patient')).toList());
  List<RoomModel> get rooms => List.unmodifiable(_rooms);
  List<ServiceModel> get services => List.unmodifiable(_services);
  Map<String, String> get userNames => Map.unmodifiable(_userNames);

  bool get doctorsLoading => _doctorsLoading;
  bool get usersLoading => _usersLoading;
  bool get roomsLoading => _roomsLoading;
  bool get servicesLoading => _servicesLoading;
  bool get isLoading => _doctorsLoading || _usersLoading || _roomsLoading || _servicesLoading;

  String? userName(String? userId) => userId == null ? null : _userNames[userId];

  /// True if patient (user) is marked as starred (VIP). Same star icon as "new patient" in schedule.
  bool isPatientStarred(String? patientId) {
    if (patientId == null) return false;
    for (final u in _users) {
      if (u.id == patientId) return u.isStarred;
    }
    return false;
  }

  /// Display name for a doctor (by doctors collection doc id). Use for appointments list.
  String? doctorDisplayName(String? doctorId) {
    if (doctorId == null) return null;
    for (final d in _doctors) {
      if (d.id == doctorId) return _userNames[d.userId] ?? d.displayName ?? doctorId;
    }
    return null;
  }

  List<DoctorAvailabilityModel>? doctorAvailability(String doctorId) => _doctorAvailability[doctorId];

  DataCacheProvider() {
    _startListening();
  }

  void _startListening() {
    _doctorsSub?.cancel();
    _doctorsSub = _firestore.doctorsStream().listen(
      (snapshot) {
        _doctors = snapshot.docs
            .map((d) => DoctorModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        _doctorsLoading = false;
        notifyListeners();
        _loadDoctorAvailabilityAndNames();
      },
      onError: (e, st) {
        debugPrint('DataCacheProvider doctorsStream error: $e');
        _doctorsLoading = false;
        notifyListeners();
      },
    );

    _usersSub?.cancel();
    _usersSub = _firestore.usersStream().listen(
      (snapshot) {
        _users = snapshot.docs
            .map((d) => UserModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        _usersLoading = false;
        _rebuildUserNames();
      },
      onError: (e, st) {
        debugPrint('DataCacheProvider usersStream error: $e');
        _usersLoading = false;
        notifyListeners();
      },
    );

    _roomsSub?.cancel();
    _roomsSub = _firestore.roomsStream().listen(
      (snapshot) {
        var list = snapshot.docs
            .map((d) => RoomModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
        _rooms = list;
        _roomsLoading = false;
        notifyListeners();
      },
      onError: (e, st) {
        debugPrint('DataCacheProvider roomsStream error: $e');
        _roomsLoading = false;
        notifyListeners();
      },
    );

    _servicesSub?.cancel();
    _servicesSub = _firestore.servicesStream().listen(
      (snapshot) {
        var list = snapshot.docs
            .map((d) => ServiceModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
        _services = list;
        _servicesLoading = false;
        notifyListeners();
      },
      onError: (e, st) {
        debugPrint('DataCacheProvider servicesStream error: $e');
        _servicesLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadDoctorAvailabilityAndNames() async {
    final names = <String, String>{..._userNames};
    final availability = <String, List<DoctorAvailabilityModel>>{};
    for (final d in _doctors) {
      if (d.userId.isNotEmpty) {
        UserModel? u;
        for (final x in _users) {
          if (x.id == d.userId) {
            u = x;
            break;
          }
        }
        names[d.userId] = u?.displayName ?? d.displayName ?? d.userId;
      }
      try {
        availability[d.id] = await _firestore.getDoctorAvailability(d.id);
      } catch (_) {
        availability[d.id] = [];
      }
    }
    _userNames.addAll(names);
    _doctorAvailability.addAll(availability);
    notifyListeners();
  }

  void _rebuildUserNames() {
    for (final u in _users) {
      _userNames[u.id] = u.displayName;
    }
    for (final d in _doctors) {
      if (d.userId.isNotEmpty && !_userNames.containsKey(d.userId)) {
        _userNames[d.userId] = d.displayName ?? d.userId;
      }
    }
    notifyListeners();
  }

  /// Call when doctors list changed so we refresh availability and names.
  Future<void> refreshDoctorsCache() async {
    await _loadDoctorAvailabilityAndNames();
  }

  @override
  void dispose() {
    _doctorsSub?.cancel();
    _usersSub?.cancel();
    _roomsSub?.cancel();
    _servicesSub?.cancel();
    super.dispose();
  }
}
