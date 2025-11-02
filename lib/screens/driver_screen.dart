import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  GoogleMapController? _map;

  // 🔹 Firestore: ผู้ใช้ที่กดเรียกรถ
  final _q = FirebaseFirestore.instance
      .collection('ride_requests')
      .where('status', isEqualTo: 'open');

  // 🔹 Realtime DB: ตำแหน่งรถจาก ESP32 (แก้ URL ให้ตรงโปรเจ็กต์ของเจี๊ยบ)
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://ride-app-2b814-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  StreamSubscription<DatabaseEvent>? _vehSub;
  LatLng? _vehiclePos; // เก็บตำแหน่งรถล่าสุด

  // จุดเริ่มซูม: KMITL Prince of Chumphon Campus
  static const _init = LatLng(10.7230, 99.3745);

  @override
  void initState() {
    super.initState();
    _listenVehicle('bus01'); // ถ้ารถหลายคัน เรียกซ้ำ/ทำเป็นลิสต์ได้
  }

  void _listenVehicle(String vehicleId) {
    _vehSub = _db.ref('vehicles/$vehicleId').onValue.listen((ev) {
      final v = ev.snapshot.value;
      if (v is Map) {
        final lat = double.tryParse(v['lat'].toString());
        final lng = double.tryParse(v['lng'].toString());
        if (lat != null && lng != null) {
          setState(() {
            _vehiclePos = LatLng(lat, lng);
          });
          // จะให้กล้องตามรถทุกครั้งก็ได้ หรือคอมเมนต์บรรทัดนี้ถ้าไม่อยากตามตลอด
          _map?.animateCamera(CameraUpdate.newLatLng(_vehiclePos!));
        }
      }
    });
  }

  // แปลง userId เป็นสี (hue) ให้หมุดแต่ละคนต่างกัน
  double _hueFromId(String id) {
    int h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 360).toDouble();
  }

  // ถ้าพิกัดซ้ำ ให้ขยับเล็กน้อยกันทับ (≈1–3 เมตร)
  LatLng _jitterIfCollision(LatLng base, int index) {
    if (index == 0) return base;
    final rMeters = 2.0 + (index % 3);          // 2..4 m
    final angle = (index * 137.0) * pi / 180;   // golden-angle scatter
    // แปลงเมตร -> องศาโดยประมาณ
    final dLat = (rMeters / 111320.0) * sin(angle);
    final dLng = (rMeters / (111320.0 * cos(base.latitude * pi / 180))) * cos(angle);
    return LatLng(base.latitude + dLat, base.longitude + dLng);
  }

  @override
  void dispose() {
    _vehSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คนขับ: ผู้ใช้ + ตำแหน่งรถ (Realtime)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _q.snapshots(),
        builder: (context, snap) {
          final markers = <Marker>{};
          final list = <_UserPoint>[];

          // 1) วาดผู้ใช้จาก Firestore
          if (snap.hasData) {
            final byCoord = <String, List<_UserPoint>>{};
            for (final doc in snap.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;
              final a = (d['lat'] as num?)?.toDouble();
              final b = (d['lng'] as num?)?.toDouble();
              final id = (d['userId'] as String?) ?? doc.id;
              if (a == null || b == null) continue;

              final key = '${a.toStringAsFixed(6)}|${b.toStringAsFixed(6)}';
              final up = _UserPoint(
                id: id,
                lat: a,
                lng: b,
                updatedAt: (d['updated_at'] as Timestamp?)?.toDate(),
              );
              byCoord.putIfAbsent(key, () => []).add(up);
            }

            byCoord.forEach((_, group) {
              for (int i = 0; i < group.length; i++) {
                final p = group[i];
                final pos = _jitterIfCollision(LatLng(p.lat, p.lng), i);
                final hue = _hueFromId(p.id);

                markers.add(Marker(
                  markerId: MarkerId('user_${p.id}'),
                  position: pos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                  infoWindow: InfoWindow(
                    title: 'User ${p.id.substring(0, 6)}',
                    snippet: p.updatedAt != null
                        ? 'อัปเดต: ${p.updatedAt}'
                        : 'กำลังส่ง...',
                  ),
                ));
                list.add(_UserPoint(
                  id: p.id,
                  lat: pos.latitude,
                  lng: pos.longitude,
                  updatedAt: p.updatedAt,
                ));
              }
            });
          }

          // 2) วาดรถจาก Realtime Database (ถ้ามีแล้ว)
          if (_vehiclePos != null) {
            markers.add(Marker(
              markerId: const MarkerId('vehicle_bus01'),
              position: _vehiclePos!,
              icon: BitmapDescriptor.defaultMarkerWithHue(30), // โทนส้ม-น้ำตาล
              infoWindow: const InfoWindow(title: 'รถ (bus01)'),
            ));
          }

          // 3) กล้องเริ่มต้น
          final initialTarget = _vehiclePos ?? _init;

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
                  onMapCreated: (c) => _map = c,
                  myLocationEnabled: false,
                  markers: markers,
                ),
              ),
              // แถบรายชื่อด้านล่าง: แตะเพื่อกระโดดไปยังหมุดผู้ใช้
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final u = list[i];
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
    );
  }
}

class _UserPoint {
  final String id;
  final double lat, lng;
  final DateTime? updatedAt;
  _UserPoint({required this.id, required this.lat, required this.lng, this.updatedAt});
}
