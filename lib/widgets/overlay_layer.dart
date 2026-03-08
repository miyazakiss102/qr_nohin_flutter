import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/overlay_box_data.dart';

class OverlayLayer extends StatelessWidget {
  final List<OverlayBoxData> overlayItems;

  const OverlayLayer({super.key, required this.overlayItems});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: overlayItems.map((item) {
        final Color color = item.isConfirmed ? Colors.red : Colors.green;

        return Positioned(
          left: item.rect.left,
          top: item.rect.top,
          width: item.rect.width,
          height: item.rect.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
            ),
            child: item.confirmedNo == null
                ? const SizedBox()
                : Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '${item.confirmedNo}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                math.min(item.rect.width, item.rect.height) *
                                0.75,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 6
                              ..color = Colors.white,
                          ),
                        ),
                        Text(
                          '${item.confirmedNo}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                math.min(item.rect.width, item.rect.height) *
                                0.75,
                            fontWeight: FontWeight.w900,
                            color: color.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }
}
