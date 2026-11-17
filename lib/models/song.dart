class Song {
  final String title;
  final String artist;
  final String album;
  final String image;
  final String url;
  final String videoId;
  final String query;

  Song({
    required this.title,
    required this.artist,
    this.videoId = '',
    this.album = '',
    this.image = '',
    this.url = '',
    this.query = '',
  });

  /// Emisora de radio en vivo (la dirección de la transmisión va en [url]).
  bool get isRadio => query.startsWith('radio:');

  Song withVideoId(String id) => Song(
        title: title,
        artist: artist,
        album: album,
        image: image,
        url: 'https://www.youtube.com/watch?v=$id',
        videoId: id,
        query: query,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'image': image,
        'url': url,
        'videoId': videoId,
        'query': query,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        image: (j['image'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        videoId: (j['videoId'] ?? '') as String,
        query: (j['query'] ?? '') as String,
      );
}
