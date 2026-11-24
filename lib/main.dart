import 'more_user_benefits.dart';
import 'user_benefits.dart';
import 'user_page_canvas.dart';

import 'dart:async';
import 'dart:convert';

import 'design.dart';
import 'home_slides.dart';
import 'getting_started.dart';
import 'user_saved_login.dart';
import 'delete_account.dart';
import 'user_theme.dart';
import 'brand_wordmark.dart';
import 'account_block_guard.dart';
import 'earn_design.dart';
import 'user_page_design.dart';
import 'app_updates.dart';
import 'evidence_image.dart';
import 'support_page.dart';
import 'guest_support_page.dart';
import 'user_features.dart';
import 'push_notifications.dart';
import 'personal_information.dart';
import 'secure_auth_storage.dart';
import 'referral_download.dart';
import 'referral_history.dart';
import 'referral_design.dart';
import 'wallet_balance.dart';
import 'wallet_transfer.dart';
import 'legal_pages.dart';
import 'safe_error_widget.dart';
import 'secure_transport.dart';
import 'password_policy.dart';
import 'password_recovery.dart';
import 'auth_captcha.dart';
import 'auth_languages.dart';
import 'auth_invitation.dart';
import 'user_localization.dart';
import 'official_social_links.dart';

import 'package:share_plus/share_plus.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const authRedirect = 'space.freelan.app://login-callback/';
final language = ValueNotifier<Locale>(const Locale('en'));
SupabaseClient get db => Supabase.instance.client;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = safeErrorWidget;
  final configured = validClientConfiguration(supabaseUrl, supabaseKey);
  if (configured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      httpClient: secureHttpClient,
      realtimeClientOptions: RealtimeClientOptions(
        transport: secureRealtimeTransport,
      ),
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: true,
        localStorage: ProtectedAuthStorage(
          'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token',
        ),
        pkceAsyncStorage: ProtectedPkceStorage(Uri.parse(supabaseUrl).host),
      ),
    );
  }
  runApp(GrowthApp(configured: configured));
}

const words = <String, List<String>>{
  'savedTasks': ['Saved tasks', 'Save ചെയ്ത tasks'],
  'emptySavedTasks': [
    'No saved tasks match.',
    'Save ചെയ്ത tasks ഈ filter-ൽ ഇല്ല.',
  ],
  'emptyFilteredTasksHelp': [
    'Try all tasks or change your filters.',
    'എല്ലാ tasks-ഉം കാണുക അല്ലെങ്കിൽ filter മാറ്റുക.',
  ],
  'showAllTasks': ['Show all tasks', 'എല്ലാ tasks-ഉം കാണുക'],
  'saveTask': ['Save task', 'Task save ചെയ്യുക'],
  'unsaveTask': ['Remove saved task', 'Save ചെയ്ത task ഒഴിവാക്കുക'],
  'viewHistory': ['View all submissions', 'എല്ലാ submissions-ഉം കാണുക'],
  'helpGuide': ['Help & guide', 'സഹായവും മാർഗ്ഗനിർദ്ദേശവും'],
  'shareReferral': ['Share referral code', 'Referral code share ചെയ്യുക'],
  'referralDownload': [
    'Download Freelan Space',
    'Freelan Space ഡൗൺലോഡ് ചെയ്യുക',
  ],
  'referralDownloadUnavailable': [
    'Could not get the app download link. Please try again later.',
    'App download link ലഭിച്ചില്ല. പിന്നീട് വീണ്ടും ശ്രമിക്കുക.',
  ],
  'referralDownloadNotPublished': [
    'The app download link is not available yet. Please contact support.',
    'App download link ഇതുവരെ ലഭ്യമല്ല. Support-നെ ബന്ധപ്പെടുക.',
  ],
  'rejectionReason': [
    'Reason for rejection (optional)',
    'നിരസിക്കാനുള്ള കാരണം (ഐച്ഛികം)',
  ],
  'supportReply': [
    'Support replied to your ticket',
    'നിങ്ങളുടെ ticket-ന് support മറുപടി നൽകി',
  ],
  'adminAdjustment': ['Admin adjustment', 'Admin adjustment'],
  'support': ['Support', 'സഹായം'],
  'transferSent': ['Coins sent', 'അയച്ച coins'],
  'transferReceived': ['Coins received', 'ലഭിച്ച coins'],
  'reportCampaign': ['Report', 'റിപ്പോർട്ട്'],
  'email_otp_required': [
    'PIN setup requires a verified email account without a linked phone. Contact support to check your account.',
    'PIN സജ്ജമാക്കാൻ verified email account വേണം; linked phone ഉണ്ടെങ്കിൽ support-നെ ബന്ധപ്പെടുക.',
  ],
  'otp_required': [
    'Send and verify a fresh email OTP.',
    'പുതിയ email OTP അയച്ച് സ്ഥിരീകരിക്കുക.',
  ],
  'sendPinOtp': ['Send email OTP', 'Email OTP അയയ്ക്കുക'],
  'otpSentPin': [
    'OTP sent to your signed-in email. Enter it to verify and save your PIN.',
    'നിങ്ങളുടെ email-ലേക്ക് OTP അയച്ചു. അത് നൽകി PIN സ്ഥിരീകരിച്ച് സേവ് ചെയ്യുക.',
  ],
  'otpTitle': ['Verify your email', 'ഇമെയിൽ സ്ഥിരീകരിക്കുക'],
  'otpHint': ['Enter the 6-digit code sent to', '6 അക്ക കോഡ് അയച്ച ഇമെയിൽ'],
  'otp': ['6-digit code', '6 അക്ക കോഡ്'],
  'verifyOtp': ['Verify email', 'ഇമെയിൽ സ്ഥിരീകരിക്കുക'],
  'resendOtp': ['Resend code', 'കോഡ് വീണ്ടും അയയ്ക്കുക'],
  'receivedOtp': [
    'Already received a code? Verify email',
    'കോഡ് ലഭിച്ചോ? ഇമെയിൽ സ്ഥിരീകരിക്കുക',
  ],
  'changeEmail': [
    'Change email / Back to sign in',
    'ഇമെയിൽ മാറ്റുക / ലോഗിനിലേക്ക് മടങ്ങുക',
  ],
  'invalidOtp': ['Enter a valid 6-digit code.', 'ശരിയായ 6 അക്ക കോഡ് നൽകുക.'],
  'expiredOtp': [
    'Code is invalid or expired. Check it or request a new code.',
    'കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ കാലാവധി കഴിഞ്ഞു. പരിശോധിക്കുക അല്ലെങ്കിൽ പുതിയ കോഡ് ആവശ്യപ്പെടുക.',
  ],
  'signupComplete': [
    'Email verified. Sign in with your password to continue.',
    'ഇമെയിൽ സ്ഥിരീകരിച്ചു. തുടരാൻ പാസ്‌വേഡ് ഉപയോഗിച്ച് ലോഗിൻ ചെയ്യുക.',
  ],
  'confirmationRequired': [
    'Email confirmation must be enabled by the app owner before signup.',
    'Signup-ന് മുമ്പ് ആപ്പ് ഉടമ email confirmation പ്രവർത്തനക്ഷമമാക്കണം.',
  ],
  'checkEmail': [
    'Check your email to confirm your account.',
    'അക്കൗണ്ട് സ്ഥിരീകരിക്കാൻ ഇമെയിൽ പരിശോധിക്കുക.',
  ],
  'newPassword': ['New password', 'പുതിയ പാസ്‌വേഡ്'],
  'updatePassword': ['Update password', 'പാസ്‌വേഡ് പുതുക്കുക'],
  'passwordUpdated': ['Password updated.', 'പാസ്‌വേഡ് പുതുക്കി.'],
  'tagline': [
    'Grow together, one connection at a time.',
    'ഒരുമിച്ച് വളരാം, ഓരോ ബന്ധത്തിലൂടെയും.',
  ],
  'accountBlocked': [
    'Your app access is blocked. Contact Customer Support.',
    'നിങ്ങളുടെ app access തടഞ്ഞിരിക്കുന്നു. Customer Support-നെ ബന്ധപ്പെടുക.',
  ],
  'email': ['Email', 'ഇമെയിൽ'],
  'authWelcome': ['Welcome back', 'വീണ്ടും സ്വാഗതം'],
  'authWelcomeDesc': [
    'Sign in to continue growing together.',
    'ഒരുമിച്ച് വളരാൻ ലോഗിൻ ചെയ്യുക.',
  ],
  'authSignupDesc': [
    'Join your community today.',
    'നമ്മുടെ കൂട്ടായ്മയിൽ ചേരൂ.',
  ],
  'authName': ['Name · optional', 'പേര് · നിർബന്ധമില്ല'],
  'authNameHint': ['Your name', 'നിങ്ങളുടെ പേര്'],
  'authEmailHint': ['you@example.com', 'you@example.com'],
  'authPasswordHint': ['Enter your password', 'പാസ്‌വേഡ് നൽകുക'],
  'authNewPasswordHint': ['At least 12 characters', 'കുറഞ്ഞത് 12 അക്ഷരങ്ങൾ'],
  'authSignupHelp': [
    'Verify your email with a 6-digit code, then sign in with your password.',
    '6 അക്ക കോഡ് ഉപയോഗിച്ച് ഇമെയിൽ സ്ഥിരീകരിച്ച് പാസ്‌വേഡ് നൽകി ലോഗിൻ ചെയ്യുക.',
  ],
  'showPassword': ['Show password', 'പാസ്‌വേഡ് കാണിക്കുക'],
  'hidePassword': ['Hide password', 'പാസ്‌വേഡ് മറയ്ക്കുക'],
  'password': ['Password', 'പാസ്‌വേഡ്'],
  'login': ['Sign in', 'ലോഗിൻ'],
  'register': ['Create account', 'അക്കൗണ്ട് തുറക്കുക'],
  'forgot': ['Forgot password?', 'പാസ്‌വേഡ് മറന്നോ?'],
  'resetSent': [
    'Password reset email sent.',
    'പാസ്‌വേഡ് മാറ്റാനുള്ള ഇമെയിൽ അയച്ചു.',
  ],
  'enterEmail': ['Enter your email first.', 'ആദ്യം ഇമെയിൽ നൽകുക.'],
  'noAccount': [
    'New here? Create account',
    'പുതിയ ഉപയോക്താവാണോ? അക്കൗണ്ട് തുറക്കുക',
  ],
  'haveAccount': [
    'Already have an account? Sign in',
    'അക്കൗണ്ട് ഉണ്ടോ? ലോഗിൻ ചെയ്യുക',
  ],
  'home': ['Home', 'ഹോം'],
  'earn': ['Earn', 'നേടുക'],
  'campaigns': ['Campaigns', 'ക്യാമ്പെയ്‌നുകൾ'],
  'profile': ['Profile', 'പ്രൊഫൈൽ'],
  'balance': ['Your coin balance', 'നിങ്ങളുടെ coin ബാലൻസ്'],
  'coins': ['coins', 'coins'],
  'purchaseReason': ['Coin purchase', 'Coins വാങ്ങിയത്'],
  'welcome': [
    'Small actions. Shared momentum.',
    'ചെറിയ പ്രവർത്തനങ്ങൾ. ഒരുമിച്ചുള്ള വളർച്ച.',
  ],
  'homeDesc': [
    'Complete easy Instagram tasks and earn coins while growing our community.',
    'മറ്റുള്ളവരുടെ പോസ്റ്റുകൾ കണ്ടെത്തി coins നേടൂ; നിങ്ങളുടെ campaign ആരംഭിക്കൂ.',
  ],
  'browse': ['Browse tasks', 'Task-ുകൾ കാണുക'],
  'create': ['Create campaign', 'Campaign തുടങ്ങുക'],
  'disclaimer': [
    'Tasks are reviewed by campaign owners or administrators. Instagram activity is not automatically verified or guaranteed.',
    'Task campaign ഉടമയോ administrator-ഓ പരിശോധിക്കും. Instagram പ്രവർത്തനം സ്വയമേവ പരിശോധിക്കുകയോ ഉറപ്പുനൽകുകയോ ചെയ്യുന്നില്ല.',
  ],
  'allTasks': ['All', 'എല്ലാം'],
  'noFilteredTasks': [
    'No tasks in this category.',
    'ഈ വിഭാഗത്തിൽ task-ുകൾ ഇല്ല.',
  ],
  'notifications': ['Notifications', 'അറിയിപ്പുകൾ'],
  'noNotifications': ['No notifications yet.', 'ഇതുവരെ അറിയിപ്പുകളൊന്നുമില്ല.'],
  'notificationApproved': [
    'Your submission was approved.',
    'നിങ്ങളുടെ submission അംഗീകരിച്ചു.',
  ],
  'notificationRejected': [
    'Your submission was rejected.',
    'നിങ്ങളുടെ submission നിരസിച്ചു.',
  ],
  'notificationCoins': ['Coins received', 'Coins ലഭിച്ചു'],
  'notificationUnread': ['Unread', 'വായിച്ചിട്ടില്ല'],
  'markRead': ['Mark as read', 'വായിച്ചതായി അടയാളപ്പെടുത്തുക'],
  'earnTitle': ['Explore tasks', 'Task-ുകൾ കണ്ടെത്തുക'],
  'submitProof': ['Submit for review', 'പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofTitle': ['Submit your task', 'Task പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofInfo': [
    'Enter your Instagram username and choose a screenshot. The campaign owner or an administrator will review it before you earn coins.',
    'Instagram username-ഉം screenshot-ഉം നൽകുക. Campaign ഉടമയോ administrator-ഓ പരിശോധിച്ച ശേഷമേ coin ലഭിക്കൂ.',
  ],
  'proofHandle': ['Instagram username', 'Instagram username'],
  'proofSelect': ['Choose screenshot', 'Screenshot തിരഞ്ഞെടുക്കുക'],
  'proofChange': ['Change screenshot', 'Screenshot മാറ്റുക'],
  'proofRequired': [
    'Choose a JPEG or PNG screenshot under 512 KB.',
    '512 KB-ൽ താഴെയുള്ള JPEG അല്ലെങ്കിൽ PNG screenshot തിരഞ്ഞെടുക്കുക.',
  ],
  'proofBadHandle': [
    'Enter a valid Instagram username.',
    'ശരിയായ Instagram username നൽകുക.',
  ],
  'proofSubmitted': [
    'Submitted. Your coin is awarded after approval.',
    'അയച്ചു. അംഗീകരിച്ച ശേഷം coin ലഭിക്കും.',
  ],
  'pending': ['Awaiting review', 'പരിശോധനയ്ക്കായി കാത്തിരിക്കുന്നു'],
  'adminReviewing': [
    'AI is checking your submission',
    'AI നിങ്ങളുടെ submission പരിശോധിക്കുന്നു',
  ],
  'approved': ['Approved', 'അംഗീകരിച്ചു'],
  'rejected': ['Rejected · you can resubmit', 'നിരസിച്ചു · വീണ്ടും അയയ്ക്കാം'],
  'reviewCancelled': ['Campaign cancelled', 'Campaign റദ്ദാക്കി'],
  'reviewTitle': ['Review submission', 'Task പരിശോധിക്കുക'],
  'enlargeProof': ['Enlarge screenshot', 'Screenshot വലുതാക്കുക'],
  'reviewHelp': [
    'Check the screenshot and Instagram activity before deciding. Screenshots can be misleading.',
    'തീരുമാനിക്കുന്നതിന് മുമ്പ് screenshot-ഉം Instagram പ്രവർത്തനവും പരിശോധിക്കുക. Screenshot തെറ്റിദ്ധരിപ്പിക്കുന്നതാകാം.',
  ],
  'approve': ['Approve', 'അംഗീകരിക്കുക'],
  'reject': ['Reject', 'നിരസിക്കുക'],
  'reviewDone': ['Decision saved.', 'തീരുമാനം സേവ് ചെയ്തു.'],
  'reviewEmpty': ['Evidence unavailable.', 'തെളിവ് ലഭ്യമല്ല.'],
  'reviewCapacity': [
    'All remaining tasks are awaiting review.',
    'ബാക്കിയുള്ള task-ുകൾ പരിശോധനയ്ക്കായി കാത്തിരിക്കുന്നു.',
  ],
  'reviewedCount': ['approved', 'അംഗീകരിച്ചത്'],
  'mySubmissions': ['Your submissions', 'നിങ്ങൾ അയച്ചവ'],
  'withdraw': ['Withdraw submission', 'സമർപ്പിച്ചത് പിൻവലിക്കുക'],
  'withdrawn': [
    'Withdrawn · you can resubmit',
    'പിൻവലിച്ചു · വീണ്ടും അയയ്ക്കാം',
  ],
  'withdrawDone': ['Submission withdrawn.', 'സമർപ്പിച്ചത് പിൻവലിച്ചു.'],
  'proofNoPrivate': [
    'Share only the relevant screenshot. You, the campaign owner, and administrators can view it until review.',
    'ആവശ്യമായ screenshot മാത്രം നൽകുക. പരിശോധന വരെ അത് നിങ്ങൾക്കും campaign ഉടമയ്ക്കും administrators-നും കാണാം.',
  ],
  'earnDesc': [
    'Open Instagram, complete an action and submit it for review.',
    'Instagram തുറന്ന് പ്രവർത്തനം പൂർത്തിയാക്കി പരിശോധനയ്ക്ക് അയയ്ക്കുക.',
  ],
  'emptyTasks': ['No tasks available yet.', 'ഇപ്പോൾ task-ുകൾ ലഭ്യമല്ല.'],
  'open': ['Open Instagram', 'Instagram തുറക്കുക'],
  'confirm': ['I completed this', 'ഇത് പൂർത്തിയാക്കി'],
  'confirmTitle': ['Confirm your action', 'പ്രവർത്തനം സ്ഥിരീകരിക്കുക'],
  'confirmBody': [
    'Only confirm after completing the action. This app cannot verify Instagram activity.',
    'പ്രവർത്തനം പൂർത്തിയാക്കിയ ശേഷം മാത്രം സ്ഥിരീകരിക്കുക. ഇത് ആപ്പിന് പരിശോധിക്കാനാവില്ല.',
  ],
  'cancel': ['Cancel', 'റദ്ദാക്കുക'],
  'yesConfirm': ['Confirm', 'സ്ഥിരീകരിക്കുക'],
  'claimed': [
    'Claim recorded. Coins received.',
    'സ്ഥിരീകരിച്ചു. Coins ലഭിച്ചു.',
  ],
  'type': ['Action', 'പ്രവർത്തനം'],
  'follow': ['Follow', 'Follow'],
  'like': ['Like', 'Like'],
  'comment': ['Comment', 'Comment'],
  'share': ['Share', 'Share'],
  'link': ['Instagram link', 'Instagram ലിങ്ക്'],
  'profileHint': [
    'https://www.instagram.com/username/',
    'https://www.instagram.com/username/',
  ],
  'postHint': [
    'https://www.instagram.com/p/.../',
    'https://www.instagram.com/p/.../',
  ],
  'count': ['Number of tasks', 'Task എണ്ണം'],
  'perTask': ['per task', 'ഓരോ task-നും'],
  'totalCost': ['Total cost', 'ആകെ ചെലവ്'],
  'submit': ['Create campaign', 'Campaign തുടങ്ങുക'],
  'created': ['Campaign created.', 'Campaign ആരംഭിച്ചു.'],
  'myCampaigns': ['Your campaigns', 'നിങ്ങളുടെ campaign-ുകൾ'],
  'emptyCampaigns': ['You have no campaigns yet.', 'ഇതുവരെ campaign-ുകൾ ഇല്ല.'],
  'claims': ['counted', 'രേഖപ്പെടുത്തിയവ'],
  'legacy': [
    'Previously self-reported · already paid',
    'മുൻപ് സ്വയം അറിയിച്ചത് · coin നൽകിയിട്ടുണ്ട്',
  ],
  'legacyCount': ['Previously self-reported', 'മുൻപ് സ്വയം അറിയിച്ചത്'],
  'remaining': ['remaining', 'ബാക്കി'],
  'active': ['Active', 'സജീവം'],
  'completed': ['Completed', 'പൂർത്തിയായി'],
  'cancelled': ['Cancelled', 'റദ്ദാക്കി'],
  'cancelCampaign': ['Cancel campaign', 'Campaign റദ്ദാക്കുക'],
  'cancelTitle': ['Cancel this campaign?', 'Campaign റദ്ദാക്കണോ?'],
  'cancelBody': [
    'Unapproved tasks, including pending submissions, will be cancelled and their coins returned.',
    'പരിശോധനയിലുള്ളവ ഉൾപ്പെടെ അംഗീകരിക്കാത്ത task-ുകൾ റദ്ദാക്കി coins തിരികെ നൽകും.',
  ],
  'cancelledMessage': [
    'Campaign cancelled and unused coins refunded.',
    'Campaign റദ്ദാക്കി; ബാക്കി coins തിരികെ നൽകി.',
  ],
  'accountSection': ['Account', 'അക്കൗണ്ട്'],
  'profileJoined': ['Joined', 'ചേർന്നത്'],
  'profileAccounts': ['Accounts', 'അക്കൗണ്ടുകൾ'],
  'profileReferrals': ['Referrals', 'Referrals'],
  'profileReferralDesc': [
    'Share your code with friends',
    'നിങ്ങളുടെ code സുഹൃത്തുക്കളുമായി പങ്കിടൂ',
  ],
  'profileSettings': ['Profile settings', 'Profile settings'],
  'profileDataError': [
    'Could not load profile details.',
    'Profile വിവരങ്ങൾ ലഭ്യമായില്ല.',
  ],
  'instagramAccounts': ['Instagram accounts', 'Instagram അക്കൗണ്ടുകൾ'],
  'addAccount': [
    'Add Instagram username manually',
    'Instagram username നേരിട്ട് ചേർക്കുക',
  ],
  'instagramSearch': ['Search Instagram username', 'Instagram username തിരയുക'],
  'instagramSearchHelp': [
    'Enter the full username of a Business or Creator account. Personal and age-restricted accounts are not supported.',
    'Business അല്ലെങ്കിൽ Creator account-ന്റെ മുഴുവൻ username നൽകുക. Personal, പ്രായപരിധിയുള്ള accounts ലഭ്യമല്ല.',
  ],
  'instagramSearchHint': ['Exact username', 'മുഴുവൻ username'],
  'instagramSearchAction': ['Search', 'തിരയുക'],
  'instagramSearchAdd': ['Add account', 'Account ചേർക്കുക'],
  'instagramSearchNotFound': [
    'No supported account found. Check the full username; personal and age-restricted accounts may not appear.',
    'Account കണ്ടെത്തിയില്ല. മുഴുവൻ username പരിശോധിക്കുക; personal, പ്രായപരിധിയുള്ള accounts ലഭ്യമാകണമെന്നില്ല.',
  ],
  'instagramSearchUnavailable': [
    'Search is unavailable. Ask the app owner to configure Instagram access.',
    'Search ലഭ്യമല്ല. Instagram access ക്രമീകരിക്കാൻ app ഉടമയോട് പറയുക.',
  ],
  'instagramSearchLimited': [
    'Too many searches. Please try again later.',
    'തിരച്ചിലുകൾ കൂടുതലാണ്. കുറച്ച് കഴിഞ്ഞ് ശ്രമിക്കുക.',
  ],
  'instagramSearchDenied': [
    'Sign in again or contact the administrator.',
    'വീണ്ടും login ചെയ്യുക അല്ലെങ്കിൽ administrator-നെ ബന്ധപ്പെടുക.',
  ],
  'instagramSearchOwnership': [
    'This result does not verify account ownership.',
    'ഈ ഫലം account ഉടമസ്ഥാവകാശം സ്ഥിരീകരിക്കുന്നില്ല.',
  ],
  'noAccounts': [
    'No Instagram usernames added yet.',
    'Instagram username ചേർത്തിട്ടില്ല.',
  ],
  'removeAccount': ['Remove', 'നീക്കം ചെയ്യുക'],
  'referrals': ['Referral program', 'Referral പദ്ധതി'],
  'referralCode': ['Your referral code', 'നിങ്ങളുടെ referral കോഡ്'],
  'referralCount': ['People referred', 'Referral വഴി ചേർന്നവർ'],
  'referralEnter': ['Enter a referral code', 'Referral കോഡ് നൽകുക'],
  'referralApplied': ['Referral code applied.', 'Referral കോഡ് ചേർത്തു.'],
  'invalidReferral': ['Invalid referral code.', 'Referral കോഡ് തെറ്റാണ്.'],
  'duplicateAccount': [
    'This username is already added.',
    'ഈ username ചേർത്തിട്ടുണ്ട്.',
  ],
  'referralJoined': [
    'Referral code already applied.',
    'Referral കോഡ് ചേർത്തിട്ടുണ്ട്.',
  ],
  'referralNoReward': [
    'Referral rewards follow the current administrator settings.',
    'Admin settings അനുസരിച്ച് referral reward ലഭിക്കും.',
  ],
  'copyCode': ['Copy code', 'കോഡ് പകർത്തുക'],
  'copied': ['Code copied.', 'കോഡ് പകർത്തി.'],
  'apply': ['Apply', 'ചേർക്കുക'],
  'releasePin': ['Security PIN', 'Security PIN'],
  'setupPin': ['Set up 4-digit PIN', '4 അക്ക PIN സജ്ജമാക്കുക'],
  'changePin': ['Change / reset PIN', 'PIN മാറ്റുക / reset ചെയ്യുക'],
  'enterPin': [
    'Enter your 4-digit Security PIN to continue.',
    'തുടരാൻ 4 അക്ക Security PIN നൽകുക.',
  ],
  'currentPin': ['Current PIN', 'നിലവിലെ PIN'],
  'newPin': ['New 4-digit PIN', 'പുതിയ 4 അക്ക PIN'],
  'confirmPin': ['Confirm PIN', 'PIN സ്ഥിരീകരിക്കുക'],
  'pinMismatch': ['Enter matching 4-digit PINs.', 'ഒരേ 4 അക്ക PIN നൽകുക.'],
  'pinSaved': ['PIN saved.', 'PIN സേവ് ചെയ്തു.'],
  'pin_missing': [
    'Set up a Security PIN in your profile first.',
    'ആദ്യം പ്രൊഫൈലിൽ Security PIN സജ്ജമാക്കുക.',
  ],
  'invalid_pin': [
    'Incorrect PIN. Try again.',
    'PIN തെറ്റാണ്. വീണ്ടും ശ്രമിക്കുക.',
  ],
  'pin_locked': [
    'Too many attempts. Try again in 15 minutes.',
    'ശ്രമങ്ങൾ കൂടുതലാണ്. 15 മിനിറ്റിന് ശേഷം ശ്രമിക്കുക.',
  ],
  'invalid_format': ['Enter a 4-digit PIN.', '4 അക്ക PIN നൽകുക.'],
  'save': ['Save', 'സേവ് ചെയ്യുക'],
  'processing': ['In progress', 'പുരോഗമിക്കുന്നു'],
  'actionDisabled': [
    'This action is temporarily disabled by an administrator.',
    'ഈ action administrator താൽക്കാലികമായി തടഞ്ഞിരിക്കുന്നു.',
  ],
  'history': ['Coin history', 'Coin ചരിത്രം'],
  'emptyHistory': ['No transactions yet.', 'ഇതുവരെ ഇടപാടുകളില്ല.'],
  'welcomeReason': ['Welcome coins', 'സ്വാഗത coins'],
  'dailyBonusReason': ['Daily check-in bonus', 'Daily check-in bonus'],
  'badgeBonusReason': ['Achievement bonus', 'Achievement bonus'],
  'campaignReason': ['Campaign budget', 'Campaign ബജറ്റ്'],
  'taskReason': ['Task claim', 'Task സ്ഥിരീകരണം'],
  'refundReason': ['Campaign refund', 'Campaign refund'],
  'signout': ['Sign out', 'ലോഗൗട്ട്'],
  'language': ['മലയാളം', 'English'],
  'emailNotAuthorized': [
    'Email delivery is restricted. Ask the app owner to configure email service.',
    'ഇമെയിൽ അയയ്ക്കുന്നതിന് നിയന്ത്രണമുണ്ട്. Email service ക്രമീകരിക്കാൻ ആപ്പ് ഉടമയോട് പറയുക.',
  ],
  'emailNotConfirmed': [
    'Confirm your email before signing in. Check your inbox.',
    'ലോഗിൻ ചെയ്യുന്നതിന് മുമ്പ് ഇമെയിൽ സ്ഥിരീകരിക്കുക. Inbox പരിശോധിക്കുക.',
  ],
  'tooManyRequests': [
    'Too many attempts. Wait a while and try again.',
    'വളരെയധികം ശ്രമങ്ങൾ നടന്നു. കുറച്ച് കഴിഞ്ഞ് വീണ്ടും ശ്രമിക്കുക.',
  ],
  'signupUnavailable': [
    'Account registration is unavailable. Contact the app owner.',
    'അക്കൗണ്ട് തുറക്കാനാവുന്നില്ല. ആപ്പ് ഉടമയെ ബന്ധപ്പെടുക.',
  ],
  'connectionError': [
    'Could not connect. Check your internet and try again.',
    'ബന്ധിപ്പിക്കാൻ കഴിഞ്ഞില്ല. Internet പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
  ],
  'confirmationEmailFailed': [
    'Could not send your verification email. Try again later or contact support.',
    'Verification email അയയ്ക്കാൻ കഴിഞ്ഞില്ല. പിന്നീട് ശ്രമിക്കുക അല്ലെങ്കിൽ support-നെ ബന്ധപ്പെടുക.',
  ],
  'accountCreationFailed': [
    'Could not create your account. Try again later or contact support.',
    'അക്കൗണ്ട് തുറക്കാൻ കഴിഞ്ഞില്ല. പിന്നീട് ശ്രമിക്കുക അല്ലെങ്കിൽ support-നെ ബന്ധപ്പെടുക.',
  ],
  'serviceUnavailable': [
    'The sign-in service is temporarily unavailable. Try again later.',
    'ലോഗിൻ സേവനം ഇപ്പോൾ ലഭ്യമല്ല. കുറച്ച് കഴിഞ്ഞ് ശ്രമിക്കുക.',
  ],
  'passwordRequirements': [
    'Password does not meet the requirements. Try a stronger password.',
    'പാസ്‌വേഡ് നിബന്ധനകൾ പാലിക്കുന്നില്ല. കൂടുതൽ ശക്തമായ പാസ്‌വേഡ് നൽകുക.',
  ],
  'error': [
    'Something went wrong. Please try again.',
    'പ്രശ്നം സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കുക.',
  ],
  'required': ['This field is required.', 'ഈ വിവരങ്ങൾ നൽകുക.'],
  'openError': ['Could not open Instagram.', 'Instagram തുറക്കാൻ കഴിഞ്ഞില്ല.'],
  'loading': ['Loading…', 'ലോഡ് ചെയ്യുന്നു…'],
  'retry': ['Retry', 'വീണ്ടും ശ്രമിക്കുക'],
  'notEnough': ['Not enough coins.', 'ആവശ്യത്തിന് coins ഇല്ല.'],
  'already': [
    'You already claimed this task.',
    'ഈ task നിങ്ങൾ ഇതിനകം സ്ഥിരീകരിച്ചു.',
  ],
  'inactive': [
    'This campaign is no longer active.',
    'ഈ campaign ഇപ്പോൾ സജീവമല്ല.',
  ],
  'invalidLink': [
    'Check the Instagram link for this action.',
    'ഈ പ്രവർത്തനത്തിനുള്ള Instagram ലിങ്ക് പരിശോധിക്കുക.',
  ],
  'invalidLogin': [
    'Check your email and password. If you have no account, create one below.',
    'ഇമെയിലും പാസ്‌വേഡും പരിശോധിക്കുക. അക്കൗണ്ട് ഇല്ലെങ്കിൽ താഴെ Sign up ചെയ്യുക.',
  ],
  'emailInUse': [
    'This email is already registered.',
    'ഈ ഇമെയിൽ ഇതിനകം രജിസ്റ്റർ ചെയ്തിട്ടുണ്ട്.',
  ],
  'weakPassword': [passwordRequirementsEnglish, passwordRequirementsMalayalam],
};
String tr(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  final pair = words[key];
  return authTranslations[code]?[key] ??
      (pair == null ? key : userText(context, pair[0], pair[1]));
}

// RPC results are untrusted: only translate known PIN outcomes.
String safePinError(BuildContext context, Object? result) {
  const known = {
    'email_otp_required',
    'otp_required',
    'pin_missing',
    'invalid_pin',
    'pin_locked',
    'invalid_format',
  };
  return tr(
    context,
    result is String && known.contains(result) ? result : 'error',
  );
}

String? authErrorKey(AuthException e) {
  switch (e.code) {
    case 'otp_expired':
      return 'expiredOtp';
    case 'confirmation_required':
      return 'confirmationRequired';
    case 'email_address_not_authorized':
      return 'emailNotAuthorized';
    case 'email_not_confirmed':
      return 'emailNotConfirmed';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'tooManyRequests';
    case 'email_exists':
    case 'user_already_exists':
      return 'emailInUse';
    case 'signup_disabled':
    case 'email_provider_disabled':
      return 'signupUnavailable';
    case 'weak_password':
      return 'passwordRequirements';
    case 'invalid_credentials':
      return 'invalidLogin';
  }
  var message = e.message.toLowerCase();
  // GoTrue wraps HTTP 5xx bodies in AuthRetryableFetchException without
  // parsing their JSON error code. Read known fields, never display raw text.
  if (e is AuthRetryableFetchException && e.statusCode != null) {
    try {
      final body = jsonDecode(e.message);
      if (body is Map<String, dynamic>) {
        message =
            (body['msg'] ?? body['message'] ?? body['error_description'] ?? '')
                .toString()
                .toLowerCase();
      }
    } on FormatException {
      // Proxy HTML or other non-JSON responses retain the generic fallback.
    }
    if (message.contains('error sending confirmation email') ||
        message.contains('error sending recovery email') ||
        message.contains('error sending reauthentication email') ||
        message.contains('error sending magic link email')) {
      return 'confirmationEmailFailed';
    }
    if (message.contains('database error saving new user')) {
      return 'accountCreationFailed';
    }
  }
  if (message.contains('already registered')) return 'emailInUse';
  if (message.contains('password') && message.contains('least')) {
    return 'passwordRequirements';
  }
  if (message.contains('invalid login credentials')) return 'invalidLogin';
  if (message.contains('email') && message.contains('not authorized')) {
    return 'emailNotAuthorized';
  }
  if (e.statusCode == '429') return 'tooManyRequests';
  if (e is AuthRetryableFetchException) {
    return e.statusCode == null ? 'connectionError' : 'serviceUnavailable';
  }
  return null;
}

String friendlyError(BuildContext context, Object e) {
  if (e is AuthException) {
    final key = authErrorKey(e);
    return tr(context, key ?? 'error');
  }
  if (e is TimeoutException) return tr(context, 'connectionError');
  if (e is PostgrestException) {
    if (e.code == 'P0C01') {
      return uf(
        context,
        'Your campaign plan limit has been reached.',
        'നിങ്ങളുടെ campaign plan പരിധിയിലെത്തി.',
      );
    }
    if (e.code == 'P0C02') {
      return uf(
        context,
        'Task count exceeds your campaign plan limit.',
        'Task എണ്ണം നിങ്ങളുടെ campaign പരിധി കടന്നു.',
      );
    }
    if (e.message.contains('Account access is blocked')) {
      return tr(context, 'accountBlocked');
    }
    if (e.message.contains('already claimed') ||
        e.message.contains('already submitted')) {
      return tr(context, 'already');
    }
    if (e.message.contains('awaiting review')) {
      return tr(context, 'reviewCapacity');
    }
    if (e.message.contains('action is disabled')) {
      return tr(context, 'actionDisabled');
    }
    if (e.message.contains('cancellation period has ended')) {
      return userText(
        context,
        'The one-minute cancellation period has ended.',
        'Campaign റദ്ദാക്കാനുള്ള ഒരു മിനിറ്റ് കഴിഞ്ഞു.',
      );
    }
    if (e.message.contains('not yet available')) {
      return userText(
        context,
        'This campaign will be available one minute after creation.',
        'Campaign സൃഷ്ടിച്ച് ഒരു മിനിറ്റിനുശേഷം ലഭ്യമാകും.',
      );
    }
    if (e.message.contains('Invalid referral code')) {
      return tr(context, 'invalidReferral');
    }
    if (e.message.contains('Instagram username')) {
      return tr(context, 'proofBadHandle');
    }
    if (e.message.contains('JPEG') || e.message.contains('Invalid image')) {
      return tr(context, 'proofRequired');
    }
    if (e.message.contains('Invalid Instagram')) {
      return tr(context, 'invalidLink');
    }
    if (e.message.contains('Reward changed')) {
      return userText(
        context,
        'Reward changed. Check the updated price and try again.',
        'Coin നിരക്ക് മാറി. പുതിയ നിരക്ക് പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
      );
    }
    if (e.message.contains('Not enough coins') ||
        e.message.contains('Not enough available coins')) {
      return tr(context, 'notEnough');
    }
    if (e.message.contains('Wallet is inactive')) {
      return userText(
        context,
        'Your wallet is inactive. Contact support.',
        'Wallet inactive ആണ്. Support-നെ ബന്ധപ്പെടുക.',
      );
    }
    if (e.message.contains('no longer active')) return tr(context, 'inactive');
  }
  return tr(context, 'error');
}

void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
  );
}

