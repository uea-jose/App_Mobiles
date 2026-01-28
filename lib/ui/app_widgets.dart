import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6F8FF),
            Color(0xFFEAF1FF),
            Color(0xFFF8FAFF),
          ],
        ),
      ),
      child: Stack(
        children: const [
          _Blob(
              alignment: Alignment(-1.2, -1.0),
              size: 260,
              color: Color(0x332563EB)),
          _Blob(
              alignment: Alignment(1.2, -0.8),
              size: 220,
              color: Color(0x222563EB)),
          _Blob(
              alignment: Alignment(0.9, 1.2),
              size: 280,
              color: Color(0x1A2563EB)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _Blob(
      {required this.alignment, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;

  const SoftCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GlowLiftButton extends StatefulWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const GlowLiftButton({
    super.key,
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<GlowLiftButton> createState() => _GlowLiftButtonState();
}

class _GlowLiftButtonState extends State<GlowLiftButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final lift = (!enabled)
        ? 0.0
        : _down
            ? -1.0
            : (_hover ? -3.0 : 0.0);

    final shadowStrength = (!enabled)
        ? 0.06
        : _down
            ? 0.10
            : (_hover ? 0.14 : 0.10);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lift, 0),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(37, 99, 235, shadowStrength),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onPressed,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DangerLiftButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const DangerLiftButton(
      {super.key, required this.text, required this.onPressed});

  @override
  State<DangerLiftButton> createState() => _DangerLiftButtonState();
}

class _DangerLiftButtonState extends State<DangerLiftButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final lift = _down ? -1.0 : (_hover ? -3.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lift, 0),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFE0555F), Color(0xFFD63C47)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33E0555F),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onPressed,
              child: Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
