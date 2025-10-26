import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/file_helper.dart';
import 'dart:ui';

class GalleryPage extends StatefulWidget {
  final String searchQuery;
  const GalleryPage({super.key, this.searchQuery = ''});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // === Memuat semua catatan yang punya gambar ===
  Future<void> _loadNotes() async {
    try {
      final data = await FileHelper.readNotes();
      setState(() {
        _notes = data.where((note) {
          if (note['content'] != null && note['content'] is List) {
            return (note['content'] as List).any(
              (block) => block['type'] == 'image',
            );
          }
          return note['image'] != null;
        }).toList();
        _applySearch();
      });
    } catch (e) {
      debugPrint('Gagal memuat galeri: $e');
    }
  }

  // === Filter berdasarkan teks pencarian ===
  void _applySearch() {
    final query = widget.searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredNotes = _notes;
    } else {
      _filteredNotes = _notes.where((note) {
        final title = (note['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
    }
  }

  // === Ambil semua gambar dari content[] atau dari field image lama ===
  List<File> _extractImages(Map<String, dynamic> note) {
    final List<File> images = [];

    if (note['content'] != null && note['content'] is List) {
      for (final block in note['content']) {
        if (block['type'] == 'image' &&
            block['value'] != null &&
            File(block['value']).existsSync()) {
          images.add(File(block['value']));
        }
      }
    } else if (note['image'] != null) {
      final file = File(note['image']);
      if (file.existsSync()) images.add(file);
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _applySearch();

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _filteredNotes.isEmpty
              ? Center(
                  child: Text(
                    _notes.isEmpty
                        ? 'Belum ada foto di galeri 📷'
                        : 'Foto tidak ditemukan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      final images = _extractImages(note);
                      return _buildPhotoCard(note, images, theme, isDark);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  // === Kartu foto utama ===
  Widget _buildPhotoCard(
    Map<String, dynamic> note,
    List<File> images,
    ThemeData theme,
    bool isDark,
  ) {
    final hasImage = images.isNotEmpty;
    final imageFile = hasImage ? images.first : null;

    return GestureDetector(
      onTap: hasImage
          ? () => _showImageDialog(
              images,
              title: note['title'],
              date: note['date']?.toString().substring(0, 10),
            )
          : null,

      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262629) : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === Gambar utama ===
            Expanded(
              child: hasImage
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      child: Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildBrokenImage(theme),
                      ),
                    )
                  : _buildBrokenImage(theme),
            ),

            // === Informasi ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note['title'] ?? 'Tanpa Judul',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    note['date']?.toString().substring(0, 10) ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === Placeholder jika gambar rusak/hilang ===
  Widget _buildBrokenImage(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        size: 60,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }

  // ganti fungsi _showImageDialog lama dengan yang ini

  void _showImageDialog(List<File> images, {String? title, String? date}) {
    final PageController controller = PageController();
    final ValueNotifier<int> pageNotifier = ValueNotifier<int>(0);

    void listener() {
      final double? p = controller.page;
      pageNotifier.value = (p != null) ? p.round() : 0;
    }

    controller.addListener(listener);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Column(
            children: [
              // === HEADER FIX TANPA EFEK KACA ===
              Container(
                height: 80,
                width: double.infinity,
                color: Colors.black.withOpacity(0.45), // transparan lembut saja
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // === Info text (judul & tanggal)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null && title.isNotEmpty)
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (date != null && date.isNotEmpty)
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // === Tombol Close ===
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // === AREA GAMBAR ===
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(images[index], fit: BoxFit.contain),
                    );
                  },
                ),
              ),

              // === INDIKATOR BAWAH ===
              ValueListenableBuilder<int>(
                valueListenable: pageNotifier,
                builder: (context, current, _) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == current ? 12 : 8,
                          height: i == current ? 12 : 8,
                          decoration: BoxDecoration(
                            color: i == current
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    ).then((_) {
      controller.removeListener(listener);
      controller.dispose();
      pageNotifier.dispose();
    });
  }
}
