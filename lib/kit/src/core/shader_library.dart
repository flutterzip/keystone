import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Loads each fragment program once and hands it out synchronously afterwards.
abstract final class ShaderLibrary {
  static final Map<String, ui.FragmentProgram> _ready = {};
  static final Map<String, Future<ui.FragmentProgram>> _pending = {};

  /// The program if it has already been loaded.
  static ui.FragmentProgram? peek(String asset) => _ready[asset];

  static Future<ui.FragmentProgram> load(String asset) {
    return _pending[asset] ??= ui.FragmentProgram.fromAsset(asset).then((p) {
      _ready[asset] = p;
      return p;
    });
  }

  /// Warm several programs up front, so the first frame of an effect is ready.
  static Future<void> preload(Iterable<String> assets) =>
      Future.wait(assets.map(load));
}

typedef ShaderWidgetBuilder =
    Widget Function(BuildContext context, ui.FragmentShader? shader);

/// Owns one [ui.FragmentShader] for the lifetime of the widget.
///
/// [builder] receives null until the program has loaded, so callers can paint
/// a plain fallback for that first frame.
class ShaderBuilder extends StatefulWidget {
  const ShaderBuilder({super.key, required this.asset, required this.builder});

  final String asset;
  final ShaderWidgetBuilder builder;

  @override
  State<ShaderBuilder> createState() => _ShaderBuilderState();
}

class _ShaderBuilderState extends State<ShaderBuilder> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ShaderBuilder old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      _shader?.dispose();
      _shader = null;
      _resolve();
    }
  }

  void _resolve() {
    final asset = widget.asset;
    final ready = ShaderLibrary.peek(asset);
    if (ready != null) {
      _shader = ready.fragmentShader();
      return;
    }
    ShaderLibrary.load(asset).then((program) {
      if (!mounted || widget.asset != asset) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shader);
}
