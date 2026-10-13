/// Static string constants for Daylee.
/// All UI text should be referenced from here for easy localization later.
class AppStrings {
  AppStrings._();

  // ── App ────────────────────────────────────────────────────
  static const String appName = 'DayLee';
  static const String appTagline = 'Your daily essentials, all in one place.';

  // ── Navigation ─────────────────────────────────────────────
  static const String navDashboard = 'Home';
  static const String navTasks = 'Tasks';
  static const String navMoney = 'Finance';
  static const String navPrayer = 'Prayers';
  static const String navProfile = 'Profile';

  // ── Dashboard ──────────────────────────────────────────────
  static const String dashboardGreetingMorning = 'Good Morning';
  static const String dashboardGreetingAfternoon = 'Good Afternoon';
  static const String dashboardGreetingEvening = 'Good Evening';
  static const String dashboardCurrentBalance = 'Current Balance';
  static const String dashboardQuickActions = 'Quick Actions';
  static const String dashboardOpenFinance = 'Open Finance';
  static const String dashboardOpenProfile = 'Open Profile';

  // ── Money Management ───────────────────────────────────────
  static const String moneyTitle = 'Money';
  static const String moneyBalance = 'Total Balance';
  static const String moneyAddTransaction = 'Add Transaction';
  static const String moneyEditTransaction = 'Edit Transaction';
  static const String moneyIncome = 'Income';
  static const String moneyExpense = 'Expense';
  static const String moneySaving = 'Saving';
  static const String moneyNoBudget = 'No budget set yet.';
  static const String moneyTransactions = 'Transactions';
  static const String moneyCategory = 'Category';
  static const String moneyNote = 'Note';
  static const String moneyRecurring = 'Recurring';
  static const String moneyBudgets = 'Budgets';
  static const String moneySetBudget = 'Set Budget';
  static const String moneyThisMonth = 'This Month';
  static const String moneySmartInsights = 'Smart Insights';
  static const String moneyNoTransactions = 'No transactions yet.';
  static const String moneyOnline = 'Online';
  static const String moneyOffline = 'Offline (Cash)';
  static const String moneyRemainingOnline = 'Remaining Online';
  static const String moneyRemainingOffline = 'Remaining Offline';
  static const String moneyOnlineSources = 'Online Sources';
  static const String moneyAddSource = 'Add Source';
  static const String moneyMonthlyTracker = 'Monthly Money Tracker';
  static const String moneyMoveRemainingToSavings = 'Move Remaining To Savings';
  static const String moneyUseSavings = 'Use Savings';
  static const String moneyCashout = 'Cashout / Convert';
  static const String moneySourceWallet = 'Source Wallet';
  static const String moneyTargetWallet = 'Target Wallet';
  static const String moneyReference = 'Reference';
  static const String moneyWallet = 'Wallet';

  // ── Profile ────────────────────────────────────────────────
  static const String profileTitle = 'Profile & Settings';
  static const String profileUsageStats = 'Usage Stats';
  static const String profileTheme = 'Theme';
  static const String profileNotifications = 'Notifications';
  static const String profileCurrency = 'Currency';
  static const String profileBackupRestore = 'Backup & Restore';
  static const String profileExport = 'Export Data (CSV)';
  static const String profileSecurity = 'Security Lock';
  static const String profileSecuritySubtitle =
      'Use fingerprint, face, or device passcode';
  static const String profileSecurityInactiveSubtitle =
      'Lock is currently turned off';
  static const String profileGoals = 'Goals';
  static const String profileHabits = 'Habit Tracking';

  // ── Prayer Reminder ─────────────────────────────────────
  static const String prayerTitle = 'Prayer Reminder';
  static const String prayerAdd = 'Add Prayer';
  static const String prayerEdit = 'Edit Prayer';
  static const String prayerNoReminders = 'No prayer reminder yet';
  static const String prayerFrequencyDaily = 'Daily';
  static const String prayerFrequencyWeekly = 'Weekly';
  static const String prayerFrequencyMonthly = 'Monthly';

  // ── Security ──────────────────────────────────────────────
  static const String securityLockTitle = 'Secure Access';
  static const String securityLockMessage =
      'Unlock DayLee with your phone biometrics or built-in password.';
  static const String securityUnlockButton = 'Unlock DayLee';
  static const String securityUnlockReason = 'Authenticate to open DayLee.';
  static const String securityEnableReason =
      'Authenticate once to enable security lock for DayLee.';
  static const String securityUnsupportedTitle = 'Security Not Available';
  static const String securityUnsupportedMessage =
      'This phone does not support device authentication.';
  static const String securityEnableCancelledTitle = 'Security Not Enabled';
  static const String securityEnableCancelledMessage =
      'Authentication was cancelled or failed.';
  static const String securityEnabledTitle = 'Security Enabled';
  static const String securityEnabledMessage =
      'DayLee will require authentication on app launch.';
  static const String securityDisabledTitle = 'Security Disabled';
  static const String securityDisabledMessage =
      'DayLee lock has been turned off.';
  static const String securityAuthFailed =
      'Authentication did not complete. Please try again.';

  // ── Common ─────────────────────────────────────────────────
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String done = 'Done';
  static const String add = 'Add';
  static const String loading = 'Loading...';
  static const String error = 'Something went wrong.';
  static const String retry = 'Retry';
}
