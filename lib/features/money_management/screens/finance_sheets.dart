import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/app_sheet.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_helper.dart';
import '../controllers/money_controller.dart';
import '../models/money_transfer.dart';
import '../models/wallet.dart';

MoneyController get _money => Get.find<MoneyController>();

String _walletLabel(Wallet w) =>
    '${w.name}  •  ${CurrencyHelper.formatShort(w.spendable)} free';

void _error(String message) => Get.snackbar('Check this', message);

// ── Wallet ────────────────────────────────────────────────────

Future<void> showWalletSheet(BuildContext context, {Wallet? wallet}) {
  return showAppSheet<void>(
    context,
    title: wallet == null ? 'Add wallet' : 'Edit wallet',
    subtitle: wallet == null
        ? 'A place where you keep money: a bank account or a mobile wallet.'
        : null,
    builder: (_) => _WalletForm(wallet: wallet),
  );
}

class _WalletForm extends StatefulWidget {
  const _WalletForm({this.wallet});

  final Wallet? wallet;

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _phone;
  late WalletType _type;
  bool _saving = false;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _name = TextEditingController(text: w?.name ?? '');
    _balance = TextEditingController(
      text: w == null ? '' : CurrencyHelper.input(w.currentBalance),
    );
    _bank = TextEditingController(text: w?.bankName ?? '');
    _account = TextEditingController(text: w?.accountName ?? '');
    _phone = TextEditingController(text: w?.phoneNumber ?? '');
    _type = w?.type ?? WalletType.bank;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _bank.dispose();
    _account.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _error('Give the wallet a name.');
      return;
    }
    setState(() => _saving = true);
    final balance = CurrencyHelper.parse(_balance.text);
    final existing = widget.wallet;
    final ok = existing == null
        ? await _money.addWallet(
            name: _name.text,
            type: _type,
            balance: balance,
            bankName: _bank.text,
            accountName: _account.text,
            phoneNumber: _phone.text,
          )
        : await _money.updateWallet(
            wallet: existing,
            name: _name.text,
            balance: balance,
            bankName: _bank.text,
            accountName: _account.text,
            phoneNumber: _phone.text,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCash = widget.wallet?.type == WalletType.cash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Wallet name'),
        ),
        if (!_isEdit) ...[
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<WalletType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: WalletType.bank, label: Text('Bank')),
              ButtonSegment(value: WalletType.mobile, label: Text('Mobile')),
              ButtonSegment(value: WalletType.cash, label: Text('Cash')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AmountField(
          controller: _balance,
          label: _isEdit ? 'Current balance' : 'Opening balance',
          helper: _isEdit
              ? 'Changing this records a "Balance correction" in your history.'
              : 'How much is in it right now.',
        ),
        if (!isCash && _type == WalletType.bank) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _bank,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _account,
            decoration: const InputDecoration(labelText: 'Account name / number'),
          ),
        ],
        if (_type == WalletType.mobile) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Save changes' : 'Create wallet'),
          ),
        ),
      ],
    );
  }
}

// ── Transfer ──────────────────────────────────────────────────

Future<void> showTransferSheet(BuildContext context, {MoneyTransfer? transfer}) {
  if (_money.wallets.length < 2) {
    Get.snackbar('Need two wallets', 'Add another wallet to move money.');
    return Future.value();
  }
  return showAppSheet<void>(
    context,
    title: transfer == null ? 'Move money' : 'Edit transfer',
    subtitle:
        'Between your own wallets. For example: you send a friend money '
        'online and take cash from them.',
    builder: (_) => _TransferForm(transfer: transfer),
  );
}

class _TransferForm extends StatefulWidget {
  const _TransferForm({this.transfer});

