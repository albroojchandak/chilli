$ErrorActionPreference = "Stop"

$baseDir = "c:\Users\itsme\Documents\Chilli\chilli\lib"

$replacements = [ordered]@{
    "LowBalanceDialog" = "FundsSheet"
    "ModernCallRequestDialog" = "InboundCall"
    "_ModernCallRequestDialogState" = "_InboundCallState"
    "ProfileCard" = "UserTile"
    "_ProfileCardState" = "_UserTileState"

    "ThemeColors" = "Palette"
    "TypographyStyles" = "Tokens"

    "AnalyticsTrackingService" = "EventTracker"
    "AppRatingService" = "ReviewManager"
    "AppVersionService" = "BuildValidator"
    "AuthenticationService" = "IdentityManager"
    "CloudDatabaseService" = "FirestoreRepo"
    "CloudStorageService" = "MediaUploader"
    "FaceRecognitionService" = "BiometricScanner"
    "FbAnalyticsService" = "FbReporter"
    "GiftsManagerService" = "ItemStore"
    "HttpService" = "DataBridge"
    "LocalNotificationService" = "AlertDispatcher"
    "PushNotificationService" = "PushReceiver"
    "PushSenderService" = "NotifTransmitter"
    "RealtimeDbService" = "PresenceRepo"
    "VideoCallService" = "PeerSession"

    "GiftModel" = "VirtualItem"
    "GiftModelCatalog" = "VirtualItemCatalog"
    "GiftModelMessage" = "VirtualItemMessage"
    "GiftModelAnimation" = "VirtualItemAnimation"
    "UserData" = "Profile"

    "ProfessionHelper" = "RolePicker"
    "ProfileImageHelper" = "AvatarStore"

    "PrivacyPage" = "PrivacyScreen"
    "RefundPolicyContent" = "RefundScreen"
    "RestrictionPage" = "RestrictionsScreen"
    "Terms_Page" = "TermsScreen"

    "LocaleManager" = "LangBundle"

    "AuthPage" = "AuthScreen"
    "_AuthPageState" = "_AuthScreenState"
    "BalancePage" = "WalletScreen"
    "_BalancePageState" = "_WalletScreenState"
    "CallsHistoryPage" = "CallLogScreen"
    "_CallsHistoryPageState" = "_CallLogScreenState"
    "ChatPage" = "ChatScreen"
    "_ChatPageState" = "_ChatScreenState"
    "ContactUsPage" = "SupportScreen"
    "_ContactUsPageState" = "_SupportScreenState"
    "DiagnosticsPage" = "DebugScreen"
    "FaceVerifyPage" = "FaceScanScreen"
    "_FaceVerifyPageState" = "_FaceScanScreenState"
    "LanguageSelectPage" = "LangScreen"
    "_LanguageSelectPageState" = "_LangScreenState"
    "MainPage" = "HomeScreen"
    "_MainPageState" = "_HomeScreenState"
    "ProfilePage" = "ProfileScreen"
    "_ProfilePageState" = "_ProfileScreenState"
    "TransactionsPage" = "TxnScreen"
    "_TransactionsPageState" = "_TxnScreenState"
    "UserDetailsPage" = "OnboardScreen"
    "_UserDetailsPageState" = "_OnboardScreenState"
    "VideoCallPage" = "ChilliCallView"
    "_VideoCallPageState" = "_ChilliCallViewState"
}

$dartFiles = Get-ChildItem -Path $baseDir -Recurse -Filter "*.dart"

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $newContent = $content
    
    foreach ($oldName in $replacements.Keys) {
        $newName = $replacements[$oldName]
        $newContent = [System.Text.RegularExpressions.Regex]::Replace($newContent, "\b$oldName\b", $newName)
    }
    
    if ($content -cne $newContent) {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "Updated classes in $($file.FullName)"
    }
}

Write-Host "Class rename complete."
