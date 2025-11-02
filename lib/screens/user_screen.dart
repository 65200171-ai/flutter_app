import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  StreamSubscription<DatabaseEvent>? _vehSub;
  StreamSubscription<DatabaseEvent>? _vehAllSub;

  FirebaseDatabase? _db;
  static const LatLng _init = LatLng(10.7230, 99.3745); // KMITL PCC
  String _vehicleStatus = 'รถ: รอข้อมูล...';

  @override
  void initState() {
    super.initState();
    _setupAndListen();
  }

  Future<void> _setupAndListen() async {
    try {
      // ปลอดภัย: เรียกอีกรอบได้แม้ main จะ init แล้ว
      await Firebase.initializeApp();

      const dbUrl =
          'https://ride-app-2b814-default-rtdb.asia-southeast1.firebasedatabase.app';
      _db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: dbUrl);
      debugPrint('Realtime DB URL = $dbUrl');

      // ONE-SHOT
      final snap = await _db!.ref('vehicles/bus01').get();
      debugPrint('ONE-SHOT vehicles/bus01 => ${snap.value}');
      setState(() => _vehicleStatus = 'ONE-SHOT: ${snap.value}');

      // STREAM เฉพาะ bus01
      _listenVehicle('bus01');

      // STREAM fallback: ทั้งโหนด vehicles (กันสะกดคีย์ไม่ตรง)
      _vehAllSub = _db!.ref('vehicles').onValue.listen((ev) {
        final val = ev.snapshot.value;
        debugPrint('📡 vehicles => $val');

        if (val is Map) {
          final dynamic bus = val['bus01'] ?? (val.values.isNotEmpty ? val.values.first : null);
          if (bus is Map) {
            final lat = double.tryParse(bus['lat']?.toString() ?? '');
            final lng = double.tryParse(bus['lng']?.toString() ?? '');
            if (lat != null && lng != null) {
              final pos = LatLng(lat, lng);
              _setVehicleMarker(pos);
              setState(() => _vehicleStatus = 'vehicles(any): $lat,$lng');
              _map?.animateCamera(CameraUpdate.newLatLng(pos));
            }
          } else {
            setState(() => _vehicleStatus = 'vehicles: ไม่มี bus01');
          }
        } else if (val == null) {
          setState(() => _vehicleStatus = 'vehicles: ว่าง');
        }
      });
    } catch (e) {
      debugPrint('❌ setup DB failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เชื่อม Realtime DB ไม่ได้: $e')),
      );
      setState(() => _vehicleStatus = 'DB error: $e');
    }
  }

  void _listenVehicle(String vehicleId) {
    final ref = _db!.ref('vehicles/$vehicleId');
    _vehSub = ref.onValue.listen((ev) {
      final val = ev.snapshot.value;
      debugPrint('📡 vehicles/$vehicleId => $val');

      if (val is Map) {
        final lat = double.tryParse(val['lat']?.toString() ?? '');
        final lng = double.tryParse(val['lng']?.toString() ?? '');
        if (lat == null || lng == null) {
          debugPrint('⚠️ lat/lng null หรือ parse ไม่ได้: $val');
          setState(() => _vehicleStatus = '$vehicleId: lat/lng parse ไม่ได้');
          return;
        }
        final pos = LatLng(lat, lng);
        _setVehicleMarker(pos);
        setState(() => _vehicleStatus = '$vehicleId: $lat,$lng');
        _map?.animateCamera(CameraUpdate.newLatLng(pos));
      } else if (val == null) {
        debugPrint('ℹ️ ยังไม่มีค่าที่ /vehicles/$vehicleId');
        setState(() => _vehicleStatus = '$vehicleId: ยังไม่มีข้อมูล');
      } else {
        debugPrint('⚠️ snapshot ไม่ใช่ Map: $val');
        setState(() => _vehicleStatus = '$vehicleId: snapshot ไม่ใช่ Map');
      }
    });
  }

  void _setVehicleMarker(LatLng pos) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'vehicle_bus01')
        ..add(Marker(
          markerId: const MarkerId('vehicle_bus01'),
          position: pos,
          infoWindow: const InfoWindow(title: 'รถ (bus01)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(30),
        ));
    });
  }

  @override
  void dispose() {
    _vehSub?.cancel();
    _vehAllSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ผู้ใช้: ติดตามตำแหน่งรถ')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _init, zoom: 14),
              onMapCreated: (c) => _map = c,
              markers: _markers,
              myLocationEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _vehicleStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
