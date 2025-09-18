import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('fr')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        ) ??
        AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'VAR6 Betting App',
      'sign_in': 'Sign In',
      'email': 'Email',
      'password': 'Password',
      'remember_me': 'Remember me',
      'choose_language': 'Choose language',
      'english': 'English',
      'french': 'Français',
      'save': 'Save',
      'change_language': 'Change Language',
      'change_password': 'Change password',
  'current_password': 'Current password',
  'new_password': 'New password',
      'update_email': 'Update Email',
  'test_teams_gallery': 'Test team logos',
  'new_email': 'New email',
      'delete_account': 'Delete Account',
  'irreversible_action': 'This action is irreversible.',
  'confirm_password': 'Confirm password',
  'delete': 'Delete',
      'not_signed_in': 'Not signed in',
      'no_predictions': 'No predictions yet',
      'create_account': 'Create account',
      'log_out': 'Log out',
      'home': 'Home',
      'settings': 'Settings',
      'game_rules': 'Game Rules',
      'menu': 'Menu',
      'check_predictions': 'Check Predictions',
      'submit': 'Submit',
  'submit_prediction': 'Submit prediction',
      'auto_signing_in': 'Signing you in automatically...',
      'image_not_found': 'Image not found',
      'official_game_rules': 'Official Game Rules',
      'cancel': 'Cancel',
      'update': 'Update',
  'password_updated': 'Password updated',
  'email_updated': 'Email updated',
      'please_make_prediction': 'Please make at least one prediction.',
      'latest_match': 'Latest Match',
      'todays_matches': "Today's matches",
      'no_more_match_to_predict': 'No more match to predict',
      'your_predictions': 'Your predictions',
      'check_submitted_predictions': 'Check your submitted predictions below.',
      'place_your_predictions_for_todays_match_ups': "Place your predictions for today's match ups.",
      'forgot_password': 'Forgot password?',
      'password_reset_email_sent': 'Password reset email sent.',
      'vs': 'VS',
      'auto_login_failed': 'Auto-login failed. Please sign in manually.',
      'auth_invalid_email': 'Invalid email address.',
      'auth_user_not_found': 'No user found with this email.',
      'auth_wrong_password': 'Incorrect password.',
      'auth_user_disabled': 'This account has been disabled.',
      'auth_too_many_requests': 'Too many attempts. Try again later.',
      'auth_network_error': 'Network error. Check your connection.',
      'auth_unknown_error': 'An unknown error occurred.',
      'auth_email_in_use': 'This email is already in use.',
      'auth_missing_password': 'Please enter your password.',
      'auth_operation_not_allowed': 'Email/password sign-in is not enabled.',
      'hello': 'Hello',
      'rules_intro_1': "- On your homepage you'll be presented with the games that are upcoming so you can place your match game predictions",
      'rules_intro_2': '- If your prediction is correct at the end of game play you can win a special prize',
      'rules_intro_3': '- If your prediction is slightly wrong, but you predicted the winning team in that match would win, you stand the chance to win a runners up reward',
      'rules_intro_4': '- Winners are announced every Friday',
      'rules_prizes_intro': '- If your Game prediction is accurate you will win 1 of 2 prizes:',
      'prize1': '1. £100',
      'prize2': '2. A Brand new football Jersey',
      'rules_contact': 'If you want more info on how to receive your prize winnings please email: info@var6.net',
      'rules_disclaimer': 'The Var 6 mobile app wishes to make clear that Apple is in no way shape or form involved with the contest or sweepstakes played on this mobile application. Var 6 acts as an independent entity and is not apart of Apples products, only available on its App Store.',
    },
    'fr': {
      'app_title': 'Application de paris VAR6',
      'sign_in': 'Se connecter',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'remember_me': 'Se souvenir de moi',
      'choose_language': 'Choisir la langue',
      'english': 'Anglais',
      'french': 'Français',
      'save': 'Enregistrer',
      'change_language': 'Changer la langue',
      'change_password': 'Changer le mot de passe',
  'current_password': 'Mot de passe actuel',
  'new_password': 'Nouveau mot de passe',
      'update_email': 'Mettre à jour l’email',
  'test_teams_gallery': 'Tester les logos des équipes',
  'new_email': 'Nouvel e-mail',
      'delete_account': 'Supprimer le compte',
  'irreversible_action': 'Cette action est irréversible.',
  'confirm_password': 'Confirmez le mot de passe',
  'delete': 'Supprimer',
      'not_signed_in': 'Non connecté',
      'no_predictions': 'Aucune prédiction pour le moment',
      'create_account': 'Créer un compte',
      'log_out': 'Se déconnecter',
      'home': 'Accueil',
      'settings': 'Paramètres',
      'game_rules': 'Règles du jeu',
      'menu': 'Menu',
      'check_predictions': 'Voir les prédictions',
      'submit': 'Valider',
  'submit_prediction': 'Valider la prédiction',
      'auto_signing_in': 'Connexion automatique en cours…',
      'image_not_found': 'Image introuvable',
      'official_game_rules': 'Règles officielles du jeu',
      'cancel': 'Annuler',
      'update': 'Mettre à jour',
  'password_updated': 'Mot de passe mis à jour',
  'email_updated': 'E-mail mis à jour',
      'please_make_prediction': 'Veuillez faire au moins une prédiction.',
      'latest_match': 'Dernier match',
      'todays_matches': 'Matchs du jour',
      'no_more_match_to_predict': 'Plus de match à prédire',
      'your_predictions': 'Vos prédictions',
      'check_submitted_predictions': 'Consultez vos prédictions soumises ci-dessous.',
      'place_your_predictions_for_todays_match_ups': 'Faites vos prédictions pour les matchs du jour.',
      'forgot_password': 'Mot de passe oublié ?',
      'password_reset_email_sent': 'E-mail de réinitialisation du mot de passe envoyé.',
      'vs': 'VS',
      'auto_login_failed': 'La connexion automatique a échoué. Veuillez vous connecter manuellement.',
      'auth_invalid_email': 'Adresse e-mail invalide.',
      'auth_user_not_found': "Aucun utilisateur trouvé avec cet e-mail.",
      'auth_wrong_password': 'Mot de passe incorrect.',
      'auth_user_disabled': 'Ce compte a été désactivé.',
      'auth_too_many_requests': 'Trop de tentatives. Réessayez plus tard.',
      'auth_network_error': 'Erreur réseau. Vérifiez votre connexion.',
      'auth_unknown_error': 'Une erreur inconnue est survenue.',
      'auth_email_in_use': 'Cet e-mail est déjà utilisé.',
      'auth_missing_password': 'Veuillez saisir votre mot de passe.',
      'auth_operation_not_allowed': "La connexion e-mail/mot de passe n'est pas activée.",
      'hello': 'Bonjour',
      'rules_intro_1': "- Sur votre page d'accueil, vous verrez les matchs à venir afin de pouvoir placer vos prédictions",
      'rules_intro_2': '- Si votre prédiction est correcte à la fin du match, vous pouvez gagner un prix spécial',
      'rules_intro_3': "- Si votre prédiction est légèrement erronée mais que vous avez indiqué l'équipe gagnante, vous pouvez remporter une récompense de consolation",
      'rules_intro_4': '- Les gagnants sont annoncés chaque vendredi',
      'rules_prizes_intro': '- Si votre prédiction est exacte, vous gagnerez 1 des 2 prix :',
      'prize1': '1. 100 £',
      'prize2': '2. Un tout nouveau maillot de football',
      'rules_contact': "Pour plus d'informations sur la réception de vos gains, veuillez envoyer un e-mail à : info@var6.net",
      'rules_disclaimer': "L'application mobile Var 6 tient à préciser qu'Apple n'est en aucun cas impliquée dans le concours ou le tirage au sort proposés sur cette application. Var 6 agit en tant qu'entité indépendante et ne fait pas partie des produits Apple, seulement disponible sur l'App Store.",
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    final table = _localizedValues[lang] ?? _localizedValues['en']!;
    return table[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
