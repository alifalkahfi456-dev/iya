// ==================== BOKEP_TOOLS.DART ====================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class BokepToolsPage extends StatefulWidget {
  final String sessionKey;
  const BokepToolsPage({super.key, required this.sessionKey});

  @override
  State<BokepToolsPage> createState() => _BokepToolsPageState();
}

class _BokepToolsPageState extends State<BokepToolsPage> with SingleTickerProviderStateMixin {
  // BLUE THEME
  // RED ELEGANT DARK THEME
final Color primaryBlue = const Color(0xFF8B1A1A);
final Color darkBlue = const Color(0xFF5C0A0A);
final Color lightBlue = const Color(0xFFB22222);
final Color accentBlue = const Color(0xFFC62828);
final Color darkBg = const Color(0xFF0D0608);
final Color cardBg = const Color(0xFF1A0A0A);
final Color textWhite = const Color(0xFFF5E6E6);
final Color textGray = const Color(0xFFD0A8A8);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TabController _tabController;

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  String _selectedCategory = "All";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ["ALL", "HOT", "NEW", "TOP", "JAV", "ASIAN", "WESTERN"];

  // VIDEO DATA DARI CATBOX
  final List<String> _videoUrls = [
    "https://files.catbox.moe/8c7gz3.mp4",
    "https://files.catbox.moe/ylcuvj.mp4",
    "https://files.catbox.moe/nk5l10.mp4",
    "https://files.catbox.moe/r3ip1j.mp4",
    "https://files.catbox.moe/71l6bo.mp4",
    "https://files.catbox.moe/rdggsh.mp4",
    "https://files.catbox.moe/3288uf.mp4",
    "https://files.catbox.moe/jdopgq.mp4",
    "https://files.catbox.moe/8ca9cw.mp4",
    "https://files.catbox.moe/b99qh3.mp4",
    "https://files.catbox.moe/6bkokw.mp4",
    "https://files.catbox.moe/ebisdh.mp4",
    "https://files.catbox.moe/3yko44.mp4",
    "https://files.catbox.moe/apqlvo.mp4",
    "https://files.catbox.moe/wqe1r7.mp4",
    "https://files.catbox.moe/n37liq.mp4",
    "https://files.catbox.moe/0728bg.mp4",
    "https://files.catbox.moe/p69jdc.mp4",
    "https://files.catbox.moe/occ3en.mp4",
    "https://files.catbox.moe/y8hmau.mp4",
    "https://files.catbox.moe/tvj95b.mp4",
    "https://files.catbox.moe/3g2djb.mp4",
    "https://files.catbox.moe/xlbafn.mp4",
    "https://files.catbox.moe/br8crz.mp4",
    "https://files.catbox.moe/h2w5jl.mp4",
    "https://files.catbox.moe/8y32qo.mp4",
    "https://files.catbox.moe/9w39ag.mp4",
    "https://files.catbox.moe/gv4087.mp4",
    "https://files.catbox.moe/uw6qbs.mp4",
    "https://files.catbox.moe/a537h1.mp4",
    "https://files.catbox.moe/4x09p9.mp4",
    "https://files.catbox.moe/n992te.mp4",
    "https://files.catbox.moe/ltdsbm.mp4",
    "https://files.catbox.moe/rt62tl.mp4",
    "https://files.catbox.moe/y4rote.mp4",
    "https://files.catbox.moe/dxn5oj.mp4",
    "https://files.catbox.moe/tw6m9q.mp4",
    "https://files.catbox.moe/qfl235.mp4",
    "https://files.catbox.moe/q9f2rs.mp4",
    "https://files.catbox.moe/e5ci9z.mp4",
    "https://files.catbox.moe/cdl11t.mp4",
    "https://files.catbox.moe/pmyi1y.mp4"
  ];

  final List<String> _titles = [
    "Hot Video 1", "Hot Video 2", "Hot Video 3", "Hot Video 4",
    "Hot Video 5", "Hot Video 6", "Hot Video 7", "Hot Video 8",
    "Hot Video 9", "Hot Video 10", "Hot Video 11", "Hot Video 12",
    "Hot Video 13", "Hot Video 14", "Hot Video 15", "Hot Video 16",
    "Hot Video 17", "Hot Video 18", "Hot Video 19", "Hot Video 20",
    "JAV Special 1", "JAV Special 2", "JAV Special 3", "JAV Special 4",
    "Asian Cutie 1", "Asian Cutie 2", "Asian Cutie 3", "Asian Cutie 4",
    "Western Babe 1", "Western Babe 2", "Western Babe 3", "Western Babe 4",
    "New Release 1", "New Release 2", "New Release 3", "New Release 4",
    "Top Rated 1", "Top Rated 2", "Top Rated 3", "Top Rated 4",
    "Exclusive 1", "Exclusive 2", "Exclusive 3"
  ];

