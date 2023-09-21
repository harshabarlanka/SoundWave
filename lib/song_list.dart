import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

class Song {
  final String name;
  final String url;
  Song({required this.name, required this.url});
}

class SongListScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String? currentlyPlayingSong;
  final void Function(String) onSongSelected;

  const SongListScreen({
    Key? key,
    required this.audioPlayer,
    required this.currentlyPlayingSong,
    required this.onSongSelected,
  }) : super(key: key);

  @override
  _SongListScreenState createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  late Future<List<Song>> songsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<Song> filteredSongs = [];

  @override
  void initState() {
    super.initState();
    songsFuture = fetchSongsFromStorage();
  }

  Future<List<Song>> fetchSongsFromStorage() async {
    List<Song> songs = [];
    try {
      final storageReference = FirebaseStorage.instance.ref().child('songs');
      final ListResult result = await storageReference.listAll();

      for (final Reference ref in result.items) {
        final url = await ref.getDownloadURL();
        final name = ref.name;
        songs.add(Song(name: name, url: url));
      }
    } catch (e) {
      print('Error fetching songs from Firebase Storage: $e');
    }
    return songs;
  }

  void filterSongs(String query) {
    songsFuture.then((allSongs) {
      final List<Song> filtered = allSongs
          .where(
              (song) => song.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      setState(() {
        filteredSongs = filtered;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: TextField(
          controller: _searchController,
          onChanged: filterSongs,
          decoration: const InputDecoration(
            hintText: 'Search songs',
            hintStyle: TextStyle(color: Colors.white, fontSize: 19),
            border: InputBorder.none,
          ),
        ),
      ),
      body: FutureBuilder<List<Song>>(
        future: songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching songs: ${snapshot.error}',
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 19),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No songs available.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
              ),
            );
          } else {
            final songs =
                filteredSongs.isNotEmpty ? filteredSongs : snapshot.data!;

            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  title: Text(
                    song.name.split('/').last.replaceAll('.mp3', ''),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 19),
                  ),
                  onTap: () async {
                    try {
                      await widget.audioPlayer.setUrl(song.url);
                      await widget.audioPlayer.setLoopMode(LoopMode.off);
                      await widget.audioPlayer.setVolume(1.0);
                      await widget.audioPlayer.play();
                      widget.onSongSelected(song.name);
                    } catch (e) {
                      print('Error playing song: $e');
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
