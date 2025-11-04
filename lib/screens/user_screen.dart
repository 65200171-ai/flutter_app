// lib/screens/user_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

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

  // Firestore: ฟังคำขอเรียกรถจากผู้ใช้ทั้งหมด
  StreamSubscription<QuerySnapshot>? _reqSub;

  FirebaseDatabase? _db;
  static const LatLng _init = LatLng(10.7230, 99.3745); // KMITL PCC
  String _vehicleStatus = 'รถ: รอข้อมูล...';

  // เอกสารคำขอของฉัน (ไว้ยกเลิก)
  bool _requesting = false;
  String? _reqDocId;

  // ⚙️ สถานะ “ล็อกกล้องติดรถ”
  bool _followVehicle = true;

  // ------- เพิ่มสำหรับการ follow กล้องให้เนียน -------
  LatLng? _lastVehiclePos;
  bool _mapReady = false;
  DateTime _lastCamMove = DateTime.fromMillisecondsSinceEpoch(0);
  // ------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _setupAndListen();
  }

  Future<void> _setupAndListen() async {
    try {
      await Firebase.initializeApp();

      // 🔹 ล้างคำขอค้างของ "ฉัน" ก่อน (กันหมุดค้างจากรอบก่อน ๆ)
      await _cleanupMyOpenRequests();

      // ====== Realtime DB: ตำแหน่งรถ ======
      const dbUrl =
          'https://ride-app-2b814-default-rtdb.asia-southeast1.firebasedatabase.app';
      _db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: dbUrl);

      final snap = await _db!.ref('vehicles/bus01').get();
      setState(() => _vehicleStatus = 'ONE-SHOT: ${snap.value}');

      _listenVehicle('bus01');

      _vehAllSub = _db!.ref('vehicles').onValue.listen((ev) {
        final val = ev.snapshot.value;
        if (val is Map) {
          final dynamic bus =
              val['bus01'] ?? (val.values.isNotEmpty ? val.values.first : null);
          if (bus is Map) {
            final lat = double.tryParse(bus['lat']?.toString() ?? '');
            final lng = double.tryParse(bus['lng']?.toString() ?? '');
            if (lat != null && lng != null) {
              final pos = LatLng(lat, lng);
              _setVehicleMarker(pos);
              setState(() => _vehicleStatus = 'vehicles(any): $lat,$lng');
              // ✅ อัปเดตตำแหน่งล่าสุดแล้วค่อยพยายามเลื่อนกล้อง
              _lastVehiclePos = pos;
              _maybeFollow();
            }
          } else {
            setState(() => _vehicleStatus = 'vehicles: ไม่มี bus01');
          }
        } else if (val == null) {
          setState(() => _vehicleStatus = 'vehicles: ว่าง');
        }
      });

      // ====== Firestore: ตำแหน่งผู้โดยสารทั้งหมด ======
      _listenAllRideRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เชื่อมต่อฐานข้อมูลไม่สำเร็จ: $e')),
      );
      setState(() => _vehicleStatus = 'DB error: $e');
    }
  }

  void _listenVehicle(String vehicleId) {
    final ref = _db!.ref('vehicles/$vehicleId');
    _vehSub = ref.onValue.listen((ev) {
      final val = ev.snapshot.value;
      if (val is Map) {
        final lat = double.tryParse(val['lat']?.toString() ?? '');
        final lng = double.tryParse(val['lng']?.toString() ?? '');
        if (lat == null || lng == null) {
          setState(() => _vehicleStatus = '$vehicleId: lat/lng ไม่ถูกต้อง');
          return;
        }
        final pos = LatLng(lat, lng);
        _setVehicleMarker(pos);
        setState(() => _vehicleStatus = '$vehicleId: $lat,$lng');

        // ✅ เก็บตำแหน่งล่าสุดแล้วใช้ _maybeFollow() แทน animateCamera ตรง ๆ
        _lastVehiclePos = pos;
        _maybeFollow();
      } else if (val == null) {
        setState(() => _vehicleStatus = '$vehicleId: ยังไม่มีข้อมูล');
      } else {
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

  // ====== Firestore: ฟังคำขอจากผู้โดยสารทุกคน ======
  void _listenAllRideRequests() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _reqSub = FirebaseFirestore.instance
        .collection('ride_requests')
        .where('status', whereIn: ['open', 'accepted'])
        .snapshots()
        .listen((qs) {
      final newMarkers = <Marker>{};

      for (final doc in qs.docs) {
        final d = doc.data();
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final isMe = (d['userId'] == uid);
        final markerId = 'req_${doc.id}';
        final hue = isMe
            ? BitmapDescriptor.hueViolet // ของฉัน = สีม่วง
            : BitmapDescriptor.hueOrange; // คนอื่น = สีส้ม

        newMarkers.add(Marker(
          markerId: MarkerId(markerId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: isMe ? 'ตำแหน่งฉัน (คำขอ)' : 'ผู้โดยสาร',
            snippet: (d['status'] as String?) ?? 'open',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ));
      }

      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('req_'));
        _markers.addAll(newMarkers);
      });
    });
  }

  // ====== 🧹 ล้างคำขอค้างของฉัน (เปิดแอปแล้วเก็บกวาด) ======
  Future<void> _cleanupMyOpenRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    final qs = await FirebaseFirestore.instance
        .collection('ride_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['open', 'accepted'])
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in qs.docs) {
      final data = doc.data();
      final ts = (data['updated_at'] ?? data['created_at']);
      DateTime? updated;
      if (ts is Timestamp) updated = ts.toDate();

      // ถ้าไม่มี timestamp เลย ให้ถือว่าค้าง และลบทิ้ง
      if (updated == null || updated.isBefore(tenMinutesAgo)) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  // ====== เรียกรถ / ยกเลิกคำขอ ======
  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('โปรดเปิด Location Service')));
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ต้องอนุญาตตำแหน่งเพื่อเรียกรถ')));
      return false;
    }
    return true;
  }

  Future<void> _callRide() async {
    if (_requesting) return;
    if (!await _ensureLocationPermission()) return;

    try {
      // ล้างของค้างของฉันก่อน กันหมุดซ้ำ
      await _cleanupMyOpenRequests();

      final pos = await Geolocator.getCurrentPosition();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('ride_requests').add({
        'userId': user.uid,
        'email': user.email,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _requesting = true;
        _reqDocId = doc.id;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ส่งคำขอเรียกรถแล้ว')));

      _map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เรียกรถไม่สำเร็จ: $e')));
    }
  }

  Future<void> _cancelRide() async {
    if (!_requesting || _reqDocId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(_reqDocId)
          .delete();
      setState(() {
        _requesting = false;
        _reqDocId = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ยกเลิกคำขอเรียบร้อย')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')));
    }
  }

  Future<void> _confirmAndLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok == true) {
      await _vehSub?.cancel();
      await _vehAllSub?.cancel();
      await _reqSub?.cancel();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ออกจากระบบแล้ว')),
      );
    }
  }

  // ---------- สำคัญ: ฟังก์ชันช่วยเลื่อนกล้องแบบเนียน ----------
  void _maybeFollow() {
    if (!_mapReady || !_followVehicle || _lastVehiclePos == null) return;

    // กันสั่น: ถ้าเพิ่งขยับกล้องภายใน 300ms ให้ข้าม
    if (DateTime.now().difference(_lastCamMove).inMilliseconds < 300) return;

    _lastCamMove = DateTime.now();
    _map?.animateCamera(CameraUpdate.newLatLng(_lastVehiclePos!));
  }
  // --------------------------------------------------------------

  @override
  void dispose() {
    _vehSub?.cancel();
    _vehAllSub?.cancel();
    _reqSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = _requesting
        ? FloatingActionButton.extended(
      onPressed: _cancelRide,
      icon: const Icon(Icons.close),
      label: const Text('ยกเลิกคำขอ'),
      backgroundColor: Colors.red,
    )
        : FloatingActionButton.extended(
      onPressed: _callRide,
      icon: const Icon(Icons.local_taxi),
      label: const Text('เรียกรถ'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ใช้: ติดตามตำแหน่งรถ'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'ตัวเลือก',
            onSelected: (value) async {
              if (value == 'toggle_follow') {
                setState(() => _followVehicle = !_followVehicle);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _followVehicle ? 'ล็อกกล้องติดรถ: เปิด' : 'ล็อกกล้องติดรถ: ปิด',
                    ),
                  ),
                );
                if (_followVehicle) _maybeFollow(); // เปิดล็อกแล้ว เลื่อนกล้องให้ทันที
              } else if (value == 'logout') {
                await _confirmAndLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle_follow',
                child: Row(
                  children: [
                    Icon(
                      _followVehicle ? Icons.location_searching : Icons.location_disabled,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(_followVehicle ? 'ล็อกกล้องติดรถ: เปิด' : 'ล็อกกล้องติดรถ: ปิด'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ออกจากระบบ'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _init, zoom: 14),
              onMapCreated: (c) {
                _map = c;
                _mapReady = true;
                _maybeFollow(); // ถ้ามีตำแหน่งแล้วและเปิดล็อกไว้ จะเลื่อนให้ทันที
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
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
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
