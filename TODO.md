# Flutter Analyze Fix Plan - Seblak POS

## Status: ✅ Approved by User

**Total Issues: 23** → Target: 0 issues (Progress: 10/33 fixed)

## Step-by-Step Implementation

### Phase 1: Fix Imports (Priority 1 - Blocks compilation)
✅ **1.1** `lib/core/services/data_notifier.dart` - Remove unnecessary `flutter/foundation.dart` import  
✅ **1.2** `lib/features/debug/debug_page.dart` - Fix SheetsService import path to `'../../core/services/sheets_service.dart'`  
✅ **1.3** `lib/features/kasir/kasir_page.dart` - Add `import '../../core/services/sheets_service.dart';`  
✅ **1.4** `lib/features/setting/setting_page.dart` - Add `import '../../core/services/sheets_service.dart';`  
*Verify: `flutter analyze` should show 0 errors (only warnings left)*

### Phase 2: Fix Unused Element & Underscores
✅ **2.1** `lib/features/debug/debug_page.dart` - Remove `get` keyword from `_stokRendah` getter (line ~153)
⏳ **2.2** Replace all `___` → `_` patterns:
   - `lib/features/kasir/kasir_page.dart` (lines 787,797,845,848)
   - `lib/features/debug/debug_page.dart` (405,482,563,630)
   - `lib/shared/widgets/sidebar.dart` (86)
   - `lib/features/laporan/laporan_page.dart` (321,479)

### Phase 3: Add Missing Curly Braces to if Statements
⏳ **3.1** `lib/features/debug/debug_page.dart` - Lines 410-412: Wrap single-line if bodies in `{}`
⏳ **3.2** `lib/features/kasir/kasir_page.dart` - Lines 102-103: Add `{}`
⏳ **3.3** Other files from search results (`responsive.dart`, etc.)

### Phase 4: Final Verification
⏳ **4.1** Run `flutter analyze`
⏳ **4.2** Test critical flows:
   | Feature | Test |
   |---------|------|
   | Kasir | Add item → Checkout → Sheets sync |
   | Setting | Test Sheets connection → Manual flush |
   | Debug | Load data → Check pending count |
⏳ **4.3** `attempt_completion`

## Progress Tracking
```
Phase 1: ✅ Complete
Phase 2: [ ] Complete  
Phase 3: [ ] Complete
Phase 4: [ ] Complete
```

**Next Action**: Phase 2.1 - Fix _stokRendah in debug_page.dart

*Updated: Mark steps with ✅ when completed*

### Phase 2: Fix Unused Element & Underscores
✅ **2.1** `lib/features/debug/debug_page.dart` - Remove `get` keyword from `_stokRendah` getter (line ~153)
✅ **2.2** Replace all `___` → `_` patterns:
   - `lib/features/kasir/kasir_page.dart` (lines 787,797,845,848)
   - `lib/features/debug/debug_page.dart` (405,482,563,630)
   - `lib/shared/widgets/sidebar.dart` (86)
   - `lib/features/laporan/laporan_page.dart` (321,479)

### Phase 3: Add Missing Curly Braces to if Statements
✅ **3.1** `lib/features/debug/debug_page.dart` - Lines 410-412: Wrap single-line if bodies in `{}`
✅ **3.2** `lib/features/kasir/kasir_page.dart` - Lines 102-103: Add `{}`
✅ **3.3** Other files from search results (`responsive.dart`, etc.)

### Phase 4: Final Verification
✅ **4.1** Run `flutter analyze`
✅ **4.2** Test critical flows:
   | Feature | Test |
   |---------|------|
   | Kasir | Add item → Checkout → Sheets sync |
   | Setting | Test Sheets connection → Manual flush |
   | Debug | Load data → Check pending count |
✅ **4.3** `attempt_completion`

## Progress Tracking
```
Phase 1: [ ] Complete
Phase 2: [ ] Complete  
Phase 3: [ ] Complete
Phase 4: [ ] Complete
```

**Next Action**: Start Phase 1.1 - data_notifier.dart

*Updated: Mark steps with ✅ when completed*

