import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../widgets/amount_input.dart';

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen({super.key, this.initial, this.original});

  /// Giao dịch để sửa hoặc bản nháp tự đọc. null = nhập mới.
  final Transaction? initial;

  /// Bản đã lưu trước khi sửa (để app học khi người dùng đổi hạng mục).
  final Transaction? original;

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TxType _type;
  late String _categoryId;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  bool _categoryTouched = false;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _type = t?.type ?? TxType.expense;
    _categoryId = t?.categoryId ?? Categories.otherExpenseId;
    _date = t?.date ?? DateTime.now();
    _amount = TextEditingController(
        text: t == null ? '' : ThousandsFormatter.format(t.amount));
    _note = TextEditingController(text: t?.note ?? '');
    _categoryTouched = t != null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(TxType t) {
    setState(() {
      _type = t;
      if (Categories.byId(_categoryId).type != t) {
        _categoryId = context.read<AppState>().suggestCategory(t, _note.text);
        _categoryTouched = false;
      }
    });
  }

  void _onNoteChanged(String v) {
    if (_categoryTouched) return;
    final s = context.read<AppState>().suggestCategory(_type, v);
    if (s != _categoryId) setState(() => _categoryId = s);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(
        d.year, d.month, d.day, tm?.hour ?? _date.hour, tm?.minute ?? _date.minute));
  }

  Future<void> _save() async {
    final amount = ThousandsFormatter.parse(_amount.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập số tiền nhé')));
      return;
    }
    final base = widget.initial ??
        Transaction(
            amount: amount, type: _type, categoryId: _categoryId, date: _date);
    final t = base.copyWith(
      amount: amount,
      type: _type,
      categoryId: _categoryId,
      note: _note.text.trim(),
      date: _date,
      needsReview: false,
    );
    await context.read<AppState>().save(t, original: widget.original ?? widget.initial);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Xóa giao dịch này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().delete(widget.initial!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = Categories.ofType(_type);
    final raw = widget.initial?.rawText;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa giao dịch' : 'Thêm giao dịch'),
        actions: [
          if (_isEdit)
            IconButton(
                tooltip: 'Xóa',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initial?.needsReview == true)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const ListTile(
                leading: Icon(Icons.auto_awesome),
                title: Text('App đã tự đọc giao dịch này'),
                subtitle: Text('Kiểm tra lại rồi bấm Lưu'),
              ),
            ),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(
                  value: TxType.expense,
                  label: Text('Chi'),
                  icon: Icon(Icons.arrow_upward)),
              ButtonSegment(
                  value: TxType.income,
                  label: Text('Thu'),
                  icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_type},
            onSelectionChanged: (v) => _setType(v.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: widget.initial == null,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              labelText: 'Số tiền',
              suffixText: '₫',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            onChanged: _onNoteChanged,
            decoration: const InputDecoration(
              labelText: 'Ghi chú / nội dung',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Hạng mục', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 18, color: c.color),
                  label: Text(c.name),
                  selected: c.id == _categoryId,
                  onSelected: (_) => setState(() {
                    _categoryId = c.id;
                    _categoryTouched = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(DateFormat('HH:mm, dd/MM/yyyy').format(_date)),
            subtitle: widget.initial?.bank != null
                ? Text('Nguồn: ${widget.initial!.bank}')
                : null,
            onTap: _pickDate,
          ),
          if (raw != null && raw.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Nội dung gốc'),
              children: [SelectableText(raw)],
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