  final List<String> _categories = [
    "hot", "hot", "hot", "hot",
    "hot", "hot", "hot", "hot",
    "hot", "hot", "hot", "hot",
    "hot", "hot", "hot", "hot",
    "hot", "hot", "hot", "hot",
    "jav", "jav", "jav", "jav",
    "asian", "asian", "asian", "asian",
    "western", "western", "western", "western",
    "new", "new", "new", "new",
    "top", "top", "top", "top",
    "hot", "hot", "hot"
  ];

  final List<String> _durations = [
    "12:34", "08:22", "15:47", "10:15", "22:08", "09:43", "35:21", "18:56",
    "14:32", "11:45", "07:23", "19:12", "16:54", "13:28", "21:37", "17:43",
    "24:15", "08:56", "12:48", "15:33", "28:14", "19:45", "23:22", "14:56",
    "11:23", "09:12", "18:34", "22:45", "13:56", "16:23", "20:12", "17:34",
    "10:23", "14:12", "19:56", "21:34", "12:45", "15:23", "18:12", "20:45",
    "09:34", "13:12", "16:45"
  ];

  final List<String> _views = [
    "1.2M", "856K", "2.1M", "543K", "3.4M", "678K", "5.2M", "1.8M",
    "2.3M", "945K", "1.1M", "4.2M", "3.8M", "2.5M", "6.1M", "1.9M",
    "4.5M", "567K", "2.9M", "3.2M", "7.1M", "4.8M", "5.5M", "2.2M",
    "1.5M", "789K", "3.6M", "4.1M", "2.7M", "1.3M", "5.8M", "3.3M",
    "2.4M", "1.7M", "4.9M", "6.2M", "3.9M", "2.8M", "5.1M", "4.3M",
    "1.4M", "2.1M", "3.7M"
  ];

  final List<double> _ratings = [
    4.8, 4.5, 4.9, 4.3, 4.7, 4.6, 4.9, 4.8,
    4.4, 4.2, 4.1, 4.9, 4.7, 4.5, 4.8, 4.6,
    4.3, 4.0, 4.4, 4.7, 4.9, 4.8, 4.7, 4.5,
    4.2, 4.1, 4.6, 4.8, 4.4, 4.3, 4.9, 4.7,
    4.5, 4.2, 4.8, 4.9, 4.6, 4.4, 4.7, 4.8,
    4.1, 4.3, 4.5
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _tabs[_tabController.index];
        });
      }
    });
    _loadVideos();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadVideos() {
    _videos = [];
    for (int i = 0; i < _videoUrls.length; i++) {
      _videos.add({
        "id": i.toString(),
        "url": _videoUrls[i],
        "title": _titles[i % _titles.length],
        "category": _categories[i % _categories.length],
        "duration": _durations[i % _durations.length],
        "views": _views[i % _views.length],
        "rating": _ratings[i % _ratings.length],
      });
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredVideos {
    return _videos.where((video) {
      if (_selectedCategory != "ALL" && video['category']?.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return video['title'].toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  Future<void> _playVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackbar("Cannot open video");
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryBlue, accentBlue],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              "BOKEP TOOLS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        backgroundColor: darkBg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: primaryBlue.withOpacity(0.3), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E88E5)),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadVideos();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textWhite),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search videos...",
                hintStyle: TextStyle(color: textGray),
                prefixIcon: Icon(Icons.search, color: primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textGray),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryBlue.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryBlue, width: 1),
                ),
              ),
            ),
          ),

          // TAB BAR
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: primaryBlue.withOpacity(0.3)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: primaryBlue,
              unselectedLabelColor: textGray,
              indicator: BoxDecoration(
                color: primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // VIDEO LIST
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "LOADING VIDEOS...",
                          style: TextStyle(
                            color: textGray,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredVideos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 80, color: textGray.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              "No videos found",
                              style: TextStyle(color: textGray),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredVideos.length,
                        itemBuilder: (context, index) {
                          final video = _filteredVideos[index];
                          return _buildVideoCard(video);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () => _playVideo(video['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBlue.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THUMBNAIL
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [darkBlue, primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 60),
                  ),
                ),
                // DURATION
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      video['duration'] ?? '00:00',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // RATING
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.yellow, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          video['rating'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // INFO
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? 'No Title',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.visibility, color: textGray, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        video['views'] ?? '0',
                        style: TextStyle(color: textGray, fontSize: 11),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.category, color: textGray, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        video['category']?.toUpperCase() ?? 'Unknown',
                        style: TextStyle(color: primaryBlue, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}