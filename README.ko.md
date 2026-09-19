[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

# jevis

Jevis는 Flutter의 `integration_test`를 기반으로 동작하며, TypeSafe의 Jev 모델로 Flutter 앱을 테스트하는 Dart 패키지입니다. **테스트에 허용할 액션을 등록하고, 목표와 최대 행동 횟수를 지정하세요.** Jev가 현재 UI를 바탕으로 다음 행동을 선택하고 목표 달성 여부를 판단합니다.

[![YouTube에서 Jevis 작동 영상 보기](https://img.youtube.com/vi/pfnfXmgHioU/hqdefault.jpg)](https://www.youtube.com/watch?v=pfnfXmgHioU)

[▶ YouTube에서 Jevis 작동 영상 보기](https://www.youtube.com/watch?v=pfnfXmgHioU)

[How to start](#how-to-start) · [액션](#actions) · [목표와 실행](#goals-and-execution) · [관찰과 한계](#observation-and-limits) · [로그](#logging) · [예제와 테스트](#example-and-tests) · [라이선스와 기여](#license-and-contributing)

```dart
final agent = JevisTester(
  tester: tester,
  actions: [
    JevisActions.tap(),
    JevisActions.enterText(values: ['Buy milk']),
    JevisActions.scroll(),
    JevisActions.back(),
  ],
);

await agent.test(
  goal: 'A Buy milk todo is completed.',
  instruction: 'Add Buy milk, then mark it complete.',
  attempts: 20,
);
```

`actions`는 실행 순서가 아니라 허용할 능력의 목록입니다. 생성자에는 목표, fixture 맵, `successCondition`이 필요하지 않습니다. Flutter 테스트 패키지이므로 독립적인 Dart 설치만으로는 사용할 수 없으며 Flutter SDK가 필요합니다.

<a id="how-to-start"></a>
## How to start

### 1. Flutter 준비와 패키지 설치

Flutter 앱, Dart 3.4 이상이 포함된 Flutter SDK, 앱이 지원하는 기기·에뮬레이터·시뮬레이터가 필요합니다. 먼저 개발 환경을 확인합니다.

```bash
flutter doctor
```

아래는 로컬 소스를 사용하는 설치 방법입니다. 이 저장소를 다운로드하거나 clone한 뒤, 예를 들어 앱 옆에 배치합니다.

```text
workspace/
  your_app/
  jevis/
```

앱의 `pubspec.yaml`에서 `dev_dependencies`에 패키지를 추가합니다.

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  jevis:
    path: ../jevis
```

`path`는 실제 저장소 폴더 경로에 맞게 변경하세요. 폴더 이름이 패키지 이름과 같을 필요는 없습니다. 앱 루트에서 다음을 실행합니다.

```bash
flutter pub get
```

### 2. API 키 발급과 설정

[TypeSafe 콘솔](https://console.typesafe.ai/)에 로그인해 API 키를 발급받습니다. [TypeSafe 공식 빠른 시작 문서](https://docs.typesafe.ai/introduction/quickstart)에서도 API 키를 받을 수 있는 대시보드를 안내합니다.

**앱 루트**의 `pubspec.yaml` 옆에 `jev.local.json`을 만듭니다.

```json
{
  "TYPESAFE_API_KEY": "YOUR_TYPESAFE_API_KEY"
}
```

실제 키를 저장하기 전에 앱의 `.gitignore`에 다음 항목을 추가합니다.

```gitignore
jev.local.json
```

키를 소스 관리에 포함하지 마세요. Jevis는 Dart 컴파일 시점의 정의에서 `TYPESAFE_API_KEY`를 읽습니다. JSON 파일은 **자동으로 로드되지 않으므로** 테스트 실행 시 `--dart-define-from-file=jev.local.json`을 전달해야 합니다. 셸 환경변수를 export하는 것만으로는 기본 클라이언트에 키가 설정되지 않습니다. 자체 설정에서 읽은 키를 `JevisTester`의 `apiKey:`로 직접 전달할 수도 있습니다.

기본 클라이언트는 실제 Jev API를 호출합니다. 키가 없으면 초기화 단계에서 실패합니다. 모델 ID는 `jev-latest`이며, 이 문서의 설정 파일명은 `jev.local.json`입니다.

### 3. 첫 테스트 작성

앱에 `integration_test/todo_test.dart`를 만듭니다.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jevis/jevis.dart';
import 'package:your_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Jevis adds and completes a todo', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final agent = JevisTester(
      tester: tester,
      actions: [
        JevisActions.tap(),
        JevisActions.enterText(values: ['Buy milk']),
        JevisActions.scroll(),
        JevisActions.back(),
      ],
    );

    await agent.test(
      goal: 'A Buy milk todo is completed.',
      instruction: 'Add Buy milk, then mark it complete.',
      attempts: 20,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
```

`your_app`을 앱의 `pubspec.yaml`에 정의된 패키지 이름으로 바꾸세요. 이 예제는 할 일 관리 UI를 가정하므로 목표, 행동 지침, 입력값도 앱에 맞게 변경해야 합니다. `tester`는 Flutter UI 실행 컨텍스트입니다. 저장소에 포함된 UI로 먼저 실행하려면 [예제와 테스트](#example-and-tests)를 참고하세요.

### 4. 테스트 실행

기기나 시뮬레이터를 실행한 뒤 앱 루트에서 다음 명령을 실행합니다.

```bash
flutter devices
flutter test integration_test/todo_test.dart \
  -d <device-id> \
  --dart-define-from-file=jev.local.json
```

`<device-id>`를 `flutter devices`에 표시된 ID로 바꾸세요. 성공하면 `JevisReport`를 반환합니다. 목표를 달성하지 못하면 `JevisTestFailure`를 던져 Flutter 테스트를 실패시킵니다.

설정 문제가 발생하면 먼저 로컬 의존성 경로, 기기 ID, `--dart-define-from-file` 전달 여부를 확인하세요. API 요청에는 현재 UI 텍스트와 액션 설명이 포함되므로 테스트용 계정과 데이터를 사용하세요.

<a id="actions"></a>
## 액션

### 표준 컨트롤 자동 탐색

시나리오에 필요한 능력만 등록하세요. `JevisActions`가 현재 화면에서 구체적인 대상을 탐색합니다.

```dart
final agent = JevisTester(
  tester: tester,
  actions: [
    JevisActions.tap(),
    JevisActions.focus(),
    JevisActions.enterText(values: ['Alex', 'alex@example.com']),
    JevisActions.clearText(),
    JevisActions.keyboardAction(), // Uses the field's declared IME action.
    JevisActions.longPress(instruction: 'Hold a sample note to reveal its delete button.'),
    JevisActions.doubleTap(),
    JevisActions.drag(offset: const Offset(-250, 0)),
    JevisActions.selectOption(),
    JevisActions.adjustSlider(),
    JevisActions.scroll(),
    JevisActions.back(),
  ],
);
```

- `focus()`는 포커스되지 않은 입력 필드, `clearText()`는 값이 있는 편집 가능한 입력 필드를 후보로 만듭니다.
- `keyboardAction()`은 입력 필드의 IME 액션을 사용합니다. `action: TextInputAction.done`으로 직접 지정할 수도 있습니다.
- `selectOption()`은 드롭다운을 열고 다음 관찰에서 활성화된 화면상의 옵션을 제공합니다. `values: ['High priority']`로 옵션 문구를 제한할 수 있습니다.
- `adjustSlider()`는 Material Slider의 가능한 증가·감소 방향을 제공합니다. `direction`과 `steps`로 조작을 설정합니다.
- `dragTo(destination: find.byKey(const ValueKey('catalog_drop_target')), holdDuration: const Duration(milliseconds: 650))`는 출발 Draggable을 탐색합니다. 목적지와 시간은 개발자가 지정합니다.
- `wait()`와 `waitUntil(condition: ...)`으로 명시적으로 기다릴 수 있습니다. 액션의 `instruction`은 후보 설명에 지침을 추가하며, 동작 성공의 증거로 사용되지 않습니다.

입력 문자열은 `values` 또는 `value`로 제공해야 합니다. Jevis는 임의의 문자열을 생성하지 않습니다. 실행 가능한 후보가 254개를 넘으면 명시적으로 실패하므로 필요에 따라 입력값이나 허용 능력을 줄이세요.

### 특정 위젯 지정과 커스텀 액션

자동 탐색 액션과 명시적인 `JevisAction` 대상을 함께 사용할 수 있습니다. 위젯에 안정적인 Key를 붙이세요.

```dart
FilledButton(
  key: const ValueKey('save_todo'),
  onPressed: saveTodo,
  child: const Text('Save'),
)
```

```dart
JevisAction.tap('Tap Save.', key: 'save');
JevisAction.tap('Open Settings.', finder: find.text('Settings'));
JevisAction.enterText('Enter email.', key: 'email', value: 'test@example.com');
JevisAction.scroll('Explore the list.', key: 'list', offset: const Offset(0, -300));
JevisAction.wait();
JevisAction.custom('Perform a custom gesture.', run: (tester) async {
  await tester.longPress(find.byKey(const ValueKey('item')));
});
```

명시적인 제스처와 대기 조건도 조합할 수 있습니다.

```dart
JevisAction.longPress(
  'Long-press the Buy milk todo to reveal its delete icon.',
  key: 'milk_todo',
  waitFor: JevisWait.visible(key: 'delete_todo'),
);
JevisAction.drag(
  'Swipe the todo left to reveal its actions.',
  key: 'milk_todo',
  offset: const Offset(-250, 0),
  duration: const Duration(milliseconds: 500),
);
```

대상이 있는 액션에는 `key`와 `finder` 중 하나만 지정합니다. Finder는 화면상의 대상 하나를 찾아야 합니다. 액션 ID는 패키지가 생성합니다. 커스텀 컨트롤의 추가 사용 가능 조건은 `availableWhen: () => ...`으로 지정하세요. 핀치 제스처는 기본 제공하지 않습니다. 대상, 시간 설정, 예제는 [액션 안내](doc/actions.md)를 참고하세요.

<a id="goals-and-execution"></a>
## 목표와 실행

### goal, instruction, attempts

`test()`는 이름 있는 인자를 사용합니다. `goal`과 `attempts`는 필수이며 `instruction`과 `verify`는 선택입니다. `instruction`을 생략하면 `goal`을 행동 지침으로도 사용합니다.

목표는 관찰 가능한 최종 상태로, 행동 지침은 수행할 작업으로 작성하세요. 별도 지침을 지정한다면 볼륨 70%처럼 행동에 필요한 값도 지침에 포함해야 합니다.

```dart
await agent.test(
  goal: 'The Widget Catalog displays "Drop status: Delivered".',
  instruction: 'Navigate to Widget Catalog. Find Parcel and drag it onto Drop zone.',
  attempts: 50,
);
```

`attempts: 20`은 **최대 20번의 UI 행동 실행**을 허용합니다. 시나리오를 20번 재시작하거나 API를 20번 재시도한다는 뜻이 아닙니다. 예를 들어 열기·입력·저장을 거쳐 항목 10개를 생성하면 최소 30번의 행동이 필요하고, 탐색이나 완료 처리에는 추가 횟수가 필요합니다.

행동 실행 전과 마지막 허용 행동 이후에도 목표 달성 여부를 평가합니다. 한 실행에서 Noul은 최대 `attempts + 1`번, Choice는 최대 `attempts`번 호출될 수 있습니다. 성공하면 즉시 반환합니다. 미달성, 진행 불가, 낮은 확신도, 반복, API 오류는 테스트 실패로 처리합니다.

매 `test()` 호출은 탐색 기억, 행동 이력, 반복 카운터를 초기화합니다. 앱 상태는 유지되므로 같은 agent로 목표를 순차 실행할 수 있습니다. 같은 UI에서 병렬 실행하지 마세요.

```dart
await agent.test(goal: 'A Buy milk todo exists.', instruction: 'Add a todo titled Buy milk.', attempts: 10);
await agent.test(goal: 'The Buy milk todo is completed.', instruction: 'Mark Buy milk complete.', attempts: 10);
```

### Noul과 Choice의 동작

각 단계는 관찰 → Noul → 필요하면 Choice → 실행 → 재관찰 순서로 진행됩니다.

- **Noul**은 `{goal, screen}`으로 현재 화면이 목표를 충족하는지 판단합니다. 액션 후보나 행동 이력은 받지 않습니다.
- **Choice**는 `{actionInstruction, previousActions, screen}`과 실행 가능한 후보를 받아 다음 행동을 고릅니다. `actionInstruction`에는 `instruction`을 사용하며, 생략했다면 `goal`을 사용합니다.

두 요청은 동일한 현재 화면을 사용합니다. Noul이 `goalThreshold`에 도달하면 Choice를 호출하지 않고 성공합니다. 목표가 미달성이고 남은 횟수와 후보가 있을 때만 Choice를 호출합니다. `decisionTimeout`은 한 단계의 두 HTTP 호출을 합친 제한입니다. Noul 요청이 실패하면 Choice나 UI 행동을 실행하지 않습니다.

다음은 Noul 요청을 축약한 예시입니다. 실제 요청에는 모델과 criteria도 포함됩니다.

```json
{
  "state": {"goal": "Goal", "screen": {"visibleText": [], "widgets": []}},
  "questions": {"goal_reached": {"type": "noul", "instructions": "Is the goal already achieved on the current screen?"}}
}
```

화면 데이터에는 현재 텍스트, 보이는 컨트롤, 스크롤 상태가 포함됩니다. Choice 후보는 `questions.next_action.criteria`로 전달됩니다. `previousActions`에는 실행에 성공한 액션의 요약을 순서대로 담으며, 반복도 별도 항목으로 유지합니다. `historyLimit`으로 잘라내지 않습니다.

이전 화면, 최초 상태, 탐색 기억, 변경 목록, 커스텀 `observe` 데이터, 이전 확률은 기본 클라이언트의 요청에 포함하지 않습니다. 로컬 기록과 사용자 정의 brain에서는 사용할 수 있습니다. `JevisRequest.toJson()`은 로컬 문맥 직렬화이며 HTTP 요청 본문과 다릅니다. 실제 본문은 `onRequest`로 확인하세요.

Choice가 지침을 완료했다고 판단하면 `__stop__`을 선택할 수 있습니다. 이때 Jevis는 화면을 다시 관찰하고 Noul로 한 번 더 확인하며, Choice나 UI 행동을 추가 실행하지 않습니다. 목표가 확인되면 성공하고, 그렇지 않으면 `stopped`로 실패합니다. 실행 후보가 없으면 `noActions`, 행동 횟수가 소진되면 `attemptsExhausted`로 실패합니다. 반복과 실행 오류 검사도 유지됩니다.

### 결과 검증

기본 성공 기준은 `goalThreshold: 0.95`입니다. 이는 **모델의 확률적 판단이며 결정론적 보장이 아닙니다.** 보고서에는 `completionBasis: model`로 표시됩니다. 화면에 드러나지 않는 상태, 저장 지속성, 서버 처리 결과는 UI 증거만으로 확인할 수 없습니다.

모델 완료 판단 이후 결정론적인 확인이 필요하다면 `verify`를 추가하세요.

```dart
await agent.test(goal: 'The saved name is Alex.', instruction: 'Enter Alex and save the form.', attempts: 15,
  verify: () => repository.savedName == 'Alex',
);
```

`repository`는 앱이나 테스트에서 제공하는 의존성입니다. `verify`가 false를 반환하거나 예외를 던지면 `verificationFailed`로 실패하며, 완료 판단 기준은 `model+assertion`이 됩니다.

<a id="observation-and-limits"></a>
## 관찰과 한계

관찰기는 터치 가능한 표준 Flutter 컨트롤을 읽고 항목 탭, 제공된 값 입력, 스크롤, 뒤로 가기 같은 구체적인 액션을 만듭니다. 비활성화되거나 화면 밖인 대상은 실행 후보에서 제외하며, 실행 직전에 대상의 유효성을 다시 검사합니다.

최대 100개의 화면상 `Text` 문자열, 라벨, 입력값 또는 비밀번호 필드의 비어 있음 여부, 체크박스·스위치 상태, 슬라이더 값, 스크롤 위치·경계를 수집합니다. 표준 버튼, 목록, 입력, Material Slider, DropdownButton, Draggable, Dismissible 및 지원되는 GestureDetector/InkWell 콜백을 관찰할 수 있습니다. 최초 상태와 최근 이력은 로컬에서 사용할 수 있으며, `historyLimit`의 기본값은 8입니다.

목록 항목에는 `ValueKey(item.id)`처럼 데이터에 대응하는 안정적인 Key를 붙이세요. 라벨이 같아도 구분할 수 있습니다. 재정렬·삭제가 가능한 항목에 인덱스 Key를 사용하지 마세요. Key 없는 목록 항목도 화면에 보이면 조작할 수 있지만 탐색 기억에 누적하지 않습니다.

`memory.elements`는 안정적인 Key를 가진 최대 500개 대상의 마지막 관찰을 보관하고, 한도를 넘으면 `memory.truncated`를 표시합니다. `changes`에는 새로 관찰하거나 상태가 바뀐 대상이 담깁니다. `visible: false`는 과거 기록이며, 대상이 현재도 존재하거나 같은 상태라는 증거가 아닙니다. 스크롤 길이를 항목 수로 환산하지 않습니다. 정확한 최종 개수는 화면의 집계 표시나 `verify`로 확인하세요.

사용자 정의 관찰 데이터는 JSON 직렬화가 가능해야 합니다. 로컬에 기록되며 기본 `JevisClient`는 전송하지 않습니다.

```dart
final agent = JevisTester(
  tester: tester,
  actions: actions,
  observe: () => {'screen': currentScreen, 'saveStatus': saveStatus},
);
```

비밀번호처럼 가려진 입력값은 기본 수집에서 제외하지만 일반 화면 텍스트와 액션 설명은 API로 전송됩니다. 설명에 비밀번호를 넣지 말고 테스트 데이터와 계정을 사용하세요.

스크린샷, 커스텀 캔버스·게임 화면, WebView, 임의 제스처의 업무적 의미를 해석하지 않습니다. OS 권한 팝업, 비전 검사, 핀치, 자유 형식 입력 생성은 기본 제공하지 않습니다. 필요한 경우 명시적·커스텀 액션이나 별도 검증 전략을 사용하세요. 히트 테스트가 시각적인 가림 여부를 완전히 검사하는 것은 아닙니다.

기본 대기에서는 끝나지 않는 애니메이션 때문에 `pumpAndSettle` timeout이 발생할 수 있습니다. 지속적인 애니메이션이 있는 화면에는 액션의 `waitFor`로 특정 결과를 기다리도록 지정하세요. 예제는 영어 목표와 지침을 사용합니다. 언어별 정확도와 Noul/Choice 분리에 따른 정확도 개선 여부는 이 프로젝트의 테스트로 입증하지 않았습니다.

<a id="logging"></a>
## 로그와 튜닝

```dart
final agent = JevisTester(
  tester: tester,
  actions: actions,
  model: 'jev-latest',
  options: const JevisOptions(
    goalThreshold: 0.95,
    actionThreshold: 0.5,
    maxRepeatedAction: 2,
    decisionTimeout: Duration(seconds: 30),
    settleTimeout: Duration(seconds: 5),
    stepDelay: Duration(milliseconds: 300),
  ),
  onReport: (report) => print(report.toJson()),
);
```

반환 보고서, `agent.lastReport`, `JevisTestFailure.report`에는 관찰 기록, 목표 확률, 행동 확신도와 확률 분포, 응답 모델 ID, 실행 액션, 실패 정보가 담깁니다. API 키는 보고서에 포함하지 않습니다. 디버깅할 때 `onRequest`와 `onResponse`로 HTTP 본문을 확인할 수 있으며, 본문에는 테스트 UI 데이터가 포함될 수 있습니다.

행동 확신도는 정답률이 아닙니다. 앱의 테스트 데이터로 기준값을 조정하세요. 현재 예제 catalog 테스트는 `goalThreshold: 0.6`, `actionThreshold: 0.2`를 사용하며, 패키지 기본값은 각각 `0.95`, `0.5`입니다.

<a id="example-and-tests"></a>
## 예제와 테스트

저장소의 [Widget Catalog 통합 테스트](example/integration_test/todo_agent_test.dart)는 실제 Jev API를 사용합니다. 저장소 루트에서 다음을 실행합니다.

```bash
cd example
flutter pub get
```

[How to start](#how-to-start)를 따라 `example/jev.local.json`에 API 키를 설정합니다. 다음 명령은 `example/`에서 실행하세요.

```bash
flutter devices
flutter test integration_test/todo_agent_test.dart \
  -d <device-id> \
  --dart-define-from-file=jev.local.json
```

실제 API 키 없이 패키지 동작을 확인하려면 저장소 루트에서 mock 기반 테스트와 위젯 테스트를 실행합니다.

```bash
flutter test
flutter analyze
```

로컬 테스트는 패키지 동작을 검증하며 실제 모델 판단의 정확도를 입증하지는 않습니다. 자세한 내용은 [액션 안내](doc/actions.md)와 [변경 이력](CHANGELOG.md)을 참고하세요.

<a id="license-and-contributing"></a>
## 라이선스와 기여

Copyright (c) 2026 jevis contributors.

[Apache License 2.0](LICENSE)으로 배포됩니다. 기여에도 동일한 라이선스가 적용되며, 각 커밋에 [Developer Certificate of Origin (DCO) 1.1](DCO) sign-off가 필요합니다. 방법은 [기여 안내](CONTRIBUTING.md)를 참고하세요.
