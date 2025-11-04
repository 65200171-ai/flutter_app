// lib/screens/driver_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// ตั้ง alias กันชนชื่อคลาส
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_database/firebase_database.dart' as rtdb;

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};

  static const LatLng _initPos = LatLng(10.7230, 99.3745);

  // Firestore: คิวรีผู้โดยสาร
  final fs.Query _q = fs.FirebaseFirestore.instance
      .collection('ride_requests')
      .where('status', isEqualTo: 'open');

  // RTDB: รถ
  rtdb.FirebaseDatabase? _db;
  StreamSubscription<rtdb.DatabaseEvent>? _vehSub;
  static const _vehicleId = 'bus01';
  static const _dbUrl =
      'https://ride-app-2b814-default-rtdb.asia-southeast1.firebasedatabase.app';

  // สถานะติดตามรถ + เก็บตำแหน่งล่าสุด
  bool _followCar = false;
  LatLng? _vehiclePos;

  // ---------- เพิ่มเพื่อให้ follow กล้องลื่น ----------
  bool _mapReady = false;
  DateTime _lastCamMove = DateTime.fromMillisecondsSinceEpoch(0);
  // -----------------------------------------------------

  @override
  void initState() {
    super.initState();
    _setupVehicleListener();
  }

  Future<void> _setupVehicleListener() async {
    try {
      await Firebase.initializeApp();
      _db = rtdb.FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      );

      _vehSub = _db!.ref('vehicles/$_vehicleId').onValue.listen((ev) {
        final val = ev.snapshot.value;
        if (val is Map) {
          final lat = double.tryParse(val['lat']?.toString() ?? '');
          final lng = double.tryParse(val['lng']?.toString() ?? '');
          if (lat != null && lng != null) {
            final pos = LatLng(lat, lng);
            _vehiclePos = pos;
            _setVehicleMarker(pos);
            _maybeFollow(); // ✅ ใช้ตัวช่วยแทน animateCamera ตรง ๆ
          }
        }
      });
    } catch (e) {
      debugPrint('RTDB setup error: $e');
    }
  }

  void _setVehicleMarker(LatLng pos) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'vehicle_$_vehicleId')
        ..add(Marker(
          markerId: MarkerId('vehicle_$_vehicleId'),
          position: pos,
          infoWindow: const InfoWindow(title: 'รถ (bus01)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
    });
  }

  double _hueFromId(String id) {
    int h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 360).toDouble();
  }

  LatLng _jitterIfCollision(LatLng base, int index) {
    if (index == 0) return base;
    final rMeters = 2.0 + (index % 3);
    final angle = (index * 137.0) * pi / 180;
    final dLat = (rMeters / 111320.0) * sin(angle);
    final dLng =
        (rMeters / (111320.0 * cos(base.latitude * pi / 180))) * cos(angle);
    return LatLng(base.latitude + dLat, base.longitude + dLng);
  }

  @override
  void dispose() {
    _vehSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่ไหม?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ออกจากระบบแล้ว')),
      );
    }
  }

  void _recenterToVehicle() {
    if (_vehiclePos != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_vehiclePos!, 14));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีตำแหน่งรถ')),
      );
    }
  }

  // ---------- ฟังก์ชันช่วยเลื่อนกล้องแบบเนียน ----------
  void _maybeFollow() {
    if (!_mapReady || !_followCar || _vehiclePos == null) return;

    // กันสั่น: ถ้าเพิ่งขยับกล้องภายใน 300ms ให้ข้าม
    if (DateTime.now().difference(_lastCamMove).inMilliseconds < 300) return;

    _lastCamMove = DateTime.now();
    _map?.animateCamera(CameraUpdate.newLatLng(_vehiclePos!));
  }
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คนขับ: รถ + ผู้โดยสาร'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'ตัวเลือก',
            onSelected: (value) async {
              if (value == 'toggle_follow') {
                setState(() => _followCar = !_followCar);
                if (_followCar) _maybeFollow(); // เปิดล็อกแล้วเลื่อนกล้องทันทีถ้ามีพิกัด
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_followCar ? 'ล็อกกล้องติดรถ: เปิด' : 'ล็อกกล้องติดรถ: ปิด')),
                );
              } else if (value == 'logout') {
                await _confirmLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle_follow',
                child: Row(
                  children: [
                    Icon(
                      _followCar ? Icons.location_searching : Icons.location_disabled,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(_followCar ? 'ล็อกกล้องติดรถ: เปิด' : 'ล็อกกล้องติดรถ: ปิด'),
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

      body: Stack(
        children: [
          // แผนที่ + รายชื่อผู้โดยสาร
          StreamBuilder<fs.QuerySnapshot>(
            stream: _q.snapshots(),
            builder: (context, snap) {
              final riderMarkers = <Marker>{};
              final tiles = <_UserPoint>[];

              double camLat = _initPos.latitude, camLng = _initPos.longitude;

              if (snap.hasData) {
                final groups = <String, List<_UserPoint>>{};
                for (final doc in snap.data!.docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final lat = (d['lat'] as num?)?.toDouble();
                  final lng = (d['lng'] as num?)?.toDouble();
                  if (lat == null || lng == null) continue;

                  final id = (d['userId'] as String?) ?? doc.id;
                  final key = '${lat.toStringAsFixed(6)}|${lng.toStringAsFixed(6)}';
                  groups.putIfAbsent(key, () => []).add(
                    _UserPoint(
                      id: id,
                      lat: lat,
                      lng: lng,
                      updatedAt: (d['updated_at'] is fs.Timestamp)
                          ? (d['updated_at'] as fs.Timestamp).toDate()
                          : null,
                    ),
                  );
                }

                groups.forEach((_, list) {
                  for (int i = 0; i < list.length; i++) {
                    final p = list[i];
                    final pos = _jitterIfCollision(LatLng(p.lat, p.lng), i);
                    final hue = _hueFromId(p.id);
                    riderMarkers.add(Marker(
                      markerId: MarkerId('rider_${p.id}_$i'),
                      position: pos,
                      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                      infoWindow: InfoWindow(
                        title: 'User ${p.id.substring(0, 6)}',
                        snippet: p.updatedAt != null ? 'อัปเดต: ${p.updatedAt}' : 'กำลังส่ง...',
                      ),
                    ));
                    tiles.add(_UserPoint(
                      id: p.id,
                      lat: pos.latitude,
                      lng: pos.longitude,
                      updatedAt: p.updatedAt,
                    ));
                    camLat = pos.latitude;
                    camLng = pos.longitude;
                  }
                });

                if (!_followCar && tiles.isNotEmpty && _map != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _map?.animateCamera(
                      CameraUpdate.newLatLngZoom(LatLng(camLat, camLng), 12.5),
                    );
                  });
                }
              }

              _markers
                ..removeWhere((m) => m.markerId.value.startsWith('rider_'))
                ..addAll(riderMarkers);

              return Column(
                children: [
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition:
                      const CameraPosition(target: _initPos, zoom: 12),
                      onMapCreated: (c) {
                        _map = c;
                        _mapReady = true;
                        _maybeFollow(); // ✅ ถ้ามีตำแหน่งรถแล้วและเปิด follow อยู่ ให้เลื่อนทันที
                      },
                      markers: _markers,
                      myLocationEnabled: false,
                    ),
                  ),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: tiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final u = tiles[i];
                        return GestureDetector(
                          onTap: () {
                            _map?.animateCamera(
                              CameraUpdate.newLatLngZoom(LatLng(u.lat, u.lng), 16),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('User ${u.id.substring(0, 6)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${u.lat.toStringAsFixed(5)}, ${u.lng.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // ✅ ปุ่ม “หาพิกัดรถ” ใต้ปุ่ม ⋮
          Positioned(
            right: 12,
            top: kToolbarHeight + 6,
            child: SafeArea(
              child: Material(
                color: const Color(0xFFEAEAFF),
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'เลื่อนไปยังตำแหน่งรถ',
                  onPressed: _recenterToVehicle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPoint {
  final String id;
  final double lat, lng;
  final DateTime? updatedAt;
  _UserPoint({required this.id, required this.lat, required this.lng, this.updatedAt});
}
