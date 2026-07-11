import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'extra_localized_values.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('nl'),
    Locale('hi'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('el'),
    Locale('pt'),
    Locale('it'),
    Locale('tr'),
    Locale('ar'),
    Locale('bn'),
    Locale('ta'),
    Locale('te'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  String get _languageCode {
    final code = locale.languageCode.toLowerCase();
    return _allLocalizedValues.containsKey(code) ? code : 'en';
  }

  String _text(String key) =>
      _allLocalizedValues[_languageCode]![key] ??
      _localizedValues['en']![key]!;

  String _format(String key, Map<String, String> values) {
    var result = _text(key);
    values.forEach((placeholder, value) {
      result = result.replaceAll('{$placeholder}', value);
    });
    return result;
  }

  String get appName => _text('appName');
  String get startingApp => _text('startingApp');
  String get preparingStartup => _text('preparingStartup');
  String get startupFailed => _text('startupFailed');
  String get loadingWallet => _text('loadingWallet');
  String get unableRestoreSession => _text('unableRestoreSession');
  String get welcomeBack => _text('welcomeBack');
  String get createYourAccount => _text('createYourAccount');
  String get signInBody => _text('signInBody');
  String get signUpBody => _text('signUpBody');
  String get login => _text('login');
  String get signUp => _text('signUp');
  String get email => _text('email');
  String get password => _text('password');
  String get enterYourEmail => _text('enterYourEmail');
  String get enterValidEmail => _text('enterValidEmail');
  String get enterYourPassword => _text('enterYourPassword');
  String get useAtLeast6Chars => _text('useAtLeast6Chars');
  String get forgotPassword => _text('forgotPassword');
  String get resetPassword => _text('resetPassword');
  String get emailHint => _text('emailHint');
  String get cancel => _text('cancel');
  String get sendResetLink => _text('sendResetLink');
  String passwordResetEmailSent(String email) =>
      _format('passwordResetEmailSent', {'email': email});
  String get unableSendResetEmail => _text('unableSendResetEmail');
  String get firebaseAuthNotice => _text('firebaseAuthNotice');
  String get createAccount => _text('createAccount');
  String get secureAccessDashboard => _text('secureAccessDashboard');
  String get firestoreBalanceStored => _text('firestoreBalanceStored');
  String get authenticationFailed => _text('authenticationFailed');
  String get noUserSessionFound => _text('noUserSessionFound');
  String get home => _text('home');
  String get earn => _text('earn');
  String get wallet => _text('wallet');
  String get profile => _text('profile');
  String get rewardConfirmedViewsAdded => _text('rewardConfirmedViewsAdded');
  String get rewardedAdNotCompleted => _text('rewardedAdNotCompleted');
  String get watchVideo => _text('watchVideo');
  String get loading => _text('loading');
  String get welcomeBackShort => _text('welcomeBackShort');
  String get signedInUser => _text('signedInUser');
  String get watchVideosEarnPaid => _text('watchVideosEarnPaid');
  String get currentViews => _text('currentViews');
  String get videosWatched => _text('videosWatched');
  String get progressToPayout => _text('progressToPayout');
  String get youAreOnYourWay => _text('youAreOnYourWay');
  String get earnViewsNow => _text('earnViewsNow');
  String get payoutUnlocked => _text('payoutUnlocked');
  String moreViewsUntilPayout(String views) =>
      _format('moreViewsUntilPayout', {'views': views});
  String get dailyBonus => _text('dailyBonus');
  String watchDailyVideosBonus(String videos) =>
      _format('watchDailyVideosBonus', {'videos': videos});
  String get bonusClaimed => _text('bonusClaimed');
  String get bonus => _text('bonus');
  String get earnViewsTitle => _text('earnViewsTitle');
  String get watchRewardedEarnViews => _text('watchRewardedEarnViews');
  String get earnViews => _text('earnViews');
  String get howItWorks => _text('howItWorks');
  String get watch => _text('watch');
  String get watchShortVideo => _text('watchShortVideo');
  String get earnStep => _text('earnStep');
  String get getViewsReward => _text('getViewsReward');
  String get cashOut => _text('cashOut');
  String reachViews(String views) => _format('reachViews', {'views': views});
  String get dailyChallenge => _text('dailyChallenge');
  String watchTodayVideosBonus(String videos) =>
      _format('watchTodayVideosBonus', {'videos': videos});
  String get totalVideosWatched => _text('totalVideosWatched');
  String memberSince(String date) => _format('memberSince', {'date': date});
  String get notAvailableYet => _text('notAvailableYet');
  String get emailVerified => _text('emailVerified');
  String get emailNotVerified => _text('emailNotVerified');
  String get security => _text('security');
  String get firebaseProtected => _text('firebaseProtected');
  String get payoutReview => _text('payoutReview');
  String get adminApproval => _text('adminApproval');
  String get readAdminReplies => _text('readAdminReplies');
  String get notificationsPrivacy => _text('notificationsPrivacy');
  String get contactAdmin => _text('contactAdmin');
  String get reportProblemBug => _text('reportProblemBug');
  String get rateApp => _text('rateApp');
  String get sendInAppRating => _text('sendInAppRating');
  String get aboutVideoMoney => _text('aboutVideoMoney');
  String get reviewPayoutRequests => _text('reviewPayoutRequests');
  String get logout => _text('logout');
  String get yourWallet => _text('yourWallet');
  String get availableViews => _text('availableViews');
  String get estimatedPayout => _text('estimatedPayout');
  String get remainingToPayout => _text('remainingToPayout');
  String get viewsUnit => _text('viewsUnit');
  String get estimateOnly => _text('estimateOnly');
  String get requestPayout => _text('requestPayout');
  String get minPayout => _text('minPayout');
  String get processingTime => _text('processingTime');
  String get approval => _text('approval');
  String get adminReview => _text('adminReview');
  String get payoutMethods => _text('payoutMethods');
  String get payoutHistory => _text('payoutHistory');
  String get noPayoutRequestsYet => _text('noPayoutRequestsYet');
  String get pendingTimestamp => _text('pendingTimestamp');
  String get paypalSubtitle => _text('paypalSubtitle');
  String get revolutSubtitle => _text('revolutSubtitle');
  String get bankTransferTitle => _text('bankTransferTitle');
  String get bankTransferSubtitle => _text('bankTransferSubtitle');
  String get viewFullHistory => _text('viewFullHistory');
  String get inbox => _text('inbox');
  String get markAllRead => _text('markAllRead');
  String get noInboxMessagesYet => _text('noInboxMessagesYet');
  String get newBadge => _text('newBadge');
  String get rateAppQuestion => _text('rateAppQuestion');
  String get choose1to5 => _text('choose1to5');
  String get saveRating => _text('saveRating');
  String get thanksForRating => _text('thanksForRating');
  String get requestPayoutTitle => _text('requestPayoutTitle');
  String get payoutRules => _text('payoutRules');
  String minimumPayoutIs(String views) =>
      _format('minimumPayoutIs', {'views': views});
  String processingCanTake(String days) =>
      _format('processingCanTake', {'days': days});
  String get everyRequestReviewed => _text('everyRequestReviewed');
  String get useBankAddIban => _text('useBankAddIban');
  String get submitUsingBalance => _text('submitUsingBalance');
  String get estimatedEarningsNotGuaranteed =>
      _text('estimatedEarningsNotGuaranteed');
  String get payoutCurrency => _text('payoutCurrency');
  String get payoutMethod => _text('payoutMethod');
  String get viewsToRequest => _text('viewsToRequest');
  String get minimumViewsHelper => _text('minimumViewsHelper');
  String get enterAmount => _text('enterAmount');
  String get enterValidPositiveNumber => _text('enterValidPositiveNumber');
  String get accountHolderName => _text('accountHolderName');
  String get enterAccountHolderName => _text('enterAccountHolderName');
  String get paypalEmail => _text('paypalEmail');
  String get enterPaypalEmail => _text('enterPaypalEmail');
  String get enterValidPaypalEmail => _text('enterValidPaypalEmail');
  String get revolutUsername => _text('revolutUsername');
  String get revolutExample => _text('revolutExample');
  String get enterRevolutUsername => _text('enterRevolutUsername');
  String get bankName => _text('bankName');
  String get enterBankName => _text('enterBankName');
  String get iban => _text('iban');
  String get ibanOptional => _text('ibanOptional');
  String get bankAccountNumber => _text('bankAccountNumber');
  String get bankRequiredIfNoIban => _text('bankRequiredIfNoIban');
  String get enterIbanOrBank => _text('enterIbanOrBank');
  String get submitRequest => _text('submitRequest');
  String get payoutRequestSubmitted => _text('payoutRequestSubmitted');
  String get payoutHistoryTitle => _text('payoutHistoryTitle');
  String get unableLoadPayoutHistory => _text('unableLoadPayoutHistory');
  String currencyLabel(String currency) =>
      _format('currencyLabel', {'currency': currency});
  String accountHolderLabel(String value) =>
      _format('accountHolderLabel', {'value': value});
  String get notProvided => _text('notProvided');
  String get helpSupport => _text('helpSupport');
  String get openSupportTicket => _text('openSupportTicket');
  String get describeIssueAdminReply => _text('describeIssueAdminReply');
  String get subject => _text('subject');
  String get helpSubjectHint => _text('helpSubjectHint');
  String get message => _text('message');
  String get messageHint => _text('messageHint');
  String get send => _text('send');
  String get sending => _text('sending');
  String get openInbox => _text('openInbox');
  String get yourTickets => _text('yourTickets');
  String get noSupportTicketsYet => _text('noSupportTicketsYet');
  String get supportMessageSent => _text('supportMessageSent');
  String adminReply(String value) => _format('adminReply', {'value': value});
  String get reportBug => _text('reportBug');
  String get tellUsWhatHappened => _text('tellUsWhatHappened');
  String get includeStepsExpected => _text('includeStepsExpected');
  String get title => _text('title');
  String get shortSummary => _text('shortSummary');
  String get description => _text('description');
  String get describeBug => _text('describeBug');
  String get submit => _text('submit');
  String get bugReportSubmitted => _text('bugReportSubmitted');
  String get aboutTagline => _text('aboutTagline');
  String get version => _text('version');
  String get minimumPayoutLabel => _text('minimumPayoutLabel');
  String get processingTimeLabel => _text('processingTimeLabel');
  String get reviewLabel => _text('reviewLabel');
  String get estimatedEarningsOnlyPolicies =>
      _text('estimatedEarningsOnlyPolicies');
  String get privacyPolicy => _text('privacyPolicy');
  String get termsOfService => _text('termsOfService');
  String get notifications => _text('notifications');
  String get enableNotifications => _text('enableNotifications');
  String get generalAppNotifications => _text('generalAppNotifications');
  String get dailyReminder => _text('dailyReminder');
  String get dailyReminderSubtitle => _text('dailyReminderSubtitle');
  String get settingsSaved => _text('settingsSaved');
  String get privacy => _text('privacy');
  String get appVersion => _text('appVersion');
  String get save => _text('save');
  String get saving => _text('saving');
  String get termsUsingTitle => _text('termsUsingTitle');
  String get termsViewsTitle => _text('termsViewsTitle');
  String get termsPayoutsTitle => _text('termsPayoutsTitle');
  String get termsSupportTitle => _text('termsSupportTitle');
  String get termsUsingBullet1 => _text('termsUsingBullet1');
  String get termsUsingBullet2 => _text('termsUsingBullet2');
  String get termsUsingBullet3 => _text('termsUsingBullet3');
  String get termsViewsBullet1 => _text('termsViewsBullet1');
  String get termsViewsBullet2 => _text('termsViewsBullet2');
  String get termsViewsBullet3 => _text('termsViewsBullet3');
  String get termsPayoutsBullet1 => _text('termsPayoutsBullet1');
  String get termsPayoutsBullet2 => _text('termsPayoutsBullet2');
  String get termsPayoutsBullet3 => _text('termsPayoutsBullet3');
  String get termsSupportBullet1 => _text('termsSupportBullet1');
  String get termsSupportBullet2 => _text('termsSupportBullet2');
  String get termsSupportBullet3 => _text('termsSupportBullet3');
  String get settingsTitle => _text('settingsTitle');
  String get appLanguage => _text('appLanguage');
  String get appLanguageSubtitle => _text('appLanguageSubtitle');
  String get automaticLanguage => _text('automaticLanguage');

  String payoutStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _text('statusPending');
      case 'approved':
        return _text('statusApproved');
      case 'paid':
        return _text('statusPaid');
      case 'rejected':
        return _text('statusRejected');
      default:
        return status.toUpperCase();
    }
  }

  String supportStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _text('statusPending');
      case 'processing':
        return _text('statusProcessing');
      case 'fixed':
        return _text('statusFixed');
      case 'closed':
        return _text('statusClosed');
      default:
        return status.toUpperCase();
    }
  }

  String supportType(String type) {
    switch (type.toLowerCase()) {
      case 'support':
        return _text('typeSupport');
      case 'payment':
        return _text('typePayment');
      case 'bug':
        return _text('typeBug');
      default:
        return type.toUpperCase();
    }
  }

  static const Map<String, Map<String, String>> _allLocalizedValues = {
    ..._localizedValues,
    ...extraLocalizedValues,
  };

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'VideoMoney',
      'startingApp': 'Starting VideoMoney',
      'preparingStartup':
          'Preparing Firebase, wallet data, and rewarded ads...',
      'startupFailed': 'Startup failed',
      'loadingWallet': 'Loading your wallet...',
      'unableRestoreSession': 'Unable to restore your session right now.',
      'welcomeBack': 'Welcome back',
      'createYourAccount': 'Create your account',
      'signInBody':
          'Sign in to keep earning views and managing payouts.',
      'signUpBody':
          'Register to start watching rewarded videos and building your balance.',
      'login': 'Login',
      'signUp': 'Sign up',
      'email': 'Email',
      'password': 'Password',
      'enterYourEmail': 'Enter your email.',
      'enterValidEmail': 'Enter a valid email address.',
      'enterYourPassword': 'Enter your password.',
      'useAtLeast6Chars': 'Use at least 6 characters.',
      'forgotPassword': 'Forgot password?',
      'resetPassword': 'Reset password',
      'emailHint': 'name@example.com',
      'cancel': 'Cancel',
      'sendResetLink': 'Send reset link',
      'passwordResetEmailSent': 'Password reset email sent to {email}.',
      'unableSendResetEmail': 'Unable to send reset email.',
      'firebaseAuthNotice':
          'Firebase Authentication stays unchanged. This redesign only updates the presentation layer.',
      'createAccount': 'Create account',
      'secureAccessDashboard': 'Secure access to your earning dashboard',
      'firestoreBalanceStored':
          'Your payout history and reward balance are stored in Firestore',
      'authenticationFailed': 'Authentication failed.',
      'noUserSessionFound': 'No user session found.',
      'home': 'Home',
      'earn': 'Earn',
      'wallet': 'Wallet',
      'profile': 'Profile',
      'rewardConfirmedViewsAdded': 'Reward confirmed. Views added.',
      'rewardedAdNotCompleted': 'Rewarded ad was not completed.',
      'watchVideo': 'Watch Video',
      'loading': 'Loading...',
      'welcomeBackShort': 'Welcome back,',
      'signedInUser': 'Signed-in user',
      'watchVideosEarnPaid': 'Watch videos, earn views, and get paid.',
      'currentViews': 'Current Views',
      'videosWatched': 'Videos Watched',
      'progressToPayout': 'Progress to payout',
      'youAreOnYourWay': 'You\'re on your way.',
      'earnViewsNow': 'Earn views now.',
      'payoutUnlocked': 'Payout unlocked. You can request payout in the Wallet.',
      'moreViewsUntilPayout': '{views} more views until payout.',
      'dailyBonus': 'Daily Bonus',
      'watchDailyVideosBonus':
          'Watch {videos} videos daily to get bonus views.',
      'bonusClaimed': 'Bonus claimed',
      'bonus': 'Bonus',
      'earnViewsTitle': 'Earn Views',
      'watchRewardedEarnViews':
          'Watch rewarded videos and earn views instantly.',
      'earnViews': 'Earn views',
      'howItWorks': 'How it works',
      'watch': 'Watch',
      'watchShortVideo': 'Watch a short video',
      'earnStep': 'Earn',
      'getViewsReward': 'Get views as reward',
      'cashOut': 'Cash Out',
      'reachViews': 'Reach {views} views',
      'dailyChallenge': 'Daily Challenge',
      'watchTodayVideosBonus':
          'Watch {videos} videos today and get bonus views!',
      'totalVideosWatched': 'Total videos watched',
      'memberSince': 'Member since: {date}',
      'notAvailableYet': 'Not available yet',
      'emailVerified': 'Email Verified',
      'emailNotVerified': 'Email not verified',
      'security': 'Security',
      'firebaseProtected': 'Firebase Protected',
      'payoutReview': 'Payout Review',
      'adminApproval': 'Admin Approval',
      'readAdminReplies': 'Read admin replies and notifications',
      'notificationsPrivacy': 'Notifications, privacy, and app settings',
      'contactAdmin': 'Contact admin and send messages',
      'reportProblemBug': 'Report a problem or a bug',
      'rateApp': 'Rate App',
      'sendInAppRating': 'Send your in-app rating from 1 to 5 stars',
      'aboutVideoMoney': 'About VideoMoney',
      'reviewPayoutRequests': 'Review payout requests',
      'logout': 'Logout',
      'yourWallet': 'Your Wallet',
      'availableViews': 'Available Views',
      'estimatedPayout': 'Estimated Payout',
      'remainingToPayout': 'Remaining to Payout',
      'viewsUnit': 'views',
      'estimateOnly':
          'Estimate only. 50 views ≈ €0.01 and actual earnings may vary.',
      'requestPayout': 'Request Payout',
      'minPayout': 'Min. Payout',
      'processingTime': 'Processing Time',
      'approval': 'Approval',
      'adminReview': 'Admin review',
      'payoutMethods': 'Payout Methods',
      'payoutHistory': 'Payout History',
      'noPayoutRequestsYet': 'No payout requests yet.',
      'pendingTimestamp': 'Pending timestamp',
      'paypalSubtitle': 'Request payout in EUR, GBP, or USD',
      'revolutSubtitle': 'Fast wallet payout with chosen currency',
      'bankTransferTitle': 'Bank Transfer',
      'bankTransferSubtitle':
          'Add IBAN or bank account number for manual payout',
      'viewFullHistory': 'View full history',
      'inbox': 'Inbox',
      'markAllRead': 'Mark all read',
      'noInboxMessagesYet': 'No inbox messages yet.',
      'newBadge': 'NEW',
      'rateAppQuestion': 'How would you rate VideoMoney?',
      'choose1to5':
          'Choose between 1 and 5 stars. You can update your rating later.',
      'saveRating': 'Save rating',
      'thanksForRating': 'Thanks for your rating.',
      'requestPayoutTitle': 'Request Payout',
      'payoutRules': 'Payout rules',
      'minimumPayoutIs': 'Minimum payout is {views} views.',
      'processingCanTake':
          'Processing can take up to {days} days after admin approval.',
      'everyRequestReviewed':
          'Every request is reviewed by admin before it is paid.',
      'useBankAddIban':
          'Use Bank for manual transfer and add your IBAN or bank account number.',
      'submitUsingBalance':
          'Submit a payout request using your view balance.',
      'estimatedEarningsNotGuaranteed':
          'Estimated earnings only. 50 completed views ≈ €0.01 and this is not a guaranteed payout promise.',
      'payoutCurrency': 'Payout currency',
      'payoutMethod': 'Payout method',
      'viewsToRequest': 'Views to request',
      'minimumViewsHelper': 'Minimum 10,000 views',
      'enterAmount': 'Enter an amount.',
      'enterValidPositiveNumber': 'Enter a valid positive number.',
      'accountHolderName': 'Account holder name',
      'enterAccountHolderName': 'Enter the account holder name.',
      'paypalEmail': 'PayPal email',
      'enterPaypalEmail': 'Enter a PayPal email.',
      'enterValidPaypalEmail': 'Enter a valid PayPal email.',
      'revolutUsername': 'Revolut username',
      'revolutExample': 'Example: @yourname',
      'enterRevolutUsername': 'Enter your Revolut username.',
      'bankName': 'Bank name',
      'enterBankName': 'Enter your bank name.',
      'iban': 'IBAN',
      'ibanOptional': 'Optional if you provide a bank account number',
      'bankAccountNumber': 'Bank account number',
      'bankRequiredIfNoIban':
          'Required if you do not enter an IBAN',
      'enterIbanOrBank': 'Enter an IBAN or bank account number.',
      'submitRequest': 'Submit Request',
      'payoutRequestSubmitted': 'Payout request submitted.',
      'payoutHistoryTitle': 'Payout History',
      'unableLoadPayoutHistory':
          'Unable to load payout history right now.',
      'currencyLabel': 'Currency: {currency}',
      'accountHolderLabel': 'Account holder: {value}',
      'notProvided': 'Not provided',
      'helpSupport': 'Help & Support',
      'openSupportTicket': 'Open a support ticket',
      'describeIssueAdminReply':
          'Describe your issue and the admin can reply in your inbox.',
      'subject': 'Subject',
      'helpSubjectHint': 'What do you need help with?',
      'message': 'Message',
      'messageHint': 'Write your message here...',
      'send': 'Send',
      'sending': 'Sending...',
      'openInbox': 'Open inbox',
      'yourTickets': 'Your tickets',
      'noSupportTicketsYet': 'No support tickets yet.',
      'supportMessageSent': 'Support message sent.',
      'adminReply': 'Admin reply: {value}',
      'reportBug': 'Report Bug',
      'tellUsWhatHappened': 'Tell us what happened',
      'includeStepsExpected':
          'Include steps to reproduce and what you expected to see.',
      'title': 'Title',
      'shortSummary': 'Short summary',
      'description': 'Description',
      'describeBug': 'Describe the bug...',
      'submit': 'Submit',
      'bugReportSubmitted': 'Bug report submitted.',
      'aboutTagline': 'Premium dark theme • Neon green UI',
      'version': 'Version',
      'minimumPayoutLabel': 'Minimum payout',
      'processingTimeLabel': 'Processing time',
      'reviewLabel': 'Review',
      'estimatedEarningsOnlyPolicies':
          'Estimated earnings only. Actual earnings may vary based on ad performance and policy rules.',
      'privacyPolicy': 'Privacy Policy',
      'termsOfService': 'Terms of Service',
      'notifications': 'Notifications',
      'enableNotifications': 'Enable notifications',
      'generalAppNotifications': 'General app notifications',
      'dailyReminder': 'Daily reminder',
      'dailyReminderSubtitle':
          'Get a reminder to complete daily bonus',
      'settingsSaved': 'Settings saved.',
      'privacy': 'Privacy',
      'appVersion': 'App version',
      'save': 'Save',
      'saving': 'Saving...',
      'termsUsingTitle': 'Using VideoMoney',
      'termsViewsTitle': 'Views and rewards',
      'termsPayoutsTitle': 'Payouts and review',
      'termsSupportTitle': 'Support and messages',
      'termsUsingBullet1': 'You must use accurate account information.',
      'termsUsingBullet2':
          'One person may not abuse multiple accounts, bots, scripts, VPN rotation, or emulator farms to generate extra views.',
      'termsUsingBullet3':
          'Rewarded ads, Firebase authentication, and payout review remain protected by the existing platform setup.',
      'termsViewsBullet1':
          'Views shown in the app are promotional reward units used inside VideoMoney.',
      'termsViewsBullet2':
          'Estimated earnings are informational only and can change based on platform performance, policy, fraud checks, and payout review.',
      'termsViewsBullet3':
          'Daily bonus rewards are limited to eligible activity and can be removed if abuse is detected.',
      'termsPayoutsBullet1': 'Minimum payout remains 10,000 views.',
      'termsPayoutsBullet2':
          'All payout requests require manual admin approval and can be approved, rejected, or marked paid.',
      'termsPayoutsBullet3':
          'Rejected payout requests may be refunded back to the user balance when allowed by the admin workflow.',
      'termsSupportBullet1':
          'Help & Support, bug reports, admin replies, and push notifications can be stored in your in-app inbox.',
      'termsSupportBullet2':
          'By enabling notifications, you allow VideoMoney to send app updates, support replies, and daily reminder messages to your device.',
      'termsSupportBullet3':
          'Serious misuse, harassment, or fraudulent activity can lead to restriction of app access.',
      'settingsTitle': 'Settings',
      'appLanguage': 'App language',
      'appLanguageSubtitle':
          'Use automatic device language or choose a language manually.',
      'automaticLanguage': 'Automatic (device language)',
      'statusPending': 'PENDING',
      'statusApproved': 'APPROVED',
      'statusPaid': 'PAID',
      'statusRejected': 'REJECTED',
      'statusProcessing': 'PROCESSING',
      'statusFixed': 'FIXED',
      'statusClosed': 'CLOSED',
      'typeSupport': 'SUPPORT',
      'typePayment': 'PAYMENT',
      'typeBug': 'BUG',
    },
    'nl': {
      'appName': 'VideoMoney',
      'startingApp': 'VideoMoney start op',
      'preparingStartup':
          'Firebase, walletgegevens en rewarded ads worden voorbereid...',
      'startupFailed': 'Opstarten mislukt',
      'loadingWallet': 'Je wallet wordt geladen...',
      'unableRestoreSession': 'Je sessie kon nu niet worden hersteld.',
      'welcomeBack': 'Welkom terug',
      'createYourAccount': 'Maak je account aan',
      'signInBody':
          'Log in om views te blijven verdienen en uitbetalingen te beheren.',
      'signUpBody':
          'Registreer om rewarded video\'s te kijken en je saldo op te bouwen.',
      'login': 'Inloggen',
      'signUp': 'Registreren',
      'email': 'E-mail',
      'password': 'Wachtwoord',
      'enterYourEmail': 'Voer je e-mail in.',
      'enterValidEmail': 'Voer een geldig e-mailadres in.',
      'enterYourPassword': 'Voer je wachtwoord in.',
      'useAtLeast6Chars': 'Gebruik minimaal 6 tekens.',
      'forgotPassword': 'Wachtwoord vergeten?',
      'resetPassword': 'Wachtwoord resetten',
      'emailHint': 'naam@voorbeeld.com',
      'cancel': 'Annuleren',
      'sendResetLink': 'Resetlink sturen',
      'passwordResetEmailSent': 'Resetmail verzonden naar {email}.',
      'unableSendResetEmail': 'Resetmail kon niet worden verzonden.',
      'firebaseAuthNotice':
          'Firebase Authentication blijft ongewijzigd. Dit ontwerp past alleen de presentatie aan.',
      'createAccount': 'Account aanmaken',
      'secureAccessDashboard': 'Veilige toegang tot je verdien-dashboard',
      'firestoreBalanceStored':
          'Je uitbetalingsgeschiedenis en beloningssaldo worden in Firestore opgeslagen',
      'authenticationFailed': 'Authenticatie mislukt.',
      'noUserSessionFound': 'Geen gebruikerssessie gevonden.',
      'home': 'Home',
      'earn': 'Verdien',
      'wallet': 'Wallet',
      'profile': 'Profiel',
      'rewardConfirmedViewsAdded': 'Beloning bevestigd. Views toegevoegd.',
      'rewardedAdNotCompleted': 'De rewarded advertentie is niet voltooid.',
      'watchVideo': 'Video bekijken',
      'loading': 'Laden...',
      'welcomeBackShort': 'Welkom terug,',
      'signedInUser': 'Ingelogde gebruiker',
      'watchVideosEarnPaid': 'Bekijk video\'s, verdien views en laat je uitbetalen.',
      'currentViews': 'Huidige views',
      'videosWatched': 'Video\'s bekeken',
      'progressToPayout': 'Voortgang naar uitbetaling',
      'youAreOnYourWay': 'Je bent goed op weg.',
      'earnViewsNow': 'Verdien nu views.',
      'payoutUnlocked':
          'Uitbetaling vrijgespeeld. Je kunt nu een uitbetaling aanvragen in Wallet.',
      'moreViewsUntilPayout': 'Nog {views} views tot uitbetaling.',
      'dailyBonus': 'Dagelijkse bonus',
      'watchDailyVideosBonus':
          'Bekijk dagelijks {videos} video\'s voor bonusviews.',
      'bonusClaimed': 'Bonus geclaimd',
      'bonus': 'Bonus',
      'earnViewsTitle': 'Views verdienen',
      'watchRewardedEarnViews':
          'Bekijk rewarded video\'s en verdien direct views.',
      'earnViews': 'Verdien views',
      'howItWorks': 'Hoe het werkt',
      'watch': 'Kijk',
      'watchShortVideo': 'Bekijk een korte video',
      'earnStep': 'Verdien',
      'getViewsReward': 'Krijg views als beloning',
      'cashOut': 'Uitcashen',
      'reachViews': 'Bereik {views} views',
      'dailyChallenge': 'Dagelijkse challenge',
      'watchTodayVideosBonus':
          'Bekijk vandaag {videos} video\'s en krijg bonusviews!',
      'totalVideosWatched': 'Totaal video\'s bekeken',
      'memberSince': 'Lid sinds: {date}',
      'notAvailableYet': 'Nog niet beschikbaar',
      'emailVerified': 'E-mail geverifieerd',
      'emailNotVerified': 'E-mail niet geverifieerd',
      'security': 'Beveiliging',
      'firebaseProtected': 'Beschermd door Firebase',
      'payoutReview': 'Uitbetalingscontrole',
      'adminApproval': 'Goedkeuring door admin',
      'readAdminReplies': 'Lees admin-antwoorden en meldingen',
      'notificationsPrivacy': 'Meldingen, privacy en app-instellingen',
      'contactAdmin': 'Neem contact op met admin en stuur berichten',
      'reportProblemBug': 'Meld een probleem of bug',
      'rateApp': 'App beoordelen',
      'sendInAppRating': 'Stuur je beoordeling van 1 tot 5 sterren',
      'aboutVideoMoney': 'Over VideoMoney',
      'reviewPayoutRequests': 'Bekijk uitbetalingsaanvragen',
      'logout': 'Uitloggen',
      'yourWallet': 'Jouw wallet',
      'availableViews': 'Beschikbare views',
      'estimatedPayout': 'Geschatte uitbetaling',
      'remainingToPayout': 'Nog nodig voor uitbetaling',
      'viewsUnit': 'views',
      'estimateOnly':
          'Alleen een schatting. 50 views ≈ €0,01 en de werkelijke opbrengst kan afwijken.',
      'requestPayout': 'Uitbetaling aanvragen',
      'minPayout': 'Min. uitbetaling',
      'processingTime': 'Verwerkingstijd',
      'approval': 'Goedkeuring',
      'adminReview': 'Admincontrole',
      'payoutMethods': 'Uitbetalingsmethoden',
      'payoutHistory': 'Uitbetalingsgeschiedenis',
      'noPayoutRequestsYet': 'Nog geen uitbetalingsaanvragen.',
      'pendingTimestamp': 'Tijdstip volgt nog',
      'paypalSubtitle': 'Vraag uitbetaling aan in EUR, GBP of USD',
      'revolutSubtitle': 'Snelle wallet-uitbetaling in gekozen valuta',
      'bankTransferTitle': 'Bankoverschrijving',
      'bankTransferSubtitle':
          'Voeg IBAN of rekeningnummer toe voor handmatige uitbetaling',
      'viewFullHistory': 'Volledige geschiedenis bekijken',
      'inbox': 'Inbox',
      'markAllRead': 'Alles als gelezen markeren',
      'noInboxMessagesYet': 'Nog geen inboxberichten.',
      'newBadge': 'NIEUW',
      'rateAppQuestion': 'Hoe zou je VideoMoney beoordelen?',
      'choose1to5':
          'Kies tussen 1 en 5 sterren. Je kunt je beoordeling later aanpassen.',
      'saveRating': 'Beoordeling opslaan',
      'thanksForRating': 'Bedankt voor je beoordeling.',
      'requestPayoutTitle': 'Uitbetaling aanvragen',
      'payoutRules': 'Uitbetalingsregels',
      'minimumPayoutIs': 'De minimale uitbetaling is {views} views.',
      'processingCanTake':
          'Verwerking kan tot {days} dagen duren na goedkeuring door de admin.',
      'everyRequestReviewed':
          'Elke aanvraag wordt door de admin beoordeeld voordat deze wordt uitbetaald.',
      'useBankAddIban':
          'Gebruik Bank voor handmatige overschrijving en voeg je IBAN of rekeningnummer toe.',
      'submitUsingBalance':
          'Dien een uitbetalingsaanvraag in met je viewsaldo.',
      'estimatedEarningsNotGuaranteed':
          'Alleen geschatte inkomsten. 50 afgeronde views ≈ €0,01 en dit is geen gegarandeerde uitbetalingsbelofte.',
      'payoutCurrency': 'Uitbetalingsvaluta',
      'payoutMethod': 'Uitbetalingsmethode',
      'viewsToRequest': 'Aan te vragen views',
      'minimumViewsHelper': 'Minimaal 10.000 views',
      'enterAmount': 'Voer een bedrag in.',
      'enterValidPositiveNumber': 'Voer een geldig positief getal in.',
      'accountHolderName': 'Naam rekeninghouder',
      'enterAccountHolderName': 'Voer de naam van de rekeninghouder in.',
      'paypalEmail': 'PayPal-e-mail',
      'enterPaypalEmail': 'Voer een PayPal-e-mail in.',
      'enterValidPaypalEmail': 'Voer een geldig PayPal-e-mailadres in.',
      'revolutUsername': 'Revolut-gebruikersnaam',
      'revolutExample': 'Voorbeeld: @jouwnaam',
      'enterRevolutUsername': 'Voer je Revolut-gebruikersnaam in.',
      'bankName': 'Banknaam',
      'enterBankName': 'Voer je banknaam in.',
      'iban': 'IBAN',
      'ibanOptional': 'Optioneel als je een rekeningnummer invult',
      'bankAccountNumber': 'Rekeningnummer',
      'bankRequiredIfNoIban': 'Verplicht als je geen IBAN invult',
      'enterIbanOrBank': 'Voer een IBAN of rekeningnummer in.',
      'submitRequest': 'Aanvraag versturen',
      'payoutRequestSubmitted': 'Uitbetalingsaanvraag verzonden.',
      'payoutHistoryTitle': 'Uitbetalingsgeschiedenis',
      'unableLoadPayoutHistory':
          'De uitbetalingsgeschiedenis kan nu niet worden geladen.',
      'currencyLabel': 'Valuta: {currency}',
      'accountHolderLabel': 'Rekeninghouder: {value}',
      'notProvided': 'Niet opgegeven',
      'helpSupport': 'Hulp & support',
      'openSupportTicket': 'Open een supportticket',
      'describeIssueAdminReply':
          'Beschrijf je probleem en de admin kan in je inbox antwoorden.',
      'subject': 'Onderwerp',
      'helpSubjectHint': 'Waar heb je hulp bij nodig?',
      'message': 'Bericht',
      'messageHint': 'Schrijf hier je bericht...',
      'send': 'Versturen',
      'sending': 'Versturen...',
      'openInbox': 'Inbox openen',
      'yourTickets': 'Jouw tickets',
      'noSupportTicketsYet': 'Nog geen supporttickets.',
      'supportMessageSent': 'Supportbericht verzonden.',
      'adminReply': 'Admin-antwoord: {value}',
      'reportBug': 'Bug melden',
      'tellUsWhatHappened': 'Vertel ons wat er gebeurde',
      'includeStepsExpected':
          'Voeg stappen toe om het probleem te herhalen en wat je verwachtte te zien.',
      'title': 'Titel',
      'shortSummary': 'Korte samenvatting',
      'description': 'Beschrijving',
      'describeBug': 'Beschrijf de bug...',
      'submit': 'Versturen',
      'bugReportSubmitted': 'Bugrapport verzonden.',
      'aboutTagline': 'Premium donker thema • Neon groene UI',
      'version': 'Versie',
      'minimumPayoutLabel': 'Minimale uitbetaling',
      'processingTimeLabel': 'Verwerkingstijd',
      'reviewLabel': 'Controle',
      'estimatedEarningsOnlyPolicies':
          'Alleen geschatte inkomsten. Werkelijke inkomsten kunnen verschillen door advertentieprestaties en beleidsregels.',
      'privacyPolicy': 'Privacybeleid',
      'termsOfService': 'Gebruiksvoorwaarden',
      'notifications': 'Meldingen',
      'enableNotifications': 'Meldingen inschakelen',
      'generalAppNotifications': 'Algemene appmeldingen',
      'dailyReminder': 'Dagelijkse herinnering',
      'dailyReminderSubtitle':
          'Ontvang een herinnering voor je dagelijkse bonus',
      'settingsSaved': 'Instellingen opgeslagen.',
      'privacy': 'Privacy',
      'appVersion': 'Appversie',
      'save': 'Opslaan',
      'saving': 'Opslaan...',
      'termsUsingTitle': 'VideoMoney gebruiken',
      'termsViewsTitle': 'Views en beloningen',
      'termsPayoutsTitle': 'Uitbetalingen en controle',
      'termsSupportTitle': 'Support en berichten',
      'termsUsingBullet1':
          'Je moet correcte accountgegevens gebruiken.',
      'termsUsingBullet2':
          'Eén persoon mag geen misbruik maken van meerdere accounts, bots, scripts, VPN-rotatie of emulatorfarms om extra views te genereren.',
      'termsUsingBullet3':
          'Rewarded advertenties, Firebase-authenticatie en uitbetalingscontrole blijven beschermd door de bestaande platformopzet.',
      'termsViewsBullet1':
          'Views in de app zijn promotionele beloningseenheden die binnen VideoMoney worden gebruikt.',
      'termsViewsBullet2':
          'Geschatte inkomsten zijn alleen informatief en kunnen veranderen door platformprestaties, beleid, fraudebeperking en uitbetalingscontrole.',
      'termsViewsBullet3':
          'Dagelijkse bonusbeloningen zijn beperkt tot geldige activiteit en kunnen worden verwijderd bij misbruik.',
      'termsPayoutsBullet1': 'De minimale uitbetaling blijft 10.000 views.',
      'termsPayoutsBullet2':
          'Alle uitbetalingsaanvragen vereisen handmatige goedkeuring door de admin en kunnen worden goedgekeurd, afgewezen of als betaald worden gemarkeerd.',
      'termsPayoutsBullet3':
          'Afgewezen uitbetalingsaanvragen kunnen worden teruggestort op het gebruikerssaldo als de admin-workflow dat toestaat.',
      'termsSupportBullet1':
          'Hulp & support, bugmeldingen, admin-antwoorden en pushmeldingen kunnen worden opgeslagen in je inbox in de app.',
      'termsSupportBullet2':
          'Door meldingen in te schakelen, geef je VideoMoney toestemming om app-updates, supportantwoorden en dagelijkse herinneringen naar je apparaat te sturen.',
      'termsSupportBullet3':
          'Ernstig misbruik, intimidatie of frauduleuze activiteit kan leiden tot beperking van apptoegang.',
      'settingsTitle': 'Instellingen',
      'appLanguage': 'App-taal',
      'appLanguageSubtitle':
          'Gebruik automatisch de telefoontaal of kies zelf een taal.',
      'automaticLanguage': 'Automatisch (telefoontaal)',
      'statusPending': 'IN AFWACHTING',
      'statusApproved': 'GOEDGEKEURD',
      'statusPaid': 'BETAALD',
      'statusRejected': 'AFGEWEZEN',
      'statusProcessing': 'IN BEHANDELING',
      'statusFixed': 'OPGELOST',
      'statusClosed': 'GESLOTEN',
      'typeSupport': 'SUPPORT',
      'typePayment': 'BETALING',
      'typeBug': 'BUG',
    },
    'hi': {
      'appName': 'VideoMoney',
      'startingApp': 'VideoMoney शुरू हो रहा है',
      'preparingStartup':
          'Firebase, वॉलेट डेटा और रिवॉर्डेड विज्ञापन तैयार किए जा रहे हैं...',
      'startupFailed': 'शुरुआत विफल रही',
      'loadingWallet': 'आपका वॉलेट लोड हो रहा है...',
      'unableRestoreSession': 'अभी आपका सत्र पुनः स्थापित नहीं किया जा सका।',
      'welcomeBack': 'वापसी पर स्वागत है',
      'createYourAccount': 'अपना खाता बनाएं',
      'signInBody': 'व्यू कमाने और भुगतान प्रबंधित करने के लिए साइन इन करें।',
      'signUpBody':
          'रिवॉर्डेड वीडियो देखने और बैलेंस बनाने के लिए रजिस्टर करें।',
      'login': 'लॉगिन',
      'signUp': 'साइन अप',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'enterYourEmail': 'अपना ईमेल दर्ज करें।',
      'enterValidEmail': 'मान्य ईमेल पता दर्ज करें।',
      'enterYourPassword': 'अपना पासवर्ड दर्ज करें।',
      'useAtLeast6Chars': 'कम से कम 6 अक्षर प्रयोग करें।',
      'forgotPassword': 'पासवर्ड भूल गए?',
      'resetPassword': 'पासवर्ड रीसेट करें',
      'emailHint': 'name@example.com',
      'cancel': 'रद्द करें',
      'sendResetLink': 'रीसेट लिंक भेजें',
      'passwordResetEmailSent': 'पासवर्ड रीसेट ईमेल {email} पर भेजा गया।',
      'unableSendResetEmail': 'रीसेट ईमेल भेजा नहीं जा सका।',
      'firebaseAuthNotice':
          'Firebase Authentication वैसा ही रहता है। यह नया डिज़ाइन केवल प्रस्तुति बदलता है।',
      'createAccount': 'खाता बनाएं',
      'secureAccessDashboard': 'आपके कमाई डैशबोर्ड के लिए सुरक्षित प्रवेश',
      'firestoreBalanceStored':
          'आपका भुगतान इतिहास और रिवॉर्ड बैलेंस Firestore में संग्रहीत है',
      'authenticationFailed': 'प्रमाणीकरण विफल रहा।',
      'noUserSessionFound': 'कोई उपयोगकर्ता सत्र नहीं मिला।',
      'home': 'होम',
      'earn': 'कमाएं',
      'wallet': 'वॉलेट',
      'profile': 'प्रोफ़ाइल',
      'rewardConfirmedViewsAdded': 'रिवॉर्ड की पुष्टि हो गई। व्यू जोड़े गए।',
      'rewardedAdNotCompleted': 'रिवॉर्डेड विज्ञापन पूरा नहीं हुआ।',
      'watchVideo': 'वीडियो देखें',
      'loading': 'लोड हो रहा है...',
      'welcomeBackShort': 'फिर से स्वागत है,',
      'signedInUser': 'साइन-इन उपयोगकर्ता',
      'watchVideosEarnPaid': 'वीडियो देखें, व्यू कमाएं और भुगतान पाएँ।',
      'currentViews': 'मौजूदा व्यू',
      'videosWatched': 'देखे गए वीडियो',
      'progressToPayout': 'भुगतान तक प्रगति',
      'youAreOnYourWay': 'आप सही रास्ते पर हैं।',
      'earnViewsNow': 'अभी व्यू कमाएं।',
      'payoutUnlocked':
          'भुगतान अनलॉक हो गया है। अब आप वॉलेट में भुगतान अनुरोध कर सकते हैं।',
      'moreViewsUntilPayout': 'भुगतान तक और {views} व्यू चाहिए।',
      'dailyBonus': 'दैनिक बोनस',
      'watchDailyVideosBonus':
          'बोनस व्यू पाने के लिए रोज़ {videos} वीडियो देखें।',
      'bonusClaimed': 'बोनस लिया गया',
      'bonus': 'बोनस',
      'earnViewsTitle': 'व्यू कमाएं',
      'watchRewardedEarnViews':
          'रिवॉर्डेड वीडियो देखें और तुरंत व्यू कमाएं।',
      'earnViews': 'व्यू कमाएं',
      'howItWorks': 'यह कैसे काम करता है',
      'watch': 'देखें',
      'watchShortVideo': 'एक छोटा वीडियो देखें',
      'earnStep': 'कमाएं',
      'getViewsReward': 'रिवॉर्ड में व्यू पाएं',
      'cashOut': 'निकासी',
      'reachViews': '{views} व्यू तक पहुँचें',
      'dailyChallenge': 'दैनिक चुनौती',
      'watchTodayVideosBonus':
          'आज {videos} वीडियो देखें और बोनस व्यू पाएं!',
      'totalVideosWatched': 'कुल देखे गए वीडियो',
      'memberSince': 'सदस्य since: {date}',
      'notAvailableYet': 'अभी उपलब्ध नहीं',
      'emailVerified': 'ईमेल सत्यापित',
      'emailNotVerified': 'ईमेल सत्यापित नहीं',
      'security': 'सुरक्षा',
      'firebaseProtected': 'Firebase द्वारा सुरक्षित',
      'payoutReview': 'भुगतान समीक्षा',
      'adminApproval': 'एडमिन स्वीकृति',
      'readAdminReplies': 'एडमिन के जवाब और सूचनाएँ पढ़ें',
      'notificationsPrivacy': 'नोटिफिकेशन, गोपनीयता और ऐप सेटिंग्स',
      'contactAdmin': 'एडमिन से संपर्क करें और संदेश भेजें',
      'reportProblemBug': 'समस्या या बग रिपोर्ट करें',
      'rateApp': 'ऐप को रेट करें',
      'sendInAppRating': '1 से 5 स्टार तक अपनी रेटिंग भेजें',
      'aboutVideoMoney': 'VideoMoney के बारे में',
      'reviewPayoutRequests': 'भुगतान अनुरोधों की समीक्षा करें',
      'logout': 'लॉगआउट',
      'yourWallet': 'आपका वॉलेट',
      'availableViews': 'उपलब्ध व्यू',
      'estimatedPayout': 'अनुमानित भुगतान',
      'remainingToPayout': 'भुगतान तक बाकी',
      'viewsUnit': 'व्यू',
      'estimateOnly':
          'केवल अनुमान। 50 व्यू ≈ €0.01 और वास्तविक आय अलग हो सकती है।',
      'requestPayout': 'भुगतान अनुरोध करें',
      'minPayout': 'न्यूनतम भुगतान',
      'processingTime': 'प्रोसेसिंग समय',
      'approval': 'स्वीकृति',
      'adminReview': 'एडमिन समीक्षा',
      'payoutMethods': 'भुगतान तरीके',
      'payoutHistory': 'भुगतान इतिहास',
      'noPayoutRequestsYet': 'अभी तक कोई भुगतान अनुरोध नहीं।',
      'pendingTimestamp': 'समय प्रतीक्षारत है',
      'paypalSubtitle': 'EUR, GBP या USD में भुगतान अनुरोध करें',
      'revolutSubtitle': 'चुनी हुई मुद्रा के साथ तेज़ वॉलेट भुगतान',
      'bankTransferTitle': 'बैंक ट्रांसफ़र',
      'bankTransferSubtitle':
          'मैन्युअल भुगतान के लिए IBAN या बैंक खाता संख्या जोड़ें',
      'viewFullHistory': 'पूरा इतिहास देखें',
      'inbox': 'इनबॉक्स',
      'markAllRead': 'सब पढ़ा हुआ चिन्हित करें',
      'noInboxMessagesYet': 'अभी तक कोई इनबॉक्स संदेश नहीं।',
      'newBadge': 'नया',
      'rateAppQuestion': 'आप VideoMoney को कैसे रेट करेंगे?',
      'choose1to5':
          '1 से 5 स्टार चुनें। आप बाद में अपनी रेटिंग बदल सकते हैं।',
      'saveRating': 'रेटिंग सहेजें',
      'thanksForRating': 'आपकी रेटिंग के लिए धन्यवाद।',
      'requestPayoutTitle': 'भुगतान अनुरोध',
      'payoutRules': 'भुगतान नियम',
      'minimumPayoutIs': 'न्यूनतम भुगतान {views} व्यू है।',
      'processingCanTake':
          'एडमिन स्वीकृति के बाद प्रोसेसिंग में {days} दिन तक लग सकते हैं।',
      'everyRequestReviewed':
          'हर अनुरोध का भुगतान से पहले एडमिन द्वारा समीक्षा की जाती है।',
      'useBankAddIban':
          'मैन्युअल ट्रांसफ़र के लिए Bank चुनें और अपना IBAN या बैंक खाता नंबर जोड़ें।',
      'submitUsingBalance':
          'अपने व्यू बैलेंस का उपयोग करके भुगतान अनुरोध भेजें।',
      'estimatedEarningsNotGuaranteed':
          'आय केवल अनुमानित है। 50 पूर्ण व्यू ≈ €0.01 और यह गारंटीकृत भुगतान नहीं है।',
      'payoutCurrency': 'भुगतान मुद्रा',
      'payoutMethod': 'भुगतान तरीका',
      'viewsToRequest': 'अनुरोधित व्यू',
      'minimumViewsHelper': 'न्यूनतम 10,000 व्यू',
      'enterAmount': 'राशि दर्ज करें।',
      'enterValidPositiveNumber': 'मान्य सकारात्मक संख्या दर्ज करें।',
      'accountHolderName': 'खाताधारक का नाम',
      'enterAccountHolderName': 'खाताधारक का नाम दर्ज करें।',
      'paypalEmail': 'PayPal ईमेल',
      'enterPaypalEmail': 'PayPal ईमेल दर्ज करें।',
      'enterValidPaypalEmail': 'मान्य PayPal ईमेल दर्ज करें।',
      'revolutUsername': 'Revolut उपयोगकर्ता नाम',
      'revolutExample': 'उदाहरण: @yourname',
      'enterRevolutUsername': 'अपना Revolut उपयोगकर्ता नाम दर्ज करें।',
      'bankName': 'बैंक का नाम',
      'enterBankName': 'अपने बैंक का नाम दर्ज करें।',
      'iban': 'IBAN',
      'ibanOptional': 'यदि आप बैंक खाता नंबर देते हैं तो वैकल्पिक',
      'bankAccountNumber': 'बैंक खाता संख्या',
      'bankRequiredIfNoIban': 'यदि IBAN नहीं है तो आवश्यक',
      'enterIbanOrBank': 'IBAN या बैंक खाता संख्या दर्ज करें।',
      'submitRequest': 'अनुरोध भेजें',
      'payoutRequestSubmitted': 'भुगतान अनुरोध भेज दिया गया।',
      'payoutHistoryTitle': 'भुगतान इतिहास',
      'unableLoadPayoutHistory':
          'अभी भुगतान इतिहास लोड नहीं किया जा सका।',
      'currencyLabel': 'मुद्रा: {currency}',
      'accountHolderLabel': 'खाताधारक: {value}',
      'notProvided': 'प्रदान नहीं किया गया',
      'helpSupport': 'मदद और सहायता',
      'openSupportTicket': 'सपोर्ट टिकट खोलें',
      'describeIssueAdminReply':
          'अपनी समस्या बताएं और एडमिन आपके इनबॉक्स में जवाब दे सकता है।',
      'subject': 'विषय',
      'helpSubjectHint': 'आपको किस बात में मदद चाहिए?',
      'message': 'संदेश',
      'messageHint': 'अपना संदेश यहाँ लिखें...',
      'send': 'भेजें',
      'sending': 'भेजा जा रहा है...',
      'openInbox': 'इनबॉक्स खोलें',
      'yourTickets': 'आपके टिकट',
      'noSupportTicketsYet': 'अभी तक कोई सपोर्ट टिकट नहीं।',
      'supportMessageSent': 'सहायता संदेश भेज दिया गया।',
      'adminReply': 'एडमिन का जवाब: {value}',
      'reportBug': 'बग रिपोर्ट करें',
      'tellUsWhatHappened': 'हमें बताएं क्या हुआ',
      'includeStepsExpected':
          'समस्या दोहराने के चरण और अपेक्षित परिणाम जोड़ें।',
      'title': 'शीर्षक',
      'shortSummary': 'संक्षिप्त सारांश',
      'description': 'विवरण',
      'describeBug': 'बग का वर्णन करें...',
      'submit': 'जमा करें',
      'bugReportSubmitted': 'बग रिपोर्ट भेज दी गई।',
      'aboutTagline': 'प्रीमियम डार्क थीम • नीयॉन हरा UI',
      'version': 'संस्करण',
      'minimumPayoutLabel': 'न्यूनतम भुगतान',
      'processingTimeLabel': 'प्रोसेसिंग समय',
      'reviewLabel': 'समीक्षा',
      'estimatedEarningsOnlyPolicies':
          'आय केवल अनुमानित है। वास्तविक आय विज्ञापन प्रदर्शन और नीति नियमों के अनुसार बदल सकती है।',
      'privacyPolicy': 'गोपनीयता नीति',
      'termsOfService': 'सेवा की शर्तें',
      'notifications': 'सूचनाएँ',
      'enableNotifications': 'सूचनाएँ सक्षम करें',
      'generalAppNotifications': 'सामान्य ऐप सूचनाएँ',
      'dailyReminder': 'दैनिक रिमाइंडर',
      'dailyReminderSubtitle': 'दैनिक बोनस पूरा करने की याद दिलाएँ',
      'settingsSaved': 'सेटिंग्स सहेजी गईं।',
      'privacy': 'गोपनीयता',
      'appVersion': 'ऐप संस्करण',
      'save': 'सहेजें',
      'saving': 'सहेजा जा रहा है...',
      'termsUsingTitle': 'VideoMoney का उपयोग',
      'termsViewsTitle': 'व्यू और रिवॉर्ड',
      'termsPayoutsTitle': 'भुगतान और समीक्षा',
      'termsSupportTitle': 'सहायता और संदेश',
      'termsUsingBullet1': 'आपको सही खाता जानकारी का उपयोग करना चाहिए।',
      'termsUsingBullet2':
          'एक व्यक्ति अतिरिक्त व्यू बनाने के लिए कई खाते, बॉट, स्क्रिप्ट, VPN रोटेशन या एमुलेटर फ़ार्म का दुरुपयोग नहीं कर सकता।',
      'termsUsingBullet3':
          'रिवॉर्डेड विज्ञापन, Firebase प्रमाणीकरण और भुगतान समीक्षा वर्तमान प्लेटफ़ॉर्म सेटअप द्वारा सुरक्षित हैं।',
      'termsViewsBullet1':
          'ऐप में दिखाए गए व्यू VideoMoney के भीतर उपयोग होने वाली प्रमोशनल रिवॉर्ड यूनिट्स हैं।',
      'termsViewsBullet2':
          'अनुमानित कमाई केवल जानकारी के लिए है और प्लेटफ़ॉर्म प्रदर्शन, नीति, फ़्रॉड जाँच और भुगतान समीक्षा के अनुसार बदल सकती है।',
      'termsViewsBullet3':
          'दैनिक बोनस रिवॉर्ड केवल योग्य गतिविधि तक सीमित हैं और दुरुपयोग मिलने पर हटाए जा सकते हैं।',
      'termsPayoutsBullet1': 'न्यूनतम भुगतान 10,000 व्यू ही रहेगा।',
      'termsPayoutsBullet2':
          'सभी भुगतान अनुरोधों के लिए मैन्युअल एडमिन स्वीकृति आवश्यक है और उन्हें स्वीकृत, अस्वीकृत या भुगतान-चिह्नित किया जा सकता है।',
      'termsPayoutsBullet3':
          'यदि एडमिन वर्कफ़्लो अनुमति देता है, तो अस्वीकृत भुगतान अनुरोध उपयोगकर्ता बैलेंस में वापस किए जा सकते हैं।',
      'termsSupportBullet1':
          'Help & Support, बग रिपोर्ट, एडमिन जवाब और पुश नोटिफिकेशन आपके इन-ऐप इनबॉक्स में संग्रहीत हो सकते हैं।',
      'termsSupportBullet2':
          'सूचनाएँ सक्षम करके, आप VideoMoney को आपके डिवाइस पर ऐप अपडेट, सहायता उत्तर और दैनिक रिमाइंडर संदेश भेजने की अनुमति देते हैं।',
      'termsSupportBullet3':
          'गंभीर दुरुपयोग, उत्पीड़न या धोखाधड़ी वाली गतिविधि ऐप एक्सेस पर प्रतिबंध ला सकती है।',
      'settingsTitle': 'सेटिंग्स',
      'statusPending': 'लंबित',
      'statusApproved': 'स्वीकृत',
      'statusPaid': 'भुगतान किया गया',
      'statusRejected': 'अस्वीकृत',
      'statusProcessing': 'प्रक्रिया में',
      'statusFixed': 'ठीक किया गया',
      'statusClosed': 'बंद',
      'typeSupport': 'सपोर्ट',
      'typePayment': 'भुगतान',
      'typeBug': 'बग',
    },
    'de': {
      'appName': 'VideoMoney',
      'startingApp': 'VideoMoney wird gestartet',
      'preparingStartup':
          'Firebase, Wallet-Daten und Rewarded Ads werden vorbereitet...',
      'startupFailed': 'Start fehlgeschlagen',
      'loadingWallet': 'Dein Wallet wird geladen...',
      'unableRestoreSession':
          'Deine Sitzung kann gerade nicht wiederhergestellt werden.',
      'welcomeBack': 'Willkommen zurück',
      'createYourAccount': 'Erstelle dein Konto',
      'signInBody':
          'Melde dich an, um weiter Views zu verdienen und Auszahlungen zu verwalten.',
      'signUpBody':
          'Registriere dich, um Rewarded Videos anzusehen und dein Guthaben aufzubauen.',
      'login': 'Anmelden',
      'signUp': 'Registrieren',
      'email': 'E-Mail',
      'password': 'Passwort',
      'enterYourEmail': 'Gib deine E-Mail ein.',
      'enterValidEmail': 'Gib eine gültige E-Mail-Adresse ein.',
      'enterYourPassword': 'Gib dein Passwort ein.',
      'useAtLeast6Chars': 'Verwende mindestens 6 Zeichen.',
      'forgotPassword': 'Passwort vergessen?',
      'resetPassword': 'Passwort zurücksetzen',
      'emailHint': 'name@beispiel.com',
      'cancel': 'Abbrechen',
      'sendResetLink': 'Reset-Link senden',
      'passwordResetEmailSent':
          'Passwort-Reset-E-Mail an {email} gesendet.',
      'unableSendResetEmail':
          'Reset-E-Mail konnte nicht gesendet werden.',
      'firebaseAuthNotice':
          'Firebase Authentication bleibt unverändert. Dieses Redesign ändert nur die Darstellung.',
      'createAccount': 'Konto erstellen',
      'secureAccessDashboard':
          'Sicherer Zugriff auf dein Verdienst-Dashboard',
      'firestoreBalanceStored':
          'Dein Auszahlungsverlauf und Guthaben werden in Firestore gespeichert',
      'authenticationFailed': 'Authentifizierung fehlgeschlagen.',
      'noUserSessionFound': 'Keine Benutzersitzung gefunden.',
      'home': 'Start',
      'earn': 'Verdienen',
      'wallet': 'Wallet',
      'profile': 'Profil',
      'rewardConfirmedViewsAdded':
          'Belohnung bestätigt. Views wurden hinzugefügt.',
      'rewardedAdNotCompleted':
          'Die Rewarded-Anzeige wurde nicht abgeschlossen.',
      'watchVideo': 'Video ansehen',
      'loading': 'Lädt...',
      'welcomeBackShort': 'Willkommen zurück,',
      'signedInUser': 'Angemeldeter Nutzer',
      'watchVideosEarnPaid':
          'Sieh Videos an, verdiene Views und lass dich auszahlen.',
      'currentViews': 'Aktuelle Views',
      'videosWatched': 'Angesehene Videos',
      'progressToPayout': 'Fortschritt zur Auszahlung',
      'youAreOnYourWay': 'Du bist auf dem richtigen Weg.',
      'earnViewsNow': 'Jetzt Views verdienen.',
      'payoutUnlocked':
          'Auszahlung freigeschaltet. Du kannst jetzt im Wallet eine Auszahlung anfordern.',
      'moreViewsUntilPayout': 'Noch {views} Views bis zur Auszahlung.',
      'dailyBonus':
          'Täglicher Bonus',
      'watchDailyVideosBonus':
          'Sieh täglich {videos} Videos an, um Bonus-Views zu erhalten.',
      'bonusClaimed': 'Bonus erhalten',
      'bonus': 'Bonus',
      'earnViewsTitle': 'Views verdienen',
      'watchRewardedEarnViews':
          'Sieh Rewarded Videos an und verdiene sofort Views.',
      'earnViews': 'Views verdienen',
      'howItWorks': 'So funktioniert es',
      'watch': 'Ansehen',
      'watchShortVideo': 'Ein kurzes Video ansehen',
      'earnStep': 'Verdienen',
      'getViewsReward': 'Views als Belohnung erhalten',
      'cashOut': 'Auszahlen',
      'reachViews': '{views} Views erreichen',
      'dailyChallenge': 'Tägliche Herausforderung',
      'watchTodayVideosBonus':
          'Sieh heute {videos} Videos an und erhalte Bonus-Views!',
      'totalVideosWatched': 'Insgesamt angesehene Videos',
      'memberSince': 'Mitglied seit: {date}',
      'notAvailableYet': 'Noch nicht verfügbar',
      'emailVerified': 'E-Mail verifiziert',
      'emailNotVerified': 'E-Mail nicht verifiziert',
      'security': 'Sicherheit',
      'firebaseProtected': 'Durch Firebase geschützt',
      'payoutReview': 'Auszahlungsprüfung',
      'adminApproval': 'Admin-Freigabe',
      'readAdminReplies': 'Admin-Antworten und Benachrichtigungen lesen',
      'notificationsPrivacy': 'Benachrichtigungen, Datenschutz und App-Einstellungen',
      'contactAdmin': 'Admin kontaktieren und Nachrichten senden',
      'reportProblemBug': 'Problem oder Fehler melden',
      'rateApp': 'App bewerten',
      'sendInAppRating':
          'Sende deine In-App-Bewertung von 1 bis 5 Sternen',
      'aboutVideoMoney': 'Über VideoMoney',
      'reviewPayoutRequests': 'Auszahlungsanfragen prüfen',
      'logout': 'Abmelden',
      'yourWallet': 'Dein Wallet',
      'availableViews': 'Verfügbare Views',
      'estimatedPayout': 'Geschätzte Auszahlung',
      'remainingToPayout': 'Verbleibend bis Auszahlung',
      'viewsUnit': 'Views',
      'estimateOnly':
          'Nur Schätzung. 50 Views ≈ €0,01 und die tatsächlichen Einnahmen können abweichen.',
      'requestPayout': 'Auszahlung anfordern',
      'minPayout': 'Mindestbetrag',
      'processingTime': 'Bearbeitungszeit',
      'approval': 'Freigabe',
      'adminReview': 'Admin-Prüfung',
      'payoutMethods': 'Auszahlungsmethoden',
      'payoutHistory': 'Auszahlungsverlauf',
      'noPayoutRequestsYet': 'Noch keine Auszahlungsanfragen.',
      'pendingTimestamp': 'Zeitstempel ausstehend',
      'paypalSubtitle':
          'Auszahlung in EUR, GBP oder USD anfordern',
      'revolutSubtitle':
          'Schnelle Wallet-Auszahlung mit gewählter Währung',
      'bankTransferTitle': 'Banküberweisung',
      'bankTransferSubtitle':
          'IBAN oder Kontonummer für manuelle Auszahlung hinzufügen',
      'viewFullHistory': 'Gesamten Verlauf anzeigen',
      'inbox': 'Postfach',
      'markAllRead': 'Alles als gelesen markieren',
      'noInboxMessagesYet': 'Noch keine Nachrichten im Postfach.',
      'newBadge': 'NEU',
      'rateAppQuestion': 'Wie würdest du VideoMoney bewerten?',
      'choose1to5':
          'Wähle zwischen 1 und 5 Sternen. Du kannst deine Bewertung später ändern.',
      'saveRating': 'Bewertung speichern',
      'thanksForRating': 'Danke für deine Bewertung.',
      'requestPayoutTitle': 'Auszahlung anfordern',
      'payoutRules': 'Auszahlungsregeln',
      'minimumPayoutIs': 'Die Mindestauszahlung beträgt {views} Views.',
      'processingCanTake':
          'Die Bearbeitung kann nach Admin-Freigabe bis zu {days} Tage dauern.',
      'everyRequestReviewed':
          'Jede Anfrage wird vor der Auszahlung vom Admin geprüft.',
      'useBankAddIban':
          'Nutze Bank für manuelle Überweisung und füge deine IBAN oder Kontonummer hinzu.',
      'submitUsingBalance':
          'Sende eine Auszahlungsanfrage mit deinem View-Guthaben.',
      'estimatedEarningsNotGuaranteed':
          'Einnahmen sind nur geschätzt. 50 abgeschlossene Views ≈ €0,01 und dies ist kein garantiertes Auszahlungsversprechen.',
      'payoutCurrency': 'Auszahlungswährung',
      'payoutMethod': 'Auszahlungsmethode',
      'viewsToRequest': 'Anzufordernde Views',
      'minimumViewsHelper': 'Mindestens 10.000 Views',
      'enterAmount': 'Betrag eingeben.',
      'enterValidPositiveNumber':
          'Gib eine gültige positive Zahl ein.',
      'accountHolderName': 'Kontoinhaber',
      'enterAccountHolderName':
          'Gib den Namen des Kontoinhabers ein.',
      'paypalEmail': 'PayPal-E-Mail',
      'enterPaypalEmail': 'Gib eine PayPal-E-Mail ein.',
      'enterValidPaypalEmail':
          'Gib eine gültige PayPal-E-Mail ein.',
      'revolutUsername': 'Revolut-Benutzername',
      'revolutExample': 'Beispiel: @deinname',
      'enterRevolutUsername':
          'Gib deinen Revolut-Benutzernamen ein.',
      'bankName': 'Bankname',
      'enterBankName': 'Gib deinen Banknamen ein.',
      'iban': 'IBAN',
      'ibanOptional':
          'Optional, wenn du eine Kontonummer angibst',
      'bankAccountNumber': 'Kontonummer',
      'bankRequiredIfNoIban':
          'Erforderlich, wenn du keine IBAN angibst',
      'enterIbanOrBank':
          'Gib eine IBAN oder Kontonummer ein.',
      'submitRequest': 'Anfrage senden',
      'payoutRequestSubmitted': 'Auszahlungsanfrage gesendet.',
      'payoutHistoryTitle': 'Auszahlungsverlauf',
      'unableLoadPayoutHistory':
          'Der Auszahlungsverlauf kann gerade nicht geladen werden.',
      'currencyLabel': 'Währung: {currency}',
      'accountHolderLabel': 'Kontoinhaber: {value}',
      'notProvided': 'Nicht angegeben',
      'helpSupport': 'Hilfe & Support',
      'openSupportTicket': 'Support-Ticket öffnen',
      'describeIssueAdminReply':
          'Beschreibe dein Problem und der Admin kann dir im Postfach antworten.',
      'subject': 'Betreff',
      'helpSubjectHint': 'Wobei brauchst du Hilfe?',
      'message': 'Nachricht',
      'messageHint': 'Schreibe deine Nachricht hier...',
      'send': 'Senden',
      'sending': 'Wird gesendet...',
      'openInbox': 'Postfach öffnen',
      'yourTickets': 'Deine Tickets',
      'noSupportTicketsYet': 'Noch keine Support-Tickets.',
      'supportMessageSent': 'Support-Nachricht gesendet.',
      'adminReply': 'Admin-Antwort: {value}',
      'reportBug': 'Fehler melden',
      'tellUsWhatHappened': 'Erzähle uns, was passiert ist',
      'includeStepsExpected':
          'Füge Schritte zur Reproduktion und das erwartete Ergebnis hinzu.',
      'title': 'Titel',
      'shortSummary': 'Kurze Zusammenfassung',
      'description': 'Beschreibung',
      'describeBug': 'Beschreibe den Fehler...',
      'submit': 'Absenden',
      'bugReportSubmitted': 'Fehlerbericht gesendet.',
      'aboutTagline': 'Premium-Dark-Theme • Neon-grüne UI',
      'version': 'Version',
      'minimumPayoutLabel': 'Mindestbetrag',
      'processingTimeLabel': 'Bearbeitungszeit',
      'reviewLabel': 'Prüfung',
      'estimatedEarningsOnlyPolicies':
          'Nur geschätzte Einnahmen. Tatsächliche Einnahmen können je nach Anzeigenleistung und Richtlinien variieren.',
      'privacyPolicy': 'Datenschutzrichtlinie',
      'termsOfService': 'Nutzungsbedingungen',
      'notifications': 'Benachrichtigungen',
      'enableNotifications': 'Benachrichtigungen aktivieren',
      'generalAppNotifications': 'Allgemeine App-Benachrichtigungen',
      'dailyReminder': 'Tägliche Erinnerung',
      'dailyReminderSubtitle':
          'Erhalte eine Erinnerung an deinen täglichen Bonus',
      'settingsSaved': 'Einstellungen gespeichert.',
      'privacy': 'Datenschutz',
      'appVersion': 'App-Version',
      'save': 'Speichern',
      'saving': 'Speichert...',
      'termsUsingTitle': 'Nutzung von VideoMoney',
      'termsViewsTitle': 'Views und Belohnungen',
      'termsPayoutsTitle': 'Auszahlungen und Prüfung',
      'termsSupportTitle': 'Support und Nachrichten',
      'termsUsingBullet1':
          'Du musst korrekte Kontoinformationen verwenden.',
      'termsUsingBullet2':
          'Eine Person darf keine Mehrfachkonten, Bots, Skripte, VPN-Rotation oder Emulator-Farmen missbrauchen, um zusätzliche Views zu erzeugen.',
      'termsUsingBullet3':
          'Rewarded Ads, Firebase-Authentifizierung und Auszahlungsprüfung bleiben durch die bestehende Plattform geschützt.',
      'termsViewsBullet1':
          'In der App angezeigte Views sind Promotion-Belohnungseinheiten innerhalb von VideoMoney.',
      'termsViewsBullet2':
          'Geschätzte Einnahmen dienen nur zur Information und können sich je nach Plattformleistung, Richtlinien, Betrugsprüfung und Auszahlungsprüfung ändern.',
      'termsViewsBullet3':
          'Tägliche Bonusbelohnungen sind auf berechtigte Aktivität begrenzt und können bei Missbrauch entfernt werden.',
      'termsPayoutsBullet1':
          'Die Mindestauszahlung bleibt bei 10.000 Views.',
      'termsPayoutsBullet2':
          'Alle Auszahlungsanfragen benötigen eine manuelle Admin-Freigabe und können genehmigt, abgelehnt oder als bezahlt markiert werden.',
      'termsPayoutsBullet3':
          'Abgelehnte Auszahlungsanfragen können dem Nutzerguthaben zurückerstattet werden, wenn der Admin-Workflow dies erlaubt.',
      'termsSupportBullet1':
          'Hilfe & Support, Fehlerberichte, Admin-Antworten und Push-Benachrichtigungen können in deinem In-App-Postfach gespeichert werden.',
      'termsSupportBullet2':
          'Durch das Aktivieren von Benachrichtigungen erlaubst du VideoMoney, App-Updates, Support-Antworten und tägliche Erinnerungen an dein Gerät zu senden.',
      'termsSupportBullet3':
          'Schwerer Missbrauch, Belästigung oder betrügerische Aktivitäten können zu Einschränkungen des App-Zugangs führen.',
      'settingsTitle': 'Einstellungen',
      'statusPending': 'AUSSTEHEND',
      'statusApproved': 'GENEHMIGT',
      'statusPaid': 'BEZAHLT',
      'statusRejected': 'ABGELEHNT',
      'statusProcessing': 'IN BEARBEITUNG',
      'statusFixed': 'BEHOBEN',
      'statusClosed': 'GESCHLOSSEN',
      'typeSupport': 'SUPPORT',
      'typePayment': 'ZAHLUNG',
      'typeBug': 'FEHLER',
    },
    'es': {
      'appName': 'VideoMoney',
      'startingApp': 'Iniciando VideoMoney',
      'preparingStartup': 'Preparando Firebase, los datos de la cartera y los anuncios recompensados...',
      'startupFailed': 'Error al iniciar',
      'loadingWallet': 'Cargando tu cartera...',
      'unableRestoreSession': 'No se puede restaurar tu sesión en este momento.',
      'welcomeBack': 'Bienvenido de nuevo',
      'createYourAccount': 'Crea tu cuenta',
      'signInBody': 'Inicia sesión para seguir ganando vistas y gestionar pagos.',
      'signUpBody': 'Regístrate para empezar a ver vídeos recompensados y aumentar tu saldo.',
      'login': 'Iniciar sesión',
      'signUp': 'Registrarse',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'enterYourEmail': 'Introduce tu correo electrónico.',
      'enterValidEmail': 'Introduce una dirección de correo válida.',
      'enterYourPassword': 'Introduce tu contraseña.',
      'useAtLeast6Chars': 'Usa al menos 6 caracteres.',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'resetPassword': 'Restablecer contraseña',
      'emailHint': 'nombre@ejemplo.com',
      'cancel': 'Cancelar',
      'sendResetLink': 'Enviar enlace de restablecimiento',
      'passwordResetEmailSent': 'Correo de restablecimiento de contraseña enviado a {email}.',
      'unableSendResetEmail': 'No se pudo enviar el correo de restablecimiento.',
      'firebaseAuthNotice': 'Firebase Authentication no cambia. Este rediseño solo actualiza la capa de presentación.',
      'createAccount': 'Crear cuenta',
      'secureAccessDashboard': 'Acceso seguro a tu panel de ganancias',
      'firestoreBalanceStored': 'Tu historial de pagos y saldo de recompensas se almacenan en Firestore',
      'authenticationFailed': 'La autenticación falló.',
      'noUserSessionFound': 'No se encontró ninguna sesión de usuario.',
      'home': 'Inicio',
      'earn': 'Ganar',
      'wallet': 'Cartera',
      'profile': 'Perfil',
      'rewardConfirmedViewsAdded': 'Recompensa confirmada. Vistas añadidas.',
      'rewardedAdNotCompleted': 'El anuncio recompensado no se completó.',
      'watchVideo': 'Ver vídeo',
      'loading': 'Cargando...',
      'welcomeBackShort': 'Bienvenido de nuevo,',
      'signedInUser': 'Usuario con sesión iniciada',
      'watchVideosEarnPaid': 'Mira vídeos, gana vistas y recibe pagos.',
      'currentViews': 'Vistas actuales',
      'videosWatched': 'Vídeos vistos',
      'progressToPayout': 'Progreso hacia el pago',
      'youAreOnYourWay': 'Vas por buen camino.',
      'earnViewsNow': 'Gana vistas ahora.',
      'payoutUnlocked': 'Pago desbloqueado. Puedes solicitar un pago en la Cartera.',
      'moreViewsUntilPayout': 'Faltan {views} vistas para el pago.',
      'dailyBonus': 'Bono diario',
      'watchDailyVideosBonus': 'Mira {videos} vídeos al día para obtener vistas de bonificación.',
      'bonusClaimed': 'Bono reclamado',
      'bonus': 'Bono',
      'earnViewsTitle': 'Ganar vistas',
      'watchRewardedEarnViews': 'Mira vídeos recompensados y gana vistas al instante.',
      'earnViews': 'Ganar vistas',
      'howItWorks': 'Cómo funciona',
      'watch': 'Ver',
      'watchShortVideo': 'Ver un vídeo corto',
      'earnStep': 'Ganar',
      'getViewsReward': 'Obtén vistas como recompensa',
      'cashOut': 'Retirar',
      'reachViews': 'Alcanza {views} vistas',
      'dailyChallenge': 'Desafío diario',
      'watchTodayVideosBonus': 'Mira {videos} vídeos hoy y consigue vistas de bonificación.',
      'totalVideosWatched': 'Total de vídeos vistos',
      'memberSince': 'Miembro desde: {date}',
      'notAvailableYet': 'Aún no disponible',
      'emailVerified': 'Correo verificado',
      'emailNotVerified': 'Correo no verificado',
      'security': 'Seguridad',
      'firebaseProtected': 'Protegido por Firebase',
      'payoutReview': 'Revisión de pago',
      'adminApproval': 'Aprobación del administrador',
      'readAdminReplies': 'Lee las respuestas y notificaciones del administrador',
      'notificationsPrivacy': 'Notificaciones, privacidad y ajustes de la app',
      'contactAdmin': 'Contacta con el administrador y envía mensajes',
      'reportProblemBug': 'Informar de un problema o error',
      'rateApp': 'Calificar app',
      'sendInAppRating': 'Envía tu calificación en la app de 1 a 5 estrellas',
      'aboutVideoMoney': 'Acerca de VideoMoney',
      'reviewPayoutRequests': 'Revisar solicitudes de pago',
      'logout': 'Cerrar sesión',
      'yourWallet': 'Tu cartera',
      'availableViews': 'Vistas disponibles',
      'estimatedPayout': 'Pago estimado',
      'remainingToPayout': 'Restante para el pago',
      'viewsUnit': 'vistas',
      'estimateOnly': 'Solo estimación. 50 vistas ≈ €0,01 y las ganancias reales pueden variar.',
      'requestPayout': 'Solicitar pago',
      'minPayout': 'Pago mín.',
      'processingTime': 'Tiempo de procesamiento',
      'approval': 'Aprobación',
      'adminReview': 'Revisión del administrador',
      'payoutMethods': 'Métodos de pago',
      'payoutHistory': 'Historial de pagos',
      'noPayoutRequestsYet': 'Aún no hay solicitudes de pago.',
      'pendingTimestamp': 'Marca de tiempo pendiente',
      'paypalSubtitle': 'Solicita el pago en EUR, GBP o USD',
      'revolutSubtitle': 'Pago rápido a la cartera en la moneda elegida',
      'bankTransferTitle': 'Transferencia bancaria',
      'bankTransferSubtitle': 'Añade un IBAN o número de cuenta bancaria para un pago manual',
      'viewFullHistory': 'Ver historial completo',
      'inbox': 'Bandeja de entrada',
      'markAllRead': 'Marcar todo como leído',
      'noInboxMessagesYet': 'Aún no hay mensajes en la bandeja de entrada.',
      'newBadge': 'NUEVO',
      'rateAppQuestion': '¿Cómo calificarías VideoMoney?',
      'choose1to5': 'Elige entre 1 y 5 estrellas. Puedes actualizar tu calificación más tarde.',
      'saveRating': 'Guardar calificación',
      'thanksForRating': 'Gracias por tu calificación.',
      'requestPayoutTitle': 'Solicitar pago',
      'payoutRules': 'Reglas de pago',
      'minimumPayoutIs': 'El pago mínimo es de {views} vistas.',
      'processingCanTake': 'El procesamiento puede tardar hasta {days} días después de la aprobación del administrador.',
      'everyRequestReviewed': 'Cada solicitud es revisada por el administrador antes de pagarse.',
      'useBankAddIban': 'Usa Banco para transferencia manual y añade tu IBAN o número de cuenta bancaria.',
      'submitUsingBalance': 'Envía una solicitud de pago usando tu saldo de vistas.',
      'estimatedEarningsNotGuaranteed': 'Solo ganancias estimadas. 50 vistas completadas ≈ €0,01 y esto no es una promesa de pago garantizada.',
      'payoutCurrency': 'Moneda de pago',
      'payoutMethod': 'Método de pago',
      'viewsToRequest': 'Vistas a solicitar',
      'minimumViewsHelper': 'Mínimo 10.000 vistas',
      'enterAmount': 'Introduce una cantidad.',
      'enterValidPositiveNumber': 'Introduce un número positivo válido.',
      'accountHolderName': 'Nombre del titular de la cuenta',
      'enterAccountHolderName': 'Introduce el nombre del titular de la cuenta.',
      'paypalEmail': 'Correo de PayPal',
      'enterPaypalEmail': 'Introduce un correo de PayPal.',
      'enterValidPaypalEmail': 'Introduce un correo de PayPal válido.',
      'revolutUsername': 'Nombre de usuario de Revolut',
      'revolutExample': 'Ejemplo: @tunombre',
      'enterRevolutUsername': 'Introduce tu nombre de usuario de Revolut.',
      'bankName': 'Nombre del banco',
      'enterBankName': 'Introduce el nombre de tu banco.',
      'iban': 'IBAN',
      'ibanOptional': 'Opcional si proporcionas un número de cuenta bancaria',
      'bankAccountNumber': 'Número de cuenta bancaria',
      'bankRequiredIfNoIban': 'Obligatorio si no introduces un IBAN',
      'enterIbanOrBank': 'Introduce un IBAN o un número de cuenta bancaria.',
      'submitRequest': 'Enviar solicitud',
      'payoutRequestSubmitted': 'Solicitud de pago enviada.',
      'payoutHistoryTitle': 'Historial de pagos',
      'unableLoadPayoutHistory': 'No se puede cargar el historial de pagos en este momento.',
      'currencyLabel': 'Moneda: {currency}',
      'accountHolderLabel': 'Titular de la cuenta: {value}',
      'notProvided': 'No proporcionado',
      'helpSupport': 'Ayuda y soporte',
      'openSupportTicket': 'Abrir un ticket de soporte',
      'describeIssueAdminReply': 'Describe tu problema y el administrador podrá responder en tu bandeja de entrada.',
      'subject': 'Asunto',
      'helpSubjectHint': '¿Con qué necesitas ayuda?',
      'message': 'Mensaje',
      'messageHint': 'Escribe tu mensaje aquí...',
      'send': 'Enviar',
      'sending': 'Enviando...',
      'openInbox': 'Abrir bandeja de entrada',
      'yourTickets': 'Tus tickets',
      'noSupportTicketsYet': 'Aún no hay tickets de soporte.',
      'supportMessageSent': 'Mensaje de soporte enviado.',
      'adminReply': 'Respuesta del administrador: {value}',
      'reportBug': 'Informar error',
      'tellUsWhatHappened': 'Cuéntanos qué pasó',
      'includeStepsExpected': 'Incluye los pasos para reproducirlo y lo que esperabas ver.',
      'title': 'Título',
      'shortSummary': 'Resumen breve',
      'description': 'Descripción',
      'describeBug': 'Describe el error...',
      'submit': 'Enviar',
      'bugReportSubmitted': 'Informe de error enviado.',
      'aboutTagline': 'Tema oscuro premium • Interfaz verde neón',
      'version': 'Versión',
      'minimumPayoutLabel': 'Pago mínimo',
      'processingTimeLabel': 'Tiempo de procesamiento',
      'reviewLabel': 'Revisión',
      'estimatedEarningsOnlyPolicies': 'Solo ganancias estimadas. Las ganancias reales pueden variar según el rendimiento de los anuncios y las reglas de la política.',
      'privacyPolicy': 'Política de privacidad',
      'termsOfService': 'Términos de servicio',
      'notifications': 'Notificaciones',
      'enableNotifications': 'Activar notificaciones',
      'generalAppNotifications': 'Notificaciones generales de la app',
      'dailyReminder': 'Recordatorio diario',
      'dailyReminderSubtitle': 'Recibe un recordatorio para completar el bono diario',
      'settingsSaved': 'Ajustes guardados.',
      'privacy': 'Privacidad',
      'appVersion': 'Versión de la app',
      'save': 'Guardar',
      'saving': 'Guardando...',
      'termsUsingTitle': 'Uso de VideoMoney',
      'termsViewsTitle': 'Vistas y recompensas',
      'termsPayoutsTitle': 'Pagos y revisión',
      'termsSupportTitle': 'Soporte y mensajes',
      'termsUsingBullet1': 'Debes usar información de cuenta precisa.',
      'termsUsingBullet2': 'Una persona no puede abusar de múltiples cuentas, bots, scripts, rotación de VPN o granjas de emuladores para generar vistas extra.',
      'termsUsingBullet3': 'Los anuncios recompensados, la autenticación de Firebase y la revisión de pagos siguen protegidos por la configuración existente de la plataforma.',
      'termsViewsBullet1': 'Las vistas mostradas en la app son unidades promocionales de recompensa usadas dentro de VideoMoney.',
      'termsViewsBullet2': 'Las ganancias estimadas son solo informativas y pueden cambiar según el rendimiento de la plataforma, la política, las comprobaciones de fraude y la revisión de pagos.',
      'termsViewsBullet3': 'Las recompensas del bono diario están limitadas a la actividad elegible y pueden eliminarse si se detecta abuso.',
      'termsPayoutsBullet1': 'El pago mínimo sigue siendo de 10.000 vistas.',
      'termsPayoutsBullet2': 'Todas las solicitudes de pago requieren aprobación manual del administrador y pueden aprobarse, rechazarse o marcarse como pagadas.',
      'termsPayoutsBullet3': 'Las solicitudes de pago rechazadas pueden reembolsarse al saldo del usuario cuando lo permita el flujo de trabajo del administrador.',
      'termsSupportBullet1': 'Ayuda y soporte, informes de errores, respuestas del administrador y notificaciones push pueden almacenarse en tu bandeja de entrada de la app.',
      'termsSupportBullet2': 'Al activar las notificaciones, permites que VideoMoney envíe actualizaciones de la app, respuestas de soporte y recordatorios diarios a tu dispositivo.',
      'termsSupportBullet3': 'El uso indebido grave, el acoso o la actividad fraudulenta pueden llevar a la restricción del acceso a la app.',
      'settingsTitle': 'Ajustes',
      'statusPending': 'PENDIENTE',
      'statusApproved': 'APROBADO',
      'statusPaid': 'PAGADO',
      'statusRejected': 'RECHAZADO',
      'statusProcessing': 'EN PROCESO',
      'statusFixed': 'CORREGIDO',
      'statusClosed': 'CERRADO',
      'typeSupport': 'SOPORTE',
      'typePayment': 'PAGO',
      'typeBug': 'ERROR',
    },
    'fr': {
      'appName': 'VideoMoney',
      'startingApp': 'Démarrage de VideoMoney',
      'preparingStartup': 'Préparation de Firebase, des données du portefeuille et des publicités récompensées...',
      'startupFailed': 'Échec du démarrage',
      'loadingWallet': 'Chargement de votre portefeuille...',
      'unableRestoreSession': 'Impossible de restaurer votre session pour le moment.',
      'welcomeBack': 'Bon retour',
      'createYourAccount': 'Créez votre compte',
      'signInBody': 'Connectez-vous pour continuer à gagner des vues et gérer vos paiements.',
      'signUpBody': 'Inscrivez-vous pour commencer à regarder des vidéos récompensées et augmenter votre solde.',
      'login': 'Connexion',
      'signUp': 'S\'inscrire',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'enterYourEmail': 'Saisissez votre e-mail.',
      'enterValidEmail': 'Saisissez une adresse e-mail valide.',
      'enterYourPassword': 'Saisissez votre mot de passe.',
      'useAtLeast6Chars': 'Utilisez au moins 6 caractères.',
      'forgotPassword': 'Mot de passe oublié ?',
      'resetPassword': 'Réinitialiser le mot de passe',
      'emailHint': 'nom@exemple.com',
      'cancel': 'Annuler',
      'sendResetLink': 'Envoyer le lien de réinitialisation',
      'passwordResetEmailSent': 'E-mail de réinitialisation du mot de passe envoyé à {email}.',
      'unableSendResetEmail': 'Impossible d\'envoyer l\'e-mail de réinitialisation.',
      'firebaseAuthNotice': 'Firebase Authentication reste inchangé. Cette refonte met uniquement à jour la couche de présentation.',
      'createAccount': 'Créer un compte',
      'secureAccessDashboard': 'Accès sécurisé à votre tableau de bord de gains',
      'firestoreBalanceStored': 'Votre historique de paiements et votre solde de récompenses sont stockés dans Firestore',
      'authenticationFailed': 'Échec de l\'authentification.',
      'noUserSessionFound': 'Aucune session utilisateur trouvée.',
      'home': 'Accueil',
      'earn': 'Gagner',
      'wallet': 'Portefeuille',
      'profile': 'Profil',
      'rewardConfirmedViewsAdded': 'Récompense confirmée. Vues ajoutées.',
      'rewardedAdNotCompleted': 'La publicité récompensée n\'a pas été terminée.',
      'watchVideo': 'Regarder la vidéo',
      'loading': 'Chargement...',
      'welcomeBackShort': 'Bon retour,',
      'signedInUser': 'Utilisateur connecté',
      'watchVideosEarnPaid': 'Regardez des vidéos, gagnez des vues et soyez payé.',
      'currentViews': 'Vues actuelles',
      'videosWatched': 'Vidéos regardées',
      'progressToPayout': 'Progression vers le paiement',
      'youAreOnYourWay': 'Vous êtes en bonne voie.',
      'earnViewsNow': 'Gagnez des vues maintenant.',
      'payoutUnlocked': 'Paiement débloqué. Vous pouvez demander un paiement dans le Portefeuille.',
      'moreViewsUntilPayout': 'Encore {views} vues avant le paiement.',
      'dailyBonus': 'Bonus quotidien',
      'watchDailyVideosBonus': 'Regardez {videos} vidéos par jour pour obtenir des vues bonus.',
      'bonusClaimed': 'Bonus réclamé',
      'bonus': 'Bonus',
      'earnViewsTitle': 'Gagner des vues',
      'watchRewardedEarnViews': 'Regardez des vidéos récompensées et gagnez des vues instantanément.',
      'earnViews': 'Gagner des vues',
      'howItWorks': 'Comment ça fonctionne',
      'watch': 'Regarder',
      'watchShortVideo': 'Regarder une courte vidéo',
      'earnStep': 'Gagner',
      'getViewsReward': 'Recevez des vues en récompense',
      'cashOut': 'Retirer',
      'reachViews': 'Atteignez {views} vues',
      'dailyChallenge': 'Défi quotidien',
      'watchTodayVideosBonus': 'Regardez {videos} vidéos aujourd\'hui et obtenez des vues bonus.',
      'totalVideosWatched': 'Nombre total de vidéos regardées',
      'memberSince': 'Membre depuis : {date}',
      'notAvailableYet': 'Pas encore disponible',
      'emailVerified': 'E-mail vérifié',
      'emailNotVerified': 'E-mail non vérifié',
      'security': 'Sécurité',
      'firebaseProtected': 'Protégé par Firebase',
      'payoutReview': 'Examen du paiement',
      'adminApproval': 'Approbation de l\'administrateur',
      'readAdminReplies': 'Lire les réponses et notifications de l\'administrateur',
      'notificationsPrivacy': 'Notifications, confidentialité et paramètres de l\'application',
      'contactAdmin': 'Contacter l\'administrateur et envoyer des messages',
      'reportProblemBug': 'Signaler un problème ou un bug',
      'rateApp': 'Noter l\'application',
      'sendInAppRating': 'Envoyez votre note dans l\'application de 1 à 5 étoiles',
      'aboutVideoMoney': 'À propos de VideoMoney',
      'reviewPayoutRequests': 'Examiner les demandes de paiement',
      'logout': 'Déconnexion',
      'yourWallet': 'Votre portefeuille',
      'availableViews': 'Vues disponibles',
      'estimatedPayout': 'Paiement estimé',
      'remainingToPayout': 'Reste avant paiement',
      'viewsUnit': 'vues',
      'estimateOnly': 'Estimation uniquement. 50 vues ≈ 0,01 € et les gains réels peuvent varier.',
      'requestPayout': 'Demander un paiement',
      'minPayout': 'Paiement min.',
      'processingTime': 'Délai de traitement',
      'approval': 'Approbation',
      'adminReview': 'Examen de l\'administrateur',
      'payoutMethods': 'Modes de paiement',
      'payoutHistory': 'Historique des paiements',
      'noPayoutRequestsYet': 'Aucune demande de paiement pour le moment.',
      'pendingTimestamp': 'Horodatage en attente',
      'paypalSubtitle': 'Demandez un paiement en EUR, GBP ou USD',
      'revolutSubtitle': 'Paiement rapide vers le portefeuille avec la devise choisie',
      'bankTransferTitle': 'Virement bancaire',
      'bankTransferSubtitle': 'Ajoutez un IBAN ou un numéro de compte bancaire pour un paiement manuel',
      'viewFullHistory': 'Voir l\'historique complet',
      'inbox': 'Boîte de réception',
      'markAllRead': 'Tout marquer comme lu',
      'noInboxMessagesYet': 'Aucun message dans la boîte de réception pour le moment.',
      'newBadge': 'NOUVEAU',
      'rateAppQuestion': 'Comment évalueriez-vous VideoMoney ?',
      'choose1to5': 'Choisissez entre 1 et 5 étoiles. Vous pourrez modifier votre note plus tard.',
      'saveRating': 'Enregistrer la note',
      'thanksForRating': 'Merci pour votre note.',
      'requestPayoutTitle': 'Demander un paiement',
      'payoutRules': 'Règles de paiement',
      'minimumPayoutIs': 'Le paiement minimum est de {views} vues.',
      'processingCanTake': 'Le traitement peut prendre jusqu\'à {days} jours après l\'approbation de l\'administrateur.',
      'everyRequestReviewed': 'Chaque demande est examinée par l\'administrateur avant d\'être payée.',
      'useBankAddIban': 'Utilisez Banque pour un transfert manuel et ajoutez votre IBAN ou numéro de compte bancaire.',
      'submitUsingBalance': 'Soumettez une demande de paiement en utilisant votre solde de vues.',
      'estimatedEarningsNotGuaranteed': 'Gains estimés uniquement. 50 vues complétées ≈ 0,01 € et ceci ne constitue pas une promesse de paiement garanti.',
      'payoutCurrency': 'Devise du paiement',
      'payoutMethod': 'Mode de paiement',
      'viewsToRequest': 'Vues à demander',
      'minimumViewsHelper': 'Minimum 10 000 vues',
      'enterAmount': 'Saisissez un montant.',
      'enterValidPositiveNumber': 'Saisissez un nombre positif valide.',
      'accountHolderName': 'Nom du titulaire du compte',
      'enterAccountHolderName': 'Saisissez le nom du titulaire du compte.',
      'paypalEmail': 'E-mail PayPal',
      'enterPaypalEmail': 'Saisissez une adresse e-mail PayPal.',
      'enterValidPaypalEmail': 'Saisissez une adresse e-mail PayPal valide.',
      'revolutUsername': 'Nom d\'utilisateur Revolut',
      'revolutExample': 'Exemple : @votrenom',
      'enterRevolutUsername': 'Saisissez votre nom d\'utilisateur Revolut.',
      'bankName': 'Nom de la banque',
      'enterBankName': 'Saisissez le nom de votre banque.',
      'iban': 'IBAN',
      'ibanOptional': 'Optionnel si vous fournissez un numéro de compte bancaire',
      'bankAccountNumber': 'Numéro de compte bancaire',
      'bankRequiredIfNoIban': 'Obligatoire si vous ne saisissez pas d\'IBAN',
      'enterIbanOrBank': 'Saisissez un IBAN ou un numéro de compte bancaire.',
      'submitRequest': 'Envoyer la demande',
      'payoutRequestSubmitted': 'Demande de paiement envoyée.',
      'payoutHistoryTitle': 'Historique des paiements',
      'unableLoadPayoutHistory': 'Impossible de charger l\'historique des paiements pour le moment.',
      'currencyLabel': 'Devise : {currency}',
      'accountHolderLabel': 'Titulaire du compte : {value}',
      'notProvided': 'Non renseigné',
      'helpSupport': 'Aide et support',
      'openSupportTicket': 'Ouvrir un ticket de support',
      'describeIssueAdminReply': 'Décrivez votre problème et l\'administrateur pourra répondre dans votre boîte de réception.',
      'subject': 'Sujet',
      'helpSubjectHint': 'De quoi avez-vous besoin d\'aide ?',
      'message': 'Message',
      'messageHint': 'Écrivez votre message ici...',
      'send': 'Envoyer',
      'sending': 'Envoi...',
      'openInbox': 'Ouvrir la boîte de réception',
      'yourTickets': 'Vos tickets',
      'noSupportTicketsYet': 'Aucun ticket de support pour le moment.',
      'supportMessageSent': 'Message de support envoyé.',
      'adminReply': 'Réponse de l\'administrateur : {value}',
      'reportBug': 'Signaler un bug',
      'tellUsWhatHappened': 'Dites-nous ce qui s\'est passé',
      'includeStepsExpected': 'Incluez les étapes pour reproduire le problème et ce que vous vous attendiez à voir.',
      'title': 'Titre',
      'shortSummary': 'Bref résumé',
      'description': 'Description',
      'describeBug': 'Décrivez le bug...',
      'submit': 'Envoyer',
      'bugReportSubmitted': 'Rapport de bug envoyé.',
      'aboutTagline': 'Thème sombre premium • Interface vert néon',
      'version': 'Version',
      'minimumPayoutLabel': 'Paiement minimum',
      'processingTimeLabel': 'Délai de traitement',
      'reviewLabel': 'Examen',
      'estimatedEarningsOnlyPolicies': 'Gains estimés uniquement. Les gains réels peuvent varier selon les performances publicitaires et les règles de la politique.',
      'privacyPolicy': 'Politique de confidentialité',
      'termsOfService': 'Conditions d\'utilisation',
      'notifications': 'Notifications',
      'enableNotifications': 'Activer les notifications',
      'generalAppNotifications': 'Notifications générales de l\'application',
      'dailyReminder': 'Rappel quotidien',
      'dailyReminderSubtitle': 'Recevez un rappel pour compléter le bonus quotidien',
      'settingsSaved': 'Paramètres enregistrés.',
      'privacy': 'Confidentialité',
      'appVersion': 'Version de l\'application',
      'save': 'Enregistrer',
      'saving': 'Enregistrement...',
      'termsUsingTitle': 'Utilisation de VideoMoney',
      'termsViewsTitle': 'Vues et récompenses',
      'termsPayoutsTitle': 'Paiements et examen',
      'termsSupportTitle': 'Support et messages',
      'termsUsingBullet1': 'Vous devez utiliser des informations de compte exactes.',
      'termsUsingBullet2': 'Une seule personne ne peut pas abuser de comptes multiples, de bots, de scripts, de rotation VPN ou de fermes d\'émulateurs pour générer des vues supplémentaires.',
      'termsUsingBullet3': 'Les publicités récompensées, l\'authentification Firebase et l\'examen des paiements restent protégés par la configuration existante de la plateforme.',
      'termsViewsBullet1': 'Les vues affichées dans l\'application sont des unités promotionnelles de récompense utilisées dans VideoMoney.',
      'termsViewsBullet2': 'Les gains estimés sont fournis à titre informatif uniquement et peuvent changer en fonction des performances de la plateforme, de la politique, des contrôles anti-fraude et de l\'examen des paiements.',
      'termsViewsBullet3': 'Les récompenses du bonus quotidien sont limitées à l\'activité éligible et peuvent être supprimées si un abus est détecté.',
      'termsPayoutsBullet1': 'Le paiement minimum reste de 10 000 vues.',
      'termsPayoutsBullet2': 'Toutes les demandes de paiement nécessitent une approbation manuelle de l\'administrateur et peuvent être approuvées, rejetées ou marquées comme payées.',
      'termsPayoutsBullet3': 'Les demandes de paiement rejetées peuvent être recréditées sur le solde de l\'utilisateur lorsque le flux de travail de l\'administrateur l\'autorise.',
      'termsSupportBullet1': 'L\'aide et le support, les rapports de bugs, les réponses de l\'administrateur et les notifications push peuvent être stockés dans votre boîte de réception intégrée.',
      'termsSupportBullet2': 'En activant les notifications, vous autorisez VideoMoney à envoyer à votre appareil des mises à jour de l\'application, des réponses du support et des rappels quotidiens.',
      'termsSupportBullet3': 'Une mauvaise utilisation grave, le harcèlement ou une activité frauduleuse peuvent entraîner une restriction de l\'accès à l\'application.',
      'settingsTitle': 'Paramètres',
      'statusPending': 'EN ATTENTE',
      'statusApproved': 'APPROUVÉ',
      'statusPaid': 'PAYÉ',
      'statusRejected': 'REJETÉ',
      'statusProcessing': 'EN COURS',
      'statusFixed': 'CORRIGÉ',
      'statusClosed': 'FERMÉ',
      'typeSupport': 'SUPPORT',
      'typePayment': 'PAIEMENT',
      'typeBug': 'BUG',
    },
    'ru': {
      'appName': 'VideoMoney',
      'startingApp': 'Запуск VideoMoney',
      'preparingStartup': 'Подготовка Firebase, данных кошелька и рекламы с вознаграждением...',
      'startupFailed': 'Не удалось запустить приложение',
      'loadingWallet': 'Загрузка вашего кошелька...',
      'unableRestoreSession': 'Сейчас не удаётся восстановить вашу сессию.',
      'welcomeBack': 'С возвращением',
      'createYourAccount': 'Создайте аккаунт',
      'signInBody': 'Войдите, чтобы продолжать зарабатывать просмотры и управлять выплатами.',
      'signUpBody': 'Зарегистрируйтесь, чтобы начать смотреть видео с вознаграждением и увеличивать свой баланс.',
      'login': 'Войти',
      'signUp': 'Регистрация',
      'email': 'Электронная почта',
      'password': 'Пароль',
      'enterYourEmail': 'Введите ваш адрес электронной почты.',
      'enterValidEmail': 'Введите действительный адрес электронной почты.',
      'enterYourPassword': 'Введите ваш пароль.',
      'useAtLeast6Chars': 'Используйте не менее 6 символов.',
      'forgotPassword': 'Забыли пароль?',
      'resetPassword': 'Сбросить пароль',
      'emailHint': 'name@example.com',
      'cancel': 'Отмена',
      'sendResetLink': 'Отправить ссылку для сброса',
      'passwordResetEmailSent': 'Письмо для сброса пароля отправлено на {email}.',
      'unableSendResetEmail': 'Не удалось отправить письмо для сброса пароля.',
      'firebaseAuthNotice': 'Firebase Authentication остаётся без изменений. Этот редизайн обновляет только слой интерфейса.',
      'createAccount': 'Создать аккаунт',
      'secureAccessDashboard': 'Безопасный доступ к вашей панели заработка',
      'firestoreBalanceStored': 'История ваших выплат и баланс вознаграждений хранятся в Firestore',
      'authenticationFailed': 'Ошибка аутентификации.',
      'noUserSessionFound': 'Сессия пользователя не найдена.',
      'home': 'Главная',
      'earn': 'Заработок',
      'wallet': 'Кошелёк',
      'profile': 'Профиль',
      'rewardConfirmedViewsAdded': 'Награда подтверждена. Просмотры добавлены.',
      'rewardedAdNotCompleted': 'Реклама с вознаграждением не была завершена.',
      'watchVideo': 'Смотреть видео',
      'loading': 'Загрузка...',
      'welcomeBackShort': 'С возвращением,',
      'signedInUser': 'Вошедший пользователь',
      'watchVideosEarnPaid': 'Смотрите видео, зарабатывайте просмотры и получайте выплаты.',
      'currentViews': 'Текущие просмотры',
      'videosWatched': 'Просмотрено видео',
      'progressToPayout': 'Прогресс до выплаты',
      'youAreOnYourWay': 'Вы на верном пути.',
      'earnViewsNow': 'Зарабатывайте просмотры сейчас.',
      'payoutUnlocked': 'Выплата разблокирована. Вы можете запросить выплату в Кошельке.',
      'moreViewsUntilPayout': 'До выплаты осталось {views} просмотров.',
      'dailyBonus': 'Ежедневный бонус',
      'watchDailyVideosBonus': 'Смотрите {videos} видео в день, чтобы получить бонусные просмотры.',
      'bonusClaimed': 'Бонус получен',
      'bonus': 'Бонус',
      'earnViewsTitle': 'Зарабатывайте просмотры',
      'watchRewardedEarnViews': 'Смотрите видео с вознаграждением и мгновенно получайте просмотры.',
      'earnViews': 'Заработать просмотры',
      'howItWorks': 'Как это работает',
      'watch': 'Смотреть',
      'watchShortVideo': 'Посмотреть короткое видео',
      'earnStep': 'Заработать',
      'getViewsReward': 'Получайте просмотры в награду',
      'cashOut': 'Вывести средства',
      'reachViews': 'Достигните {views} просмотров',
      'dailyChallenge': 'Ежедневное задание',
      'watchTodayVideosBonus': 'Посмотрите сегодня {videos} видео и получите бонусные просмотры!',
      'totalVideosWatched': 'Всего просмотрено видео',
      'memberSince': 'Участник с: {date}',
      'notAvailableYet': 'Пока недоступно',
      'emailVerified': 'Электронная почта подтверждена',
      'emailNotVerified': 'Электронная почта не подтверждена',
      'security': 'Безопасность',
      'firebaseProtected': 'Защищено Firebase',
      'payoutReview': 'Проверка выплаты',
      'adminApproval': 'Одобрение администратора',
      'readAdminReplies': 'Читайте ответы администратора и уведомления',
      'notificationsPrivacy': 'Уведомления, конфиденциальность и настройки приложения',
      'contactAdmin': 'Свяжитесь с администратором и отправьте сообщения',
      'reportProblemBug': 'Сообщить о проблеме или ошибке',
      'rateApp': 'Оценить приложение',
      'sendInAppRating': 'Отправьте свою оценку в приложении от 1 до 5 звёзд',
      'aboutVideoMoney': 'О VideoMoney',
      'reviewPayoutRequests': 'Просмотреть запросы на выплату',
      'logout': 'Выйти',
      'yourWallet': 'Ваш кошелёк',
      'availableViews': 'Доступные просмотры',
      'estimatedPayout': 'Оценочная выплата',
      'remainingToPayout': 'Осталось до выплаты',
      'viewsUnit': 'просмотры',
      'estimateOnly': 'Только оценка. 50 просмотров ≈ €0,01, и фактический доход может отличаться.',
      'requestPayout': 'Запросить выплату',
      'minPayout': 'Мин. выплата',
      'processingTime': 'Время обработки',
      'approval': 'Одобрение',
      'adminReview': 'Проверка администратором',
      'payoutMethods': 'Способы выплаты',
      'payoutHistory': 'История выплат',
      'noPayoutRequestsYet': 'Пока нет запросов на выплату.',
      'pendingTimestamp': 'Ожидаемая отметка времени',
      'paypalSubtitle': 'Запросите выплату в EUR, GBP или USD',
      'revolutSubtitle': 'Быстрая выплата на кошелёк в выбранной валюте',
      'bankTransferTitle': 'Банковский перевод',
      'bankTransferSubtitle': 'Добавьте IBAN или номер банковского счёта для ручной выплаты',
      'viewFullHistory': 'Посмотреть полную историю',
      'inbox': 'Входящие',
      'markAllRead': 'Отметить всё как прочитанное',
      'noInboxMessagesYet': 'Пока нет сообщений во входящих.',
      'newBadge': 'НОВОЕ',
      'rateAppQuestion': 'Как бы вы оценили VideoMoney?',
      'choose1to5': 'Выберите от 1 до 5 звёзд. Позже вы сможете изменить свою оценку.',
      'saveRating': 'Сохранить оценку',
      'thanksForRating': 'Спасибо за вашу оценку.',
      'requestPayoutTitle': 'Запросить выплату',
      'payoutRules': 'Правила выплат',
      'minimumPayoutIs': 'Минимальная выплата — {views} просмотров.',
      'processingCanTake': 'Обработка может занять до {days} дней после одобрения администратором.',
      'everyRequestReviewed': 'Каждый запрос проверяется администратором перед выплатой.',
      'useBankAddIban': 'Используйте Банк для ручного перевода и добавьте свой IBAN или номер банковского счёта.',
      'submitUsingBalance': 'Отправьте запрос на выплату, используя баланс просмотров.',
      'estimatedEarningsNotGuaranteed': 'Только ориентировочный доход. 50 завершённых просмотров ≈ €0,01, и это не является обещанием гарантированной выплаты.',
      'payoutCurrency': 'Валюта выплаты',
      'payoutMethod': 'Способ выплаты',
      'viewsToRequest': 'Просмотры для запроса',
      'minimumViewsHelper': 'Минимум 10 000 просмотров',
      'enterAmount': 'Введите сумму.',
      'enterValidPositiveNumber': 'Введите корректное положительное число.',
      'accountHolderName': 'Имя владельца счёта',
      'enterAccountHolderName': 'Введите имя владельца счёта.',
      'paypalEmail': 'Эл. почта PayPal',
      'enterPaypalEmail': 'Введите адрес PayPal.',
      'enterValidPaypalEmail': 'Введите действительный адрес PayPal.',
      'revolutUsername': 'Имя пользователя Revolut',
      'revolutExample': 'Пример: @yourname',
      'enterRevolutUsername': 'Введите ваше имя пользователя Revolut.',
      'bankName': 'Название банка',
      'enterBankName': 'Введите название вашего банка.',
      'iban': 'IBAN',
      'ibanOptional': 'Необязательно, если вы указываете номер банковского счёта',
      'bankAccountNumber': 'Номер банковского счёта',
      'bankRequiredIfNoIban': 'Обязательно, если вы не вводите IBAN',
      'enterIbanOrBank': 'Введите IBAN или номер банковского счёта.',
      'submitRequest': 'Отправить запрос',
      'payoutRequestSubmitted': 'Запрос на выплату отправлен.',
      'payoutHistoryTitle': 'История выплат',
      'unableLoadPayoutHistory': 'Сейчас не удаётся загрузить историю выплат.',
      'currencyLabel': 'Валюта: {currency}',
      'accountHolderLabel': 'Владелец счёта: {value}',
      'notProvided': 'Не указано',
      'helpSupport': 'Помощь и поддержка',
      'openSupportTicket': 'Открыть тикет поддержки',
      'describeIssueAdminReply': 'Опишите вашу проблему, и администратор сможет ответить во входящих.',
      'subject': 'Тема',
      'helpSubjectHint': 'С чем вам нужна помощь?',
      'message': 'Сообщение',
      'messageHint': 'Напишите ваше сообщение здесь...',
      'send': 'Отправить',
      'sending': 'Отправка...',
      'openInbox': 'Открыть входящие',
      'yourTickets': 'Ваши тикеты',
      'noSupportTicketsYet': 'Пока нет тикетов поддержки.',
      'supportMessageSent': 'Сообщение в поддержку отправлено.',
      'adminReply': 'Ответ администратора: {value}',
      'reportBug': 'Сообщить об ошибке',
      'tellUsWhatHappened': 'Расскажите, что произошло',
      'includeStepsExpected': 'Укажите шаги для воспроизведения и то, что вы ожидали увидеть.',
      'title': 'Заголовок',
      'shortSummary': 'Краткое описание',
      'description': 'Описание',
      'describeBug': 'Опишите ошибку...',
      'submit': 'Отправить',
      'bugReportSubmitted': 'Сообщение об ошибке отправлено.',
      'aboutTagline': 'Премиальная тёмная тема • Неоново-зелёный интерфейс',
      'version': 'Версия',
      'minimumPayoutLabel': 'Минимальная выплата',
      'processingTimeLabel': 'Время обработки',
      'reviewLabel': 'Проверка',
      'estimatedEarningsOnlyPolicies': 'Только ориентировочный доход. Фактический доход может отличаться в зависимости от эффективности рекламы и правил политики.',
      'privacyPolicy': 'Политика конфиденциальности',
      'termsOfService': 'Условия использования',
      'notifications': 'Уведомления',
      'enableNotifications': 'Включить уведомления',
      'generalAppNotifications': 'Общие уведомления приложения',
      'dailyReminder': 'Ежедневное напоминание',
      'dailyReminderSubtitle': 'Получайте напоминание о выполнении ежедневного бонуса',
      'settingsSaved': 'Настройки сохранены.',
      'privacy': 'Конфиденциальность',
      'appVersion': 'Версия приложения',
      'save': 'Сохранить',
      'saving': 'Сохранение...',
      'termsUsingTitle': 'Использование VideoMoney',
      'termsViewsTitle': 'Просмотры и награды',
      'termsPayoutsTitle': 'Выплаты и проверка',
      'termsSupportTitle': 'Поддержка и сообщения',
      'termsUsingBullet1': 'Вы должны использовать точную информацию об аккаунте.',
      'termsUsingBullet2': 'Один человек не должен злоупотреблять несколькими аккаунтами, ботами, скриптами, ротацией VPN или фермами эмуляторов для получения дополнительных просмотров.',
      'termsUsingBullet3': 'Реклама с вознаграждением, аутентификация Firebase и проверка выплат остаются защищёнными существующей настройкой платформы.',
      'termsViewsBullet1': 'Просмотры, показанные в приложении, являются промо-единицами вознаграждения, используемыми внутри VideoMoney.',
      'termsViewsBullet2': 'Оценочный доход носит исключительно информационный характер и может меняться в зависимости от производительности платформы, политики, проверок на мошенничество и проверки выплат.',
      'termsViewsBullet3': 'Награды ежедневного бонуса ограничены допустимой активностью и могут быть удалены при обнаружении злоупотреблений.',
      'termsPayoutsBullet1': 'Минимальная выплата остаётся 10 000 просмотров.',
      'termsPayoutsBullet2': 'Все запросы на выплату требуют ручного одобрения администратора и могут быть одобрены, отклонены или помечены как выплаченные.',
      'termsPayoutsBullet3': 'Отклонённые запросы на выплату могут быть возвращены на баланс пользователя, если это допускается рабочим процессом администратора.',
      'termsSupportBullet1': 'Помощь и поддержка, сообщения об ошибках, ответы администратора и push-уведомления могут храниться в вашем встроенном почтовом ящике.',
      'termsSupportBullet2': 'Включая уведомления, вы разрешаете VideoMoney отправлять на ваше устройство обновления приложения, ответы поддержки и ежедневные напоминания.',
      'termsSupportBullet3': 'Серьёзное злоупотребление, домогательства или мошенническая активность могут привести к ограничению доступа к приложению.',
      'settingsTitle': 'Настройки',
      'statusPending': 'В ОЖИДАНИИ',
      'statusApproved': 'ОДОБРЕНО',
      'statusPaid': 'ОПЛАЧЕНО',
      'statusRejected': 'ОТКЛОНЕНО',
      'statusProcessing': 'ОБРАБАТЫВАЕТСЯ',
      'statusFixed': 'ИСПРАВЛЕНО',
      'statusClosed': 'ЗАКРЫТО',
      'typeSupport': 'ПОДДЕРЖКА',
      'typePayment': 'ПЛАТЁЖ',
      'typeBug': 'ОШИБКА',
    },
    'el': {
      'appName': 'VideoMoney',
      'startingApp': 'Εκκίνηση του VideoMoney',
      'preparingStartup': 'Προετοιμασία του Firebase, των δεδομένων πορτοφολιού και των διαφημίσεων με ανταμοιβή...',
      'startupFailed': 'Η εκκίνηση απέτυχε',
      'loadingWallet': 'Φόρτωση του πορτοφολιού σας...',
      'unableRestoreSession': 'Δεν είναι δυνατή η επαναφορά της συνεδρίας σας αυτή τη στιγμή.',
      'welcomeBack': 'Καλώς ήρθατε ξανά',
      'createYourAccount': 'Δημιουργήστε τον λογαριασμό σας',
      'signInBody': 'Συνδεθείτε για να συνεχίσετε να κερδίζετε προβολές και να διαχειρίζεστε πληρωμές.',
      'signUpBody': 'Εγγραφείτε για να αρχίσετε να παρακολουθείτε βίντεο με ανταμοιβή και να αυξάνετε το υπόλοιπό σας.',
      'login': 'Σύνδεση',
      'signUp': 'Εγγραφή',
      'email': 'Ηλεκτρονικό ταχυδρομείο',
      'password': 'Κωδικός πρόσβασης',
      'enterYourEmail': 'Εισαγάγετε το email σας.',
      'enterValidEmail': 'Εισαγάγετε μια έγκυρη διεύθυνση email.',
      'enterYourPassword': 'Εισαγάγετε τον κωδικό πρόσβασής σας.',
      'useAtLeast6Chars': 'Χρησιμοποιήστε τουλάχιστον 6 χαρακτήρες.',
      'forgotPassword': 'Ξεχάσατε τον κωδικό σας;',
      'resetPassword': 'Επαναφορά κωδικού πρόσβασης',
      'emailHint': 'name@example.com',
      'cancel': 'Ακύρωση',
      'sendResetLink': 'Αποστολή συνδέσμου επαναφοράς',
      'passwordResetEmailSent': 'Το email επαναφοράς κωδικού στάλθηκε στο {email}.',
      'unableSendResetEmail': 'Δεν ήταν δυνατή η αποστολή του email επαναφοράς.',
      'firebaseAuthNotice': 'Το Firebase Authentication παραμένει αμετάβλητο. Αυτός ο ανασχεδιασμός ενημερώνει μόνο το επίπεδο παρουσίασης.',
      'createAccount': 'Δημιουργία λογαριασμού',
      'secureAccessDashboard': 'Ασφαλής πρόσβαση στον πίνακα κερδών σας',
      'firestoreBalanceStored': 'Το ιστορικό πληρωμών και το υπόλοιπο ανταμοιβών σας αποθηκεύονται στο Firestore',
      'authenticationFailed': 'Η ταυτοποίηση απέτυχε.',
      'noUserSessionFound': 'Δεν βρέθηκε συνεδρία χρήστη.',
      'home': 'Αρχική',
      'earn': 'Κέρδος',
      'wallet': 'Πορτοφόλι',
      'profile': 'Προφίλ',
      'rewardConfirmedViewsAdded': 'Η ανταμοιβή επιβεβαιώθηκε. Οι προβολές προστέθηκαν.',
      'rewardedAdNotCompleted': 'Η διαφήμιση με ανταμοιβή δεν ολοκληρώθηκε.',
      'watchVideo': 'Παρακολούθηση βίντεο',
      'loading': 'Φόρτωση...',
      'welcomeBackShort': 'Καλώς ήρθατε ξανά,',
      'signedInUser': 'Συνδεδεμένος χρήστης',
      'watchVideosEarnPaid': 'Παρακολουθήστε βίντεο, κερδίστε προβολές και πληρωθείτε.',
      'currentViews': 'Τρέχουσες προβολές',
      'videosWatched': 'Βίντεο που παρακολουθήθηκαν',
      'progressToPayout': 'Πρόοδος προς την πληρωμή',
      'youAreOnYourWay': 'Είστε στον σωστό δρόμο.',
      'earnViewsNow': 'Κερδίστε προβολές τώρα.',
      'payoutUnlocked': 'Η πληρωμή ξεκλειδώθηκε. Μπορείτε να ζητήσετε πληρωμή στο Πορτοφόλι.',
      'moreViewsUntilPayout': 'Απομένουν {views} προβολές μέχρι την πληρωμή.',
      'dailyBonus': 'Ημερήσιο μπόνους',
      'watchDailyVideosBonus': 'Παρακολουθήστε {videos} βίντεο καθημερινά για να λάβετε μπόνους προβολών.',
      'bonusClaimed': 'Το μπόνους ελήφθη',
      'bonus': 'Μπόνους',
      'earnViewsTitle': 'Κερδίστε προβολές',
      'watchRewardedEarnViews': 'Παρακολουθήστε βίντεο με ανταμοιβή και κερδίστε προβολές άμεσα.',
      'earnViews': 'Κέρδος προβολών',
      'howItWorks': 'Πώς λειτουργεί',
      'watch': 'Παρακολούθηση',
      'watchShortVideo': 'Παρακολουθήστε ένα σύντομο βίντεο',
      'earnStep': 'Κέρδος',
      'getViewsReward': 'Λάβετε προβολές ως ανταμοιβή',
      'cashOut': 'Εξαργύρωση',
      'reachViews': 'Φτάστε τις {views} προβολές',
      'dailyChallenge': 'Ημερήσια πρόκληση',
      'watchTodayVideosBonus': 'Παρακολουθήστε {videos} βίντεο σήμερα και λάβετε μπόνους προβολών!',
      'totalVideosWatched': 'Συνολικά βίντεο που παρακολουθήθηκαν',
      'memberSince': 'Μέλος από: {date}',
      'notAvailableYet': 'Δεν είναι ακόμη διαθέσιμο',
      'emailVerified': 'Το email επιβεβαιώθηκε',
      'emailNotVerified': 'Το email δεν έχει επιβεβαιωθεί',
      'security': 'Ασφάλεια',
      'firebaseProtected': 'Προστατεύεται από το Firebase',
      'payoutReview': 'Έλεγχος πληρωμής',
      'adminApproval': 'Έγκριση διαχειριστή',
      'readAdminReplies': 'Διαβάστε απαντήσεις και ειδοποιήσεις διαχειριστή',
      'notificationsPrivacy': 'Ειδοποιήσεις, απόρρητο και ρυθμίσεις εφαρμογής',
      'contactAdmin': 'Επικοινωνήστε με τον διαχειριστή και στείλτε μηνύματα',
      'reportProblemBug': 'Αναφέρετε πρόβλημα ή σφάλμα',
      'rateApp': 'Αξιολογήστε την εφαρμογή',
      'sendInAppRating': 'Στείλτε την αξιολόγησή σας στην εφαρμογή από 1 έως 5 αστέρια',
      'aboutVideoMoney': 'Σχετικά με το VideoMoney',
      'reviewPayoutRequests': 'Έλεγχος αιτημάτων πληρωμής',
      'logout': 'Αποσύνδεση',
      'yourWallet': 'Το πορτοφόλι σας',
      'availableViews': 'Διαθέσιμες προβολές',
      'estimatedPayout': 'Εκτιμώμενη πληρωμή',
      'remainingToPayout': 'Υπόλοιπο μέχρι την πληρωμή',
      'viewsUnit': 'προβολές',
      'estimateOnly': 'Μόνο εκτίμηση. 50 προβολές ≈ €0,01 και τα πραγματικά κέρδη μπορεί να διαφέρουν.',
      'requestPayout': 'Αίτημα πληρωμής',
      'minPayout': 'Ελάχ. πληρωμή',
      'processingTime': 'Χρόνος επεξεργασίας',
      'approval': 'Έγκριση',
      'adminReview': 'Έλεγχος διαχειριστή',
      'payoutMethods': 'Μέθοδοι πληρωμής',
      'payoutHistory': 'Ιστορικό πληρωμών',
      'noPayoutRequestsYet': 'Δεν υπάρχουν ακόμη αιτήματα πληρωμής.',
      'pendingTimestamp': 'Εκκρεμής χρονική σήμανση',
      'paypalSubtitle': 'Ζητήστε πληρωμή σε EUR, GBP ή USD',
      'revolutSubtitle': 'Γρήγορη πληρωμή στο πορτοφόλι με το επιλεγμένο νόμισμα',
      'bankTransferTitle': 'Τραπεζική μεταφορά',
      'bankTransferSubtitle': 'Προσθέστε IBAN ή αριθμό τραπεζικού λογαριασμού για χειροκίνητη πληρωμή',
      'viewFullHistory': 'Προβολή πλήρους ιστορικού',
      'inbox': 'Εισερχόμενα',
      'markAllRead': 'Σήμανση όλων ως αναγνωσμένων',
      'noInboxMessagesYet': 'Δεν υπάρχουν ακόμη μηνύματα στα εισερχόμενα.',
      'newBadge': 'ΝΕΟ',
      'rateAppQuestion': 'Πώς θα αξιολογούσατε το VideoMoney;',
      'choose1to5': 'Επιλέξτε από 1 έως 5 αστέρια. Μπορείτε να ενημερώσετε την αξιολόγησή σας αργότερα.',
      'saveRating': 'Αποθήκευση αξιολόγησης',
      'thanksForRating': 'Ευχαριστούμε για την αξιολόγησή σας.',
      'requestPayoutTitle': 'Αίτημα πληρωμής',
      'payoutRules': 'Κανόνες πληρωμής',
      'minimumPayoutIs': 'Η ελάχιστη πληρωμή είναι {views} προβολές.',
      'processingCanTake': 'Η επεξεργασία μπορεί να διαρκέσει έως και {days} ημέρες μετά την έγκριση του διαχειριστή.',
      'everyRequestReviewed': 'Κάθε αίτημα ελέγχεται από τον διαχειριστή πριν πληρωθεί.',
      'useBankAddIban': 'Χρησιμοποιήστε Τράπεζα για χειροκίνητη μεταφορά και προσθέστε το IBAN ή τον αριθμό τραπεζικού λογαριασμού σας.',
      'submitUsingBalance': 'Υποβάλετε αίτημα πληρωμής χρησιμοποιώντας το υπόλοιπο προβολών σας.',
      'estimatedEarningsNotGuaranteed': 'Μόνο εκτιμώμενα κέρδη. 50 ολοκληρωμένες προβολές ≈ €0,01 και αυτό δεν αποτελεί εγγυημένη υπόσχεση πληρωμής.',
      'payoutCurrency': 'Νόμισμα πληρωμής',
      'payoutMethod': 'Μέθοδος πληρωμής',
      'viewsToRequest': 'Προβολές προς αίτηση',
      'minimumViewsHelper': 'Ελάχιστο 10.000 προβολές',
      'enterAmount': 'Εισαγάγετε ποσό.',
      'enterValidPositiveNumber': 'Εισαγάγετε έναν έγκυρο θετικό αριθμό.',
      'accountHolderName': 'Όνομα κατόχου λογαριασμού',
      'enterAccountHolderName': 'Εισαγάγετε το όνομα του κατόχου του λογαριασμού.',
      'paypalEmail': 'Email PayPal',
      'enterPaypalEmail': 'Εισαγάγετε ένα email PayPal.',
      'enterValidPaypalEmail': 'Εισαγάγετε ένα έγκυρο email PayPal.',
      'revolutUsername': 'Όνομα χρήστη Revolut',
      'revolutExample': 'Παράδειγμα: @yourname',
      'enterRevolutUsername': 'Εισαγάγετε το όνομα χρήστη σας στο Revolut.',
      'bankName': 'Όνομα τράπεζας',
      'enterBankName': 'Εισαγάγετε το όνομα της τράπεζάς σας.',
      'iban': 'IBAN',
      'ibanOptional': 'Προαιρετικό αν παρέχετε αριθμό τραπεζικού λογαριασμού',
      'bankAccountNumber': 'Αριθμός τραπεζικού λογαριασμού',
      'bankRequiredIfNoIban': 'Απαιτείται αν δεν εισαγάγετε IBAN',
      'enterIbanOrBank': 'Εισαγάγετε IBAN ή αριθμό τραπεζικού λογαριασμού.',
      'submitRequest': 'Υποβολή αιτήματος',
      'payoutRequestSubmitted': 'Το αίτημα πληρωμής υποβλήθηκε.',
      'payoutHistoryTitle': 'Ιστορικό πληρωμών',
      'unableLoadPayoutHistory': 'Δεν είναι δυνατή η φόρτωση του ιστορικού πληρωμών αυτή τη στιγμή.',
      'currencyLabel': 'Νόμισμα: {currency}',
      'accountHolderLabel': 'Κάτοχος λογαριασμού: {value}',
      'notProvided': 'Δεν παρέχεται',
      'helpSupport': 'Βοήθεια και υποστήριξη',
      'openSupportTicket': 'Άνοιγμα αιτήματος υποστήριξης',
      'describeIssueAdminReply': 'Περιγράψτε το πρόβλημά σας και ο διαχειριστής μπορεί να απαντήσει στα εισερχόμενά σας.',
      'subject': 'Θέμα',
      'helpSubjectHint': 'Με τι χρειάζεστε βοήθεια;',
      'message': 'Μήνυμα',
      'messageHint': 'Γράψτε το μήνυμά σας εδώ...',
      'send': 'Αποστολή',
      'sending': 'Αποστολή...',
      'openInbox': 'Άνοιγμα εισερχομένων',
      'yourTickets': 'Τα αιτήματά σας',
      'noSupportTicketsYet': 'Δεν υπάρχουν ακόμη αιτήματα υποστήριξης.',
      'supportMessageSent': 'Το μήνυμα υποστήριξης στάλθηκε.',
      'adminReply': 'Απάντηση διαχειριστή: {value}',
      'reportBug': 'Αναφορά σφάλματος',
      'tellUsWhatHappened': 'Πείτε μας τι συνέβη',
      'includeStepsExpected': 'Συμπεριλάβετε τα βήματα αναπαραγωγής και τι περιμένατε να δείτε.',
      'title': 'Τίτλος',
      'shortSummary': 'Σύντομη σύνοψη',
      'description': 'Περιγραφή',
      'describeBug': 'Περιγράψτε το σφάλμα...',
      'submit': 'Υποβολή',
      'bugReportSubmitted': 'Η αναφορά σφάλματος υποβλήθηκε.',
      'aboutTagline': 'Premium σκούρο θέμα • Neon πράσινο UI',
      'version': 'Έκδοση',
      'minimumPayoutLabel': 'Ελάχιστη πληρωμή',
      'processingTimeLabel': 'Χρόνος επεξεργασίας',
      'reviewLabel': 'Έλεγχος',
      'estimatedEarningsOnlyPolicies': 'Μόνο εκτιμώμενα κέρδη. Τα πραγματικά κέρδη μπορεί να διαφέρουν ανάλογα με την απόδοση των διαφημίσεων και τους κανόνες πολιτικής.',
      'privacyPolicy': 'Πολιτική απορρήτου',
      'termsOfService': 'Όροι υπηρεσίας',
      'notifications': 'Ειδοποιήσεις',
      'enableNotifications': 'Ενεργοποίηση ειδοποιήσεων',
      'generalAppNotifications': 'Γενικές ειδοποιήσεις εφαρμογής',
      'dailyReminder': 'Ημερήσια υπενθύμιση',
      'dailyReminderSubtitle': 'Λάβετε υπενθύμιση για να ολοκληρώσετε το ημερήσιο μπόνους',
      'settingsSaved': 'Οι ρυθμίσεις αποθηκεύτηκαν.',
      'privacy': 'Απόρρητο',
      'appVersion': 'Έκδοση εφαρμογής',
      'save': 'Αποθήκευση',
      'saving': 'Αποθήκευση...',
      'termsUsingTitle': 'Χρήση του VideoMoney',
      'termsViewsTitle': 'Προβολές και ανταμοιβές',
      'termsPayoutsTitle': 'Πληρωμές και έλεγχος',
      'termsSupportTitle': 'Υποστήριξη και μηνύματα',
      'termsUsingBullet1': 'Πρέπει να χρησιμοποιείτε ακριβή στοιχεία λογαριασμού.',
      'termsUsingBullet2': 'Ένα άτομο δεν επιτρέπεται να καταχράται πολλαπλούς λογαριασμούς, bots, scripts, εναλλαγή VPN ή farms εξομοιωτών για να δημιουργεί επιπλέον προβολές.',
      'termsUsingBullet3': 'Οι διαφημίσεις με ανταμοιβή, η ταυτοποίηση Firebase και ο έλεγχος πληρωμών παραμένουν προστατευμένα από την υπάρχουσα ρύθμιση της πλατφόρμας.',
      'termsViewsBullet1': 'Οι προβολές που εμφανίζονται στην εφαρμογή είναι προωθητικές μονάδες ανταμοιβής που χρησιμοποιούνται μέσα στο VideoMoney.',
      'termsViewsBullet2': 'Τα εκτιμώμενα κέρδη είναι μόνο ενημερωτικά και μπορεί να αλλάξουν βάσει της απόδοσης της πλατφόρμας, της πολιτικής, των ελέγχων απάτης και του ελέγχου πληρωμών.',
      'termsViewsBullet3': 'Οι ανταμοιβές ημερήσιου μπόνους περιορίζονται σε επιλέξιμη δραστηριότητα και μπορούν να αφαιρεθούν αν εντοπιστεί κατάχρηση.',
      'termsPayoutsBullet1': 'Η ελάχιστη πληρωμή παραμένει 10.000 προβολές.',
      'termsPayoutsBullet2': 'Όλα τα αιτήματα πληρωμής απαιτούν χειροκίνητη έγκριση διαχειριστή και μπορούν να εγκριθούν, να απορριφθούν ή να σημειωθούν ως πληρωμένα.',
      'termsPayoutsBullet3': 'Τα απορριφθέντα αιτήματα πληρωμής μπορεί να επιστραφούν στο υπόλοιπο του χρήστη όταν αυτό επιτρέπεται από τη ροή εργασίας του διαχειριστή.',
      'termsSupportBullet1': 'Η Βοήθεια και υποστήριξη, οι αναφορές σφαλμάτων, οι απαντήσεις διαχειριστή και οι push ειδοποιήσεις μπορούν να αποθηκεύονται στα εισερχόμενα της εφαρμογής σας.',
      'termsSupportBullet2': 'Ενεργοποιώντας τις ειδοποιήσεις, επιτρέπετε στο VideoMoney να στέλνει στη συσκευή σας ενημερώσεις εφαρμογής, απαντήσεις υποστήριξης και ημερήσια μηνύματα υπενθύμισης.',
      'termsSupportBullet3': 'Σοβαρή κατάχρηση, παρενόχληση ή δόλια δραστηριότητα μπορεί να οδηγήσει σε περιορισμό της πρόσβασης στην εφαρμογή.',
      'settingsTitle': 'Ρυθμίσεις',
      'statusPending': 'ΣΕ ΕΚΚΡΕΜΟΤΗΤΑ',
      'statusApproved': 'ΕΓΚΡΙΘΗΚΕ',
      'statusPaid': 'ΠΛΗΡΩΘΗΚΕ',
      'statusRejected': 'ΑΠΟΡΡΙΦΘΗΚΕ',
      'statusProcessing': 'ΣΕ ΕΠΕΞΕΡΓΑΣΙΑ',
      'statusFixed': 'ΔΙΟΡΘΩΘΗΚΕ',
      'statusClosed': 'ΚΛΕΙΣΤΟ',
      'typeSupport': 'ΥΠΟΣΤΗΡΙΞΗ',
      'typePayment': 'ΠΛΗΡΩΜΗ',
      'typeBug': 'ΣΦΑΛΜΑ',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
