import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<String> _getOrCreateUserId() async {
  final sp = await SharedPreferences.getInstance();
  var id = sp.getString('user_id');
  if (id == null) {
    id = const Uuid().v4();
    await sp.setString('user_id', id);
  }
  return id;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: UserMapApp()));
}

class UserMapApp extends StatefulWidget {
  const UserMapApp({super.key});
  @override
  State<UserMapApp> createState() => _UserMapAppState();
}

class _UserMapAppState extends State<UserMapApp> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  String? _userId;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<DatabaseEvent>? _vehSub;
  bool _running = false;
  String _status = 'ยังไม่เริ่มส่งตำแหน่ง';
  String _vehicleStatus = 'รถ: รอข้อมูล...';

  FirebaseDatabase? _db; // สำหรับอ่านตำแหน่งรถ

  static const LatLng _initTarget = LatLng(10.7230, 99.3745); // KMITL PCC

  @override
  void initState() {
    super.initState();
    _setupVehicleListener(); // ✅ ฟังตำแหน่งรถจาก Realtime Database
  }

  Future<void> _ensurePermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw 'กรุณาเปิด Location (GPS) ก่อน';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'ยังไม่ได้รับสิทธิ์ตำแหน่ง';
    }
  }

  Future<void> _start() async {
    try {
      await _ensurePermissions();
      _userId ??= await _getOrCreateUserId();
      final docRef = FirebaseFirestore.instance.collection('ride_requests').doc(_userId);

      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await docRef.set({
        'userId': _userId,
        'status': 'open',
        'lat': p.latitude,
        'lng': p.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _setSelfMarker(LatLng(p.latitude, p.longitude));
      _animateTo(LatLng(p.latitude, p.longitude), zoom: 16);

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        docRef.update({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        });
        _setSelfMarker(LatLng(pos.latitude, pos.longitude));
      });

      setState(() {
        _running = true;
        _status = 'กำลังส่งตำแหน่งเป็น ${_userId!.substring(0, 6)}';
      });
      _toast('เริ่มส่งตำแหน่งแล้ว');
    } catch (e) {
      _toast('$e');
      setState(() => _status = '❌ $e');
    }
  }

  Future<void> _stop() async {
    await _posSub?.cancel();
    if (_userId != null) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(_userId)
          .set({'status': 'done', 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    setState(() {
      _running = false;
      _status = 'หยุดส่งแล้ว';
    });
    _toast('หยุดส่งตำแหน่งแล้ว');
  }

  void _setSelfMarker(LatLng pos) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'me');
      _markers.add(Marker(
        markerId: const MarkerId('me'),
        position: pos,
        infoWindow: const InfoWindow(title: 'ตำแหน่งของฉัน'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    });
  }

  void _setVehicleMarker(LatLng pos) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'vehicle_bus01');
      _markers.add(Marker(
        markerId: const MarkerId('vehicle_bus01'),
        position: pos,
        infoWindow: const InfoWindow(title: 'รถ (bus01)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(30), // โทนส้ม
      ));
    });
  }

  void _animateTo(LatLng pos, {double zoom = 15}) {
    _map?.animateCamera(CameraUpdate.newLatLngZoom(pos, zoom));
  }

  /// ✅ ฟังตำแหน่งรถแบบเรียลไทม์จาก Realtime Database
  Future<void> _setupVehicleListener() async {
    try {
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://ride-app-2b814-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      // one-shot ตรวจว่ามีค่าหรือไม่
      final snap = await _db!.ref('vehicles/bus01').get();
      debugPrint('ONE-SHOT vehicles/bus01 => ${snap.value}');
      setState(() {
        _vehicleStatus = 'ONE-SHOT: ${snap.value}';
      });

      _vehSub = _db!.ref('vehicles/bus01').onValue.listen((ev) {
        final val = ev.snapshot.value;
        debugPrint('📡 vehicles/bus01 => $val');

        if (val is Map) {
          final lat = double.tryParse(val['lat']?.toString() ?? '');
          final lng = double.tryParse(val['lng']?.toString() ?? '');
          if (lat != null && lng != null) {
            final pos = LatLng(lat, lng);
            _setVehicleMarker(pos);
            setState(() => _vehicleStatus = 'bus01: $lat,$lng');
            // ถ้าอยากตามรถตลอดให้เปิดบรรทัดนี้
            // _map?.animateCamera(CameraUpdate.newLatLng(pos));
          } else {
            setState(() => _vehicleStatus = 'bus01: lat/lng parse ไม่ได้');
          }
        } else if (val == null) {
          setState(() => _vehicleStatus = 'bus01: ยังไม่มีข้อมูล');
        } else {
          setState(() => _vehicleStatus = 'bus01: snapshot ไม่ใช่ Map');
        }
      });
    } catch (e) {
      debugPrint('❌ setupVehicleListener failed: $e');
      _toast('เชื่อม Realtime DB ไม่ได้: $e');
      setState(() => _vehicleStatus = 'DB error: $e');
    }
  }

  @override
  void dispose() {
    _vehSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ผู้ใช้: ติดตามตำแหน่งรถ + ส่งตำแหน่งตัวเอง')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _initTarget, zoom: 14),
              onMapCreated: (c) => _map = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(_vehicleStatus, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _running ? null : _start,
                      child: Text(_running ? 'กำลังส่ง…' : 'เริ่มส่งตำแหน่ง'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _running ? _stop : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('หยุด'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
