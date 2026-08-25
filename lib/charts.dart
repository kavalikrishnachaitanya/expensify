import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

class PieChartWidget extends StatefulWidget {
  final List<CategorySpending> spendings;
  final String currencySymbol;
  final double totalAmount;

  const PieChartWidget({
    super.key,
    required this.spendings,
    required this.currencySymbol,
    required this.totalAmount,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PieChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAmount != widget.totalAmount ||
        oldWidget.spendings.length != widget.spendings.length) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spendings.isEmpty || widget.totalAmount <= 0) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: Text(
          'No expense data for this period',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _PieChartPainter(
                  spendings: widget.spendings,
                  totalAmount: widget.totalAmount,
                  progress: _animation.value,
                  hoveredIndex: _hoveredIndex,
                  theme: Theme.of(context),
                  currencySymbol: widget.currencySymbol,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Legend items
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: widget.spendings.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isHovered = _hoveredIndex == idx;

            return InkWell(
              onTap: () {
                setState(() {
                  _hoveredIndex = _hoveredIndex == idx ? null : idx;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 64,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? item.category.color.withAlpha(50)
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isHovered ? item.category.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategorySpending> spendings;
  final double totalAmount;
  final double progress;
  final int? hoveredIndex;
  final ThemeData theme;
  final String currencySymbol;

  _PieChartPainter({
    required this.spendings,
    required this.totalAmount,
    required this.progress,
    required this.hoveredIndex,
    required this.theme,
    required this.currencySymbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 10;
    final innerRadius = outerRadius * 0.65;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < spendings.length; i++) {
      final item = spendings[i];
      final sweepAngle = (item.totalAmount / totalAmount) * 2 * math.pi * progress;

      final isHovered = hoveredIndex == i;
      final currentOuterRadius = isHovered ? outerRadius + 6 : outerRadius;

      final paint = Paint()
        ..color = item.category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentOuterRadius - innerRadius
        ..strokeCap = StrokeCap.butt;

      final arcRadius = (currentOuterRadius + innerRadius) / 2;
      final rect = Rect.fromCircle(center: center, radius: arcRadius);

      canvas.drawArc(rect, startAngle + 0.02, sweepAngle - 0.04, false, paint);
      startAngle += sweepAngle;
    }

    // Center Text (Total Spend)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    String centerAmount = '$currencySymbol${totalAmount.toStringAsFixed(2)}';
    if (hoveredIndex != null && hoveredIndex! < spendings.length) {
      final hovered = spendings[hoveredIndex!];
      centerAmount = '$currencySymbol${hovered.totalAmount.toStringAsFixed(2)}';
    }

    textPainter.text = TextSpan(
      children: [
        TextSpan(
          text: hoveredIndex != null ? '${spendings[hoveredIndex!].category.name}\n' : 'Total Spend\n',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: centerAmount,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    textPainter.layout(maxWidth: innerRadius * 1.8);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.totalAmount != totalAmount;
  }
}

class BarChartWidget extends StatefulWidget {
  final Map<String, double> dataPoints; // Day/Month label -> Amount
  final String currencySymbol;
  final String title;

  const BarChartWidget({
    super.key,
    required this.dataPoints,
    required this.currencySymbol,
    this.title = 'Spending Overview',
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dataPoints.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No chart data available',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final maxVal = widget.dataPoints.values.isEmpty
        ? 1.0
        : widget.dataPoints.values.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 1.5,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartHeight = constraints.maxHeight;
              final chartWidth = math.max(constraints.maxWidth, widget.dataPoints.length * 45.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: chartHeight,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(chartWidth, chartHeight),
                        painter: _BarChartPainter(
                          dataPoints: widget.dataPoints,
                          maxVal: maxVal > 0 ? maxVal : 1.0,
                          progress: _animation.value,
                          currencySymbol: widget.currencySymbol,
                          theme: Theme.of(context),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<String, double> dataPoints;
  final double maxVal;
  final double progress;
  final String currencySymbol;
  final ThemeData theme;

  _BarChartPainter({
    required this.dataPoints,
    required this.maxVal,
    required this.progress,
    required this.currencySymbol,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paddingBottom = 30.0;
    final paddingTop = 25.0;
    final chartHeight = size.height - paddingBottom - paddingTop;
    final entries = dataPoints.entries.toList();
    final barCount = entries.length;

    if (barCount == 0) return;

    final barWidth = math.min(32.0, (size.width - 20) / barCount - 8);
    final totalSpacing = size.width - (barWidth * barCount);
    final spacing = totalSpacing / (barCount + 1);

    // Draw horizontal background gridlines
    final linePaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withAlpha(70)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < barCount; i++) {
      final label = entries[i].key;
      final value = entries[i].value;

      final x = spacing + i * (barWidth + spacing);
      final currentHeight = (value / maxVal) * chartHeight * progress;
      final y = size.height - paddingBottom - currentHeight;

      // Draw Bar with Gradient
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, currentHeight),
        const Radius.circular(6),
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withAlpha(150),
        ],
      );

      final barPaint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(x, y, barWidth, currentHeight));

      canvas.drawRRect(rect, barPaint);

      // Draw Value label above bar if value > 0
      if (value > 0) {
        textPainter.text = TextSpan(
          text: value >= 1000
              ? '$currencySymbol${(value / 1000).toStringAsFixed(1)}k'
              : '$currencySymbol${value.toInt()}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x + barWidth / 2 - textPainter.width / 2, math.max(2.0, y - 16)),
        );
      }

      // Draw X-axis label
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.maxVal != maxVal;
  }
}
