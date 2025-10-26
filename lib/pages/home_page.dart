import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/file_helper.dart';
import 'add_note_page.dart';

class HomePage extends StatefulWidget {
  final String searchQuery;
  const HomePage({super.key, this.searchQuery = ''});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];

  @override
  bool get wantKeepAlive => true; // biar state tetap hidup antar tab

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final data = await FileHelper.readNotes();
      setState(() {
        _notes = data;
        _applySearch();
      });
    } catch (e) {
      debugPrint('Gagal memuat catatan: $e');
    }
  }

  void _applySearch() {
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredNotes = _notes;
    } else {
      _filteredNotes = _notes.where((note) {
        final title = (note['title'] ?? '').toString().toLowerCase();
        String descText = '';
        if (note['content'] != null && note['content'] is List) {
          descText = (note['content'] as List)
              .where((b) => b['type'] == 'text')
              .map((b) => (b['value'] ?? '').toString())
              .join(' ')
              .toLowerCase();
        } else {
          descText = (note['desc'] ?? '').toString().toLowerCase();
        }
        return title.contains(query) || descText.contains(query);
      }).toList();
    }
  }

  List<File> _extractImages(Map<String, dynamic> note) {
    if (note['content'] == null || note['content'] is! List) {
      final imgPath = note['image'];
      return (imgPath != null && File(imgPath).existsSync())
          ? [File(imgPath)]
          : [];
    }

    final List<File> imgs = [];
    for (final block in note['content']) {
      if (block['type'] == 'image' &&
          block['value'] != null &&
          File(block['value']).existsSync()) {
        imgs.add(File(block['value']));
      }
    }
    return imgs;
  }

  String _extractText(Map<String, dynamic> note) {
    if (note['content'] == null || note['content'] is! List) {
      return note['desc'] ?? '';
    }
    return (note['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['value'] ?? '')
        .join('\n\n');
  }

  Future<void> _openNoteEditor({Map<String, dynamic>? note, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNotePage(note: note, noteIndex: index),
      ),
    );

    if (result == true) {
      // langsung update setelah kembali
      await _loadNotes();
    }
  }

  void _openNotePreview(Map<String, dynamic> note, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<File> images = _extractImages(note);
    final String text = _extractText(note);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1F) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: images.length,
                          controller: PageController(viewportFraction: 0.9),
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                images[i],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (images.isNotEmpty) const SizedBox(height: 16),
                    Text(
                      note['title'] ?? '(Tanpa Judul)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${note['date']?.toString().substring(0, 10)}  •  ${note['time']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                tooltip: 'Tutup',
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  size: 26,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Edit Catatan',
                    icon: Icon(
                      Icons.edit_note_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openNoteEditor(note: note, index: index);
                    },
                  ),
                  IconButton(
                    tooltip: 'Hapus Catatan',
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteNote(index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Apakah kamu yakin ingin menghapus catatan ini secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _notes.removeAt(index);
      await FileHelper.saveNotes(_notes);
      _applySearch();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Catatan berhasil dihapus')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // penting untuk keepAlive bekerja
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _applySearch();

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: _filteredNotes.isEmpty
          ? Center(
              child: Text(
                _notes.isEmpty
                    ? 'Belum ada catatan, tambah lewat tombol ➕'
                    : 'Catatan tidak ditemukan',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                final title = note['title'] ?? '(Tanpa Judul)';
                final date = note['date'] ?? '';
                final time = note['time'] ?? '';
                final text = _extractText(note);
                final images = _extractImages(note);

                return GestureDetector(
                  onTap: () => _openNotePreview(note, index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262629) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.6)
                              : Colors.grey.withOpacity(0.15),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty)
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    images[i],
                                    width: 100,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          if (images.isNotEmpty) const SizedBox(height: 8),
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${date.toString().substring(0, 10)} • $time',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
