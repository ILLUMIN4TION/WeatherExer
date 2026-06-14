// import 'dart:async';
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class ElasticMeshImage extends StatefulWidget {
//   final String imagePath;
//   final bool debugMode;

//   const ElasticMeshImage({
//     super.key,
//     required this.imagePath,
//     this.debugMode = false,
//   });

//   @override
//   State<ElasticMeshImage> createState() => _ElasticMeshImageState();
// }

// class _ElasticMeshImageState extends State<ElasticMeshImage> with SingleTickerProviderStateMixin {
//   ui.Image? _image;
//   Offset _dragOffset = Offset.zero;
//   Offset _releaseOffset = Offset.zero;
//   Offset _touchPoint = Offset.zero; 
  
//   bool _isValidHit = false;
//   late AnimationController _springController;

//   @override
//   void initState() {
//     super.initState();
//     _loadImage(); 
//     _springController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );

//     _springController.addListener(() {
//       setState(() {
//         _dragOffset = _releaseOffset * _springController.value;
//       });
//     });
//   }

//   Future<void> _loadImage() async {
//     final ByteData data = await rootBundle.load(widget.imagePath);
//     final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
//     final ui.FrameInfo fi = await codec.getNextFrame();
//     setState(() {
//       _image = fi.image;
//     });
//   }

//   @override
//   void dispose() {
//     _springController.dispose();
//     super.dispose();
//   }

//   void _onPanDown(DragDownDetails details) {
//     final size = context.size;
//     if (size == null) return;

//     final pos = details.localPosition;
//     final nx = pos.dx / size.width;
//     final ny = pos.dy / size.height;

//     // 🔥 832x1216 가슴 위치에 맞게 히트박스 비율 정밀 조정
//     if (nx > 0.15 && nx < 0.85 && ny > 0.42 && ny < 0.70) {
//       _isValidHit = true;
//       _springController.stop();
//       setState(() {
//         _touchPoint = pos;
//         _dragOffset = Offset.zero;
//       });
//     } else {
//       _isValidHit = false;
//     }
//   }

//   void _onPanUpdate(DragUpdateDetails details) {
//     if (!_isValidHit) return;
//     setState(() {
//       _dragOffset += details.delta * 0.5; // 드래그 감도 살짝 상향
//     });
//   }

//   void _onPanEnd() {
//     if (!_isValidHit) return;
//     _isValidHit = false;
//     _releaseOffset = _dragOffset;
//     _springController.value = 1.0;
//     _springController.animateTo(0.0, curve: Curves.elasticOut);
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_image == null) return const SizedBox();

//     return GestureDetector(
//       behavior: HitTestBehavior.translucent, 
//       onPanDown: _onPanDown,
//       onPanUpdate: _onPanUpdate,
//       onPanEnd: (_) => _onPanEnd(),
//       onPanCancel: _onPanEnd,
//       child: CustomPaint(
//         size: Size.infinite,
//         painter: _MeshWarpPainter(
//           image: _image!,
//           touchPoint: _touchPoint,
//           dragOffset: _dragOffset,
//           debugMode: widget.debugMode,
//         ),
//       ),
//     );
//   }
// }

// class _MeshWarpPainter extends CustomPainter {
//   final ui.Image image;
//   final Offset touchPoint;
//   final Offset dragOffset;
//   final bool debugMode;

//   _MeshWarpPainter({
//     required this.image,
//     required this.touchPoint,
//     required this.dragOffset,
//     required this.debugMode,
//   });

//   // 🔥 터치 이벤트가 중간에 가로채지지 않도록 확실하게 true 반환
//   @override
//   bool hitTest(Offset position) => true;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint();
    
//     const int cols = 10;
//     const int rows = 10;
    
//     List<Offset> positions = [];
//     List<Offset> texCoords = [];
    
//     for (int r = 0; r < rows; r++) {
//       for (int c = 0; c < cols; c++) {
//         double px = (c / (cols - 1)) * size.width;
//         double py = (r / (rows - 1)) * size.height;
//         Offset origPos = Offset(px, py);

//         double tx = (c / (cols - 1)) * image.width;
//         double ty = (r / (rows - 1)) * image.height;
//         texCoords.add(Offset(tx, ty));

//         // 최상단 쇄골 라인(r == 0)은 고정
//         if (r == 0 || dragOffset == Offset.zero) {
//           positions.add(origPos);
//         } else {
//           double dist = (origPos - touchPoint).distance;
//           double radius = size.width * 0.4; // 영향력 범위
//           double weight = (1.0 - (dist / radius)).clamp(0.0, 1.0);
          
//           positions.add(origPos + (dragOffset * weight));
//         }
//       }
//     }

//     List<int> indices = [];
//     for (int r = 0; r < rows - 1; r++) {
//       for (int c = 0; c < cols - 1; c++) {
//         int topLeft = r * cols + c;
//         int topRight = topLeft + 1;
//         int bottomLeft = (r + 1) * cols + c;
//         int bottomRight = bottomLeft + 1;

//         indices.addAll([topLeft, topRight, bottomLeft]);
//         indices.addAll([bottomLeft, topRight, bottomRight]);
//       }
//     }

//     final vertices = ui.Vertices(
//       ui.VertexMode.triangles,
//       positions,
//       textureCoordinates: texCoords,
//       indices: indices,
//     );

//     // 🔥 [초핵심 고정] 스마트폰 화면 크기와 이미지 해상도 비율을 계산해서 셰이더를 스케일링함!
//     final double scaleX = size.width / image.width;
//     final double scaleY = size.height / image.height;
//     final shaderMatrix = Matrix4.identity()..scale(scaleX, scaleY);

//     paint.shader = ui.ImageShader(
//       image,
//       ui.TileMode.clamp,
//       ui.TileMode.clamp,
//       shaderMatrix.storage, // 계산된 매트릭스 주입
//     );

//     canvas.drawVertices(vertices, ui.BlendMode.src, paint);

//     if (debugMode) {
//       // 히트박스 시각화
//       final hitboxRect = Rect.fromLTRB(
//         size.width * 0.15, size.height * 0.42,
//         size.width * 0.85, size.height * 0.70,
//       );
//       canvas.drawRect(hitboxRect, Paint()..color = Colors.red.withOpacity(0.3));

//       // 촘촘한 정점 시각화
//       final pointPaint = Paint()
//         ..color = Colors.greenAccent
//         ..strokeWidth = 5
//         ..strokeCap = StrokeCap.round;
//       canvas.drawPoints(ui.PointMode.points, positions, pointPaint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _MeshWarpPainter oldDelegate) {
//     return oldDelegate.dragOffset != dragOffset || 
//            oldDelegate.touchPoint != touchPoint ||
//            oldDelegate.debugMode != debugMode;
//   }
// }