  final MoneyTransfer? transfer;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _from;
  late String _to;
  late TransferMoneyType _type;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transfer;
    final wallets = _money.wallets;
    // Typical case: online -> cash, so default to the first online wallet.
    final online = wallets.firstWhereOrNull((w) => w.isOnline);
    final cash = wallets.firstWhereOrNull((w) => !w.isOnline);
    _from = t?.fromWalletId ?? online?.id ?? wallets.first.id;
    _to = t?.toWalletId ?? cash?.id ?? wallets.last.id;
    if (_from == _to) _to = wallets.firstWhere((w) => w.id != _from).id;
    _type = t?.type ?? TransferMoneyType.expenseFund;
    _date = t == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(t.dateMs);
    _amount = TextEditingController(
      text: t == null ? '' : CurrencyHelper.input(t.amount),
    );
    _note = TextEditingController(text: t?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyHelper.parse(_amount.text);
    if (amount <= 0) {
      _error('Enter an amount greater than zero.');
      return;
    }
    if (_from == _to) {
      _error('Pick two different wallets.');
      return;
    }
    setState(() => _saving = true);
    final t = widget.transfer;
    final ok = t == null
        ? await _money.addTransfer(
            fromWalletId: _from,
            toWalletId: _to,
            amount: amount,
            type: _type,
            date: _date,
            note: _note.text,
          )
        : await _money.updateTransfer(
            transferId: t.id,
            fromWalletId: _from,
            toWalletId: _to,
            amount: amount,
            type: _type,
            date: _date,
            note: _note.text,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  void _swap() => setState(() {
    final tmp = _from;
    _from = _to;
    _to = tmp;
  });

  @override
  Widget build(BuildContext context) {
    final wallets = _money.wallets;
    final from = _money.walletById(_from);
    final available = from == null
        ? 0.0
        : (_type == TransferMoneyType.savings
              ? from.savingsBalance
              : from.spendable);

    DropdownMenuItem<String> item(Wallet w) => DropdownMenuItem(
      value: w.id,
      child: Text(_walletLabel(w), overflow: TextOverflow.ellipsis),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('from-$_from'),
          initialValue: _from,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'From'),
          items: wallets.map(item).toList(),
          onChanged: (v) => setState(() => _from = v ?? _from),
        ),
        Align(
          alignment: Alignment.center,
          child: IconButton(
            tooltip: 'Swap',
            onPressed: _swap,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('to-$_to'),
          initialValue: _to,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'To'),
          items: wallets.map(item).toList(),
          onChanged: (v) => setState(() => _to = v ?? _to),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<TransferMoneyType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: TransferMoneyType.expenseFund,
              label: Text('Spending money'),
            ),
            ButtonSegment(
              value: TransferMoneyType.savings,
              label: Text('Savings'),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        AmountField(
          controller: _amount,
          helper: 'Available in ${from?.name ?? 'wallet'}: '
              '${CurrencyHelper.format(available)}',
        ),
        const SizedBox(height: AppSpacing.md),
        DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.transfer == null ? 'Move money' : 'Save changes'),
          ),
        ),
      ],
    );
  }
}

// ── Savings ───────────────────────────────────────────────────

enum SavingsAction { setAside, newMoney, release }

Future<void> showSavingsSheet(
  BuildContext context, {
  SavingsAction action = SavingsAction.setAside,
  double? amount,
  String? walletId,
  String? note,
}) {
  return showAppSheet<void>(
    context,
    title: 'Savings',
    subtitle: 'Money tagged as savings is kept out of what you can spend.',
    builder: (_) => _SavingsForm(
      action: action,
      amount: amount,
      walletId: walletId,
      note: note,
    ),
  );
}

class _SavingsForm extends StatefulWidget {
  const _SavingsForm({required this.action, this.amount, this.walletId, this.note});

  final SavingsAction action;
  final double? amount;
  final String? walletId;
  final String? note;

  @override
  State<_SavingsForm> createState() => _SavingsFormState();
}

