import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:musicplayer/song_list.dart';
import 'package:carousel_slider/carousel_slider.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  String? songTitle;
  double sliderValue = 0.0;
  List<Map<String, dynamic>> imageList = [
    {"id": 1, "imagePath": 'images/1.jpeg'},
    {"id": 2, "imagePath": 'images/2.jpeg'},
    {"id": 3, "imagePath": 'images/3.jpeg'},
    {"id": 4, "imagePath": 'images/4.jpeg'},
    {"id": 5, "imagePath": 'images/5.jpeg'},
  ];
  final CarouselController carouselController = CarouselController();
  bool isPlaying = false;

  final AudioPlayer player = AudioPlayer();
  int currentIndex = 0;
  String? audioFilePath;
  Duration? duration;
  Duration? position;
  double playbackProgress = 0.0;

  List<Song> songs = [];
  int currentSongIndex = 0;

  late Stream<Duration?> _durationStream;
  late Stream<Duration?> _positionStream;

  @override
  void initState() {
    super.initState();
    _durationStream = player.durationStream;
    _positionStream = player.positionStream;
    _positionStream.listen((event) {
      if (event != null) {
        setState(() {
          position = event;
          playbackProgress = position != null && duration != null
              ? position!.inMilliseconds / duration!.inMilliseconds
              : 0.0;
          sliderValue = playbackProgress;
        });
      }
    });
    initPlayer();
    loadSongs();
  }

  Future<void> seekTo(double value) async {
    final newPosition = Duration(
        milliseconds: (value * (duration?.inMilliseconds ?? 0)).toInt());
    await player.seek(newPosition);
    setState(() {
      sliderValue = value;
    });
  }

  bool getIsPlaying() {
    return isPlaying;
  }

  Future<void> initPlayer() async {
    try {
      if (audioFilePath != null) {
        await player.setFilePath(audioFilePath!);
        await player.setLoopMode(LoopMode.off);
        await player.setVolume(1.0);
        player.playerStateStream.listen((playerState) {
          if (playerState.processingState == ProcessingState.completed) {
            setState(() {
              isPlaying = false;
              position = duration;
            });
          } else if (playerState.processingState == ProcessingState.ready) {
            setState(() {
              isPlaying = false;
            });
          }
        });
        final _duration = await player.duration;
        setState(() {
          duration = _duration;
          isPlaying = true;
          songTitle = audioFilePath!.split('/').last.replaceAll('.mp3', '');
          sliderValue =
              0.0; // Reset the slider value when a new audio file is loaded
        });
        await player.play();
      }
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  Future<void> loadSongs() async {
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
  }

  void playPreviousSong() {
    if (currentSongIndex > 0) {
      currentSongIndex--;
      playCurrentSong();
    }
  }

  void playNextSong() {
    if (currentSongIndex < songs.length - 1) {
      currentSongIndex++;
      playCurrentSong();
    }
  }

  void playCurrentSong() async {
    if (currentSongIndex >= 0 && currentSongIndex < songs.length) {
      final song = songs[currentSongIndex];
      await player.setUrl(song.url);
      await player.setLoopMode(LoopMode.off);
      await player.setVolume(1.0);
      await player.play();
      setState(() {
        isPlaying = true;
        songTitle = song.name.split('/').last.replaceAll('.mp3', '');
        sliderValue = 0.0; // Reset the slider value when a new song is played
      });
    }
  }

  Future<void> pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file != null && file.path != null) {
          audioFilePath = file.path!;
          await initPlayer();
        } else {
          print('Error: File or file path is null.');
        }
      } else {
        print('Error: No files selected.');
      }
    } catch (e) {
      print('Error picking audio file: $e');
    }
  }

  Future<void> uploadSong(String audioFilePath) async {
    try {
      final fileName = audioFilePath.split('/').last;
      final Reference storageReference =
          FirebaseStorage.instance.ref().child('songs/$fileName');
      final fileBytes = File(audioFilePath).readAsBytesSync();

      UploadTask uploadTask = storageReference.putData(fileBytes);

      await uploadTask.whenComplete(() {
        print('File Uploaded');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song uploaded successfully!'),
          ),
        );
      });
    } catch (e) {
      print('Error uploading audio file: $e');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        backgroundColor: Colors.deepOrange,
        leading: IconButton(
          onPressed: () async {
            await pickAudio();
            if (audioFilePath != null) {
              await uploadSong(audioFilePath!);
            } else {
              print('Error: No audio file selected.');
            }
          },
          icon: const Icon(
            Icons.music_note,
            size: 26,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final selectedSongName = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => SongListScreen(
                    audioPlayer: player,
                    currentlyPlayingSong: audioFilePath,
                    onSongSelected: (songName) {
                      Navigator.pop(context, songName);
                    },
                  ),
                ),
              );
              if (selectedSongName != null) {
                setState(() {
                  songTitle = selectedSongName;
                });
              }
            },
            icon: const Icon(Icons.search),
          ),
          const SizedBox(
            width: 15,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 7, right: 7, top: 8, bottom: 8),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CarouselSlider(
                    items: imageList.map((item) {
                      return Image.asset(
                        item['imagePath'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    }).toList(),
                    carouselController: carouselController,
                    options: CarouselOptions(
                      scrollPhysics: const BouncingScrollPhysics(),
                      autoPlay: true,
                      aspectRatio: 2,
                      viewportFraction: 1,
                      onPageChanged: (index, reason) {
                        setState(() {
                          currentIndex = index;
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: imageList.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap: () =>
                            carouselController.animateToPage(entry.key),
                        child: Container(
                          width: currentIndex == entry.key ? 17 : 7,
                          height: 7.0,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: currentIndex == entry.key
                                ? Colors.deepOrange
                                : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 9,
            ),
            SafeArea(
              child: Container(
                width: double.infinity,
                height: 520,
                decoration: BoxDecoration(
                  color: Colors.deepOrange[200],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(
                          height: 40,
                        ),
                        RotatingAvatarDisk(isPlaying: isPlaying),
                        const SizedBox(
                          height: 25,
                        ),
                        Center(
                          child: Text(
                            songTitle ?? 'Song Title',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Slider(
                            value: sliderValue,
                            onChanged: (value) {
                              setState(() {
                                sliderValue = value;
                              });
                            },
                            onChangeEnd: (value) {
                              seekTo(value);
                            },
                            thumbColor: Colors.deepOrange,
                            activeColor: Colors.deepOrangeAccent,
                            inactiveColor: Colors.white,
                            min: 0.0,
                            max: 1.0,
                          ),
                        ),
                        StreamBuilder<Duration?>(
                          stream: _positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            return Text(
                              '${formatDuration(position)} / ${formatDuration(duration ?? Duration.zero)}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16.0,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 20,
                      left: 10,
                      right: 10,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                onPressed: () {
                                  final newVolume = player.volume - 0.1;
                                  if (newVolume >= 0.0) {
                                    player.setVolume(newVolume);
                                  }
                                },
                                icon: const Icon(
                                  Icons.volume_down_rounded,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  playPreviousSong(); // Previous button
                                },
                                icon: const Icon(
                                  Icons.skip_previous,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  if (isPlaying) {
                                    player.pause();
                                  } else {
                                    player.play();
                                  }
                                  setState(() {
                                    isPlaying = !isPlaying;
                                  });
                                },
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  size: 40,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  playNextSong(); // Next button
                                },
                                icon: const Icon(
                                  Icons.skip_next,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final newVolume = player.volume + 0.1;
                                  if (newVolume <= 1.0) {
                                    player.setVolume(newVolume);
                                  }
                                },
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class RotatingAvatarDisk extends StatefulWidget {
  final bool isPlaying; // Declare isPlaying as a parameter

  const RotatingAvatarDisk({Key? key, required this.isPlaying})
      : super(key: key);

  @override
  _RotatingAvatarDiskState createState() => _RotatingAvatarDiskState();
}

class _RotatingAvatarDiskState extends State<RotatingAvatarDisk>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      // Pause the animation when isPlaying is false
      _animationController.stop();
    } else if (!_animationController.isAnimating) {
      // Resume the animation when isPlaying becomes true
      _animationController.repeat();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animationController.value *
              2 *
              3.14159265359, // Rotate 360 degrees
          child: Container(
            width: 250,
            height: 250,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color:
                  Colors.white, // You can use an image for the disk background
            ),
            child: const Center(
              child: Icon(
                Icons.music_note,
                size: 110,
                color: Colors.black,
              ),
            ),
          ),
        );
      },
    );
  }
}
