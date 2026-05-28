$ErrorActionPreference = "Stop"

$baseDir = "c:\Users\itsme\Documents\Chilli\chilli\lib"

$dirMap = @{
    "components" = "widgets"
    "config" = "theme"
    "core_services" = "services"
    "data_models" = "models"
    "helpers" = "utils"
    "legal_pages" = "legal"
    "localization" = "locale"
    "pages" = "screens"
}

$fileMap = [ordered]@{
    "components/call_request_dialog.dart" = "widgets/inbound_call.dart"
    "components/chat_request_dialog.dart" = "widgets/chat_request_dialog.dart"
    "components/genz_dialog.dart" = "widgets/genz_dialog.dart"
    "components/low_balance_dialog.dart" = "widgets/funds_sheet.dart"
    "components/profile_card.dart" = "widgets/user_tile.dart"

    "config/theme_colors.dart" = "theme/palette.dart"
    "config/typography_styles.dart" = "theme/tokens.dart"

    "core_services/analytics_tracking_service.dart" = "services/event_tracker.dart"
    "core_services/app_rating_service.dart" = "services/review_manager.dart"
    "core_services/app_version_service.dart" = "services/build_validator.dart"
    "core_services/authentication_service.dart" = "services/identity_manager.dart"
    "core_services/cloud_database_service.dart" = "services/firestore_repo.dart"
    "core_services/cloud_storage_service.dart" = "services/media_uploader.dart"
    "core_services/face_recognition_service.dart" = "services/biometric_scanner.dart"
    "core_services/fb_analytics_service.dart" = "services/fb_reporter.dart"
    "core_services/gifts_manager_service.dart" = "services/item_store.dart"
    "core_services/http_service.dart" = "services/data_bridge.dart"
    "core_services/local_notification_service.dart" = "services/alert_dispatcher.dart"
    "core_services/push_notification_service.dart" = "services/push_receiver.dart"
    "core_services/push_sender_service.dart" = "services/notif_transmitter.dart"
    "core_services/realtime_db_service.dart" = "services/presence_repo.dart"
    "core_services/video_call_service.dart" = "services/peer_session.dart"

    "data_models/gift_model.dart" = "models/virtual_item.dart"
    "data_models/user_data.dart" = "models/profile.dart"

    "helpers/profession_helper.dart" = "utils/role_picker.dart"
    "helpers/profile_image_helper.dart" = "utils/avatar_store.dart"

    "legal_pages/privacy_page.dart" = "legal/privacy_screen.dart"
    "legal_pages/refund_page.dart" = "legal/refund_screen.dart"
    "legal_pages/restrictions_page.dart" = "legal/restrictions_screen.dart"
    "legal_pages/terms_page.dart" = "legal/terms_screen.dart"

    "localization/locale_manager.dart" = "locale/lang_bundle.dart"

    "pages/auth_page.dart" = "screens/auth_screen.dart"
    "pages/balance_page.dart" = "screens/wallet_screen.dart"
    "pages/calls_history_page.dart" = "screens/call_log_screen.dart"
    "pages/chat_page.dart" = "screens/chat_screen.dart"
    "pages/contact_us_page.dart" = "screens/support_screen.dart"
    "pages/diagnostics_page.dart" = "screens/debug_screen.dart"
    "pages/face_verify_page.dart" = "screens/face_scan_screen.dart"
    "pages/language_select_page.dart" = "screens/lang_screen.dart"
    "pages/main_page.dart" = "screens/home_screen.dart"
    "pages/profile_page.dart" = "screens/profile_screen.dart"
    "pages/transactions_page.dart" = "screens/txn_screen.dart"
    "pages/user_details_page.dart" = "screens/onboard_screen.dart"
    "pages/video_call_page.dart" = "screens/chilli_call_view.dart"
}

# Create new directories
foreach ($newDir in $dirMap.Values) {
    $fullNewDir = Join-Path $baseDir $newDir
    if (-not (Test-Path $fullNewDir)) {
        New-Item -ItemType Directory -Path $fullNewDir | Out-Null
    }
}

# Move files
foreach ($key in $fileMap.Keys) {
    $oldPath = Join-Path $baseDir ($key -replace "/", "\")
    $newPath = Join-Path $baseDir ($fileMap[$key] -replace "/", "\")
    
    if (Test-Path $oldPath) {
        Move-Item -Path $oldPath -Destination $newPath -Force
        Write-Host "Moved $key to $($fileMap[$key])"
    }
}

# Update imports in all dart files
$dartFiles = Get-ChildItem -Path $baseDir -Recurse -Filter "*.dart"

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $newContent = $content
    
    foreach ($key in $fileMap.Keys) {
        # Replace occurrences in forward slash format (as used in dart imports)
        $newContent = $newContent -replace [regex]::Escape($key), $fileMap[$key]
    }
    
    if ($content -cne $newContent) {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "Updated imports in $($file.FullName)"
    }
}

# Clean up old directories if they are empty
foreach ($oldDir in $dirMap.Keys) {
    $fullOldDir = Join-Path $baseDir $oldDir
    if (Test-Path $fullOldDir) {
        $filesInside = Get-ChildItem -Path $fullOldDir -Force
        if ($filesInside.Count -eq 0) {
            Remove-Item -Path $fullOldDir -Force
            Write-Host "Removed empty directory $oldDir"
        } else {
            Write-Host "Directory $oldDir not empty, skipping removal"
        }
    }
}

Write-Host "Done"
