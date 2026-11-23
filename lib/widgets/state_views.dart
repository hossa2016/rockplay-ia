import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mensaje de estado (vacío / error / intro) con icono, título y acción.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isError ? AppColors.amber : AppColors.red;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.outline),
              ),
              child: Icon(icon, size: 38, color: tint),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textDim,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aparece con fundido y ligero desplazamiento. [order] escalona la entrada.
class FadeIn extends StatelessWidget {
  final Widget child;
  final int order;

  const FadeIn({super.key, required this.child, this.order = 0});

  @override
  Widget build(BuildContext context) {
    final o = order > 8 ? 8 : (order < 0 ? 0 : order);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + o * 45),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) {
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: ch),
        );
      },
      child: child,
    );
  }
}

/// Lista de esqueletos pulsantes mientras carga.
class SkeletonList extends StatefulWidget {
  final int count;
  const SkeletonList({super.key, this.count = 7});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, double r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: const [
              Color(0xFF1E1E26),
              Color(0xFF30303B),
              Color(0xFF1E1E26),
            ],
            stops: const [0.35, 0.5, 0.65],
            transform: _Slide(_c.value * 2 - 1),
          ).createShader(rect),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: widget.count,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  _box(56, 56, 8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(double.infinity, 14, 6),
                        const SizedBox(height: 8),
                        _box(120, 12, 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Slide extends GradientTransform {
  final double p;
  const _Slide(this.p);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * p, 0, 0);
}