class _SavingsFormState extends State<_SavingsForm> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late SavingsAction _action;
  late String _walletId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _action = widget.action;
    final wallets = _money.wallets;
    _walletId = widget.walletId ??
        (wallets.firstWhereOrNull((w) => w.isOnline) ?? wallets.first).id;
    _amount = TextEditingController(
      text: widget.amount == null ? '' : CurrencyHelper.input(widget.amount!),
    );
    _note = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyHelper.parse(_amount.text);
    if (amount <= 0) {
      _error('Enter an amount greater than zero.');
      return;
    }
    setState(() => _saving = true);
    final ok = _action == SavingsAction.release
        ? await _money.withdrawSavings(
            walletId: _walletId,
            amount: amount,
            date: _date,
            note: _note.text,
          )
        : await _money.addSavings(
            walletId: _walletId,
            amount: amount,
            date: _date,
            newMoney: _action == SavingsAction.newMoney,
            note: _note.text,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _money.wallets;
    final wallet = _money.walletById(_walletId);
    final theme = Theme.of(context);

    final (hint, helper, button) = switch (_action) {
      SavingsAction.setAside => (
        'Take money you already have in this wallet and tag it as savings.',
        'Free to set aside: ${CurrencyHelper.format(wallet?.spendable ?? 0)}',
        'Set aside',
      ),
      SavingsAction.newMoney => (
        'Money that just arrived and goes straight to savings (for example '
            'your father sends the same amount you carried over in cash).',
        'It is added to the wallet balance and tagged as savings.',
        'Add to savings',
      ),
      SavingsAction.release => (
        'Release saved money so you can spend it again.',
        'Saved in this wallet: ${CurrencyHelper.format(wallet?.savingsBalance ?? 0)}',
        'Release',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<SavingsAction>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: SavingsAction.setAside, label: Text('Set aside')),
            ButtonSegment(value: SavingsAction.newMoney, label: Text('New money')),
            ButtonSegment(value: SavingsAction.release, label: Text('Release')),
          ],
          selected: {_action},
          onSelectionChanged: (s) => setState(() => _action = s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: ValueKey('wallet-$_walletId'),
          initialValue: _walletId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Wallet'),
          items: wallets
              .map(
                (w) => DropdownMenuItem(
                  value: w.id,
                  child: Text(
                    '${w.name}  •  saved ${CurrencyHelper.formatShort(w.savingsBalance)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _walletId = v ?? _walletId),
        ),
        const SizedBox(height: AppSpacing.md),
        AmountField(controller: _amount, helper: helper),
        const SizedBox(height: AppSpacing.md),
        DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(button),
          ),
        ),
      ],
    );
  }
}

// ── Cycle allowance ───────────────────────────────────────────

Future<void> showCycleFundSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Allowance for this cycle',
    subtitle:
        _money.cycleLabel,
    builder: (_) => const _FundForm(),
  );
}

class _FundForm extends StatefulWidget {
  const _FundForm();

  @override
  State<_FundForm> createState() => _FundFormState();
}

class _FundFormState extends State<_FundForm> {
  late final TextEditingController _cash;
  late final TextEditingController _online;
  String? _onlineWalletId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fund = _money.repo.getCycleFund(_money.currentMonthId);
    _cash = TextEditingController(text: CurrencyHelper.input(fund.cash));
    _online = TextEditingController(text: CurrencyHelper.input(fund.online));
    _onlineWalletId =
        fund.onlineWalletId ?? _money.onlineWallets.firstOrNull?.id;

    final c = _money.cycle;
    final now = DateTime.now();
    _date = now.isBefore(c.start)
        ? c.start
        : (now.isBefore(c.endExclusive)
              ? now
              : c.endExclusive.subtract(const Duration(days: 1)));
  }

  @override
  void dispose() {
    _cash.dispose();
    _online.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cash = CurrencyHelper.parse(_cash.text);
    final online = CurrencyHelper.parse(_online.text);
    if (online > 0 && _onlineWalletId == null) {
      _error('Pick the online wallet that received the money.');
      return;
    }
    setState(() => _saving = true);
    final ok = await _money.setCycleFund(
      cash: cash,
      online: online,
      onlineWalletId: _onlineWalletId,
      date: _date,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _money.cycle;
    final online = _money.onlineWallets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            c.openingTotal > 0
                ? 'You are carrying over ${CurrencyHelper.format(c.openingTotal)} '
                      'from the previous cycle '
                      '(cash ${CurrencyHelper.formatShort(c.openingCash)}, '
                      'online ${CurrencyHelper.formatShort(c.openingOnline)}). '
                      'Only enter what you receive now.'
                : 'Enter only the money you receive for this cycle. Leftovers '
                      'from earlier cycles are carried over automatically.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AmountField(controller: _cash, label: 'Received in cash'),
        const SizedBox(height: AppSpacing.md),
        AmountField(controller: _online, label: 'Received online'),
        const SizedBox(height: AppSpacing.md),
        if (online.isEmpty)
          Text(
            'Add a bank or mobile wallet first to record online money.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey('fund-wallet-$_onlineWalletId'),
            initialValue: _onlineWalletId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Online wallet'),
            items: online
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (v) => setState(() => _onlineWalletId = v),
          ),
        const SizedBox(height: AppSpacing.md),
        DateField(
          label: 'Received on',
          value: _date,
          firstDate: c.start,
          lastDate: c.endExclusive.subtract(const Duration(days: 1)),
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save allowance'),
          ),
        ),
      ],
    );
  }
}
