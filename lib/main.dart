import 'package:flutter/material.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS Gallery',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: ModelTestScreen(),
//     );
//   }
// }
//
// class ModelTestScreen extends StatefulWidget {
//   const ModelTestScreen({super.key});
//
//   @override
//   State<ModelTestScreen> createState() => _ModelTestScreenState();
// }
//
// class _ModelTestScreenState extends State<ModelTestScreen> {
//   String status = 'Loading model...';
//   Interpreter? interpreter;
//
//   @override
//   void initState() {
//     super.initState();
//     loadAndTestModel();
//   }
//
//   Future<void> loadAndTestModel() async {
//     try {
//       // 1️⃣ Load model
//       interpreter =
//       await Interpreter.fromAsset('assets/model/mobilefacenet.tflite');
//
//       // 2️⃣ Check input/output shape
//       final inputShape = interpreter!.getInputTensor(0).shape;
//       final outputShape = interpreter!.getOutputTensor(0).shape;
//
//       // 3️⃣ Dry run with dummy input
//       final input = List.generate(
//         1,
//             (_) => List.generate(
//           112,
//               (_) => List.generate(
//             112,
//                 (_) => [0.0, 0.0, 0.0],
//           ),
//         ),
//       );
//
//       final output = List.filled(192, 0.0).reshape([1, 192]);
//
//       interpreter!.run(input, output);
//
//       setState(() {
//         status = '''
// ✅ MODEL WORKING PERFECTLY
//
// Input Shape  : $inputShape
// Output Shape : $outputShape
//
// Sample Output:
// ${output[0].take(5).toList()}
// ''';
//       });
//     } catch (e) {
//       setState(() {
//         status = '❌ ERROR:\n$e';
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     interpreter?.close();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('MobileFaceNet Test')),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Text(
//             status,
//             style: const TextStyle(fontSize: 16),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
