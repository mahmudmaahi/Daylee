import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../data/repositories/money_repository.dart';
import '../../../data/services/category_service.dart';
import '../controllers/money_controller.dart';
import '../models/money_transaction.dart';
import 'money_screen.dart' show confirmDialog;

/// Add or edit an expense / income. Opened from the finance tab, the home
/// quick actions and by tapping a transaction.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late final MoneyController _money;

  MoneyTransaction? _editing;
  late MoneyTransactionType _type;
  String? _walletId;
  String _category = 'food';
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isExpense => _type == MoneyTransactionType.expense;

  @override
  void initState() {
    super.initState();
    _money = Get.find<MoneyController>();

    final args = Get.arguments;
    final editId = args is Map ? args['transactionId'] as String? : null;
    if (editId != null) _editing = _money.findTransactionById(editId);

    final argType = args is Map ? args['type'] as String? : null;
    _type = argType == 'income'
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;

    final wallets = _money.wallets;
    // Cash is by far the most common source, so start there.
    _walletId = (wallets.firstWhereOrNull((w) => !w.isOnline) ?? wallets.firstOrNull)
        ?.id;

    final e = _editing;
    if (e != null) {
      _type = e.type;
      _walletId = e.sourceWalletId;
      _category = e.category;
      _date = DateTime.fromMillisecondsSinceEpoch(e.dateMs);
      _noteCtrl.text = e.note;
      _amountCtrl.text = CurrencyHelper.input(e.amount);
    } else {
      _category = _isExpense ? 'food' : 'allowance';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final base = _isExpense
        ? _money.expenseCategories
        : CategoryService.incomeCategories;
    return {...base, _category}.toList();
  }

  void _setType(MoneyTransactionType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = _isExpense ? 'food' : 'allowance';
    });
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Groceries'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    final created = await CategoryService.addCustom(name);
    if (created != null && mounted) setState(() => _category = created);
  }

  Future<void> _save() async {
    final amount = CurrencyHelper.parse(_amountCtrl.text);
    if (amount <= 0) {
      Get.snackbar('Check this', 'Enter an amount greater than zero.');
      return;
    }
    final walletId = _walletId;
    if (walletId == null) {
      Get.snackbar('Check this', 'Choose a wallet.');
      return;
    }

    setState(() => _saving = true);
    final e = _editing;
    final ok = e == null
        ? await _money.addTransaction(
            type: _type,
            amount: amount,
            category: _category,
            walletId: walletId,
            date: _date,
            note: _noteCtrl.text,
          )
        : await _money.updateTransaction(
            transactionId: e.id,
            type: _type,
            amount: amount,
            category: _category,
            walletId: walletId,
            date: _date,
            note: _noteCtrl.text,
          );
    if (!mounted) return;
    if (ok) {
      Get.back();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = _editing;
    if (e == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete transaction?',
      message: 'Your wallet balance will be updated.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    final done = await _money.deleteTransaction(e.id);
    if (done && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallets = _money.wallets;
    final accent = _isExpense ? AppColors.error : AppColors.success;
    final amount = CurrencyHelper.parse(_amountCtrl.text);
    final wallet = wallets.firstWhereOrNull((w) => w.id == _walletId);

    // Helpful hint about where the money comes from.
    String? hint;
    if (_isExpense && wallet != null && amount > 0) {
      var credit = 0.0; // money freed up by the expense being edited
      final old = _editing;
      if (old != null &&
          old.sourceWalletId == wallet.id &&
          old.type == MoneyTransactionType.expense) {
        credit = old.amount;
      }
      final free = wallet.spendable + credit;
      final total = wallet.currentBalance + credit;
      if (amount > total + 0.005) {
        hint = '${wallet.name} does not have enough money for this.';
      } else if (amount > free + 0.005) {
        hint =
            '${CurrencyHelper.format(amount - free)} will be taken from the '
            'savings in ${wallet.name}.';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing == null
              ? (_isExpense ? 'Add expense' : 'Add income')
              : 'Edit transaction',
        ),
        actions: [
          if (_editing != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            SegmentedButton<MoneyTransactionType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: MoneyTransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.south_west_rounded),
                ),
                ButtonSegment(
                  value: MoneyTransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.north_east_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: _editing == null,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: '${CurrencyHelper.symbol} ',
                      prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _Label('Paid from'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in wallets)
                  ChoiceChip(
                    selected: w.id == _walletId,
                    onSelected: (_) => setState(() => _walletId = w.id),
                    avatar: Icon(
                      w.isOnline
                          ? Icons.account_balance_rounded
                          : Icons.payments_rounded,
                      size: 18,
                    ),
                    label: Text(
                      '${w.name} • ${CurrencyHelper.formatShort(w.spendable)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    selected: c == _category,
                    onSelected: (_) => setState(() => _category = c),
                    avatar: Icon(
                      CategoryService.icon(c),
                      size: 18,
                      color: CategoryService.color(c),
                    ),
                    label: Text(CategoryService.label(c)),
                  ),
                if (_isExpense)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                    onPressed: _addCategory,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Label('Date'),
            Wrap(
              spacing: 8,
              children: [
                _dateChip('Today', DateTime.now()),
                _dateChip(
                  'Yesterday',
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _isQuickDate ? 'Pick date' : DateFormat('d MMM yyyy').format(_date),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 366)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _editing == null
                    ? (_isExpense ? 'Save expense' : 'Save income')
                    : 'Save changes',
              ),
            ),
            if (_editing?.category == MoneyRepository.adjustmentCategory)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'This is an automatic balance correction.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isQuickDate =>
      _sameDay(_date, DateTime.now()) ||
      _sameDay(_date, DateTime.now().subtract(const Duration(days: 1)));

  Widget _dateChip(String label, DateTime value) {
    return ChoiceChip(
      label: Text(label),
      selected: _sameDay(_date, value),
      onSelected: (_) => setState(() => _date = value),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