void toggleLanguage() =>
    language.value = Locale(language.value.languageCode == 'en' ? 'ml' : 'en');

// Shared user-app surfaces follow the profile layout on phones and wide windows.
ThemeData growthTheme() => userAppTheme();

class AppListView extends StatelessWidget {
  const AppListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(20),
    this.panel = false,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool panel;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: padding,
        children: panel
            ? [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ]
            : children,
      ),
    ),
  );
}

class GrowthApp extends StatelessWidget {
  const GrowthApp({super.key, required this.configured});
  final bool configured;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (_, locale, _) => MaterialApp(
      title: 'Freelan Space',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ta'),
        Locale('ar'),
        Locale('ml'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: growthTheme(),
      builder: (context, child) => GrowthBackdrop(
        child: configured ? AppUpdateGate(child: child!) : child!,
      ),
      home: configured ? const AuthGate() : const SetupScreen(),
    ),
  );
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});
  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.setup,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Supabase is not configured. See the project setup instructions to build this app with a Supabase project.',
        ),
      ),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> subscription;
  bool recovery = false;
  bool blockedSignOut = false;
  @override
  void initState() {
    super.initState();
    subscription = db.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.passwordRecovery) recovery = true;
          if (state.event == AuthChangeEvent.signedIn) blockedSignOut = false;
          if (state.event == AuthChangeEvent.signedOut) {
            recovery = false;
            unawaited(PushCoordinator.instance.stop(db));
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) toast(context, friendlyError(context, error));
      },
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = db.auth.currentUser;
    if (user == null) {
      return recovery
          ? RecoveryScreen(onDone: () => setState(() => recovery = false))
          : AuthScreen(blockedNotice: blockedSignOut);
    }
    return AccountBlockGuard(
      key: ValueKey(user.id),
      events: () => accountBlockEvents(db, user.id),
      readBlocked: () => accountIsBlocked(db, user.id),
      isCurrentUser: () => db.auth.currentUser?.id == user.id,
      signOut: () async {
        if (!mounted || db.auth.currentUser?.id != user.id) return;
        setState(() => blockedSignOut = true);
        await db.auth.signOut();
      },
      child: recovery
          ? RecoveryScreen(onDone: () => setState(() => recovery = false))
          : AccountGate(key: ValueKey(user.id), user: user),
    );
  }
}

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!meetsPasswordPolicy(password.text)) {
      toast(context, tr(context, 'weakPassword'));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      if (mounted) {
        toast(context, tr(context, 'passwordUpdated'));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.recovery,
    appBar: AppBar(title: Text(tr(context, 'newPassword'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xffe6d8ff),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 32,
                    color: growthPurple,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr(context, 'newPassword'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: growthInk, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(tr(context, 'weakPassword')),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: tr(context, 'newPassword'),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: busy ? null : save,
                        child: Text(tr(context, 'updatePassword')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key, required this.user, this.initializeWallet});
  final User user;
  final Future<void> Function()? initializeWallet;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late Future<void> initialize;
  @override
  void initState() {
    super.initState();
    initialize = load();
  }

  Future<void> load() async {
    if (widget.initializeWallet != null) {
      await widget.initializeWallet!();
    } else {
      await db.rpc('initialize_wallet');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialize,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final blocked =
            snapshot.error is PostgrestException &&
            (snapshot.error! as PostgrestException).message.contains(
              'Account access is blocked',
            );
        return UserPageScaffold(
          identity: blocked ? UserPageIdentity.blocked : UserPageIdentity.setup,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (blocked) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: FreelanWordmark(),
                      ),
                      const SizedBox(height: 24),
                      const GrowthArt('blocked', height: 200),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        friendlyError(context, snapshot.error!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GrowthPrimaryButton(
                      onPressed: () {
                        final next = load();
                        next.ignore();
                        setState(() {
                          initialize = next;
                        });
                      },
                      label: tr(context, 'retry'),
                      icon: Icons.refresh,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => db.auth.signOut(),
                      icon: const Icon(Icons.logout),
                      label: Text(tr(context, 'signout')),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    if (blocked) ...[
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8ddfa),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.support_agent,
                              color: growthPurple,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                uf(
                                  context,
                                  'Need help? Contact the administrator.',
                                  'സഹായത്തിനായി administrator-നെ ബന്ധപ്പെടുക.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return UserPageScaffold(
          identity: UserPageIdentity.setup,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return HomeShell(user: widget.user);
    },
  );
}

// Signup verification uses an isolated in-memory client. Its temporary session
// never reaches AuthGate or persistent storage; only password login opens Home.
class AuthActions {
  GoTrueClient get sessionClient => db.auth;

  GoTrueClient signupClient() => GoTrueClient(
    url: '$supabaseUrl/auth/v1',
    httpClient: secureHttpClient,
    headers: {'apikey': supabaseKey},
    autoRefreshToken: false,
    flowType: AuthFlowType.implicit,
  );

  Future<void> signup(
    String email,
    String password, {
    String? name,
    String? captchaToken,
  }) async {
    final client = signupClient();
    try {
      final response = await client.signUp(
        email: email,
        password: password,
        captchaToken: captchaToken,
        data: name == null || name.trim().isEmpty
            ? null
            : {'full_name': name.trim()},
      );
      if (response.session != null) {
        throw const AuthException(
          'Confirmation required',
          code: 'confirmation_required',
        );
      }
      if (response.user?.identities?.isEmpty ?? false) {
        throw const AuthException('Registered', code: 'email_exists');
      }
    } finally {
      client.dispose();
    }
  }

  Future<void> verify(String email, String code) async {
    final client = signupClient();
    try {
      await client.verifyOTP(email: email, token: code, type: OtpType.signup);
    } finally {
      client.dispose();
    }
  }

  Future<void> resend(String email, {String? captchaToken}) async {
    final client = signupClient();
    try {
      await client.resend(
        email: email,
        type: OtpType.signup,
        captchaToken: captchaToken,
      );
    } finally {
      client.dispose();
    }
  }

  Future<void> login(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    await sessionClient.signInWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
  }

  Future<void> reset(String email, {String? captchaToken}) async {
    await sessionClient.resetPasswordForEmail(
      email,
      redirectTo: authRedirect,
      captchaToken: captchaToken,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.actions,
    this.blockedNotice = false,
    this.captchaProvider,
    this.socialLinks,
    this.savedLogin,
    this.recoveryClient,
  });
  final PasswordRecoveryClient Function()? recoveryClient;
  final UserSavedLogin? savedLogin;
  final LoadSocialLinks? socialLinks;
  final AuthActions? actions;
  final AuthCaptchaProvider? captchaProvider;
  final bool blockedNotice;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final otp = TextEditingController();
  late final AuthActions actions = widget.actions ?? AuthActions();
  bool registering = false, busy = false, showPassword = false;
  String? pendingEmail;
  int cooldown = 0;
  Timer? timer;
  late final LoadSocialLinks? socialLinks =
      widget.socialLinks ??
      (widget.actions == null ? () => loadOfficialSocialLinks(db) : null);

  UserSavedLogin get savedLogin =>
      widget.savedLogin ?? UserSavedLogin(supabaseUrl);
  bool saveLogin = true;
  Future<void> fillSavedLogin() async {
    if (registering || busy) return;
    try {
      final saved = await savedLogin.load();
      if (!mounted || saved == null || registering) return;
      final use = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(uf(c, 'Saved login', 'സൂക്ഷിച്ച login')),
          content: Text(saved['email']!),
          actions: [
            TextButton(
              onPressed: () async {
                await savedLogin.forget();
                if (c.mounted) Navigator.pop(c, false);
              },
              child: const Text('Forget saved login'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(uf(c, 'Use saved login', 'Login ഉപയോഗിക്കുക')),
            ),
          ],
        ),
      );
      if (use == true && mounted && !registering && !busy) {
        email.text = saved['email']!;
        password.text = saved['password']!;
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          uf(
            context,
            'Saved login unavailable on this device.',
            'Saved login ലഭ്യമല്ല.',
          ),
        );
      }
    }
  }

  void startCooldown() {
    timer?.cancel();
    setState(() => cooldown = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => cooldown--);
      if (cooldown == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    password.dispose();
    name.dispose();
    otp.dispose();
    super.dispose();
  }

  bool validEmail() {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      toast(context, tr(context, 'enterEmail'));
      return false;
    }
    return true;
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } on CaptchaCancelled {
      // The user closed the security check without submitting the request.
    } catch (e) {
      if (mounted) {
        if (e is AuthException && authErrorKey(e) == 'tooManyRequests') {
          startCooldown();
        }
        toast(context, friendlyError(context, e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!validEmail()) return;
    if (password.text.isEmpty) {
      toast(context, tr(context, 'required'));
      return;
    }
    if (registering && !meetsPasswordPolicy(password.text)) {
      toast(context, tr(context, 'weakPassword'));
      return;
    }
    final address = email.text.trim();
    await perform(() async {
      final captchaToken = await (widget.captchaProvider ?? requestAuthCaptcha)(
        context,
      );
      if (!mounted) return;
      if (registering) {
        await actions.signup(
          address,
          password.text,
          name: name.text,
          captchaToken: captchaToken,
        );
        if (!mounted) return;
        password.clear();
        name.clear();
        setState(() => pendingEmail = address);
        startCooldown();
      } else {
        final secret = password.text;
        await actions.login(address, secret, captchaToken: captchaToken);
        try {
          if (saveLogin) {
            await savedLogin.save(address, secret);
          } else {
            await savedLogin.forget();
          }
        } catch (_) {
          if (mounted) {
            toast(
              context,
              uf(
                context,
                'Signed in, but unable to save login securely.',
                'Login വിജയിച്ചു; സുരക്ഷിതമായി സൂക്ഷിക്കാനായില്ല.',
              ),
            );
          }
        }
      }
    });
  }

  Future<void> verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(otp.text.trim())) {
      toast(context, tr(context, 'invalidOtp'));
      return;
    }
    await perform(() async {
      await actions.verify(pendingEmail!, otp.text.trim());
      if (!mounted) return;
      otp.clear();
      password.clear();
      timer?.cancel();
      setState(() {
        cooldown = 0;
        pendingEmail = null;
        registering = false;
      });
      toast(context, tr(context, 'signupComplete'));
    });
  }

  Future<void> resend() => perform(() async {
    final captchaToken = await (widget.captchaProvider ?? requestAuthCaptcha)(
      context,
    );
    if (!mounted) return;
    await actions.resend(pendingEmail!, captchaToken: captchaToken);
    if (mounted) startCooldown();
  });

  Future<void> reset() async {
    if (busy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordRecoveryPage(
          initialEmail: email.text,
          savedLogin: savedLogin,
          captchaProvider: widget.captchaProvider,
          createClient:
              widget.recoveryClient ??
              () =>
                  PasswordRecoveryClient(actions.signupClient(), authRedirect),
        ),
      ),
    );
    if (mounted) password.clear();
  }

  InputDecoration fieldDecoration(
    String label,
    String hint, {
    Widget? suffix,
    IconData? icon,
  }) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xff6d6b7c)),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    prefixIcon: icon == null ? null : Icon(icon, color: growthPurple),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: userLine),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return UserPageScaffold(
      identity: pendingEmail != null
          ? UserPageIdentity.verification
          : registering
          ? UserPageIdentity.signUp
          : UserPageIdentity.signIn,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: FreelanWordmark(),
                          ),
                        ),
                      ),
                      AuthLanguagePicker(
                        value: Localizations.localeOf(context).languageCode,
                        onChanged: (value) => language.value = Locale(value),
                      ),
                    ],
                  ),
                  if (widget.blockedNotice) ...[
                    const SizedBox(height: 18),
                    Text(
                      tr(context, 'accountBlocked'),
                      style: const TextStyle(color: Color(0xffa23636)),
                    ),
                  ],
                  if (pendingEmail != null) ...[
                    const SizedBox(height: 18),
                    const Center(child: UserOrbitMark(size: 88)),
                  ] else
                    SizedBox(
                      height: 42,
                      child: registering
                          ? null
                          : Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: uf(
                                  context,
                                  'Customer Support',
                                  'Customer Support',
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => GuestSupportPage(
                                      client: db,
                                      project: supabaseUrl,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.support_agent,
                                  color: growthPurple,
                                ),
                              ),
                            ),
                    ),
                  if (pendingEmail == null)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  context,
                                  registering ? 'register' : 'authWelcome',
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: growthInk,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tr(
                                  context,
                                  registering
                                      ? 'authSignupDesc'
                                      : 'authWelcomeDesc',
                                ),
                                style: const TextStyle(
                                  color: Color(0xff5f5d6c),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const UserOrbitMark(size: 72),
                      ],
                    )
                  else ...[
                    Text(
                      tr(context, 'otpTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: growthInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${tr(context, 'otpHint')} $pendingEmail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff5f5d6c),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  if (pendingEmail != null) ...[
                    VerificationCodeField(controller: otp, enabled: !busy),
                    const SizedBox(height: 10),
                    GrowthPrimaryButton(
                      onPressed: busy ? null : verify,
                      label: tr(context, 'verifyOtp'),
                      icon: Icons.arrow_forward,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: busy || cooldown > 0 ? null : resend,
                      child: Text(
                        '${tr(context, 'resendOtp')}${cooldown > 0 ? ' ($cooldown)' : ''}',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              pendingEmail = null;
                              registering = false;
                              otp.clear();
                              password.clear();
                            }),
                      child: Text(tr(context, 'changeEmail')),
                    ),
                  ] else ...[
                    if (registering) ...[
                      TextField(
                        key: const Key('name'),
                        controller: name,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        inputFormatters: [LengthLimitingTextInputFormatter(80)],
                        decoration: fieldDecoration(
                          tr(context, 'authName'),
                          tr(context, 'authNameHint'),
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    TextField(
                      key: const Key('email'),
                      onTap: registering ? null : fillSavedLogin,
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: fieldDecoration(
                        tr(context, 'email'),
                        tr(context, 'authEmailHint'),
                        icon: Icons.mail_outline,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const Key('password'),
                      controller: password,
                      enabled: !busy,
                      obscureText: !showPassword,
                      autofillHints: [
                        registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: fieldDecoration(
                        tr(context, 'password'),
                        tr(
                          context,
                          registering
                              ? 'authNewPasswordHint'
                              : 'authPasswordHint',
                        ),
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: tr(
                            context,
                            showPassword ? 'hidePassword' : 'showPassword',
                          ),
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => showPassword = !showPassword,
                                ),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (registering)
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                password.text = generateStrongPassword();
                                setState(() => showPassword = true);
                              },
                        icon: const Icon(Icons.password),
                        label: Text(
                          uf(
                            context,
                            'Generate strong password',
                            'Strong password ഉണ്ടാക്കുക',
                          ),
                        ),
                      ),
                    if (!registering)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          uf(
                            context,
                            'Save login securely on this device',
                            'ഈ device-ൽ login സുരക്ഷിതമായി സൂക്ഷിക്കുക',
                          ),
                        ),
                        value: saveLogin,
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => saveLogin = value ?? false),
                      ),
                    if (!registering)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy ? null : reset,
                          child: Text(tr(context, 'forgot')),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 8),
                      Text(tr(context, 'weakPassword')),
                      const SizedBox(height: 16),
                    ],
                    GrowthPrimaryButton(
                      onPressed: busy || cooldown > 0 ? null : submit,
                      label: tr(context, registering ? 'register' : 'login'),
                      icon: Icons.arrow_forward,
                    ),
                    if (registering) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'authSignupHelp'),
                        style: const TextStyle(
                          color: Color(0xff5f5d6c),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('signup_referral_hint'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xfff2edff),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uf(
                                context,
                                'Have a code from a friend?',
                                'സുഹൃത്തിന്റെ code ഉണ്ടോ?',
                              ),
                              style: const TextStyle(
                                color: growthInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              uf(
                                context,
                                'After signing in, open Profile, choose Referral program, then tap Enter a referral code.',
                                'Sign in ചെയ്ത ശേഷം Profile തുറന്ന് Referral പദ്ധതി തിരഞ്ഞെടുക്കുക. തുടർന്ന് Referral കോഡ് നൽകുക എന്നതിൽ code നൽകുക.',
                              ),
                              style: const TextStyle(
                                color: Color(0xff5f5d6c),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const LegalLinks(),
                    ],
                    const SizedBox(height: 24),
                    if (registering)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                registering = false;
                                password.clear();
                                showPassword = false;
                              }),
                        child: Text(tr(context, 'haveAccount')),
                      )
                    else
                      AuthInvitation(
                        title: tr(context, 'noAccount'),
                        onTap: busy
                            ? null
                            : () => setState(() {
                                registering = true;
                                password.clear();
                                showPassword = false;
                              }),
                      ),
                    if (registering)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (validEmail()) {
                                  setState(
                                    () => pendingEmail = email.text.trim(),
                                  );
                                }
                              },
                        child: Text(tr(context, 'receivedOtp')),
                      ),
                  ],
                  if (!registering &&
                      pendingEmail == null &&
                      socialLinks != null)
                    OfficialSocialLinks(load: socialLinks!),
                  if (busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationCodeField extends StatefulWidget {
  const VerificationCodeField({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField> {
  final focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    focusNode.addListener(_updateFocus);
  }

  void _updateFocus() => setState(() {});
  @override
  void dispose() {
    focusNode.removeListener(_updateFocus);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffded5ed)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock, size: 14, color: growthPurple),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(context, 'otp'),
                style: const TextStyle(
                  color: growthPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: Container(
                          height: 46,
                          margin: EdgeInsets.only(right: i == 5 ? 0 : 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xfffaf9ff),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  focusNode.hasFocus &&
                                      i ==
                                          value.selection.extentOffset.clamp(
                                            0,
                                            5,
                                          )
                                  ? growthPurple
                                  : const Color(0xffe1dcec),
                            ),
                          ),
                          child: Text(
                            i < value.text.length ? value.text[i] : '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: TextField(
                key: const Key('otp'),
                controller: widget.controller,
                focusNode: focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: InputDecoration(
                  labelText: tr(context, 'otp'),
                  labelStyle: const TextStyle(color: Colors.transparent),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (_, value, _) => Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${value.text.length}/6',
              style: const TextStyle(fontSize: 10, color: Color(0xff746c8a)),
            ),
          ),
        ),
      ],
    ),
  );
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xff6554c0),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 29,
      ),
    ),
  );
}

