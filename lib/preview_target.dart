//JANGAN LU MALING
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class SpotifyPage extends StatefulWidget {
  const SpotifyPage({super.key});

  @override
  State<SpotifyPage> createState() => _SpotifyPageState();
}

class _SpotifyPageState extends State<SpotifyPage> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasSearchResult = false;
  Map<String, dynamic>? _trackData;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _searchTrack() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearchResult = false;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deline.web.id/downloader/spotifyplay?q=${_searchController.text}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            _trackData = data;
            _hasSearchResult = true;
          });
          _playTrack();
        } else {
          _showError('Track tidak ditemukan');
        }
      } else {
        _showError('Gagal menghubungi server');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack() async {
    if (_trackData != null && _trackData!['result'] != null) {
      final url = _trackData!['result']['dlink'];
      await _audioPlayer.play(UrlSource(url));
    }
  }

  Future<void> _pauseTrack() async {
    await _audioPlayer.pause();
  }

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      return timeStr;
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Color(0xFF0A0A0A),
        title: const Text(
          'Spotify Play',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari lagu...',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _searchTrack(),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFDC143C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.search, color: Colors.white),
                    onPressed: _isLoading ? null : _searchTrack,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            if (_hasSearchResult && _trackData != null && _trackData!['result'] != null && _trackData!['result']['metadata'] != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _trackData!['result']['metadata']['cover'],
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 200,
                                  height: 200,
                                  color: Color(0xFF2A2A2A),
                                  child: Icon(Icons.music_note, color: Colors.grey, size: 60),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _trackData!['result']['metadata']['title'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              _trackData!['result']['metadata']['artist'],
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule, color: Colors.grey.shade400, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  _formatTimeString(_trackData!['result']['metadata']['duration']),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Slider(
                              value: _position.inSeconds.toDouble(),
                              min: 0,
                              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                              onChanged: (value) async {
                                await _audioPlayer.seek(Duration(seconds: value.toInt()));
                              },
                              activeColor: Color(0xFFDC143C),
                              inactiveColor: Colors.grey.shade700,
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.stop, color: Colors.white, size: 30),
                                  onPressed: _stopTrack,
                                ),
                                SizedBox(width: 20),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFDC143C),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    onPressed: _isPlaying ? _pauseTrack : _playTrack,
                                  ),
                                ),
                                SizedBox(width: 20),
                                IconButton(
                                  icon: Icon(Icons.replay, color: Colors.white, size: 30),
                                  onPressed: () {
                                    setState(() {
                                      _position = Duration.zero;
                                    });
                                    _audioPlayer.seek(Duration.zero);
                                    if (!_isPlaying) {
                                      _playTrack();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFDC143C),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mencari lagu...',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        color: Colors.grey.shade600,
                        size: 80,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Cari lagu favoritmu',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Masukkan judul lagu atau nama artis',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}