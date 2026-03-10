# Fix Signer Link Redirection

The user is being redirected to the login page when accessing the public signing link. This is likely due to the application using the default Hash URL strategy while trying to handle clean-looking paths, combined with an `initialLocation` of `/login`.

## Proposed Changes

### Frontend

#### [MODIFY] [main.dart](file:///c:/Users/Bluetech/Desktop/Singproof/frontend/lib/main.dart)
- Import `flutter_web_plugins/url_strategy.dart`.
- Call `usePathUrlStrategy()` in `main()`.
- This allows the app to recognize `/sign/:token` directly from the URL path without needing a `#`.

#### [MODIFY] [document_detail_page.dart](file:///c:/Users/Bluetech/Desktop/Singproof/frontend/lib/presentation/documents/document_detail_page.dart)
- Remove `/#/` from the link generation logic for the signer copy-link action.
- Ensure all generated links use the clean path format.

## Verification Plan

### Manual Verification
- Rebuild the Flutter Web app.
- Restart Docker containers.
- Navigate to a document in the admin/user dashboard.
- Copy the signer link.
- Open the link in a new incognito window (unauthenticated).
- Verify it lands directly on the document signing page without showing the login screen.