List<Map<String, dynamic>> filterTasks(
  List<Map<String, dynamic>> tasks,
  String type,
) => type == 'all'
    ? tasks
    : tasks.where((task) => task['type'] == type).toList();

class TaskTypePicker extends StatelessWidget {
  const TaskTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final choices = <Widget>[
      for (final type in ['all', 'follow', 'like', 'comment', 'share'])
        ChoiceChip(
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 3),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(
            tr(context, type == 'all' ? 'allTasks' : type),
            style: TextStyle(
              color: selected == type ? Colors.white : growthInk,
              fontSize: 10,
            ),
          ),
          avatar: type == 'all'
              ? null
              : Icon(
                  actionIcon(type),
                  size: 14,
                  color: selected == type ? Colors.white : growthPurple,
                ),
          selectedColor: growthPurple,
          backgroundColor: Colors.white,
          showCheckmark: false,
          side: BorderSide(
            color: selected == type ? growthPurple : const Color(0xffe5daef),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          selected: selected == type,
          onSelected: (_) => onSelected(type),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 350 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
          return Row(
            children: [
              for (final choice in choices)
                Expanded(
                  child: FittedBox(fit: BoxFit.scaleDown, child: choice),
                ),
            ],
          );
        }
        return Wrap(spacing: 8, runSpacing: 4, children: choices);
      },
    );
  }
}

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({
    super.key,
    required this.stream,
    required this.onPressed,
    this.style,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) => IconButton(
          tooltip: tr(context, 'notifications'),
          onPressed: onPressed,
          style: style,
          icon: Badge(
            isLabelVisible:
                snapshot.data?.any((item) => item['read_at'] == null) ?? false,
            child: const Icon(Icons.notifications_none_outlined),
          ),
        ),
      );
}

class UserPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const UserPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.notifications,
    this.onNotifications,
    this.onSignOut,
    this.primary = true,
  });

  final String title;
  final String? subtitle;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback? onNotifications;
  final VoidCallback? onSignOut;
  final bool primary;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    ButtonStyle actionStyle(Color foreground) => IconButton.styleFrom(
      backgroundColor: const Color(0xffeee4ff),
      foregroundColor: foreground,
      fixedSize: const Size(48, 48),
      iconSize: 24,
      padding: EdgeInsets.zero,
      shape: const CircleBorder(),
    );

    void openSettings() => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const UserSettingsPage()),
    );

    return AppBar(
      primary: primary,
      toolbarHeight: preferredSize.height,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: [
        if (onNotifications != null && notifications != null) ...[
          NotificationsButton(
            stream: notifications!,
            onPressed: onNotifications!,
            style: actionStyle(growthPurple),
          ),
          const SizedBox(width: 8),
        ],
        if (onSignOut == null)
          IconButton(
            tooltip: uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'),
            style: actionStyle(growthInk),
            icon: const Icon(Icons.settings_outlined),
            onPressed: openSettings,
          )
        else
          PopupMenuButton<String>(
            tooltip: tr(context, 'profileSettings'),
            style: actionStyle(growthInk),
            icon: const Icon(Icons.settings_outlined),
            onSelected: (value) {
              if (value == 'settings') {
                openSettings();
              } else if (value == 'signout') {
                onSignOut!();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Text(uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ')),
              ),
              PopupMenuItem(
                value: 'signout',
                child: Text(tr(context, 'signout')),
              ),
            ],
          ),
      ],
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.stream,
    required this.markRead,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final Future<void> Function(String id) markRead;
  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.notifications,
    appBar: AppBar(
      title: Text(tr(context, 'notifications')),
      actions: [
        IconButton(
          tooltip: uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const UserSettingsPage()),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(tr(context, 'error')));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return AppListView(
          children: [
            UserSectionIntro(
              title: tr(context, 'notifications'),
              subtitle:
                  '${items.where((item) => item['read_at'] == null).length} ${tr(context, 'notificationUnread')}',
              icon: Icons.notifications_none_rounded,
            ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: item['read_at'] == null
                        ? const Color(0xffc8a9f7)
                        : const Color(0xffece6f4),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 19,
                    backgroundColor: item['kind'] == 'coins_received'
                        ? const Color(0xffffefd5)
                        : const Color(0xffeee6fd),
                    child: Icon(
                      item['kind'] == 'coins_received'
                          ? Icons.toll_outlined
                          : Icons.fact_check_outlined,
                      color: item['kind'] == 'coins_received'
                          ? const Color(0xff966013)
                          : growthPurple,
                      size: 20,
                    ),
                  ),
                  onTap: item['kind'] == 'app_update'
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AppUpdatePage(),
                          ),
                        )
                      : null,
                  title: Text(switch (item['kind']) {
                    'admin_message' =>
                      item['title'] as String? ?? tr(context, 'notifications'),
                    'app_update' => uf(
                      context,
                      'App update available',
                      'പുതിയ app update ലഭ്യമാണ്',
                    ),
                    'approved' => tr(context, 'notificationApproved'),
                    'rejected' => tr(context, 'notificationRejected'),
                    'support_reply' => tr(context, 'supportReply'),
                    'saved_task_unavailable' => uf(
                      context,
                      'Saved task is no longer available',
                      'Save ചെയ്ത task ഇപ്പോൾ ലഭ്യമല്ല',
                    ),
                    'login_alert' => uf(
                      context,
                      'New sign-in to your account',
                      'നിങ്ങളുടെ അക്കൗണ്ടിൽ പുതിയ sign-in',
                    ),
                    'review_reminder' => uf(
                      context,
                      'Submissions await your review',
                      'Submissions പരിശോധനയ്ക്കായി കാത്തിരിക്കുന്നു',
                    ),
                    'coins_received' =>
                      '${tr(context, 'notificationCoins')}: +${item['amount']}',
                    _ => tr(context, 'notifications'),
                  }),
                  subtitle: Text(
                    [
                      if (item['kind'] == 'admin_message' &&
                          item['body'] is String)
                        item['body'] as String,
                      if (item['kind'] == 'saved_task_unavailable' &&
                          item['saved_task_link'] is String)
                        item['saved_task_link'] as String,
                      if (item['read_at'] == null)
                        tr(context, 'notificationUnread'),
                      if (DateTime.tryParse(
                            item['created_at']?.toString() ?? '',
                          )
                          case final date?)
                        MaterialLocalizations.of(context)
                            .formatShortDate(date.toLocal()),
                    ].join(' · '),
                  ),
                  trailing: item['read_at'] == null
                      ? IconButton(
                          tooltip: tr(context, 'markRead'),
                          icon: const Icon(Icons.mark_email_read_outlined),
                          onPressed: () async {
                            try {
                              await markRead(item['id'] as String);
                            } catch (_) {
                              if (context.mounted) {
                                toast(context, tr(context, 'error'));
                              }
                            }
                          },
                        )
                      : null,
                ),
              ),
            GrowthEmpty(
              art: 'notification_empty',
              title: items.isEmpty
                  ? tr(context, 'noNotifications')
                  : uf(
                      context,
                      'No more notifications',
                      'കൂടുതൽ notifications ഇല്ല',
                    ),
              subtitle: uf(
                context,
                "You're all caught up!",
                'പുതിയ notifications ഒന്നുമില്ല.',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final User user;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  Timer? _pushRetry;
  int selected = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(PushCoordinator.instance.restore(db));
    // Recover registration after an offline startup or a failed token refresh.
    _pushRetry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(PushCoordinator.instance.restore(db));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushCoordinator.instance.restore(db));
    }
  }

  @override
  void dispose() {
    _pushRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Rebuilding the signed-in shell must not revoke background push delivery.
    if (db.auth.currentUser?.id == widget.user.id) {
      unawaited(PushCoordinator.instance.detach());
    } else {
      unawaited(PushCoordinator.instance.stop(db));
    }
    super.dispose();
  }

  late final Stream<List<Map<String, dynamic>>> notifications = db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', widget.user.id)
      .order('created_at', ascending: false);
  void openNotifications() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => NotificationsPage(
        stream: notifications,
        markRead: (id) async {
          await db
              .from('notifications')
              .update({'read_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', id);
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        onBrowse: () => setState(() {
          selected = 1;
        }),
        onCampaigns: () => setState(() {
          selected = 2;
        }),
        onBrowseType: (type) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskCategoryPage(uid: widget.user.id, type: type),
          ),
        ),
        uid: widget.user.id,
        benefitsClient: db,
        slideshowGateway: HomeSlidesGateway(db),
        onReferrals: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileDetailsPage(
              uid: widget.user.id,
              gateway: SupabaseProfileGateway(db),
              accounts: false,
            ),
          ),
        ),
      ),
      EarnLanding(uid: widget.user.id),
      Campaigns(uid: widget.user.id),
      Profile(
        user: widget.user,
        onNotifications: openNotifications,
        notifications: notifications,
      ),
    ];
    final labels = ['home', 'earn', 'campaigns', 'profile'];
    return UserPageScaffold(
      identity: switch (selected) {
        0 => UserPageIdentity.home,
        1 => UserPageIdentity.earn,
        2 => UserPageIdentity.campaigns,
        _ => UserPageIdentity.profile,
      },
      appBar: selected == 3
          ? null
          : UserPageHeader(
              title: tr(context, labels[selected]),
              subtitle: selected == 2
                  ? uf(
                      context,
                      'Create and manage your campaigns with ease.',
                      'നിങ്ങളുടെ campaigns നിയന്ത്രിക്കുക.',
                    )
                  : null,
              notifications: notifications,
              onNotifications: openNotifications,
            ),
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: GrowthNavigation(
        selected: selected,
        labels: [for (final label in labels) tr(context, label)],
        onSelected: (index) => setState(() => selected = index),
      ),
    );
  }
}

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.uid,
    this.balanceStream,
    this.historyStream,
  });
  final String uid;
  final Stream<List<Map<String, dynamic>>>? balanceStream;
  final Stream<List<Map<String, dynamic>>>? historyStream;
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  late Stream<List<Map<String, dynamic>>> balances =
      widget.balanceStream ??
      db.from('wallets').stream(primaryKey: ['id']).eq('id', widget.uid);

  @override
  void didUpdateWidget(covariant BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.balanceStream != widget.balanceStream) {
      balances =
          widget.balanceStream ??
          db.from('wallets').stream(primaryKey: ['id']).eq('id', widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) => WalletBalance(
    key: ValueKey(widget.uid),
    balances: balances,
    onHistory: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoinHistoryPage(
          uid: widget.uid,
          historyStream: widget.historyStream,
        ),
      ),
    ),
    onTransfer: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WalletTransferPage(client: db)),
    ),
    onBuyCoins: () => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(uf(c, 'Add coins', 'Coins ചേർക്കുക')),
        content: Text(uf(c, 'Service coming soon', 'Service ഉടൻ ലഭ്യമാകും')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
    isMalayalam: language.value.languageCode == 'ml',
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.onBrowse,
    required this.uid,
    this.balanceStream,
    this.historyStream,
    this.onBrowseType,
    this.slideshowGateway,
    this.benefitsClient,
    this.onReferrals,
    this.onCampaigns,
  });
  final Stream<List<Map<String, dynamic>>>? balanceStream;
  final Stream<List<Map<String, dynamic>>>? historyStream;
  final ValueChanged<String>? onBrowseType;
  final VoidCallback onBrowse;
  final VoidCallback? onReferrals, onCampaigns;
  final HomeSlidesGateway? slideshowGateway;
  final SupabaseClient? benefitsClient;
  final String uid;
  @override
  Widget build(BuildContext context) => AppListView(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
    children: [
      BalanceCard(
        uid: uid,
        balanceStream: balanceStream,
        historyStream: historyStream,
      ),
      if (benefitsClient != null) ...[
        WeeklyCoinSummary(client: benefitsClient!),
        RewardsAndGoal(client: benefitsClient!),
        GuidedFirstTask(
          client: benefitsClient!,
          userId: uid,
          onBrowse: onBrowse,
        ),
      ],
      const SizedBox(height: 20),
      HomeSlideshow(
        gateway: slideshowGateway,
        onReferral: onReferrals,
        onEarnings: onBrowse,
      ),
      GettingStarted(onBrowse: onBrowse, onCampaigns: onCampaigns),
      const SizedBox(height: 14),
      Text(
        tr(context, 'welcome'),
        style: const TextStyle(
          fontSize: 23,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: growthInk,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        tr(context, 'homeDesc'),
        style: const TextStyle(
          fontSize: 12,
          height: 1.5,
          color: Color(0xff6d6580),
        ),
      ),
      const SizedBox(height: 16),
      for (final pair in [
        ['like', 'comment'],
        ['share', 'follow'],
      ]) ...[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < pair.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(child: taskTile(context, pair[index])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 14),
      const Notice(
        refined: true,
        text: 'Every campaign task and Instagram activity is reviewed and verified by AI with a 100% guarantee.',
      ),
    ],
  );

  Widget taskTile(BuildContext context, String type) => DashboardTaskTile(
    icon: actionIcon(type),
    title: tr(context, type),
    subtitle: taskDescription(context, type),
    accent: taskAccent(type),
    onTap: () {
      if (onBrowseType != null) {
        onBrowseType!(type);
      } else {
        onBrowse();
      }
    },
  );
}

String taskDescription(BuildContext context, String type) => switch (type) {
  'like' => uf(
    context,
    'Like an Instagram post',
    'Instagram post like ചെയ്യുക',
  ),
  'comment' => uf(context, 'Leave a thoughtful comment', 'ഒരു comment നൽകുക'),
  'share' => uf(
    context,
    'Share a post with friends',
    'Post സുഹൃത്തുക്കളുമായി share ചെയ്യുക',
  ),
  _ => uf(context, 'Follow an Instagram page', 'Instagram page follow ചെയ്യുക'),
};

Color taskAccent(String type) => switch (type) {
  'like' => const Color(0xffc34f82),
  'comment' => const Color(0xff6d49ad),
  'share' => const Color(0xff426bb4),
  _ => const Color(0xff7650bf),
};

class Notice extends StatelessWidget {
  const Notice({super.key, this.refined = false, this.text});
  final bool refined;
  final String? text;
  @override
  Widget build(BuildContext context) => refined
      ? Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffeeedf5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: growthPurple,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text ?? tr(context, 'disclaimer'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: growthInk,
                  ),
                ),
              ),
            ],
          ),
        )
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xfff1eefb),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.info, color: growthPurple, size: 24),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xffb99cdd),
              ),
              Expanded(
                child: Text(
                  text ?? tr(context, 'disclaimer'),
                  style: const TextStyle(fontSize: 10, color: growthInk),
                ),
              ),
            ],
          ),
        );
}

IconData actionIcon(String type) => switch (type) {
  'follow' => Icons.person_add_alt_1,
  'like' => Icons.favorite_border,
  'comment' => Icons.chat_bubble_outline,
  'share' => Icons.ios_share,
  _ => Icons.circle_outlined,
};

// Keep campaign link validation aligned with growth_internal.create_campaign.
String? normalizeCampaignLink(String type, String value) {
  if (value.length > 500 ||
      !const ['follow', 'like', 'comment', 'share'].contains(type)) {
    return null;
  }
  final clean = value.trim().replaceFirst(RegExp(r'[?#].*$'), '');
  final prefix = RegExp(
    r'^https://(www\.)?instagram\.com/',
    caseSensitive: false,
  );
  if (!prefix.hasMatch(clean)) return null;
  final path = clean.replaceFirst(prefix, '').replaceFirst(RegExp(r'/+$'), '');
  if (type == 'follow') {
    if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(path) ||
        const [
          'p',
          'reel',
          'reels',
          'stories',
          'explore',
          'accounts',
        ].contains(path.toLowerCase())) {
      return null;
    }
  } else if (!RegExp(r'^(p|reel)/[A-Za-z0-9_-]+$').hasMatch(path)) {
    return null;
  }
  return 'https://www.instagram.com/$path/';
}

Future<void> openInstagram(BuildContext context, String link) async {
  try {
    final clean =
        normalizeCampaignLink('follow', link) ??
        normalizeCampaignLink('like', link);
    if (clean == null) throw const FormatException('Invalid Instagram link.');
    final uri = Uri.parse(clean);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      toast(context, tr(context, 'openError'));
    }
  } catch (_) {
    if (context.mounted) toast(context, tr(context, 'openError'));
  }
}

class ClaimProof {
  const ClaimProof(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

typedef ProofPicker = Future<ClaimProof?> Function();

Future<ClaimProof?> pickScreenshot() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 60,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  if (await file.length() > 524288) {
    throw const FormatException('Image too large');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length < 16 || bytes.length > 524288) {
    throw const FormatException('Invalid image');
  }
  final png =
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final jpg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
  if (!png && !jpg) throw const FormatException('Invalid image');
  await validateEvidenceImage(bytes);
  return ClaimProof(bytes, png ? 'image/png' : 'image/jpeg');
}

class ClaimSubmissionDialog extends StatefulWidget {
  const ClaimSubmissionDialog({super.key, required this.onSubmit, this.picker});
  final Future<void> Function(String handle, ClaimProof proof) onSubmit;
  final ProofPicker? picker;
  @override
  State<ClaimSubmissionDialog> createState() => _ClaimSubmissionDialogState();
}

class _ClaimSubmissionDialogState extends State<ClaimSubmissionDialog> {
  final handle = TextEditingController();
  ClaimProof? proof;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    handle.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await (widget.picker ?? pickScreenshot)();
      if (mounted && selected != null) setState(() => proof = selected);
    } catch (_) {
      if (mounted) setState(() => error = tr(context, 'proofRequired'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final value = handle.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(value)) {
      setState(() => error = tr(context, 'proofBadHandle'));
      return;
    }
    if (proof == null) {
      setState(() => error = tr(context, 'proofRequired'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(value, proof!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'proofTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'proofInfo')),
          const SizedBox(height: 16),
          TextField(
            key: const Key('proof_handle'),
            controller: handle,
            enabled: !busy,
            maxLength: 31,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: tr(context, 'proofHandle'),
              hintText: '@username',
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              tr(context, proof == null ? 'proofSelect' : 'proofChange'),
            ),
          ),
          if (proof != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.memory(
                proof!.bytes,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(tr(context, 'proofRequired')),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'proofNoPrivate'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(tr(context, 'submitProof')),
      ),
    ],
  );
}

class ClaimReviewDialog extends StatefulWidget {
  const ClaimReviewDialog({
    super.key,
    required this.handle,
    required this.loadEvidence,
    required this.onDecision,
    this.onRejectWithReason,
  });
  final String handle;
  final Future<Map<String, dynamic>> Function() loadEvidence;
  final Future<void> Function(bool approve, String? pin) onDecision;
  final Future<void> Function(String reason)? onRejectWithReason;
  @override
  State<ClaimReviewDialog> createState() => _ClaimReviewDialogState();
}

class _ClaimReviewDialogState extends State<ClaimReviewDialog> {
  late final Future<Uint8List> evidence = load();
  bool busy = false;
  String? error;
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<Uint8List> load() async {
    final value = await widget.loadEvidence();
    final data = value['data'];
    if (data is! String) throw const FormatException('Missing evidence');
    return decodeEvidenceImage(data);
  }

  Future<void> decide(bool approve) async {
    if (busy) return;
    String? pin;
    if (approve) {
      pin = await showDialog<String>(
        context: context,
        builder: (_) => const ReleasePinDialog(),
      );
      if (pin == null || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!approve &&
          widget.onRejectWithReason != null &&
          reason.text.trim().isNotEmpty) {
        await widget.onRejectWithReason!(reason.text.trim());
      } else {
        await widget.onDecision(approve, pin);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PinException
              ? safePinError(context, e.code)
              : friendlyError(context, e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'reviewTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${widget.handle}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(tr(context, 'reviewHelp')),
          const SizedBox(height: 12),
          FutureBuilder<Uint8List>(
            future: evidence,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(tr(context, 'reviewEmpty'));
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final bytes = snapshot.data!;
              return Column(
                children: [
                  Image.memory(
                    bytes,
                    height: 220,
                    fit: BoxFit.contain,
                    cacheWidth: 1024,
                    errorBuilder: (_, _, _) => Text(tr(context, 'reviewEmpty')),
                  ),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog.fullscreen(
                        child: UserPageScaffold(
                          identity: UserPageIdentity.evidence,
                          appBar: AppBar(
                            title: Text(tr(context, 'reviewTitle')),
                          ),
                          body: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Center(
                              child: Image.memory(
                                bytes,
                                cacheWidth: 2048,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.zoom_in),
                    label: Text(tr(context, 'enlargeProof')),
                  ),
                ],
              );
            },
          ),
          if (widget.onRejectWithReason != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr(context, 'rejectionReason'),
              ),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: Text(tr(context, 'cancel')),
      ),
      FutureBuilder<Uint8List>(
        future: evidence,
        builder: (context, snapshot) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed:
                  busy || snapshot.connectionState != ConnectionState.done
                  ? null
                  : () => decide(false),
              child: Text(tr(context, 'reject')),
            ),
            FilledButton(
              onPressed: busy || !snapshot.hasData ? null : () => decide(true),
              child: Text(tr(context, 'approve')),
            ),
          ],
        ),
      ),
    ],
  );
}

class ReviewApi {
  const ReviewApi(this.client);
  final SupabaseClient client;
  Future<void> submit(String campaign, String handle, ClaimProof proof) async {
    await client.rpc(
      'submit_claim',
      params: {
        'p_campaign_id': campaign,
        'p_instagram_handle': handle,
        'p_mime': proof.mime,
        'p_evidence': base64Encode(proof.bytes),
      },
    );
  }

  Future<void> withdraw(String campaign) async {
    await client.rpc('withdraw_claim', params: {'p_campaign_id': campaign});
  }

  Future<Map<String, dynamic>> evidence(
    String campaign,
    String participant,
    String submission,
  ) async {
    return Map<String, dynamic>.from(
      await client.rpc(
        'get_claim_evidence',
        params: {
          'p_campaign_id': campaign,
          'p_user_id': participant,
          'p_submission_id': submission,
        },
      ) as Map,
    );
  }

  Future<void> rejectWithReason(
    String campaign,
    String participant,
    String submission,
    String reason,
  ) async {
    final result = await client.rpc(
      'review_claim_with_feedback',
      params: {
        'p_campaign_id': campaign,
        'p_user_id': participant,
        'p_submission_id': submission,
        'p_approve': false,
        'p_pin': null,
        'p_reason': reason,
      },
    );
    if (result != 'ok') throw PinException(result.toString());
  }

  Future<void> decide(
    String campaign,
    String participant,
    String submission,
    bool approve, [
    String? pin,
  ]) async {
    final result = await client.rpc(
      'review_claim_with_pin',
      params: {
        'p_campaign_id': campaign,
        'p_user_id': participant,
        'p_submission_id': submission,
        'p_approve': approve,
        'p_pin': pin,
      },
    );
    if (result != 'ok') throw PinException(result.toString());
  }
}

const earnCategories = ['follow', 'like', 'comment', 'share'];

class EarnLanding extends StatelessWidget {
  const EarnLanding({
    super.key,
    required this.uid,
    this.categoryBuilder,
    this.openHistory,
  });
  final String uid;
  final Widget Function(String type)? categoryBuilder;
  final VoidCallback? openHistory;

  @override
  Widget build(BuildContext context) => AppListView(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
    children: [
      UserSectionIntro(
        title: tr(context, 'earnTitle'),
        subtitle: tr(context, 'earnDesc'),
        icon: Icons.explore_outlined,
      ),
      const SizedBox(height: 20),
      EarnSectionHeader(title: uf(context, 'Tasks', 'Task-ുകൾ')),
      const SizedBox(height: 10),
      for (final type in earnCategories) ...[
        EarnCategoryTile(
          icon: actionIcon(type),
          title: tr(context, type),
          subtitle: taskDescription(context, type),
          accent: taskAccent(type),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  categoryBuilder?.call(type) ??
                  TaskCategoryPage(uid: uid, type: type),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed:
              openHistory ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SubmissionHistoryPage(client: db),
                ),
              ),
          icon: const Icon(Icons.history),
          label: Text(tr(context, 'viewHistory')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: Colors.white,
            foregroundColor: growthPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Notice(refined: true),
    ],
  );
}

class TaskCategoryPage extends StatelessWidget {
  const TaskCategoryPage({
    super.key,
    required this.uid,
    required this.type,
    this.controlsStream,
    this.presenceStream,
    this.campaignsStream,
    this.claimsStream,
    this.loadSavedIds,
  }) : assert(
         type == 'follow' ||
             type == 'like' ||
             type == 'comment' ||
             type == 'share',
       );
  final String uid, type;
  final Stream<List<Map<String, dynamic>>>? controlsStream,
      presenceStream,
      campaignsStream,
      claimsStream;
  final Future<List<String>> Function()? loadSavedIds;

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.earn,
    appBar: AppBar(title: Text(tr(context, type))),
    body: SafeArea(
      child: TaskList(
        uid: uid,
        initialType: type,
        separatePage: true,
        controlsStream: controlsStream,
        presenceStream: presenceStream,
        campaignsStream: campaignsStream,
        claimsStream: claimsStream,
        loadSavedIds: loadSavedIds,
      ),
    ),
  );
}

class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.uid,
    this.controlsStream,
    this.presenceStream,
    this.campaignsStream,
    this.claimsStream,
    this.loadSavedIds,
    this.searchFeatureLoader,
    this.initialType = 'all',
    this.separatePage = false,
  });
  final String initialType;
  final bool separatePage;
  final String uid;
  final Stream<List<Map<String, dynamic>>>? controlsStream,
      presenceStream,
      campaignsStream,
      claimsStream;
  final Future<List<String>> Function()? loadSavedIds;
  final Future<bool> Function()? searchFeatureLoader;
  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  late String selectedType = widget.initialType;
  late Stream<List<Map<String, dynamic>>> campaignFeed;
  late Stream<List<Map<String, dynamic>>> controlsFeed,
      presenceFeed,
      claimsFeed;
  Timer? campaignRefresh;
  final saved = <String>{};
  bool savedOnly = false, savedLoading = true, savedError = false;
  bool searchEnabled = false;
  String taskQuery = '', taskSort = 'newest';
  final taskSearch = TextEditingController();
  final saving = <String>{};
  @override
  void initState() {
    super.initState();
    configureOtherFeeds();
    configureCampaignFeed();
    loadSaved();
    loadSearchFeature();
  }

  Future<void> loadSearchFeature() async {
    try {
      final enabled =
          await (widget.searchFeatureLoader?.call() ??
              benefitEnabled(db, 'task_search'));
      if (mounted) setState(() => searchEnabled = enabled);
    } catch (_) {
      /* Existing task browsing remains available. */
    }
  }

  void configureOtherFeeds() {
    controlsFeed =
        widget.controlsStream ??
        db.from('action_controls').stream(primaryKey: ['action_type']);
    presenceFeed =
        widget.presenceStream ??
        db
            .from('admin_review_presence')
            .stream(primaryKey: ['session_id'])
            .eq('user_id', widget.uid);
    claimsFeed =
        widget.claimsStream ??
        db
            .from('campaign_claims')
            .stream(primaryKey: ['campaign_id', 'user_id'])
            .eq('user_id', widget.uid);
  }

