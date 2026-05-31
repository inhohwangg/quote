# Offline Memo App — Design Spec
Date: 2026-05-31

## 1. Overview
구형 안드로이드 기기 타겟의 오프라인 메모 앱 v2.0.
기존 quote 앱(GetX + Dio)을 완전히 교체하며, Hive + Riverpod 기반으로 재작성한다.

## 2. Tech Stack
| 레이어 | 패키지 |
|---|---|
| 로컬 DB | `hive`, `hive_flutter` |
| 상태 관리 | `flutter_riverpod` |
| 라우팅 | `go_router` |
| PDF | `pdf`, `printing` |
| 이미지 첨부 | `image_picker` |
| 권한 | `permission_handler` |
| 유틸 | `uuid`, `path_provider`, `shared_preferences` |
| 코드 생성 | `hive_generator`, `build_runner` |
| 테스트 | `flutter_test`, `mocktail` |

## 3. Folder Structure
```
lib/
├── core/
│   ├── hive/hive_init.dart
│   ├── router/app_router.dart
│   └── theme/app_theme.dart
├── features/
│   ├── memo/
│   │   ├── data/
│   │   │   ├── memo_model.dart
│   │   │   ├── memo_model.g.dart      (generated)
│   │   │   └── memo_repository.dart
│   │   ├── providers/memo_provider.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   └── memo_editor_screen.dart
│   │   └── widgets/
│   │       ├── memo_card.dart
│   │       └── drawing_canvas.dart
│   ├── pdf/pdf_service.dart
│   └── onboarding/screens/
│       ├── splash_screen.dart
│       └── onboarding_screen.dart
├── shared/widgets/responsive_layout.dart
└── main.dart
```

## 4. Data Model
```dart
@HiveType(typeId: 0)
class MemoModel extends HiveObject {
  @HiveField(0) late String id;           // uuid v4
  @HiveField(1) late String title;
  @HiveField(2) String? body;
  @HiveField(3) String? drawingPath;      // 로컬 PNG 절대 경로
  @HiveField(4) late List<String> imagePaths; // 첨부 이미지 경로 목록
  @HiveField(5) late DateTime createdAt;
  @HiveField(6) late DateTime updatedAt;
}
```

## 5. Riverpod State
- `memoRepositoryProvider` → `Provider<MemoRepository>` (Hive box 래핑, CRUD)
- `memoListProvider` → `StateNotifierProvider<MemoNotifier, List<MemoModel>>`
- `selectedMemoProvider` → `StateProvider<MemoModel?>` (에디터 진입 시 선택)

## 6. Routing Flow
```
SplashScreen (2초 대기)
  ├─ SharedPreferences 'onboarding_done' == false → /onboarding
  └─ 'onboarding_done' == true → /home

/onboarding (3페이지 PageView)
  Page 1: 메모 작성 소개
  Page 2: PDF 내보내기 소개
  Page 3: 스토리지 + 카메라 권한 요청
  [시작하기] → onboarding_done=true → /home

/home       → HomeScreen (반응형)
/memo/new   → MemoEditorScreen (신규)
/memo/:id   → MemoEditorScreen (수정)
```

## 7. Responsive Layout
`LayoutBuilder`로 너비 기준 분기:
- `width < 600` → `ListView` (1열, MemoCard)
- `width >= 600` → `GridView` (crossAxisCount 2, MemoCard)

## 8. PDF Export
`pdf` 패키지 사용:
1. 제목 → `pw.Text` (bold)
2. 본문 → `pw.Text` (normal)
3. drawingPath 존재 시 → `pw.Image` (PNG 바이트 삽입)
4. imagePaths 각각 → `pw.Image` 순서대로 삽입
5. 완성된 `pw.Document` 반환 (예외 없이 생성 보장)

## 9. Onboarding & Permissions
- `permission_handler`로 `Permission.storage`, `Permission.camera` 요청
- 완료 후 `SharedPreferences.setBool('onboarding_done', true)`
- SplashScreen에서 이 값을 읽어 라우팅 분기

## 10. Test Coverage
| 파일 | 대상 |
|---|---|
| `hive_repository_test.dart` | MemoRepository CRUD + JSON 직렬화 |
| `pdf_export_test.dart` | PdfService: 예외 없이 Document 객체 생성 |
| `home_responsive_widget_test.dart` | HomeScreen: 너비 조작 시 ListView↔GridView 전환 |
| `routing_flow_test.dart` | Splash→Onboarding→Home 라우팅 흐름 |

## 11. Out of Scope (이번 버전)
- Google Drive 백업
- IAP (인앱 결제)
