class Person {
  final String name;
  final List<String> faceImages; // cropped face paths
  final List<List<double>> embeddings;

  Person({
    required this.name,
    required this.faceImages,
    required this.embeddings,
  });
}
