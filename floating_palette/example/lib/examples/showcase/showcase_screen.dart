import 'package:flutter/material.dart';

import '../../palette_setup.dart';

/// Comprehensive showcase screen for testing all floating_palette features.
///
/// Tests:
/// - Lifecycle: create, show, hide, destroy
/// - Positioning: absolute, anchors, nearCursor
/// - Sizing: explicit size, content-driven (native resize)
/// - Animations: shake, pulse, bounce
/// - Behavior: draggable, hideOnClickOutside, hideOnEscape
/// - Appearance: cornerRadius, shadow, transparency
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final _logs = <String>[];
  bool _isCreated = false;
  bool _isVisible = false;

  // Runtime config
  bool _draggable = true;
  bool _hideOnClickOutside = true;
  bool _hideOnEscape = true;
  double _cornerRadius = 12;
  double _shadowBlur = 20;
  double _opacity = 1.0;

  void _log(String msg) {
    setState(() {
      _logs.insert(
        0,
        '[${DateTime.now().toString().split('.').first.split(' ').last}] $msg',
      );
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Showcase'),
        backgroundColor: Colors.indigo.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _logs.clear()),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Row(
        children: [
          // Control panel
          SizedBox(
            width: 360,
            child: _ControlPanel(
              isCreated: _isCreated,
              isVisible: _isVisible,
              draggable: _draggable,
              hideOnClickOutside: _hideOnClickOutside,
              hideOnEscape: _hideOnEscape,
              cornerRadius: _cornerRadius,
              shadowBlur: _shadowBlur,
              opacity: _opacity,
              onDraggableChanged: (v) => setState(() => _draggable = v),
              onHideOnClickOutsideChanged: (v) =>
                  setState(() => _hideOnClickOutside = v),
              onHideOnEscapeChanged: (v) => setState(() => _hideOnEscape = v),
              onCornerRadiusChanged: (v) => setState(() => _cornerRadius = v),
              onShadowBlurChanged: (v) => setState(() => _shadowBlur = v),
              onOpacityChanged: (v) => setState(() => _opacity = v),
              onLog: _log,
              onStateChange: (created, visible) {
                setState(() {
                  _isCreated = created;
                  _isVisible = visible;
                });
              },
            ),
          ),
          // Log panel
          Expanded(
            child: Container(
              color: Colors.grey.shade900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade800,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.terminal,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Event Log',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _StatusChip(label: 'Created', active: _isCreated),
                        const SizedBox(width: 8),
                        _StatusChip(label: 'Visible', active: _isVisible),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          _logs[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _logs[i].contains('ERROR')
                                ? Colors.red.shade300
                                : _logs[i].contains('OK')
                                ? Colors.green.shade300
                                : _logs[i].startsWith('[')
                                ? Colors.white70
                                : Colors.cyan.shade300,
                          ),
                        ),
                      ),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade700 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ControlPanel extends StatefulWidget {
  final bool isCreated;
  final bool isVisible;
  final bool draggable;
  final bool hideOnClickOutside;
  final bool hideOnEscape;
  final double cornerRadius;
  final double shadowBlur;
  final double opacity;
  final ValueChanged<bool> onDraggableChanged;
  final ValueChanged<bool> onHideOnClickOutsideChanged;
  final ValueChanged<bool> onHideOnEscapeChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final ValueChanged<double> onShadowBlurChanged;
  final ValueChanged<double> onOpacityChanged;
  final void Function(String) onLog;
  final void Function(bool created, bool visible) onStateChange;

  const _ControlPanel({
    required this.isCreated,
    required this.isVisible,
    required this.draggable,
    required this.hideOnClickOutside,
    required this.hideOnEscape,
    required this.cornerRadius,
    required this.shadowBlur,
    required this.opacity,
    required this.onDraggableChanged,
    required this.onHideOnClickOutsideChanged,
    required this.onHideOnEscapeChanged,
    required this.onCornerRadiusChanged,
    required this.onShadowBlurChanged,
    required this.onOpacityChanged,
    required this.onLog,
    required this.onStateChange,
  });

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  double _x = 200;
  double _y = 200;
  double _width = 300;
  double _height = 200;

  Future<void> _run(String name, Future<void> Function() action) async {
    widget.onLog('$name...');
    try {
      await action();
      widget.onLog('$name OK');
    } catch (e) {
      widget.onLog('$name ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ═══════════════════════════════════════════════════════════════
          // LIFECYCLE
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Lifecycle',
            icon: Icons.play_circle_outline,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    label: 'Create',
                    icon: Icons.add_circle_outline,
                    onPressed: () => _run('warmUp', () async {
                      await Palettes.demo.warmUp();
                      widget.onStateChange(true, widget.isVisible);
                    }),
                  ),
                  _ActionButton(
                    label: 'Show',
                    icon: Icons.visibility,
                    onPressed: () => _run('show', () async {
                      await Palettes.demo.show();
                      widget.onStateChange(true, true);
                    }),
                  ),
                  _ActionButton(
                    label: 'Hide',
                    icon: Icons.visibility_off,
                    onPressed: () => _run('hide', () async {
                      await Palettes.demo.hide();
                      widget.onStateChange(widget.isCreated, false);
                    }),
                  ),
                  _ActionButton(
                    label: 'Destroy',
                    icon: Icons.remove_circle_outline,
                    color: Colors.red,
                    onPressed: () => _run('coolDown', () async {
                      await Palettes.demo.coolDown();
                      widget.onStateChange(false, false);
                    }),
                  ),
                ],
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // BEHAVIOR (Runtime Config)
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Behavior',
            icon: Icons.tune,
            children: [
              _SwitchRow(
                label: 'Draggable',
                subtitle: 'User can drag the palette',
                value: widget.draggable,
                onChanged: (v) {
                  widget.onDraggableChanged(v);
                  widget.onLog('draggable = $v');
                  _run('setDraggable($v)', () => Palettes.demo.setDraggable(v));
                },
              ),
              _SwitchRow(
                label: 'Hide on Click Outside',
                subtitle: 'Dismiss when clicking outside',
                value: widget.hideOnClickOutside,
                onChanged: (v) {
                  widget.onHideOnClickOutsideChanged(v);
                  widget.onLog('hideOnClickOutside = $v');
                },
              ),
              _SwitchRow(
                label: 'Hide on Escape',
                subtitle: 'Dismiss on Escape key',
                value: widget.hideOnEscape,
                onChanged: (v) {
                  widget.onHideOnEscapeChanged(v);
                  widget.onLog('hideOnEscape = $v');
                },
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // POSITIONING
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Positioning',
            icon: Icons.open_with,
            children: [
              _SliderRow(
                label: 'X',
                value: _x,
                min: 0,
                max: 1200,
                onChanged: (v) => setState(() => _x = v),
              ),
              _SliderRow(
                label: 'Y',
                value: _y,
                min: 0,
                max: 800,
                onChanged: (v) => setState(() => _y = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    label: 'Move',
                    icon: Icons.moving,
                    onPressed: () =>
                        _run('move(${_x.toInt()}, ${_y.toInt()})', () async {
                          await Palettes.demo.move(to: Offset(_x, _y));
                        }),
                  ),
                  _ActionButton(
                    label: 'Center',
                    icon: Icons.center_focus_strong,
                    onPressed: () => _run('move(center)', () async {
                      await Palettes.demo.move(to: const Offset(500, 300));
                    }),
                  ),
                  _ActionButton(
                    label: 'Top-Left',
                    icon: Icons.north_west,
                    onPressed: () => _run('move(50, 50)', () async {
                      await Palettes.demo.move(to: const Offset(50, 50));
                    }),
                  ),
                ],
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // SIZING
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Sizing',
            icon: Icons.aspect_ratio,
            children: [
              _SliderRow(
                label: 'Width',
                value: _width,
                min: 150,
                max: 600,
                onChanged: (v) => setState(() => _width = v),
              ),
              _SliderRow(
                label: 'Height',
                value: _height,
                min: 100,
                max: 500,
                onChanged: (v) => setState(() => _height = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    label: 'Resize',
                    icon: Icons.photo_size_select_small,
                    onPressed: () => _run(
                      'resize(${_width.toInt()}x${_height.toInt()})',
                      () async {
                        await Palettes.demo.resize(to: Size(_width, _height));
                      },
                    ),
                  ),
                  _ActionButton(
                    label: 'Small',
                    icon: Icons.minimize,
                    onPressed: () => _run('resize(200x150)', () async {
                      await Palettes.demo.resize(to: const Size(200, 150));
                    }),
                  ),
                  _ActionButton(
                    label: 'Large',
                    icon: Icons.maximize,
                    onPressed: () => _run('resize(500x400)', () async {
                      await Palettes.demo.resize(to: const Size(500, 400));
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Content-driven resize: Use +/- buttons inside the palette to add/remove items. '
                        'Window resizes automatically via PaletteScaffold.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // APPEARANCE
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _SliderRow(
                label: 'Corner Radius',
                value: widget.cornerRadius,
                min: 0,
                max: 24,
                onChanged: (v) {
                  widget.onCornerRadiusChanged(v);
                  widget.onLog('cornerRadius = ${v.toInt()}');
                },
              ),
              _SliderRow(
                label: 'Shadow Blur',
                value: widget.shadowBlur,
                min: 0,
                max: 40,
                onChanged: (v) {
                  widget.onShadowBlurChanged(v);
                  widget.onLog('shadowBlur = ${v.toInt()}');
                },
              ),
              _SliderRow(
                label: 'Opacity',
                value: widget.opacity,
                min: 0.3,
                max: 1.0,
                onChanged: (v) {
                  widget.onOpacityChanged(v);
                  widget.onLog('opacity = ${v.toStringAsFixed(2)}');
                },
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // ANIMATIONS
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Animations',
            icon: Icons.animation,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    label: 'Shake',
                    icon: Icons.vibration,
                    color: Colors.orange,
                    onPressed: () => _run('shake', () => Palettes.demo.shake()),
                  ),
                  _ActionButton(
                    label: 'Pulse',
                    icon: Icons.radio_button_checked,
                    color: Colors.purple,
                    onPressed: () => _run('pulse', () => Palettes.demo.pulse()),
                  ),
                  _ActionButton(
                    label: 'Bounce',
                    icon: Icons.sports_basketball,
                    color: Colors.blue,
                    onPressed: () =>
                        _run('bounce', () => Palettes.demo.bounce()),
                  ),
                ],
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════
          // QUICK TESTS
          // ═══════════════════════════════════════════════════════════════
          _Section(
            title: 'Quick Tests',
            icon: Icons.speed,
            children: [
              _ActionButton(
                label: 'Full Lifecycle Test',
                icon: Icons.loop,
                color: Colors.teal,
                onPressed: () async {
                  widget.onLog('═══ Full Lifecycle Test ═══');
                  await _run('1. warmUp', () => Palettes.demo.warmUp());
                  widget.onStateChange(true, false);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await _run('2. show', () => Palettes.demo.show());
                  widget.onStateChange(true, true);
                  await Future.delayed(const Duration(milliseconds: 800));
                  await _run('3. shake', () => Palettes.demo.shake());
                  await Future.delayed(const Duration(milliseconds: 800));
                  await _run('4. hide', () => Palettes.demo.hide());
                  widget.onStateChange(true, false);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await _run('5. coolDown', () => Palettes.demo.coolDown());
                  widget.onStateChange(false, false);
                  widget.onLog('═══ Test Complete ═══');
                },
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: 'Move Around Test',
                icon: Icons.transform,
                color: Colors.indigo,
                onPressed: () async {
                  widget.onLog('═══ Move Around Test ═══');
                  await _run('show', () => Palettes.demo.show());
                  widget.onStateChange(true, true);
                  await Future.delayed(const Duration(milliseconds: 400));

                  for (final pos in [
                    const Offset(100, 100),
                    const Offset(600, 100),
                    const Offset(600, 400),
                    const Offset(100, 400),
                    const Offset(350, 250),
                  ]) {
                    await _run(
                      'move(${pos.dx.toInt()}, ${pos.dy.toInt()})',
                      () => Palettes.demo.move(to: pos),
                    );
                    await Future.delayed(const Duration(milliseconds: 400));
                  }
                  widget.onLog('═══ Test Complete ═══');
                },
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: 'Animation Sequence',
                icon: Icons.animation,
                color: Colors.deepPurple,
                onPressed: () async {
                  widget.onLog('═══ Animation Sequence ═══');
                  await _run('show', () => Palettes.demo.show());
                  widget.onStateChange(true, true);
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _run('shake', () => Palettes.demo.shake());
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _run('pulse', () => Palettes.demo.pulse());
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _run('bounce', () => Palettes.demo.bounce());
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _run('shake', () => Palettes.demo.shake());
                  widget.onLog('═══ Test Complete ═══');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value == value.roundToDouble()
                ? '${value.toInt()}'
                : value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
