import 'package:flutter/material.dart';

class ColorPickerTools extends StatefulWidget {
  const ColorPickerTools({super.key});

  @override
  State<ColorPickerTools> createState() => _ColorPickerToolsState();
}

class _ColorPickerToolsState extends State<ColorPickerTools> {
  Color _selectedColor = Colors.purple;
  String _hexColor = "#9C27B0";

  final Color bgDark = const Color(0xFF1A0B2E);
  final Color surfaceColor = const Color(0xFF2D1B4E);
  final Color cardColor = const Color(0xFF3D2A5E);
  final Color lightPurple = const Color(0xFFCE93D8);

  void _pickColor() async {
    final Color? picked = await showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: _selectedColor,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedColor = picked;
        _hexColor = '#${picked.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      });
    }
  }

  String _getColorName(Color color) {
    const colors = {
      Colors.red: 'Merah',
      Colors.pink: 'Pink',
      Colors.purple: 'Ungu',
      Colors.deepPurple: 'Ungu Tua',
      Colors.indigo: 'Nila',
      Colors.blue: 'Biru',
      Colors.lightBlue: 'Biru Muda',
      Colors.cyan: 'Cyan',
      Colors.teal: 'Teal',
      Colors.green: 'Hijau',
      Colors.lightGreen: 'Hijau Muda',
      Colors.lime: 'Lime',
      Colors.yellow: 'Kuning',
      Colors.amber: 'Amber',
      Colors.orange: 'Oranye',
      Colors.deepOrange: 'Oranye Tua',
      Colors.brown: 'Coklat',
      Colors.grey: 'Abu-abu',
      Colors.blueGrey: 'Abu-abu Biru',
    };
    return colors[color] ?? 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text(
          "Color Picker",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Preview Color
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getColorName(_selectedColor),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hexColor,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lightPurple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hex Code",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        _hexColor,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickColor,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Pilih",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Color List
            Expanded(
              child: GridView.count(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _colorTile(Colors.red),
                  _colorTile(Colors.pink),
                  _colorTile(Colors.purple),
                  _colorTile(Colors.deepPurple),
                  _colorTile(Colors.indigo),
                  _colorTile(Colors.blue),
                  _colorTile(Colors.lightBlue),
                  _colorTile(Colors.cyan),
                  _colorTile(Colors.teal),
                  _colorTile(Colors.green),
                  _colorTile(Colors.lightGreen),
                  _colorTile(Colors.lime),
                  _colorTile(Colors.yellow),
                  _colorTile(Colors.amber),
                  _colorTile(Colors.orange),
                  _colorTile(Colors.deepOrange),
                  _colorTile(Colors.brown),
                  _colorTile(Colors.grey),
                  _colorTile(Colors.blueGrey),
                  _colorTile(Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorTile(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _hexColor = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D1B4E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFCE93D8).withOpacity(0.2)),
      ),
      title: const Text(
        "Pilih Warna",
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          ColorPicker(
            color: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text("Pilih", style: TextStyle(color: Color(0xFFCE93D8))),
        ),
      ],
    );
  }
}

class ColorPicker extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({super.key, required this.color, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hue Slider
        _buildSlider(
          value: color.hue,
          onChanged: (v) {
            onColorChanged(HSLColor.fromAHSL(color.a, v, color.saturation, color.lightness).toColor());
          },
          colors: const [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.magenta,
            Colors.red,
          ],
        ),
        const SizedBox(height: 12),
        // Saturation Slider
        _buildSlider(
          value: color.saturation,
          onChanged: (v) {
            onColorChanged(HSLColor.fromAHSL(color.a, color.hue, v, color.lightness).toColor());
          },
          colors: [
            HSLColor.fromAHSL(1, color.hue, 0, color.lightness).toColor(),
            HSLColor.fromAHSL(1, color.hue, 1, color.lightness).toColor(),
          ],
        ),
        const SizedBox(height: 12),
        // Lightness Slider
        _buildSlider(
          value: color.lightness,
          onChanged: (v) {
            onColorChanged(HSLColor.fromAHSL(color.a, color.hue, color.saturation, v).toColor());
          },
          colors: [
            Colors.black,
            HSLColor.fromAHSL(1, color.hue, color.saturation, 0.5).toColor(),
            Colors.white,
          ],
        ),
      ],
    );
  }

  Widget _buildSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required List<Color> colors,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0,
            max: 1,
            activeColor: const Color(0xFFCE93D8),
            inactiveColor: Colors.white24,
          ),
        ),
      ],
    );
  }
}

extension ColorExtension on Color {
  double get hue => HSLColor.fromColor(this).hue;
  double get saturation => HSLColor.fromColor(this).saturation;
  double get lightness => HSLColor.fromColor(this).lightness;
}