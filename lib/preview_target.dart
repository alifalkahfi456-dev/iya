import 'package:flutter/material.dart';
import 'dart:convert';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int totalUser = 1250;
  int userAktif = 850;
  int memberVip = 150;
  double statusServer = 99;

  List<Aktivitas> aktivitasTerbaru = [
    Aktivitas(user: 'Diky', aktivitas: 'Login', waktu: '10:00'),
    Aktivitas(user: 'Andi', aktivitas: 'Redeem Code', waktu: '10:05'),
    Aktivitas(user: 'Budi', aktivitas: 'Upgrade VIP', waktu: '10:10'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.blueGrey,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '🚀 DIKY PANEL',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('🏠 Dashboard'),
                          onTap: () {},
                        ),
                        ListTile(
                          title: Text('👤 Pengguna'),
                          onTap: () {},
                        ),
                        ListTile(
                          title: Text('🤖 Bot'),
                          onTap: () {},
                        ),
                        ListTile(
                          title: Text('📊 Statistik'),
                          onTap: () {},
                        ),
                        ListTile(
                          title: Text('⚙ Pengaturan'),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    child: Row(
                      children: [
                        Text(
                          'Selamat Datang, Admin',
                          style: TextStyle(fontSize: 24),
                        ),
                        SizedBox(width: 20),
                        Text(
                          'Dashboard Bot Telegram',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    child: Row(
                      children: [
                        Card(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            width: 150,
                            child: Column(
                              children: [
                                Text(
                                  totalUser.toString(),
                                  style: TextStyle(fontSize: 24),
                                ),
                                Text('Total User'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Card(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            width: 150,
                            child: Column(
                              children: [
                                Text(
                                  userAktif.toString(),
                                  style: TextStyle(fontSize: 24),
                                ),
                                Text('User Aktif'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Card(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            width: 150,
                            child: Column(
                              children: [
                                Text(
                                  memberVip.toString(),
                                  style: TextStyle(fontSize: 24),
                                ),
                                Text('Member VIP'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Card(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            width: 150,
                            child: Column(
                              children: [
                                Text(
                                  statusServer.toString() + '%',
                                  style: TextStyle(fontSize: 24),
                                ),
                                Text('Status Server'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    child: Column(
                      children: [
                        Text(
                          'Aktivitas Terbaru',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 10),
                        DataTable(
                          columns: [
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Aktivitas')),
                            DataColumn(label: Text('Waktu')),
                          ],
                          rows: aktivitasTerbaru
                              .map((aktivitas) => DataRow(cells: [
                                    DataCell(Text(aktivitas.user)),
                                    DataCell(Text(aktivitas.aktivitas)),
                                    DataCell(Text(aktivitas.waktu)),
                                  ]))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Aktivitas {
  String user;
  String aktivitas;
  String waktu;

  Aktivitas({required this.user, required this.aktivitas, required this.waktu});
}