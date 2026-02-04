import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PeopleGroupScreen extends StatefulWidget {
  const PeopleGroupScreen({super.key});

  @override
  State<PeopleGroupScreen> createState() => _PeopleGroupScreenState();
}

class _PeopleGroupScreenState extends State<PeopleGroupScreen> {
  late Interpreter interpreter;
  bool isLoading = true;
  final double similarityThreshold = 0.8; // lower = stricter match

  List<Person> people = [];

  @override
  void initState() {
    super.initState();
    initModelAndScan();
  }

  Future<void> initModelAndScan() async {
    try {
      // Load tflite model
      interpreter =
          await Interpreter.fromAsset('assets/model/mobilefacenet.tflite');
      await scanGalleryAndGroup();
    } catch (e) {
      debugPrint('Error initializing model: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> scanGalleryAndGroup() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) return;

      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );

      if (albums.isEmpty) return;

      final assets = await albums.first.getAssetListPaged(page: 0, size: 1000);

      // For simplicity, we create empty people groups first
      List<Person> detectedPeople = [];

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final emb = await getFaceEmbedding(file.path);

        if (emb == null) continue;

        bool matched = false;

        // Compare with existing groups
        for (final person in detectedPeople) {
          for (final pEmb in person.embeddings) {
            final sim = cosineSimilarity(emb, pEmb);
            if (sim > similarityThreshold) {
              person.photos.add(file.path);
              person.embeddings.add(emb);
              matched = true;
              break;
            }
          }
          if (matched) break;
        }

        if (!matched) {
          // New person detected
          detectedPeople.add(Person(
            name: 'Person ${detectedPeople.length + 1}',
            photos: [file.path],
            embeddings: [emb],
          ));
        }
      }

      setState(() {
        people = detectedPeople;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error scanning gallery: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Run MobileFaceNet tflite to get embedding
  Future<List<double>?> getFaceEmbedding(String imagePath) async {
    try {
      final bytes = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to 112x112 as MobileFaceNet input expects
      final resized = img.copyResize(image, width: 112, height: 112);

      // Normalize pixels to [-1,1]

      var input = List.generate(
          1,
          (_) => List.generate(
              112,
              (i) => List.generate(112, (j) {
                    final px = resized.getPixel(j, i); // Pixel object
                    final r = px.r / 255.0;
                    final g = px.g / 255.0;
                    final b = px.b / 255.0;
                    return [(r - 0.5) * 2, (g - 0.5) * 2, (b - 0.5) * 2];
                  })));

      var output = List.filled(192, 0.0).reshape([1, 192]);

      interpreter.run(input, output);

      return (output).first.cast<double>();
    } catch (e) {
      debugPrint('Embedding error: $e');
      return null;
    }
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("People Groups"), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : people.isEmpty
              ? const Center(
                  child: Text("No faces detected",
                      style: TextStyle(color: Colors.white)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final cover =
                        person.photos.isNotEmpty ? person.photos.first : null;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PersonPhotosScreen(person: person)),
                        );
                      },
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundImage:
                                cover != null ? FileImage(File(cover)) : null,
                            backgroundColor: Colors.grey[800],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            person.name,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class Person {
  String name;
  List<String> photos;
  List<List<double>> embeddings;

  Person({
    required this.name,
    required this.photos,
    required this.embeddings,
  });
}

class PersonPhotosScreen extends StatelessWidget {
  final Person person;
  const PersonPhotosScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(person.name), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: person.photos.isEmpty
          ? const Center(
              child: Text('No photos yet',
                  style: TextStyle(color: Colors.white54)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: person.photos.length,
              itemBuilder: (_, i) =>
                  Image.file(File(person.photos[i]), fit: BoxFit.cover),
            ),
    );
  }
}