  void configureCampaignFeed() {
    campaignRefresh?.cancel();
    campaignFeed =
        widget.campaignsStream ??
        db.from('campaigns').stream(primaryKey: ['id']);
    if (widget.campaignsStream == null) {
      // RLS makes a campaign readable after a minute without a database event.
      campaignRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          setState(
            () =>
                campaignFeed = db.from('campaigns').stream(primaryKey: ['id']),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaignsStream != widget.campaignsStream) {
      configureCampaignFeed();
    }
    if (oldWidget.uid != widget.uid ||
        oldWidget.controlsStream != widget.controlsStream ||
        oldWidget.presenceStream != widget.presenceStream ||
        oldWidget.claimsStream != widget.claimsStream) {
      configureOtherFeeds();
    }
  }

  @override
  void dispose() {
    campaignRefresh?.cancel();
    taskSearch.dispose();
    super.dispose();
  }

  Future<void> loadSaved() async {
    try {
      final ids = widget.loadSavedIds != null
          ? await widget.loadSavedIds!()
          : (await db
                    .from('saved_tasks')
                    .select('campaign_id')
                    .eq('user_id', widget.uid))
                .map((row) => row['campaign_id'] as String)
                .toList();
      if (mounted) {
        setState(() {
          saved
            ..clear()
            ..addAll(ids);
          savedError = false;
          savedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          savedError = true;
          savedLoading = false;
        });
      }
    }
  }

  Future<void> toggleSaved(String id) async {
    if (saving.contains(id)) return;
    final next = !saved.contains(id);
    setState(() => saving.add(id));
    try {
      await db.rpc(
        'set_task_saved',
        params: {'p_campaign': id, 'p_saved': next},
      );
      if (mounted) {
        setState(() {
          if (next) {
            saved.add(id);
          } else {
            saved.remove(id);
          }
        });
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  Future<void> claim(BuildContext context, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClaimSubmissionDialog(
        onSubmit: (handle, proof) => ReviewApi(db).submit(id, handle, proof),
      ),
    );
    if (result == true && context.mounted) {
      toast(context, tr(context, 'proofSubmitted'));
    }
  }

  Future<void> withdraw(BuildContext context, String id) async {
    try {
      await ReviewApi(db).withdraw(id);
      if (context.mounted) toast(context, tr(context, 'withdrawDone'));
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: controlsFeed,
        builder: (context, controls) {
          if (controls.hasError) {
            return Center(child: Text(tr(context, 'error')));
          }
          if (!controls.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final actionStates = {
            for (final row in controls.data!)
              row['action_type'] as String: row['enabled'] == true,
          };
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: presenceFeed,
            builder: (context, presence) {
              if (presence.hasError) {
                return Center(child: Text(tr(context, 'error')));
              }
              if (!presence.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return buildTasks(context, actionStates, presence.data!);
            },
          );
        },
      );

  Widget buildTasks(
    BuildContext context,
    Map<String, bool> controls,
    List<Map<String, dynamic>> presence,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: campaignFeed,
    builder: (context, campaigns) {
      if (campaigns.hasError) return Center(child: Text(tr(context, 'error')));
      if (!campaigns.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: claimsFeed,
        builder: (context, claims) {
          if (claims.hasError) return Center(child: Text(tr(context, 'error')));
          if (!claims.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = claims.data!;
          final byCampaign = {
            for (final claim in mine) claim['campaign_id']: claim,
          };
          final allCampaigns = {
            for (final campaign in campaigns.data!) campaign['id']: campaign,
          };
          final tasks = campaigns.data!
              .where(
                (d) => d['ownerId'] != widget.uid && d['status'] == 'active',
              )
              .toList();
          final filteredTasks = filterTasks(
            tasks,
            selectedType,
          ).where((task) => !savedOnly || saved.contains(task['id'])).toList();
          if (searchEnabled) {
            filteredTasks.removeWhere(
              (task) => !('${task['link']} ${task['type']}'
                  .toLowerCase()
                  .contains(taskQuery.toLowerCase())),
            );
            filteredTasks.sort(
              (a, b) => taskSort == 'reward'
                  ? ((b['reward_per_task'] as num?) ?? 1).compareTo(
                      (a['reward_per_task'] as num?) ?? 1,
                    )
                  : (b['createdAt']?.toString() ?? '').compareTo(
                      a['createdAt']?.toString() ?? '',
                    ),
            );
          }
          final history =
              mine
                  .where(
                    (entry) =>
                        !widget.separatePage ||
                        allCampaigns[entry['campaign_id']]?['type'] ==
                            selectedType,
                  )
                  .toList()
                ..sort(
                  (a, b) => (b['created_at'] as String).compareTo(
                    a['created_at'] as String,
                  ),
                );
          return AppListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            children: [
              if (!widget.separatePage)
                EarnHero(
                  title: tr(context, 'earnTitle'),
                  subtitle: tr(context, 'earnDesc'),
                  actionLabel: uf(context, 'Start earning', 'നേടിത്തുടങ്ങുക'),
                  onAction: () => setState(() {
                    selectedType = 'all';
                    savedOnly = false;
                  }),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xffe9e2f2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: taskAccent(selectedType).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          actionIcon(selectedType),
                          color: taskAccent(selectedType),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, selectedType),
                              style: const TextStyle(
                                color: growthInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              taskDescription(context, selectedType),
                              style: const TextStyle(
                                color: Color(0xff6d6580),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Notice(refined: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SubmissionHistoryPage(client: db),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: Text(tr(context, 'viewHistory')),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: growthPurple,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Color(0xffc8b2eb)),
                  ),
                ),
              ),
              if (history.isNotEmpty) ...[
                EarnSectionHeader(title: tr(context, 'mySubmissions')),
                for (final entry in history.take(10))
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffeee6ff),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: growthPurple,
                        ),
                      ),
                      title: Text(
                        tr(
                          context,
                          allCampaigns[entry['campaign_id']]?['type'] ?? 'type',
                        ),
                      ),
                      subtitle: SubmissionStatus(
                        claim: entry,
                        presence: presence,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              EarnSectionHeader(
                title: uf(context, 'Tasks', 'Task-ുകൾ'),
                count: filteredTasks.length,
              ),
              const SizedBox(height: 10),
              if (searchEnabled) ...[
                TextField(
                  controller: taskSearch,
                  onChanged: (value) =>
                      setState(() => taskQuery = value.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: uf(
                      context,
                      'Search task or link',
                      'Task അല്ലെങ്കിൽ link തിരയുക',
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: taskSort,
                  items: [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text(uf(context, 'Newest first', 'പുതിയവ ആദ്യം')),
                    ),
                    DropdownMenuItem(
                      value: 'reward',
                      child: Text(
                        uf(context, 'Highest reward', 'കൂടുതൽ coins ആദ്യം'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => taskSort = value);
                  },
                ),
              ],
              if (!widget.separatePage)
                TaskTypePicker(
                  selected: selectedType,
                  onSelected: (value) => setState(() => selectedType = value),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  visualDensity: VisualDensity.standard,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xffeee5fb),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: Color(0xffe5daef)),
                  avatar: const Icon(
                    Icons.bookmark_border,
                    size: 16,
                    color: growthPurple,
                  ),
                  label: Text(tr(context, 'savedTasks')),
                  selected: savedOnly,
                  onSelected: savedLoading
                      ? null
                      : (value) => setState(() => savedOnly = value),
                ),
              ),
              if (savedError)
                TextButton(
                  onPressed: loadSaved,
                  child: Text(tr(context, 'retry')),
                ),
              const SizedBox(height: 12),
              if (filteredTasks.isEmpty)
                EarnEmptyState(
                  title: taskQuery.isNotEmpty
                      ? uf(
                          context,
                          'No tasks match your search.',
                          'തിരച്ചിലിന് അനുയോജ്യമായ task ഇല്ല.',
                        )
                      : tr(
                          context,
                          savedOnly
                              ? 'emptySavedTasks'
                              : selectedType == 'all'
                              ? 'emptyTasks'
                              : 'noFilteredTasks',
                        ),
                  subtitle:
                      savedOnly ||
                          (!widget.separatePage && selectedType != 'all')
                      ? tr(context, 'emptyFilteredTasksHelp')
                      : uf(
                          context,
                          'Check back later for new tasks.',
                          'പുതിയ tasks പിന്നീട് പരിശോധിക്കുക.',
                        ),
                  actionLabel: tr(context, 'showAllTasks'),
                  onAction:
                      savedOnly ||
                          taskQuery.isNotEmpty ||
                          (!widget.separatePage && selectedType != 'all')
                      ? () => setState(() {
                          if (!widget.separatePage) selectedType = 'all';
                          savedOnly = false;
                          taskQuery = '';
                          taskSearch.clear();
                        })
                      : null,
                ),
              for (final task in filteredTasks)
                Builder(
                  builder: (context) {
                    final status = byCampaign[task['id']]?['status'];
                    final enabled = controls[task['type']] == true;
                    return EarnTaskCard(
                      icon: actionIcon(task['type'] as String),
                      title: tr(context, task['type']),
                      reward:
                          '+${task['reward_per_task'] ?? 1} ${tr(context, 'coins')}',
                      link: task['link'] as String,
                      saved: saved.contains(task['id']),
                      saveTooltip: tr(
                        context,
                        saved.contains(task['id']) ? 'unsaveTask' : 'saveTask',
                      ),
                      onSave: savedLoading || saving.contains(task['id'])
                          ? null
                          : () => toggleSaved(task['id'] as String),
                      status:
                          status == 'pending' ||
                              status == 'approved' ||
                              status == 'legacy'
                          ? SubmissionStatus(
                              claim: byCampaign[task['id']]!,
                              presence: presence,
                            )
                          : null,
                      disabledMessage: !enabled
                          ? tr(context, 'actionDisabled')
                          : null,
                      actions: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: enabled
                                ? () => openInstagram(context, task['link'])
                                : null,
                            child: Text(tr(context, 'open')),
                          ),
                          TextButton(
                            onPressed: () async {
                              var reportReason = '';
                              final reason = await showDialog<String>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(tr(c, 'reportCampaign')),
                                  content: TextField(
                                    onChanged: (value) => reportReason = value,
                                    maxLength: 1000,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: supportText(
                                        c,
                                        'Reason',
                                        'കാരണം',
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: Text(tr(c, 'cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        if (reportReason.trim().isNotEmpty) {
                                          Navigator.pop(c, reportReason.trim());
                                        }
                                      },
                                      child: Text(
                                        supportText(c, 'Send', 'അയയ്ക്കുക'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (reason == null || !context.mounted) {
                                return;
                              }
                              try {
                                await db.rpc(
                                  'report_campaign',
                                  params: {
                                    'p_campaign': task['id'],
                                    'p_reason': reason,
                                  },
                                );
                                if (context.mounted) {
                                  toast(
                                    context,
                                    supportText(
                                      context,
                                      'Report sent.',
                                      'റിപ്പോർട്ട് അയച്ചു.',
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  toast(
                                    context,
                                    supportText(
                                      context,
                                      'Unable to send report.',
                                      'റിപ്പോർട്ട് അയയ്ക്കാനായില്ല.',
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(tr(context, 'reportCampaign')),
                          ),
                          if (status == 'pending')
                            TextButton(
                              onPressed: () =>
                                  withdraw(context, task['id'] as String),
                              child: Text(tr(context, 'withdraw')),
                            ),
                          FilledButton(
                            onPressed:
                                !enabled ||
                                    status == 'pending' ||
                                    status == 'approved' ||
                                    status == 'legacy'
                                ? null
                                : () => claim(context, task['id'] as String),
                            child: Text(tr(context, 'submitProof')),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      );
    },
  );
}

class SubmissionStatus extends StatefulWidget {
  const SubmissionStatus({
    super.key,
    required this.claim,
    required this.presence,
  });
  final Map<String, dynamic> claim;
  final List<Map<String, dynamic>> presence;
  @override
  State<SubmissionStatus> createState() => _SubmissionStatusState();
}

class _SubmissionStatusState extends State<SubmissionStatus> {
  Timer? timer;
  DateTime? expiry() {
    if (widget.claim['status'] != 'pending') return null;
    DateTime? latest;
    for (final row in widget.presence) {
      if (row['campaign_id'] != widget.claim['campaign_id'] ||
          row['user_id'] != widget.claim['user_id'] ||
          row['submission_id'] != widget.claim['submission_id']) {
        continue;
      }
      final until = DateTime.tryParse(row['expires_at'] as String? ?? '');
      if (until != null && (latest == null || until.isAfter(latest))) {
        latest = until;
      }
    }
    return latest;
  }

  void scheduleExpiry() {
    timer?.cancel();
    final until = expiry();
    if (until != null && until.isAfter(DateTime.now())) {
      timer = Timer(
        until.difference(DateTime.now()) + const Duration(milliseconds: 50),
        () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    scheduleExpiry();
  }

  @override
  void didUpdateWidget(covariant SubmissionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleExpiry();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = expiry();
    final active = until != null && until.isAfter(DateTime.now());
    final status = widget.claim['status'] == 'cancelled'
        ? 'reviewCancelled'
        : widget.claim['status'] as String;
    return Text(tr(context, active ? 'adminReviewing' : status));
  }
}

class PendingReviews extends StatelessWidget {
  const PendingReviews({super.key, required this.campaignId});
  final String campaignId;
  Future<void> review(BuildContext context, Map<String, dynamic> claim) async {
    final participant = claim['user_id'] as String;
    final submission = claim['submission_id'] as String;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClaimReviewDialog(
        handle: claim['instagram_handle'] as String? ?? '',
        loadEvidence: () =>
            ReviewApi(db).evidence(campaignId, participant, submission),
        onDecision: (approve, pin) =>
            ReviewApi(db)
                .decide(campaignId, participant, submission, approve, pin),
        onRejectWithReason: (reason) =>
            ReviewApi(db)
                .rejectWithReason(campaignId, participant, submission, reason),
      ),
    );
    if (result == true && context.mounted) {
      toast(context, tr(context, 'reviewDone'));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db
        .from('campaign_claims')
        .stream(primaryKey: ['campaign_id', 'user_id'])
        .eq('campaign_id', campaignId),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text(tr(context, 'error'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final pending = snapshot.data!
          .where((c) => c['status'] == 'pending')
          .toList();
      final legacyCount = snapshot.data!
          .where((c) => c['status'] == 'legacy')
          .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text(
            uf(context, 'Current submission status', 'നിലവിലെ submission നില'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Wrap(
            spacing: 12,
            children: [
              for (final state in ['pending', 'approved', 'rejected'])
                Text(
                  '${state == 'rejected' ? uf(context, 'Rejected', 'നിരസിച്ചത്') : tr(context, state)}: ${snapshot.data!.where((row) => row['status'] == state).length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          if (legacyCount > 0)
            Text(
              '${tr(context, 'legacyCount')}: $legacyCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (pending.isNotEmpty)
            Text(
              '${tr(context, 'pending')} (${pending.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          for (final entry in pending)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('@${entry['instagram_handle']}'),
              trailing: OutlinedButton(
                onPressed: () => review(context, entry),
                child: Text(tr(context, 'reviewTitle')),
              ),
            ),
        ],
      );
    },
  );
}

class Campaigns extends StatefulWidget {
  const Campaigns({
    super.key,
    required this.uid,
    this.campaignsStream,
    this.reviewsBuilder,
    this.now,
    this.categoryType,
    this.initialCampaigns,
  });
  final String uid;
  final Stream<List<Map<String, dynamic>>>? campaignsStream;
  final Widget Function(String campaignId)? reviewsBuilder;
  final DateTime Function()? now;
  final String? categoryType;
  final List<Map<String, dynamic>>? initialCampaigns;
  @override
  State<Campaigns> createState() => _CampaignsState();
}

class _CampaignsState extends State<Campaigns> {
  late final Future<bool> supportEnabled = benefitEnabled(
    db,
    'support_reference',
  );
  String selectedStatus = 'all';
  Timer? clock;
  DateTime? scheduledDeadline;
  late Stream<List<Map<String, dynamic>>> campaignFeed;

  @override
  void initState() {
    super.initState();
    campaignFeed =
        (widget.campaignsStream ??
                db
                    .from('campaigns')
                    .stream(primaryKey: ['id'])
                    .eq('ownerId', widget.uid))
            .asBroadcastStream(
              onCancel: (subscription) => subscription.cancel(),
            );
  }

  void scheduleDeadline(List<Map<String, dynamic>> campaigns) {
    final now = widget.now?.call() ?? DateTime.now();
    DateTime? earliest;
    for (final campaign in campaigns) {
      if (campaign['status'] != 'active') continue;
      final created = DateTime.tryParse(campaign['createdAt'] as String? ?? '');
      final deadline = created?.add(const Duration(minutes: 1));
      if (deadline != null &&
          deadline.isAfter(now) &&
          (earliest == null || deadline.isBefore(earliest))) {
        earliest = deadline;
      }
    }
    if (earliest == scheduledDeadline) return;
    clock?.cancel();
    scheduledDeadline = earliest;
    if (earliest != null) {
      clock = Timer(
        earliest.difference(now) + const Duration(milliseconds: 50),
        () {
          scheduledDeadline = null;
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant Campaigns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.campaignsStream != widget.campaignsStream) {
      campaignFeed =
          (widget.campaignsStream ??
                  db
                      .from('campaigns')
                      .stream(primaryKey: ['id'])
                      .eq('ownerId', widget.uid))
              .asBroadcastStream(
                onCancel: (subscription) => subscription.cancel(),
              );
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<void> cancel(BuildContext context, String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'cancelTitle')),
        content: Text(tr(context, 'cancelBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'cancelCampaign')),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await db.rpc('cancel_campaign', params: {'p_campaign_id': id});
      if (context.mounted) toast(context, tr(context, 'cancelledMessage'));
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: campaignFeed,
    initialData: widget.initialCampaigns,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr(context, 'error')));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.categoryType != null) scheduleDeadline(snapshot.data!);
      final allDocs = snapshot.data!.toList()
        ..sort(
          (a, b) =>
              (b['createdAt'] as String).compareTo(a['createdAt'] as String),
        );
      final docs = allDocs
          .where(
            (doc) =>
                doc['type'] == widget.categoryType &&
                (selectedStatus == 'all' || doc['status'] == selectedStatus),
          )
          .toList();
      if (widget.categoryType == null) {
        return AppListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          children: [
            GrowthHero(
              title: tr(context, 'myCampaigns'),
              minHeight: 150,
              subtitle: uf(
                context,
                'Create and manage your campaigns with ease.',
                'നിങ്ങളുടെ campaigns സൃഷ്ടിക്കുകയും നിയന്ത്രിക്കുകയും ചെയ്യുക.',
              ),
              icon: Icons.campaign_rounded,
              background: 'campaign_hero_reference',
              action: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: growthPurple,
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateCampaign(),
                  ),
                ),
                child: Text(tr(context, 'create')),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              uf(context, 'Campaign categories', 'Campaign വിഭാഗങ്ങൾ'),
              style: const TextStyle(
                color: growthInk,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              uf(
                context,
                'Choose a category to manage your campaigns.',
                'Campaign-ുകൾ കാണാൻ ഒരു വിഭാഗം തിരഞ്ഞെടുക്കുക.',
              ),
              style: const TextStyle(color: Color(0xff6d6580), fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final type in ['follow', 'like', 'comment', 'share']) ...[
              CampaignCategoryTile(
                title: tr(context, type),
                count: allDocs.where((doc) => doc['type'] == type).length,
                countLabel: tr(context, 'campaigns'),
                icon: actionIcon(type),
                accent: taskAccent(type),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => UserPageScaffold(
                      identity: UserPageIdentity.campaigns,
                      appBar: AppBar(title: Text(tr(context, type))),
                      body: SafeArea(
                        child: Campaigns(
                          uid: widget.uid,
                          categoryType: type,
                          campaignsStream: campaignFeed,
                          initialCampaigns: allDocs,
                          reviewsBuilder: widget.reviewsBuilder,
                          now: widget.now,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      }
      return AppListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        children: [
          GrowthHero(
            title: tr(context, widget.categoryType!),
            minHeight: 150,
            subtitle: uf(
              context,
              'Create and manage your campaigns with ease.',
              'നിങ്ങളുടെ campaigns സൃഷ്ടിക്കുകയും നിയന്ത്രിക്കുകയും ചെയ്യുക.',
            ),
            icon: Icons.campaign_rounded,
            background: 'campaign_hero_reference',
            action: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: growthPurple,
                minimumSize: const Size(0, 48),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CreateCampaign(initialType: widget.categoryType!),
                ),
              ),
              child: Text(tr(context, 'create')),
            ),
          ),
          const SizedBox(height: 12),
          if (allDocs.every((doc) => doc['type'] != widget.categoryType)) ...[
            GrowthEmpty(
              art: 'campaign_reference',
              artHeight: 200,
              title: tr(context, 'emptyCampaigns'),
              subtitle: uf(
                context,
                'Create your first campaign and reach more audience.',
                'നിങ്ങളുടെ ആദ്യ campaign സൃഷ്ടിക്കുക.',
              ),
              action: GrowthActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CreateCampaign(initialType: widget.categoryType!),
                  ),
                ),
                icon: Icons.add,
                label: tr(context, 'create'),
              ),
            ),
            Card(
              color: const Color(0xffe8dcfb),
              child: ListTile(
                leading: const GrowthIcon(Icons.bar_chart),
                title: Text(
                  uf(context, 'Track your impact', 'നിങ്ങളുടെ പുരോഗതി കാണുക'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  uf(
                    context,
                    'See progress on your campaigns.',
                    'നിങ്ങളുടെ campaigns-ന്റെ പുരോഗതി കാണുക.',
                  ),
                ),
                trailing: const Icon(Icons.trending_up, color: growthPurple),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CreateCampaign(initialType: widget.categoryType!),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'create')),
              ),
            ),
          if (allDocs.any((doc) => doc['type'] == widget.categoryType)) ...[
            const SizedBox(height: 12),
            Text(userText(context, 'Status', 'സ്ഥിതി')),
            Wrap(
              spacing: 8,
              children: [
                for (final status in [
                  'all',
                  'active',
                  'completed',
                  'cancelled',
                ])
                  ChoiceChip(
                    label: Text(
                      tr(context, status == 'all' ? 'allTasks' : status),
                    ),
                    selected: selectedStatus == status,
                    onSelected: (_) => setState(() => selectedStatus = status),
                  ),
              ],
            ),
            if (docs.isEmpty)
              Text(
                userText(
                  context,
                  'No campaigns match these filters.',
                  'ഈ filters-ന് അനുയോജ്യമായ campaigns ഇല്ല.',
                ),
              ),
          ],
          for (final doc in docs)
            Builder(
              builder: (context) {
                final data = doc;
                final remaining = data['remaining'] as int;
                final requested = data['requested'] as int;
                final createdAt = DateTime.tryParse(
                  data['createdAt'] as String? ?? '',
                );
                final canCancel =
                    data['status'] == 'active' &&
                    createdAt != null &&
                    (widget.now?.call() ?? DateTime.now()).isBefore(
                      createdAt.add(const Duration(minutes: 1)),
                    );
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(child: Icon(actionIcon(data['type']))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr(context, data['type']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            Chip(label: Text(tr(context, data['status']))),
                          ],
                        ),
                        if (data['status'] == 'active') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(tr(context, 'processing')),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (data['order_id'] is String)
                          SelectableText(
                            '${userText(context, 'Order ID', 'Order ID')}: ${data['order_id']}',
                          ),
                        const SizedBox(height: 8),
                        Text(
                          data['link'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (requested - remaining) / requested,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${requested - remaining}/$requested ${tr(context, 'claims')}',
                        ),
                        if (widget.reviewsBuilder == null)
                          FutureBuilder<bool>(
                            future: supportEnabled,
                            builder: (context, state) => state.data == true
                                ? SupportReferenceButton(
                                    client: db,
                                    kind: 'campaign',
                                    id: data['id'] as String,
                                    enabledOverride: true,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        if (widget.reviewsBuilder == null)
                          CampaignInsights(
                            client: db,
                            campaignId: data['id'] as String,
                          ),
                        widget.reviewsBuilder?.call(data['id'] as String) ??
                            PendingReviews(campaignId: data['id'] as String),
                        if (canCancel)
                          TextButton(
                            onPressed: () =>
                                cancel(context, doc['id'] as String),
                            child: Text(tr(context, 'cancelCampaign')),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class CampaignCategoryTile extends StatelessWidget {
  const CampaignCategoryTile({
    super.key,
    required this.title,
    required this.count,
    required this.countLabel,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title, countLabel;
  final int count;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: userLine),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: growthInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count $countLabel',
                    style: const TextStyle(
                      color: Color(0xff6d6580),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: accent),
          ],
        ),
      ),
    ),
  );
}

class CreateCampaign extends StatefulWidget {
  const CreateCampaign({
    super.key,
    this.loadRates,
    this.loadAccounts,
    this.loadPlan,
    this.controls,
    this.reserve,
    this.draftsClient,
    this.initialType = 'follow',
  }) : assert(
         initialType == 'follow' ||
             initialType == 'like' ||
             initialType == 'comment' ||
             initialType == 'share',
       );
  final Future<List<Map<String, dynamic>>> Function()? loadRates;
  final Future<List<String>> Function()? loadAccounts;
  final Future<CampaignPlan> Function()? loadPlan;
  final Stream<List<Map<String, dynamic>>>? controls;
  final String initialType;
  final SupabaseClient? draftsClient;
  final Future<void> Function(String type, String link, int count, int reward)?
  reserve;
  @override
  State<CreateCampaign> createState() => _CreateCampaignState();
}

class _CreateCampaignState extends State<CreateCampaign> {
  final form = GlobalKey<FormState>();
  final link = TextEditingController();
  final count = TextEditingController(text: '1');
  late String type = widget.initialType;
  String? selectedUsername;
  late Future<List<String>> accounts = loadAccounts();
  Future<List<String>> loadAccounts() async {
    if (widget.loadAccounts != null) return widget.loadAccounts!();
    final rows = await db
        .from('instagram_accounts')
        .select('username')
        .eq('user_id', db.auth.currentUser!.id)
        .order('created_at');
    return [for (final row in rows) row['username'] as String];
  }

  String get campaignLink => type == 'follow'
      ? 'https://www.instagram.com/$selectedUsername/'
      : link.text.trim();
  bool busy = false;
  late Future<(List<Map<String, dynamic>>, CampaignPlan)> options =
      loadOptions();

  Future<(List<Map<String, dynamic>>, CampaignPlan)> loadOptions() async {
    final (prices, plan) = await (
      loadRates(),
      widget.loadPlan?.call() ??
          (widget.reserve == null
              ? db
                    .rpc('campaign_plan_limits')
                    .then((value) => CampaignPlan.fromJson(value as Map))
              : Future.value(const CampaignPlan(maxTasks: 3))),
    ).wait;
    return (prices, plan);
  }

  Future<List<Map<String, dynamic>>> loadRates() async =>
      widget.loadRates != null
      ? widget.loadRates!()
      : db.from('coin_settings').select();
  late final controlsStream =
      widget.controls ??
      db.from('action_controls').stream(primaryKey: ['action_type']);
  @override
  void dispose() {
    link.dispose();
    count.dispose();
    super.dispose();
  }

  Future<void> submit(int reward) async {
    if (!form.currentState!.validate() || selectedUsername == null) return;
    setState(() => busy = true);
    try {
      if (widget.reserve != null) {
        await widget.reserve!(
          type,
          campaignLink,
          int.parse(count.text),
          reward,
        );
      } else {
        await db.rpc(
          'create_campaign_for_account',
          params: {
            'p_type': type,
            'p_reward': reward,
            'p_link': campaignLink,
            'p_username': selectedUsername,
            'p_count': int.parse(count.text),
          },
        );
      }
      if (mounted) {
        Navigator.pop(context);
        toast(context, tr(context, 'created'));
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(context, e));
        setState(() {
          options = loadOptions();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.createCampaign,
    appBar: AppBar(title: Text(tr(context, 'create'))),
    body: FutureBuilder<(List<Map<String, dynamic>>, CampaignPlan)>(
      future: options,
      builder: (context, prices) {
        if (prices.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                options = loadOptions();
              }),
              child: Text(tr(context, 'retry')),
            ),
          );
        }
        if (!prices.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reward =
            prices.data!.$1.firstWhere((row) => row['key'] == type)['amount']
                as int;
        final refreshing = prices.connectionState != ConnectionState.done;
        final plan = prices.data!.$2;
        final next = plan.nextCampaignAt?.toLocal();
        final coolingDown = next != null && next.isAfter(DateTime.now());
        final locale = MaterialLocalizations.of(context);
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: controlsStream,
          builder: (context, controls) {
            if (controls.hasError) {
              return Center(child: Text(tr(context, 'error')));
            }
            if (!controls.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final enabled = controls.data!.any(
              (row) => row['action_type'] == type && row['enabled'] == true,
            );
            return Form(
              key: form,
              child: AppListView(
                panel: true,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: [
                  Text(
                    tr(context, 'create'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: growthInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uf(
                      context,
                      'Grow your Instagram presence with powerful campaigns.',
                      'നിങ്ങളുടെ Instagram സാന്നിധ്യം വളർത്തുക.',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userText(
                      context,
                      'Your campaign becomes public after one minute. You can cancel only during that first minute.',
                      'ഒരു മിനിറ്റിന് ശേഷം campaign മറ്റുള്ളവർക്ക് ലഭ്യമാകും. ആദ്യ മിനിറ്റിൽ മാത്രം റദ്ദാക്കാം.',
                    ),
                  ),
                  if (coolingDown) ...[
                    Text(
                      '${uf(context, 'Next campaign available:', 'അടുത്ത campaign തുടങ്ങാവുന്ന സമയം:')} '
                      '${locale.formatMediumDate(next)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(next))}',
                      key: const Key('campaign-cooldown'),
                    ),
                    TextButton(
                      onPressed: refreshing
                          ? null
                          : () => setState(() {
                              options = loadOptions();
                            }),
                      child: Text(
                        uf(context, 'Refresh limits', 'പരിധികൾ പുതുക്കുക'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('campaign_type_$type'),
                    isExpanded: true,
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: tr(context, 'type'),
                      prefixIcon: Icon(actionIcon(type), color: growthPurple),
                      isDense: true,
                    ),
                    items: ['follow', 'like', 'comment', 'share']
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(tr(context, t)),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => type = v!),
                  ),
                  if (!enabled) Text(tr(context, 'actionDisabled')),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: accounts,
                    builder: (c, snapshot) {
                      if (snapshot.hasError) {
                        return TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  accounts = loadAccounts();
                                }),
                          child: Text(tr(c, 'retry')),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.data!.isEmpty) {
                        return Text(
                          uf(
                            c,
                            'Add an Instagram account in Profile → Instagram accounts before creating a campaign.',
                            'Campaign തുടങ്ങുന്നതിന് മുമ്പ് Profile → Instagram accounts-ൽ account ചേർക്കുക.',
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        key: ValueKey('campaign_user_$selectedUsername'),
                        initialValue: selectedUsername,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: uf(
                            c,
                            'Instagram username',
                            'Instagram username',
                          ),
                          prefixIcon: const Icon(Icons.alternate_email),
                        ),
                        items: [
                          for (final username in snapshot.data!)
                            DropdownMenuItem(
                              value: username,
                              child: Text('@$username'),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => selectedUsername = value),
                        validator: (value) => value == null
                            ? uf(
                                c,
                                'Choose an account from your Profile',
                                'Profile-ലെ account തിരഞ്ഞെടുക്കുക',
                              )
                            : null,
                      );
                    },
                  ),
                  if (type != 'follow') ...[
                    TextFormField(
                      controller: link,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: uf(
                          context,
                          'Post or reel link',
                          'Post / Reel link',
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(10),
                          child: InstagramLogo(),
                        ),
                        isDense: true,
                        hintText: tr(
                          context,
                          type == 'follow' ? 'profileHint' : 'postHint',
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? tr(context, 'required')
                          : normalizeCampaignLink(type, v) == null
                          ? tr(context, 'invalidLink')
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: count,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr(context, 'count'),
                      isDense: true,
                      prefixIcon: IconButton(
                        tooltip: uf(context, 'Decrease', 'കുറയ്ക്കുക'),
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                final n = int.tryParse(count.text) ?? 1;
                                count.text = (n - 1)
                                    .clamp(1, plan.maxTasks)
                                    .toString();
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      suffixIcon: IconButton(
                        tooltip: uf(context, 'Increase', 'കൂട്ടുക'),
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                final n = int.tryParse(count.text) ?? 1;
                                count.text = (n + 1)
                                    .clamp(1, plan.maxTasks)
                                    .toString();
                              }),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      helperText:
                          '$reward ${tr(context, 'coins')} ${tr(context, 'perTask')} · 1–${plan.maxTasks}',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > plan.maxTasks
                          ? '${uf(context, 'Allowed task count:', 'അനുവദിച്ച task എണ്ണം:')} 1–${plan.maxTasks}'
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: const Color(0xffe8ddfc),
                    child: ListTile(
                      leading: const Icon(
                        Icons.local_offer,
                        color: growthPurple,
                      ),
                      title: Text(
                        '${tr(context, 'totalCost')}: ${(int.tryParse(count.text) ?? 0) * reward} ${tr(context, 'coins')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: growthPurple,
                        ),
                      ),
                      trailing: const GrowthArt('coins', height: 52),
                    ),
                  ),
                  if (widget.draftsClient != null ||
                      (widget.reserve == null &&
                          widget.loadRates == null &&
                          widget.loadAccounts == null))
                    CampaignDraftControls(
                      client: widget.draftsClient ?? db,
                      current: () => {
                        'kind': type,
                        'link': link.text.trim(),
                        'username': selectedUsername ?? '',
                        'count': int.tryParse(count.text),
                      },
                      restore: (draft) async {
                        final existing = await accounts;
                        if (!mounted) return;
                        setState(() {
                          type = draft['kind'] as String;
                          link.text = draft['link'] as String;
                          count.text = '${draft['task_count']}';
                          final username = draft['username'] as String;
                          selectedUsername = existing.contains(username)
                              ? username
                              : null;
                        });
                      },
                    ),
                  const Notice(),
                  const SizedBox(height: 14),
                  GrowthPrimaryButton(
                    onPressed:
                        busy ||
                            refreshing ||
                            coolingDown ||
                            !enabled ||
                            selectedUsername == null
                        ? null
                        : () => submit(reward),
                    label: tr(context, 'submit'),
                    icon: Icons.arrow_forward,
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

String? profileName(User user) {
  final value = user.userMetadata?['full_name'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class Profile extends StatelessWidget {
  const Profile({
    super.key,
    required this.user,
    this.gateway,
    this.authorizeChange,
    this.onNotifications,
    this.notifications,
  });
  final User user;
  final ProfileGateway? gateway;
  final Future<bool> Function()? authorizeChange;
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  @override
  Widget build(BuildContext context) => ProfileFeatures(
    user: user,
    gateway: gateway,
    authorizeChange: authorizeChange,
    onNotifications: onNotifications,
    notifications: notifications,
  );
}

class CoinHistoryPage extends StatefulWidget {
  const CoinHistoryPage({super.key, required this.uid, this.historyStream});
  final String uid;
  final Stream<List<Map<String, dynamic>>>? historyStream;
  @override
  State<CoinHistoryPage> createState() => _CoinHistoryPageState();
}

class _CoinHistoryPageState extends State<CoinHistoryPage> {
  late final Future<bool> supportEnabled = benefitEnabled(
    db,
    'support_reference',
  );
  String filter = 'all';
  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.coinHistory,
    appBar: AppBar(title: Text(tr(context, 'history'))),
    body: AppListView(
      padding: const EdgeInsets.all(20),
      children: [
        GrowthHero(
          title: tr(context, 'history'),
          subtitle: uf(
            context,
            'Track your earned and spent coins',
            'ലഭിച്ചതും ചെലവാക്കിയതുമായ coins കാണുക',
          ),
          icon: Icons.stars_rounded,
          background: 'coins_background',
        ),
        const SizedBox(height: 8),
        if (widget.historyStream == null) WalletStatementButton(client: db),
        Wrap(
          spacing: 8,
          children: [
            for (final option in ['all', 'earned', 'spent', 'refund'])
              FilterChip(
                selectedColor: growthPurple,
                checkmarkColor: Colors.white,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(
                  switch (option) {
                    'earned' => uf(context, 'Earned', 'ലഭിച്ചത്'),
                    'spent' => uf(context, 'Spent', 'ചെലവായത്'),
                    'refund' => uf(context, 'Refunds', 'Refunds'),
                    _ => uf(context, 'All', 'എല്ലാം'),
                  },
                  style: TextStyle(
                    color: filter == option ? Colors.white : growthInk,
                    fontSize: 10,
                  ),
                ),
                selected: filter == option,
                onSelected: (_) => setState(() => filter = option),
              ),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              widget.historyStream ??
              db
                  .from('coin_ledger')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', widget.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(tr(context, 'error'));
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs =
                snapshot.data!.where((row) {
                  final amount = row['amount'] as int;
                  return switch (filter) {
                    'earned' => amount > 0 && row['reason'] != 'refund',
                    'spent' => amount < 0,
                    'refund' => row['reason'] == 'refund',
                    _ => true,
                  };
                }).toList()..sort(
                  (a, b) => (b['createdAt'] as String).compareTo(
                    a['createdAt'] as String,
                  ),
                );
            if (docs.isEmpty) {
              return GrowthEmpty(
                art: 'coins',
                title: uf(
                  context,
                  'No Coin History Yet',
                  'ഇതുവരെ coin history ഇല്ല',
                ),
                subtitle: uf(
                  context,
                  'Start earning coins and explore exciting rewards!',
                  'Coins നേടി rewards കണ്ടെത്തൂ!',
                ),
              );
            }
            return Column(
              children: [
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final data = doc;
                      final amount = data['amount'] as int;
                      final reason = switch (data['reason']) {
                        'welcome' => 'welcomeReason',
                        'daily_bonus' => 'dailyBonusReason',
                        'badge_bonus' => 'badgeBonusReason',
                        'campaign' => 'campaignReason',
                        'task' => 'taskReason',
                        'refund' => 'refundReason',
                        'referral' => 'referrals',
                        'admin_adjustment' => 'adminAdjustment',
                        'purchase' => 'purchaseReason',
                        'transfer_sent' => 'transferSent',
                        'transfer_received' => 'transferReceived',
                        _ => 'history',
                      };
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: amount > 0
                                    ? const Color(0xffe2f3e9)
                                    : const Color(0xffffece2),
                                child: Icon(
                                  amount > 0
                                      ? Icons.south_west_rounded
                                      : Icons.north_east_rounded,
                                  color: amount > 0
                                      ? const Color(0xff268258)
                                      : const Color(0xffa85a38),
                                  size: 19,
                                ),
                              ),
                              title: Text(tr(context, reason)),
                              subtitle: data['reference_id'] is String
                                  ? SelectableText(
                                      '${uf(context, 'Reference ID', 'Reference ID')}: ${data['reference_id']}',
                                    )
                                  : null,
                              trailing: Text(
                                '${amount > 0 ? '+' : ''}$amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: amount > 0
                                      ? Colors.green.shade700
                                      : null,
                                ),
                              ),
                            ),
                            if (widget.historyStream == null &&
                                data['id'] is String)
                              Align(
                                alignment: Alignment.centerRight,
                                child: FutureBuilder<bool>(
                                  future: supportEnabled,
                                  builder: (context, state) =>
                                      state.data == true
                                      ? SupportReferenceButton(
                                          client: db,
                                          kind: 'transaction',
                                          id: data['id'] as String,
                                          enabledOverride: true,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class PinException implements Exception {
  const PinException(this.code);
  final String code;
}

class ReleasePinDialog extends StatefulWidget {
  const ReleasePinDialog({
    super.key,
    this.setup = false,
    this.changing = false,
    this.savePin,
    this.sendOtp,
  });
  final Future<void> Function()? sendOtp;
  final bool setup;
  final bool changing;
  final Future<String> Function(String pin, String? otpCode)? savePin;
  @override
  State<ReleasePinDialog> createState() => _ReleasePinDialogState();
}

class _ReleasePinDialogState extends State<ReleasePinDialog> {
  final pin = TextEditingController();
  final confirm = TextEditingController();
  final current = TextEditingController();
  String? error;
  bool busy = false, otpSent = false;
  bool showPin = false, showConfirm = false;
  int cooldown = 0;
  Timer? otpTimer;
  @override
  void dispose() {
    pin.dispose();
    confirm.dispose();
    current.dispose();
    otpTimer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.setup &&
        (!otpSent || !RegExp(r'^\d{6}$').hasMatch(current.text))) {
      setState(() => error = tr(context, 'otp_required'));
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin.text) ||
        (widget.setup && pin.text != confirm.text)) {
      setState(
        () => error = tr(
          context,
          widget.setup ? 'pinMismatch' : 'invalid_format',
        ),
      );
      return;
    }
    if (!widget.setup) {
      Navigator.pop(context, pin.text);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final otpCode = current.text;
      final result = widget.savePin == null
          ? await db.rpc(
              'set_release_pin',
              params: {'p_pin': pin.text, 'p_current_pin': otpCode},
            )
          : await widget.savePin!(pin.text, otpCode);
      if (!mounted) return;
      if (result == 'ok') {
        Navigator.pop(context, 'ok');
      } else {
        setState(() => error = safePinError(context, result));
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget pinField(
    TextEditingController controller,
    String label, {
    bool confirmation = false,
  }) => TextField(
    controller: controller,
    obscureText: confirmation ? !showConfirm : !showPin,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(
      labelText: tr(context, label),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: const Icon(Icons.lock_outline, color: growthPurple),
      suffixIcon: IconButton(
        tooltip: tr(
          context,
          (confirmation ? showConfirm : showPin)
              ? 'hidePassword'
              : 'showPassword',
        ),
        onPressed: () => setState(() {
          if (confirmation) {
            showConfirm = !showConfirm;
          } else {
            showPin = !showPin;
          }
        }),
        icon: Icon(
          (confirmation ? showConfirm : showPin)
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    titlePadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    backgroundColor: const Color(0xfff8f5ff),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    title: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/design/pin_shield.png',
              height: widget.setup ? 105 : 78,
              excludeFromSemantics: true,
            ),
            Text(
              tr(
                context,
                widget.setup
                    ? (widget.changing ? 'changePin' : 'setupPin')
                    : 'releasePin',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: growthInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.setup)
              Text(
                uf(
                  context,
                  'Keep your account more secure',
                  'നിങ്ങളുടെ account കൂടുതൽ സുരക്ഷിതമാക്കുക',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: tr(context, 'cancel'),
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (!widget.setup)
              Text(
                tr(context, 'enterPin'),
                style: const TextStyle(fontSize: 11),
              ),
            if (widget.setup) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  onPressed: busy || cooldown > 0 || widget.sendOtp == null
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.sendOtp!();
                            if (mounted) {
                              setState(() {
                                otpSent = true;
                                cooldown = 60;
                              });
                              otpTimer?.cancel();
                              otpTimer = Timer.periodic(
                                const Duration(seconds: 1),
                                (timer) {
                                  if (!mounted) {
                                    timer.cancel();
                                    return;
                                  }
                                  setState(() => cooldown--);
                                  if (cooldown == 0) timer.cancel();
                                },
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = friendlyError(context, e));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  label: Text(
                    '${tr(context, 'sendPinOtp')}${cooldown > 0 ? ' ($cooldown)' : ''}',
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xffe9def9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (otpSent) Text(tr(context, 'otpSentPin')),
              TextField(
                controller: current,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: tr(context, 'otp'),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: growthPurple,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            pinField(pin, widget.setup ? 'newPin' : 'releasePin'),
            if (widget.setup) ...[
              const SizedBox(height: 8),
              pinField(confirm, 'confirmPin', confirmation: true),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        style: TextButton.styleFrom(
          side: const BorderSide(color: Color(0xffa68ccf)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
        child: Text(tr(context, 'cancel')),
      ),
      SizedBox(
        width: 125,
        child: GrowthPrimaryButton(
          onPressed: busy ? null : submit,
          label: tr(context, widget.setup ? 'save' : 'yesConfirm'),
        ),
      ),
    ],
  );
}

class InstagramLookupException implements Exception {
  const InstagramLookupException(this.code);
  final String code;
}

class ProfileInfo {
  final Map<String, int> referralRewards;
  const ProfileInfo({
    this.referralRewards = const {},
    this.publicUserId,
    this.photo,
    required this.usernames,
    required this.referralCode,
    required this.referralCount,
    required this.referralJoined,
    required this.pinSet,
  });
  final String? publicUserId;
  final Uint8List? photo;
  final List<String> usernames;
  final String referralCode;
  final int referralCount;
  final bool referralJoined, pinSet;
}

abstract class ProfileGateway {
  Future<ProfileInfo> load(String uid);
  Stream<int?> balance(String uid);
  Stream<List<Map<String, dynamic>>> history(String uid);
  Future<void> addAccount(String username);
  Future<String> searchInstagram(String username);
  Future<void> removeAccount(String username);
  Future<void> applyReferral(String code);
  Future<String?> latestAppDownloadUrl();
  Future<void> sendPinOtp();
  Future<String> setPin(String pin, String? otpCode);
  Future<void> signOut();
}

class SupabaseProfileGateway
    implements ProfileGateway, ReferralHistoryGateway, CampaignPlanGateway {
  const SupabaseProfileGateway(this.client);
  final SupabaseClient client;
  @override
  Future<String?> latestAppDownloadUrl() =>
      ReferralDownloadGateway(client).load();

  @override
  Future<CampaignPlan> loadCampaignPlan() async =>
      CampaignPlan.fromJson(await client.rpc('campaign_plan_limits') as Map);

  @override
  Future<List<ReferralHistoryEntry>> loadReferralHistory(int offset) async {
    final rows = await client.rpc(
      'referral_history',
      params: {'p_offset': offset},
    );
    return [
      for (final row in rows as List) ReferralHistoryEntry.fromRow(row as Map),
    ];
  }

  @override
  Future<ProfileInfo> load(String uid) async {
    final values = await Future.wait<dynamic>([
      client
          .from('instagram_accounts')
          .select('username')
          .eq('user_id', uid)
          .order('created_at'),
      client.rpc('referral_info'),
      client.rpc('release_pin_is_set'),
      client.from('coin_settings').select(),
      _loadProfilePhoto(),
    ]);
    final accounts = values[0] as List;
    final referral = Map<String, dynamic>.from(values[1] as Map);
    return ProfileInfo(
      photo: values[4] as Uint8List?,
      usernames: [
        for (final account in accounts) account['username'] as String,
      ],
      publicUserId: referral['user_id'] as String?,
      referralCode: referral['code'] as String,
      referralCount: referral['count'] as int,
      referralJoined: referral['joined'] as bool,
      pinSet: values[2] as bool,
      referralRewards: {
        for (final row in values[3] as List)
          if ([
            'invite',
            'milestone_5',
            'milestone_10',
            'milestone_15',
          ].contains(row['key']))
            row['key'] as String: row['amount'] as int,
      },
    );
  }

  Future<Uint8List?> _loadProfilePhoto() async {
    try {
      final value = await client.rpc('profile_photo');
      return value == null ? null : await decodeProfilePhoto(value as String);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<int?> balance(String uid) => client
      .from('wallets')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) {
        if (rows.isEmpty) return null;
        final total = rows.first['balance'] as int?;
        final held = rows.first['held_balance'] as int? ?? 0;
        return total == null ? null : total - held;
      });
  @override
  Stream<List<Map<String, dynamic>>> history(String uid) =>
      client.from('coin_ledger').stream(primaryKey: ['id']).eq('user_id', uid);
  @override
  Future<void> addAccount(String username) async =>
      client.rpc('add_instagram_account', params: {'p_username': username});
  @override
  Future<String> searchInstagram(String username) async {
    try {
      final response = await client.functions.invoke(
        'instagram-lookup',
        body: {'username': username},
      );
      final data = response.data;
      if (data is! Map || data['username'] is! String) {
        throw const InstagramLookupException('lookup_unavailable');
      }
      final result = data['username'] as String;
      final query = username.trim().replaceFirst(RegExp(r'^@'), '');
      if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(result) ||
          result.toLowerCase() != query.toLowerCase()) {
        throw const InstagramLookupException('lookup_unavailable');
      }
      return result;
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      if (code == 'not_found_or_unsupported' ||
          code == 'rate_limited' ||
          code == 'access_denied' ||
          code == 'unauthorized') {
        throw InstagramLookupException(code as String);
      }
      if (e.status == 401) throw const InstagramLookupException('unauthorized');
      if (e.status == 403) {
        throw const InstagramLookupException('access_denied');
      }
      if (e.status == 429) throw const InstagramLookupException('rate_limited');
      throw const InstagramLookupException('lookup_unavailable');
    }
  }

  @override
  Future<void> removeAccount(String username) async =>
      client.rpc('remove_instagram_account', params: {'p_username': username});
  @override
  Future<void> applyReferral(String code) async =>
      client.rpc('apply_referral', params: {'p_code': code});
  @override
  Future<void> sendPinOtp() => client.auth.reauthenticate();

  @override
  Future<String> setPin(String pin, String? otpCode) async {
    if (client.auth.currentUser?.email == null || otpCode == null) {
      return 'otp_required';
    }
    return await client.rpc(
      'set_release_pin_reauthenticated',
      params: {'p_pin': pin, 'p_nonce': otpCode},
    ) as String;
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

String profileInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length > 1) {
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
  return parts.first.characters.take(2).toString().toUpperCase();
}

class ProfileFeatures extends StatefulWidget {
  const ProfileFeatures({
    super.key,
    required this.user,
    this.gateway,
    this.authorizeChange,
    this.onNotifications,
    this.notifications,
  });
  final User user;
  final ProfileGateway? gateway;
  final Future<bool> Function()? authorizeChange;
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  @override
  State<ProfileFeatures> createState() => _ProfileFeaturesState();
}

class _ProfileFeaturesState extends State<ProfileFeatures> {
  late final ProfileGateway gateway =
      widget.gateway ?? SupabaseProfileGateway(db);
  late final Stream<int?> balance = gateway.balance(widget.user.id);
  late Future<ProfileInfo> data = gateway.load(widget.user.id);
  void reload() => setState(() {
    data = gateway.load(widget.user.id);
  });
  Future<void> openDetails(
    bool accounts, {
    ReferralSection referralSection = ReferralSection.menu,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsPage(
          uid: widget.user.id,
          gateway: gateway,
          accounts: accounts,
          referralSection: referralSection,
          authorizeChange: widget.authorizeChange,
        ),
      ),
    );
    if (mounted) reload();
  }

  Future<void> openPin(bool pinSet) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => ReleasePinDialog(
        setup: true,
        changing: pinSet,
        savePin: gateway.setPin,
        sendOtp: gateway.sendPinOtp,
      ),
    );
    if (result == 'ok' && mounted) {
      toast(context, tr(context, 'pinSaved'));
      reload();
    }
  }

  Future<void> signOut() async {
    try {
      if (widget.gateway == null) await PushCoordinator.instance.stop(db);
      await gateway.signOut();
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProfileInfo>(
    future: data,
    builder: (context, details) => StreamBuilder<int?>(
      stream: balance,
      builder: (context, wallet) => ProfileLayout(
        user: widget.user,
        info: details.data,
        balance: wallet.data,
        loading: details.connectionState != ConnectionState.done,
        error: details.hasError,
        onRetry: reload,
        onPersonalInfo: !details.hasData
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PersonalInformationPage(
                      user: widget.user,
                      publicId: details.data?.publicUserId,
                      authorizeChange:
                          widget.authorizeChange ??
                          () => confirmSecurityPin(context),
                      gateway: SupabasePersonalInformationGateway(
                        db,
                        () => SupabaseClient(
                          supabaseUrl,
                          supabaseKey,
                          httpClient: secureHttpClient,
                          realtimeClientOptions: RealtimeClientOptions(
                            transport: secureRealtimeTransport,
                          ),
                          authOptions: const AuthClientOptions(
                            autoRefreshToken: false,
                            authFlowType: AuthFlowType.implicit,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                if (mounted) reload();
              },
        loadCampaignPlan: gateway is CampaignPlanGateway
            ? (gateway as CampaignPlanGateway).loadCampaignPlan
            : () => Future.error(StateError('Campaign limits unavailable')),
        onAccounts: () => openDetails(true),
        onReferrals: () => openDetails(false),
        onCampaignReferrals: () =>
            openDetails(false, referralSection: ReferralSection.code),
        onPin: details.hasData ? () => openPin(details.data!.pinSet) : null,
        onSignOut: signOut,
        onLanguage: toggleLanguage,
        onNotifications: widget.onNotifications,
        notifications: widget.notifications,
      ),
    ),
  );
}

class ProfileLayout extends StatelessWidget {
  const ProfileLayout({
    super.key,
    required this.user,
    required this.info,
    required this.balance,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onPersonalInfo,
    required this.onAccounts,
    required this.onReferrals,
    required this.onPin,
    required this.onSignOut,
    required this.onLanguage,
    this.onNotifications,
    this.notifications,
    this.loadCampaignPlan,
    this.onCampaignReferrals,
  });
  final Future<CampaignPlan> Function()? loadCampaignPlan;
  final Future<void> Function()? onCampaignReferrals;
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final User user;
  final ProfileInfo? info;
  final int? balance;
  final bool loading, error;
  final VoidCallback? onPersonalInfo;
  final VoidCallback onRetry, onAccounts, onReferrals, onSignOut, onLanguage;
  final VoidCallback? onPin;
  @override
  Widget build(BuildContext context) {
    final name = profileName(user) ?? user.email ?? tr(context, 'profile');
    final created = DateTime.tryParse(user.createdAt);
    final joined = created == null
        ? null
        : '${tr(context, 'profileJoined')} ${MaterialLocalizations.of(context).formatMonthYear(created.toLocal())}';
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          UserPageHeader(
            primary: false,
            title: tr(context, 'profile'),
            notifications: notifications,
            onNotifications: onNotifications,
            onSignOut: onSignOut,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: userLine),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xffd8bdf7),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 31,
                              backgroundColor: const Color(0xffe4d4f5),
                              backgroundImage: info?.photo == null
                                  ? null
                                  : MemoryImage(info!.photo!),
                              child: info?.photo != null
                                  ? null
                                  : Text(
                                      profileInitials(name),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff392457),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: userInk,
                                  ),
                                ),
                                if (profileName(user) != null &&
                                    user.email != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    user.email!,
                                    style: const TextStyle(
                                      color: userMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (info?.publicUserId != null) ...[
                                  const SizedBox(height: 7),
                                  SelectableText(
                                    'User ID: ${info!.publicUserId}',
                                    style: const TextStyle(
                                      color: growthPurple,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (joined != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    joined,
                                    style: const TextStyle(
                                      color: userMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xffe9e2f2)),
                      ),
                      child: Row(
                        children: [
                          ProfileStat(
                            value: balance?.toString() ?? '—',
                            label: tr(context, 'coins'),
                            icon: Icons.toll,
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: const Color(0xfff0eff4),
                          ),
                          ProfileStat(
                            value: info?.usernames.length.toString() ?? '—',
                            label: tr(context, 'profileAccounts'),
                            icon: Icons.person,
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: const Color(0xfff0eff4),
                          ),
                          ProfileStat(
                            value: info?.referralCount.toString() ?? '—',
                            label: tr(context, 'profileReferrals'),
                            icon: Icons.share,
                          ),
                        ],
                      ),
                    ),
                    if (error)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tr(context, 'profileDataError')),
                            ),
                            TextButton(
                              onPressed: onRetry,
                              child: Text(tr(context, 'retry')),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: growthPurple,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          key: const Key('profile_referral_banner'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: onReferrals,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff6840d6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.people_alt_outlined,
                                    color: Color(0xffe5d9ff),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(context, 'referrals'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        tr(context, 'profileReferralDesc'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xffe9e2f2)),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Text(
                              tr(context, 'accountSection'),
                              style: const TextStyle(
                                color: Color(0xff6a6f8b),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.person_outline,
                            title: uf(
                              context,
                              'Personal information',
                              'വ്യക്തിഗത വിവരങ്ങൾ',
                            ),
                            onTap: onPersonalInfo,
                          ),
                          ProfileMenuTile(
                            icon: Icons.alternate_email,
                            title: tr(context, 'instagramAccounts'),
                            onTap: onAccounts,
                            trailingText: info?.usernames.length.toString(),
                          ),
                          ProfileMenuTile(
                            icon: Icons.people_outline,
                            title: tr(context, 'referrals'),
                            onTap: onReferrals,
                          ),
                          ProfileMenuTile(
                            icon: Icons.speed_outlined,
                            title: uf(
                              context,
                              'Campaign Limits',
                              'Campaign പരിധികൾ',
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => CampaignLimitsPage(
                                  onOpenReferrals: onCampaignReferrals,
                                  loadPlan:
                                      loadCampaignPlan ??
                                      () => Future.error(
                                        StateError(
                                          'Campaign limits unavailable',
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.help_outline,
                            title: tr(context, 'helpGuide'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => UserHelpPage(client: db),
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.support_agent_outlined,
                            title: tr(context, 'support'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SupportPage(client: db),
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.lock_outline,
                            title: tr(context, 'releasePin'),
                            subtitle: info == null
                                ? null
                                : tr(
                                    context,
                                    info!.pinSet ? 'changePin' : 'setupPin',
                                  ),
                            onTap: onPin,
                          ),
                          const LegalLinks(),
                        ],
                      ),
                    ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value, label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        if (icon != null) Icon(icon, size: 18, color: growthPurple),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff62647a), fontSize: 11),
        ),
      ],
    ),
  );
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle, trailingText;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      enabled: onTap != null,
      onTap: onTap,
      dense: false,
      minTileHeight: 66,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      horizontalTitleGap: 12,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xfff0edfa),
          borderRadius: BorderRadius.circular(11),
        ),
        child: icon == Icons.alternate_email
            ? const Center(child: InstagramLogo())
            : Icon(icon, size: 19, color: growthPurple),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: const TextStyle(color: Color(0xff71748b)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

enum ReferralSection { menu, code, enter }

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({
    super.key,
    required this.uid,
    required this.gateway,
    required this.accounts,
    this.authorizeChange,
    this.shareReferral,
    this.referralSection = ReferralSection.menu,
  });
  final String uid;
  final ProfileGateway gateway;
  final bool accounts;
  final ReferralSection referralSection;
  final Future<bool> Function()? authorizeChange;
  final Future<void> Function(String text)? shareReferral;
  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final referralCodeInput = TextEditingController();
  final accountSearchInput = TextEditingController();
  bool applyingReferral = false, sharingReferral = false;
  @override
  void dispose() {
    referralCodeInput.dispose();
    accountSearchInput.dispose();
    super.dispose();
  }

  Future<void> submitReferral() async {
    final value = referralCodeInput.text.trim();
    if (value.isEmpty || applyingReferral) return;
    setState(() => applyingReferral = true);
    try {
      if (!await (widget.authorizeChange?.call() ??
          confirmSecurityPin(context))) {
        return;
      }
      if (!mounted) return;
      await widget.gateway.applyReferral(value);
      if (!mounted) return;
      referralCodeInput.clear();
      toast(context, tr(context, 'referralApplied'));
      reload();
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is PostgrestException && e.code == '23505'
              ? tr(context, 'referralJoined')
              : friendlyError(context, e),
        );
      }
    } finally {
      if (mounted) setState(() => applyingReferral = false);
    }
  }

  Future<void> shareReferral(String code) async {
    if (sharingReferral) return;
    setState(() => sharingReferral = true);
    try {
      String? url;
      try {
        url = await widget.gateway.latestAppDownloadUrl().timeout(
          const Duration(seconds: 15),
        );
      } catch (_) {
        if (mounted) toast(context, tr(context, 'referralDownloadUnavailable'));
        return;
      }
      if (!mounted) return;
      if (url == null) {
        toast(context, tr(context, 'referralDownloadNotPublished'));
        return;
      }
      final text =
          '${uf(context, 'Join me on Freelan Space! Use my referral code below.', 'Freelan Space-ൽ ചേരൂ! താഴെയുള്ള എന്റെ referral code ഉപയോഗിക്കൂ.')}\n\n'
          '${tr(context, 'referralCode')}: $code\n'
          '${tr(context, 'referralDownload')}: $url\n\n'
          '${uf(context, 'After signing in, open Profile, choose Referral program, then tap Enter a referral code.', 'Sign in ചെയ്ത ശേഷം Profile തുറന്ന് Referral പദ്ധതി തിരഞ്ഞെടുക്കുക. തുടർന്ന് Referral കോഡ് നൽകുക എന്നതിൽ code നൽകുക.')}';
      if (widget.shareReferral != null) {
        await widget.shareReferral!(text);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      if (mounted) toast(context, tr(context, 'error'));
    } finally {
      if (mounted) setState(() => sharingReferral = false);
    }
  }

  late Future<ProfileInfo> data = widget.gateway.load(widget.uid);
  void reload() => setState(() {
    data = widget.gateway.load(widget.uid);
  });
  Future<void> input() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ProfileInputDialog(titleKey: 'addAccount'),
    );
    if (value == null || value.isEmpty || !mounted) return;
    if (!await (widget.authorizeChange?.call() ??
        confirmSecurityPin(context))) {
      return;
    }
    try {
      await widget.gateway.addAccount(value);
      if (!mounted) return;
      reload();
    } catch (e) {
      if (mounted) {
        final message = e is PostgrestException && e.code == '23505'
            ? tr(context, 'duplicateAccount')
            : friendlyError(context, e);
        toast(context, message);
      }
    }
  }

  Future<void> search() async {
    final username = await showDialog<String>(
      context: context,
      builder: (_) => InstagramSearchDialog(
        gateway: widget.gateway,
        initialQuery: accountSearchInput.text.trim(),
      ),
    );
    if (username == null || !mounted) return;
    if (!await (widget.authorizeChange?.call() ??
        confirmSecurityPin(context))) {
      return;
    }
    try {
      await widget.gateway.addAccount(username);
      if (mounted) reload();
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is PostgrestException && e.code == '23505'
              ? tr(context, 'duplicateAccount')
              : friendlyError(context, e),
        );
      }
    }
  }

  Future<void> remove(String username) async {
    if (!await (widget.authorizeChange?.call() ??
        confirmSecurityPin(context))) {
      return;
    }
    try {
      await widget.gateway.removeAccount(username);
      if (mounted) reload();
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    }
  }

  Future<void> openReferral(ReferralSection section) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsPage(
          uid: widget.uid,
          gateway: widget.gateway,
          accounts: false,
          authorizeChange: widget.authorizeChange,
          shareReferral: widget.shareReferral,
          referralSection: section,
        ),
      ),
    );
  }

  Widget referralMenu(BuildContext context) => AppListView(
    panel: false,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
    children: [
      ReferralHeader(
        eyebrow: uf(context, 'Your community', 'നിങ്ങളുടെ കൂട്ടായ്മ'),
        title: uf(context, 'Refer & Earn', 'Refer & Earn'),
        description: uf(
          context,
          'Invite your friends and earn rewards',
          'സുഹൃത്തുക്കളെ ക്ഷണിച്ച് rewards നേടുക',
        ),
        icon: Icons.people_alt_outlined,
        dark: true,
      ),
      const SizedBox(height: 24),
      Text(
        uf(context, 'Your referral tools', 'നിങ്ങളുടെ referral tools'),
        style: const TextStyle(
          color: growthInk,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        uf(
          context,
          'Everything you need to get started.',
          'തുടങ്ങാൻ വേണ്ടതെല്ലാം ഇവിടെ.',
        ),
        style: const TextStyle(color: userMuted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      ReferralActionTile(
        icon: Icons.ios_share_rounded,
        title: tr(context, 'referralCode'),
        subtitle: uf(
          context,
          'Copy or share your personal code',
          'നിങ്ങളുടെ code copy ചെയ്യുകയോ share ചെയ്യുകയോ ചെയ്യാം',
        ),
        color: growthPurple,
        onTap: () => openReferral(ReferralSection.code),
      ),
      const SizedBox(height: 10),
      ReferralActionTile(
        icon: Icons.history_rounded,
        title: uf(context, 'Referral History', 'Referral ചരിത്രം'),
        subtitle: uf(
          context,
          'See your referral connections',
          'Referral വഴി ബന്ധമുള്ളവരെ കാണാം',
        ),
        color: userTeal,
        onTap: () {
          final gateway = widget.gateway;
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReferralHistoryPage(
                load: gateway is ReferralHistoryGateway
                    ? (gateway as ReferralHistoryGateway).loadReferralHistory
                    : (_) => Future.error(
                        StateError('Referral history unavailable'),
                      ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 10),
      ReferralActionTile(
        icon: Icons.link_rounded,
        title: tr(context, 'referralEnter'),
        subtitle: uf(
          context,
          'Have a code from a friend?',
          'സുഹൃത്തിൽ നിന്ന് code ലഭിച്ചോ?',
        ),
        color: const Color(0xffbb6c27),
        onTap: () => openReferral(ReferralSection.enter),
      ),
      const SizedBox(height: 20),
      Text(
        tr(context, 'referralNoReward'),
        style: const TextStyle(color: userMuted, fontSize: 11, height: 1.5),
      ),
    ],
  );

  Widget referralEntry(BuildContext context, ProfileInfo info) => AppListView(
    panel: false,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
    children: [
      ReferralHeader(
        eyebrow: uf(
          context,
          'Connect with a friend',
          'സുഹൃത്തുമായി ബന്ധിപ്പിക്കുക',
        ),
        title: tr(context, 'referralEnter'),
        description: uf(
          context,
          'Add the code your friend shared with you.',
          'സുഹൃത്ത് share ചെയ്ത code നൽകുക.',
        ),
        icon: Icons.link_rounded,
      ),
      const SizedBox(height: 18),
      ReferralSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info.referralJoined) ...[
              const Icon(Icons.check_circle_rounded, size: 40, color: userTeal),
              const SizedBox(height: 12),
              Text(
                tr(context, 'referralJoined'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: growthInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              Text(
                uf(context, 'Friend’s code', 'സുഹൃത്തിന്റെ code'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: growthInk,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                uf(
                  context,
                  'Enter the code exactly as shared.',
                  'Share ചെയ്തതുപോലെ code നൽകുക.',
                ),
                style: const TextStyle(color: userMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: referralCodeInput,
                enabled: !applyingReferral,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  labelText: tr(context, 'referralEnter'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onSubmitted: (_) => submitReferral(),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: applyingReferral ? null : submitReferral,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(uf(context, 'Submit', 'നൽകുക')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                uf(
                  context,
                  'You’ll confirm with your Security PIN.',
                  'Security PIN ഉപയോഗിച്ച് സ്ഥിരീകരിക്കുക.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: userMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget referralCodePage(BuildContext context, ProfileInfo info) {
    final next = [5, 10, 15].where((n) => n > info.referralCount).firstOrNull;
    final milestone = next == null
        ? uf(
            context,
            'All referral milestones reached.',
            'എല്ലാ referral milestones-ഉം പൂർത്തിയായി.',
          )
        : '${uf(context, 'Next milestone', 'അടുത്ത milestone')}: ${info.referralCount}/$next';
    return AppListView(
      panel: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        ReferralHeader(
          eyebrow: uf(context, 'Share your code', 'നിങ്ങളുടെ code പങ്കിടുക'),
          title: tr(context, 'referralCode'),
          description: uf(
            context,
            'Share your code with friends to invite them.',
            'സുഹൃത്തുക്കളെ ക്ഷണിക്കാൻ നിങ്ങളുടെ code share ചെയ്യുക.',
          ),
          icon: Icons.ios_share_rounded,
          dark: true,
        ),
        const SizedBox(height: 18),
        ReferralSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'referralCode'),
                style: const TextStyle(
                  color: userMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff3efff),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffd8c9fb)),
                ),
                child: SelectableText(
                  info.referralCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: growthInk,
                    fontSize: 22,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: sharingReferral
                    ? null
                    : () => shareReferral(info.referralCode),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(tr(context, 'shareReferral')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: info.referralCode),
                  );
                  if (context.mounted) toast(context, tr(context, 'copied'));
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(tr(context, 'copyCode')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ReferralSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, color: userTeal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tr(context, 'referralCount')}: ${info.referralCount}',
                      style: const TextStyle(
                        color: growthInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                milestone,
                style: const TextStyle(color: userMuted, fontSize: 12),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: (info.referralCount / next).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xffeeeaf7),
                    color: userTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          uf(context, 'Referral rewards', 'Referral rewards'),
          style: const TextStyle(
            color: growthInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(context, 'referralNoReward'),
          style: const TextStyle(color: userMuted, fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 12),
        for (final reward in info.referralRewards.entries) ...[
          ReferralSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: growthPurple,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reward.key == 'invite'
                            ? userText(
                                context,
                                'Each referral',
                                'ഓരോ invite-നും',
                              )
                            : '${reward.key.split('_').last} ${userText(context, 'invites', 'invites')} · ${userText(context, 'extra bonus', 'അധിക bonus')}',
                        style: const TextStyle(
                          color: growthInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${reward.value} ${tr(context, 'coins')}',
                  style: const TextStyle(
                    color: growthPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: widget.accounts
        ? UserPageIdentity.instagramAccounts
        : UserPageIdentity.referrals,
    appBar: AppBar(
      title: Text(
        tr(
          context,
          widget.accounts
              ? 'instagramAccounts'
              : switch (widget.referralSection) {
                  ReferralSection.menu => 'referrals',
                  ReferralSection.code => 'referralCode',
                  ReferralSection.enter => 'referralEnter',
                },
        ),
      ),
    ),
    body: FutureBuilder<ProfileInfo>(
      future: isReferralMenu ? null : data,
      builder: (context, snapshot) {
        if (isReferralMenu) return referralMenu(context);
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'profileDataError')),
                TextButton(
                  onPressed: reload,
                  child: Text(tr(context, 'retry')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snapshot.data!;
        if (!widget.accounts &&
            widget.referralSection == ReferralSection.enter) {
          return referralEntry(context, info);
        }
        if (!widget.accounts) return referralCodePage(context, info);
        return AppListView(
          panel: false,
          padding: const EdgeInsets.all(14),
          children: [
            if (widget.accounts)
              UserSectionIntro(
                title: tr(context, 'instagramAccounts'),
                subtitle: uf(
                  context,
                  'Choose the accounts you use for campaign tasks.',
                  'Campaign tasks-ന് ഉപയോഗിക്കുന്ന accounts തിരഞ്ഞെടുക്കുക.',
                ),
                icon: Icons.alternate_email_rounded,
              ),
            if (widget.accounts) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: accountSearchInput,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          hintText: tr(context, 'instagramSearch'),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xffeee7fa),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: growthPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            tooltip: tr(context, 'instagramSearch'),
                            onPressed: search,
                            icon: const Icon(Icons.search, size: 20),
                          ),
                        ),
                        onSubmitted: (_) => search(),
                      ),
                      if (info.usernames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            uf(
                              context,
                              'No Instagram usernames added yet.',
                              'Instagram usernames ചേർത്തിട്ടില്ല.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              uf(context, 'or', 'അല്ലെങ്കിൽ'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xffe2d3fb),
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: input,
                        icon: const Icon(Icons.add_circle),
                        label: Text(tr(context, 'addAccount')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (info.usernames.isEmpty)
                GrowthEmpty(
                  art: 'accounts',
                  title: uf(
                    context,
                    'No Instagram Accounts Yet!',
                    'Instagram accounts ചേർത്തിട്ടില്ല!',
                  ),
                  subtitle: uf(
                    context,
                    'Add your Instagram username to manage your account here.',
                    'നിങ്ങളുടെ Instagram username ചേർക്കുക.',
                  ),
                  action: GrowthActionButton(
                    onPressed: input,
                    icon: Icons.add,
                    label: uf(
                      context,
                      'Add Instagram username',
                      'Instagram username ചേർക്കുക',
                    ),
                  ),
                ),
              for (final username in info.usernames)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    horizontalTitleGap: 6,
                    minLeadingWidth: 38,
                    leading: IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 48,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Open @$username on Instagram',
                      icon: const InstagramLogo(),
                      onPressed: () => openInstagramProfile(context, username),
                    ),
                    title: Tooltip(
                      message: '@$username',
                      child: Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (MediaQuery.sizeOf(context).width >= 360 &&
                            MediaQuery.textScalerOf(context).scale(1) <= 1.2)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffdcf6e9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              uf(context, 'Saved', 'ചേർത്തു'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff16845c),
                              ),
                            ),
                          ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: tr(context, 'removeAccount'),
                          onPressed: () => remove(username),
                        ),
                        PopupMenuButton<String>(
                          tooltip: uf(
                            context,
                            'Account options',
                            'Account options',
                          ),
                          child: const SizedBox(
                            width: 40,
                            height: 48,
                            child: Icon(Icons.more_vert, size: 18),
                          ),
                          onSelected: (value) async {
                            if (value == 'open') {
                              await openInstagramProfile(context, username);
                            } else if (value == 'copy') {
                              await Clipboard.setData(
                                ClipboardData(text: '@$username'),
                              );
                              if (context.mounted) {
                                toast(context, tr(context, 'copied'));
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'open',
                              child: Text(
                                uf(
                                  context,
                                  'Open Instagram',
                                  'Instagram തുറക്കുക',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'copy',
                              child: Text(
                                uf(
                                  context,
                                  'Copy username',
                                  'Username പകർത്തുക',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                color: const Color(0xffe4d6fa),
                child: ListTile(
                  leading: const GrowthIcon(Icons.verified_user),
                  trailing: const Icon(
                    Icons.people,
                    size: 44,
                    color: Color(0xffbc99ed),
                  ),
                  title: Text(uf(context, 'Total Accounts', 'ആകെ Accounts')),
                  subtitle: Text(
                    '${info.usernames.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: growthPurple,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  bool get isReferralMenu =>
      !widget.accounts && widget.referralSection == ReferralSection.menu;
}

class ProfileInputDialog extends StatefulWidget {
  const ProfileInputDialog({super.key, required this.titleKey});
  final String titleKey;
  @override
  State<ProfileInputDialog> createState() => _ProfileInputDialogState();
}

class _ProfileInputDialogState extends State<ProfileInputDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    titlePadding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
    contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    title: Row(
      children: [
        if (widget.titleKey == 'addAccount') ...[
          const SizedBox(width: 64, child: GrowthArt('accounts', height: 64)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            tr(context, widget.titleKey),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: growthInk,
            ),
          ),
        ),
        IconButton(
          tooltip: uf(context, 'Close', 'അടയ്ക്കുക'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.titleKey == 'addAccount') ...[
          Text(
            uf(
              context,
              'Enter the Instagram username you want to add manually to your account list.',
              'Account പട്ടികയിൽ ചേർക്കാനുള്ള Instagram username നൽകുക.',
            ),
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              widget.titleKey == 'addAccount'
                  ? Icons.alternate_email
                  : Icons.link,
            ),
            labelText: widget.titleKey == 'addAccount'
                ? uf(context, 'Instagram username', 'Instagram username')
                : tr(context, widget.titleKey),
            hintText: widget.titleKey == 'addAccount' ? '@username' : null,
          ),
        ),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(tr(context, 'apply')),
      ),
    ],
  );
}

class InstagramSearchDialog extends StatefulWidget {
  const InstagramSearchDialog({
    super.key,
    required this.gateway,
    this.initialQuery = '',
  });
  final ProfileGateway gateway;
  final String initialQuery;
  @override
  State<InstagramSearchDialog> createState() => _InstagramSearchDialogState();
}

class _InstagramSearchDialogState extends State<InstagramSearchDialog> {
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) search();
      });
    }
  }

  bool busy = false;
  String? result, error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (busy) return;
    final handle = controller.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(handle)) {
      setState(() {
        result = null;
        error = tr(context, 'proofBadHandle');
      });
      return;
    }
    setState(() {
      busy = true;
      result = null;
      error = null;
    });
    try {
      final username = await widget.gateway.searchInstagram(handle);
      if (mounted) setState(() => result = username);
    } on InstagramLookupException catch (e) {
      if (mounted) {
        final key = switch (e.code) {
          'not_found_or_unsupported' => 'instagramSearchNotFound',
          'rate_limited' => 'instagramSearchLimited',
          'access_denied' || 'unauthorized' => 'instagramSearchDenied',
          _ => 'instagramSearchUnavailable',
        };
        setState(() => error = tr(context, key));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = tr(context, 'instagramSearchUnavailable'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'instagramSearch')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'instagramSearchHelp')),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !busy,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr(context, 'instagramSearchHint'),
              hintText: '@username',
            ),
            onChanged: (_) => setState(() {
              result = null;
              error = null;
            }),
            onSubmitted: (_) => search(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : search,
            icon: const Icon(Icons.search),
            label: Text(tr(context, 'instagramSearchAction')),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (result != null) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text('@$result'),
            ),
            Text(
              tr(context, 'instagramSearchOwnership'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: busy || result == null
            ? null
            : () => Navigator.pop(context, result),
        child: Text(tr(context, 'instagramSearchAdd')),
      ),
    ],
  );
}

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({
    super.key,
    this.enabledLoader,
    this.pushUpdater,
    this.authorizeChange,
  });
  final Future<bool> Function()? authorizeChange;
  final Future<bool> Function()? enabledLoader;
  final Future<void> Function(bool)? pushUpdater;
  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage>
    with WidgetsBindingObserver {
  bool enabled = false, loading = true, busy = false;
  int loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    final request = ++loadGeneration;
    try {
      final value =
          await (widget.enabledLoader?.call() ??
              PushCoordinator.instance.isEnabled(db));
      if (mounted && request == loadGeneration) {
        setState(() {
          enabled = value;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == loadGeneration) {
        setState(() => loading = false);
        toast(context, tr(context, 'error'));
      }
    }
  }

  Future<void> changePush(bool value) async {
    if (busy) return;
    if (!await (widget.authorizeChange?.call() ??
        confirmSecurityPin(context))) {
      return;
    }
    if (!mounted || busy) return;
    // A prior permission read must not overwrite this explicit change.
    loadGeneration++;
    setState(() => busy = true);
    try {
      if (widget.pushUpdater != null) {
        await widget.pushUpdater!(value);
      } else if (value) {
        final granted = await PushCoordinator.instance.enable(db);
        if (!granted) throw const PushPermissionDenied();
      } else {
        await PushCoordinator.instance.disable(db);
      }
      if (mounted) setState(() => enabled = value);
    } on PushPermissionDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uf(
                context,
                'Allow notifications in Android settings, then turn this switch on again.',
                'Android settings-ൽ notifications അനുവദിച്ച ശേഷം switch വീണ്ടും ON ചെയ്യുക.',
              ),
            ),
            action: SnackBarAction(
              label: uf(context, 'Open settings', 'Settings തുറക്കുക'),
              onPressed: () async {
                try {
                  await updateChannel.invokeMethod<void>(
                    'openNotificationSettings',
                  );
                } catch (_) {
                  if (mounted) toast(context, tr(context, 'error'));
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          uf(
            context,
            'Unable to change notifications. Check permission and connection, then retry.',
            'Notification മാറ്റാനായില്ല. Permission, connection പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.settings,
    appBar: AppBar(title: Text(uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            UserSectionIntro(
              title: uf(context, 'Make it yours', 'നിങ്ങളുടെ ഇഷ്ടത്തിന്'),
              subtitle: uf(
                context,
                'Language, notifications and app preferences.',
                'ഭാഷ, notifications, app ക്രമീകരണങ്ങൾ.',
              ),
              icon: Icons.tune_rounded,
            ),
            Card(
              child: ListTile(
                minTileHeight: 64,
                leading: const GrowthIcon(Icons.system_update),
                title: Text(uf(context, 'App updates', 'App updates')),
                subtitle: Text(
                  uf(
                    context,
                    'Check for latest version',
                    'പുതിയ പതിപ്പ് പരിശോധിക്കുക',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AppUpdatePage(),
                  ),
                ),
              ),
            ),
            if (widget.enabledLoader == null)
              NotificationPreferences(client: db),
            Card(
              child: SwitchListTile(
                secondary: const GrowthIcon(Icons.notifications_active),
                subtitle: Text(
                  uf(
                    context,
                    'Get notified about important updates',
                    'പ്രധാന updates അറിയുക',
                  ),
                ),
                title: Text(
                  uf(context, 'Push notifications', 'Push notifications'),
                ),
                value: enabled,
                onChanged: loading || busy ? null : changePush,
              ),
            ),
            Card(
              child: ListTile(
                leading: const GrowthIcon(Icons.music_note_outlined),
                title: Text(
                  uf(context, 'Notification sound', 'Notification ശബ്ദം'),
                ),
                subtitle: Text(
                  uf(
                    context,
                    'Choose a sound or silent in Android settings',
                    'Android settings-ൽ ശബ്ദം അല്ലെങ്കിൽ silent തിരഞ്ഞെടുക്കുക',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await updateChannel.invokeMethod<void>(
                      'openNotificationSoundSettings',
                    );
                  } catch (_) {
                    if (context.mounted) {
                      toast(
                        context,
                        uf(
                          context,
                          'Notification sound settings are unavailable on this device.',
                          'ഈ ഉപകരണത്തിൽ notification sound settings ലഭ്യമല്ല.',
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            Card(
              child: ListTile(
                minTileHeight: 64,
                leading: const GrowthIcon(Icons.language),
                title: Text(uf(context, 'Language', 'ഭാഷ')),
                subtitle: Text(
                  uf(
                    context,
                    'Choose your preferred language',
                    'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0e8ff),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xffd9c7fb)),
                  ),
                  child: DropdownButton<String>(
                    underline: const SizedBox(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: growthInk,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    value: Localizations.localeOf(context).languageCode,
                    items: [
                      for (final entry in authLanguages.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value != null &&
                          await (widget.authorizeChange?.call() ??
                              confirmSecurityPin(context))) {
                        language.value = Locale(value);
                      }
                    },
                  ),
                ),
              ),
            ),
            const LegalLinks(),
            if (loading || busy) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Card(
              color: const Color(0xffe8dcfb),
              child: ListTile(
                minTileHeight: 64,
                leading: const Icon(
                  Icons.verified_user_outlined,
                  color: growthPurple,
                ),
                title: Text(
                  uf(
                    context,
                    'Your data is safe and secure',
                    'നിങ്ങളുടെ വിവരങ്ങൾ സുരക്ഷിതമാണ്',
                  ),
                ),
                subtitle: Text(
                  uf(
                    context,
                    'We value your privacy',
                    'നിങ്ങളുടെ സ്വകാര്യത പ്രധാനമാണ്',
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  uf(
                    context,
                    'Permanently delete account',
                    'Account സ്ഥിരമായി നീക്കുക',
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DeleteAccountPage(
                      client: db,
                      savedLogin: UserSavedLogin(supabaseUrl),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// The existing PIN hash and server lockout are shared with coin confirmation.
Future<bool> confirmSecurityPin(BuildContext context) async {
  final userId = db.auth.currentUser?.id;
  try {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const ReleasePinDialog(setup: false),
    );
    if (pin == null || !context.mounted) return false;
    final result = await db.rpc('verify_security_pin', params: {'p_pin': pin});
    if (result == 'ok' && userId != null && db.auth.currentUser?.id == userId) {
      return true;
    }
    if (context.mounted) toast(context, safePinError(context, result));
  } catch (error) {
    if (context.mounted) toast(context, friendlyError(context, error));
  }
  return false;
}

Future<void> openInstagramProfile(BuildContext context, String username) async {
  if (!RegExp(r'^[A-Za-z0-9_.]{1,30}$').hasMatch(username)) return;
  try {
    final native = Uri(
      scheme: 'instagram',
      host: 'user',
      queryParameters: {'username': username},
    );
    if (await launchUrl(native, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* Fall back to the public profile when Instagram is absent. */
  }
  if (context.mounted) {
    await openInstagram(context, 'https://www.instagram.com/$username/');
  }
}

class InstagramLogo extends StatelessWidget {
  const InstagramLogo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xffffc837), Color(0xffe1306c), Color(0xff833ab4)],
      ),
    ),
    child: Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            const Positioned(
              top: 2,
              right: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: SizedBox(width: 3, height: 3),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
