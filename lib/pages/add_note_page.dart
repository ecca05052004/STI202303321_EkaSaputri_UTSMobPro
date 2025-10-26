import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/file_helper.dart';

class AddNotePage extends StatefulWidget {
  final Map<String, dynamic>? note;
  final int? noteIndex;

  const AddNotePage({super.key, this.note, this.noteIndex});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final List<_EditorBlock> _blocks = [];

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_isEditing) {
      final note = widget.note!;
      _titleController.text = note['title'] ?? '';

      // 🔹 Jika data baru sudah pakai "content"
      if (note['content'] != null && note['content'] is List) {
        for (final block in note['content']) {
          if (block['type'] == 'text') {
            _blocks.add(_EditorBlock.text(block['value'] ?? ''));
          } else if (block['type'] == 'image' && block['value'] != null) {
            final file = File(block['value']);
            if (file.existsSync()) _blocks.add(_EditorBlock.image(file));
          }
        }
      } else {
        // 🔹 Backward compatibility (data lama)
        _blocks.add(_EditorBlock.text(note['desc'] ?? ''));
        if (note['image'] != null) {
          final file = File(note['image']);
          if (file.existsSync()) _blocks.add(_EditorBlock.image(file));
        }
      }

      _selectedDate = DateTime.tryParse(note['date'] ?? '');
      final timeString = note['time'];
      if (timeString != null && timeString.contains(':')) {
        final parts = timeString.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1].split(' ')[0]) ?? 0;
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      }
    } else {
      _blocks.add(_EditorBlock.text(''));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final newImage = File(pickedFile.path);
        setState(() {
          // Tambah gambar di posisi terakhir + blok teks baru setelahnya
          _blocks.add(_EditorBlock.image(newImage));
          _blocks.add(_EditorBlock.text(''));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak dapat memuat foto.')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveNote() async {
    final content = _blocks.map((block) {
      if (block.type == BlockType.text) {
        return {'type': 'text', 'value': block.controller.text};
      } else {
        return {'type': 'image', 'value': block.image?.path};
      }
    }).toList();

    // validasi isi
    final hasContent = content.any(
      (block) =>
          (block['type'] == 'text' &&
              (block['value'] as String).trim().isNotEmpty) ||
          (block['type'] == 'image' && block['value'] != null),
    );

    if (_titleController.text.isEmpty && !hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan tidak boleh kosong!')),
      );
      return;
    }

    final newNote = {
      'title': _titleController.text,
      'content': content,
      'date': (_selectedDate ?? DateTime.now()).toIso8601String(),
      'time': (_selectedTime ?? TimeOfDay.now()).format(context),
    };

    final notes = await FileHelper.readNotes();
    if (_isEditing && widget.noteIndex != null) {
      notes[widget.noteIndex!] = newNote;
    } else {
      notes.add(newNote);
    }
    await FileHelper.saveNotes(notes);

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing ? 'Perubahan disimpan.' : 'Catatan baru disimpan!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 2,
        title: Text(
          _isEditing ? 'Edit Catatan' : 'Tambah Catatan',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Editor Blocks
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 70),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Masukkan Judul...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Isi konten (teks + gambar)
                    ..._blocks.map((block) {
                      if (block.type == BlockType.text) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: block.controller,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tulis catatan di sini...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.45,
                                ),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  block.image!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _blocks.remove(block));
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Toolbar bawah
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Sisipkan Gambar',
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        color: theme.colorScheme.primary,
                        onPressed: _pickImage,
                      ),
                      IconButton(
                        tooltip: 'Tanggal',
                        icon: const Icon(Icons.calendar_month_rounded),
                        color: theme.colorScheme.primary,
                        onPressed: _pickDate,
                      ),
                      IconButton(
                        tooltip: 'Waktu',
                        icon: const Icon(Icons.access_time_rounded),
                        color: theme.colorScheme.primary,
                        onPressed: _pickTime,
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveNote,
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BlockType { text, image }

class _EditorBlock {
  final BlockType type;
  final TextEditingController controller;
  final File? image;

  _EditorBlock.text(String text)
    : type = BlockType.text,
      controller = TextEditingController(text: text),
      image = null;

  _EditorBlock.image(File img)
    : type = BlockType.image,
      controller = TextEditingController(),
      image = img;
}
