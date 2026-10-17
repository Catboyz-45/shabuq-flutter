import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_content_service.dart';

/// Super Admin editor for the help, terms and privacy pages.
class AppContentAdminScreen extends StatelessWidget {
  const AppContentAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: AppContentPage.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ข้อความในแอป'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final page in AppContentPage.values) Tab(text: page.title),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final page in AppContentPage.values) _PageEditor(page: page),
          ],
        ),
      ),
    );
  }
}

class _PageEditor extends StatefulWidget {
  const _PageEditor({required this.page});

  final AppContentPage page;

  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  final _service = AppContentService();
  final _controller = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service.watch(widget.page).first.then((body) {
      if (!mounted) return;
      setState(() {
        _controller.text = body;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.save(widget.page, _controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึก "${widget.page.title}" แล้ว')),
      );
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _controller,
          enabled: !_saving,
          maxLength: 10000,
          minLines: 12,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            labelText: 'ข้อความที่ผู้ใช้จะเห็น',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon:
              _saving
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.save),
          label: Text('บันทึก${widget.page.title}'),
        ),
      ],
    );
  }
}
