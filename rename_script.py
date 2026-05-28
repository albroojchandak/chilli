import os
import glob

base_dir = r"c:\Users\itsme\Documents\Chilli\chilli\lib"

dir_map = {
    "components": "widgets",
    "config": "theme",
    "core_services": "services",
    "data_models": "models",
    "helpers": "utils",
    "legal_pages": "legal",
    "localization": "locale",
    "pages": "screens"
}

file_map = {
    "components/call_request_dialog.dart": "widgets/inbound_call.dart",
    "components/chat_request_dialog.dart": "widgets/chat_request_dialog.dart",
    "components/genz_dialog.dart": "widgets/genz_dialog.dart",
    "components/low_balance_dialog.dart": "widgets/funds_sheet.dart",
    "components/profile_card.dart": "widgets/user_tile.dart",

    "config/theme_colors.dart": "theme/palette.dart",
    "config/typography_styles.dart": "theme/tokens.dart",

    "core_services/analytics_tracking_service.dart": "services/event_tracker.dart",
    "core_services/app_rating_service.dart": "services/review_manager.dart",
    "core_services/app_version_service.dart": "services/build_validator.dart",
    "core_services/authentication_service.dart": "services/identity_manager.dart",
    "core_services/cloud_database_service.dart": "services/firestore_repo.dart",
    "core_services/cloud_storage_service.dart": "services/media_uploader.dart",
    "core_services/face_recognition_service.dart": "services/biometric_scanner.dart",
    "core_services/fb_analytics_service.dart": "services/fb_reporter.dart",
    "core_services/gifts_manager_service.dart": "services/item_store.dart",
    "core_services/http_service.dart": "services/data_bridge.dart",
    "core_services/local_notification_service.dart": "services/alert_dispatcher.dart",
    "core_services/push_notification_service.dart": "services/push_receiver.dart",
    "core_services/push_sender_service.dart": "services/notif_transmitter.dart",
    "core_services/realtime_db_service.dart": "services/presence_repo.dart",
    "core_services/video_call_service.dart": "services/peer_session.dart",

    "data_models/gift_model.dart": "models/virtual_item.dart",
    "data_models/user_data.dart": "models/profile.dart",

    "helpers/profession_helper.dart": "utils/role_picker.dart",
    "helpers/profile_image_helper.dart": "utils/avatar_store.dart",

    "legal_pages/privacy_page.dart": "legal/privacy_screen.dart",
    "legal_pages/refund_page.dart": "legal/refund_screen.dart",
    "legal_pages/restrictions_page.dart": "legal/restrictions_screen.dart",
    "legal_pages/terms_page.dart": "legal/terms_screen.dart",

    "localization/locale_manager.dart": "locale/lang_bundle.dart",

    "pages/auth_page.dart": "screens/auth_screen.dart",
    "pages/balance_page.dart": "screens/wallet_screen.dart",
    "pages/calls_history_page.dart": "screens/call_log_screen.dart",
    "pages/chat_page.dart": "screens/chat_screen.dart",
    "pages/contact_us_page.dart": "screens/support_screen.dart",
    "pages/diagnostics_page.dart": "screens/debug_screen.dart",
    "pages/face_verify_page.dart": "screens/face_scan_screen.dart",
    "pages/language_select_page.dart": "screens/lang_screen.dart",
    "pages/main_page.dart": "screens/home_screen.dart",
    "pages/profile_page.dart": "screens/profile_screen.dart",
    "pages/transactions_page.dart": "screens/txn_screen.dart",
    "pages/user_details_page.dart": "screens/onboard_screen.dart",
    "pages/video_call_page.dart": "screens/chilli_call_view.dart",
}

# Ensure new directories exist
for new_dir in dir_map.values():
    os.makedirs(os.path.join(base_dir, new_dir), exist_ok=True)

# Move files
for old_rel, new_rel in file_map.items():
    old_path = os.path.join(base_dir, old_rel.replace("/", os.sep))
    new_path = os.path.join(base_dir, new_rel.replace("/", os.sep))
    if os.path.exists(old_path):
        os.rename(old_path, new_path)
        print(f"Moved {old_rel} to {new_rel}")

# Find all dart files
dart_files = []
for root, _, files in os.walk(base_dir):
    for file in files:
        if file.endswith(".dart"):
            dart_files.append(os.path.join(root, file))

# Update imports
for dart_file in dart_files:
    with open(dart_file, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content
    for old_rel, new_rel in file_map.items():
        # Replace occurrences in both forward slash and any other forms if needed,
        # usually imports are always forward slashes in dart
        new_content = new_content.replace(old_rel, new_rel)

    if new_content != content:
        with open(dart_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated imports in {dart_file}")

# Clean up old directories if empty
for old_dir in dir_map.keys():
    old_dir_path = os.path.join(base_dir, old_dir)
    if os.path.exists(old_dir_path):
        try:
            os.rmdir(old_dir_path)
            print(f"Removed empty directory {old_dir_path}")
        except OSError:
            print(f"Directory {old_dir_path} not empty, skipping removal")

