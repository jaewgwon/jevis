[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

# jevis

Jevisは、Flutterの`integration_test`を基盤として動作し、TypeSafeのJevモデルを使ってFlutterアプリをテストするDartパッケージです。**テストで許可するアクションを登録し、目標とアクションの上限回数を指定します。** Jevが現在のUIから次の操作を選び、目標を達成したかどうかを判断します。

[How to start](#how-to-start) · [アクション](#actions) · [目標と実行](#goals-and-execution) · [観察と制約](#observation-and-limits) · [ログ](#logging) · [サンプルとテスト](#example-and-tests) · [ライセンスと貢献](#license-and-contributing)

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

`actions`は実行順序ではなく、使用を許可する操作の一覧です。コンストラクターに目標、fixtureのマップ、`successCondition`を渡す必要はありません。Flutter用のテストパッケージなので、Dart単体ではなくFlutter SDKが必要です。

<a id="how-to-start"></a>
## How to start

### 1. Flutterの準備とパッケージのインストール

Flutterアプリ、Dart 3.4以降を含むFlutter SDK、アプリが対応する実機・エミュレーター・シミュレーターが必要です。まず開発環境を確認します。

```bash
flutter doctor
```

以下では、ローカルのソースコードを依存関係として使います。このリポジトリをダウンロードまたはcloneし、例えばアプリと同じ親フォルダーに配置します。

```text
workspace/
  your_app/
  jevis/
```

アプリの`pubspec.yaml`で、`dev_dependencies`にパッケージを追加します。

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  jevis:
    path: ../jevis
```

`path`は実際のリポジトリの場所に合わせて変更してください。フォルダー名とパッケージ名は同じでなくても構いません。アプリのルートで次を実行します。

```bash
flutter pub get
```

### 2. APIキーの取得と設定

[TypeSafeコンソール](https://console.typesafe.ai/)にログインしてAPIキーを取得します。[TypeSafe公式クイックスタート](https://docs.typesafe.ai/introduction/quickstart)にも、APIキーを取得するダッシュボードへの案内があります。

**アプリのルート**にある`pubspec.yaml`と同じ場所に、`jev.local.json`を作成します。

```json
{
  "TYPESAFE_API_KEY": "YOUR_TYPESAFE_API_KEY"
}
```

実際のキーを保存する前に、アプリの`.gitignore`に次の行を追加してください。

```gitignore
jev.local.json
```

キーをバージョン管理に含めないでください。JevisはDartのコンパイル時の定義から`TYPESAFE_API_KEY`を読み取ります。JSONファイルは**自動では読み込まれない**ため、テストの実行時に`--dart-define-from-file=jev.local.json`を渡してください。シェルの環境変数をexportするだけでは、デフォルトのクライアントにキーは設定されません。独自の設定から取得したキーを、`JevisTester`の`apiKey:`に直接渡すこともできます。

デフォルトのクライアントは実際のJev APIを呼び出します。キーがない場合は初期化時に失敗します。モデルIDは`jev-latest`のままで、このドキュメントでは設定ファイル名として`jev.local.json`を使用します。

### 3. 最初のテストを書く

アプリに`integration_test/todo_test.dart`を作成します。

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

`your_app`をアプリの`pubspec.yaml`にあるパッケージ名に置き換えてください。このテンプレートはToDo管理UIを想定しているため、目標、操作の指示、入力値もアプリに合わせて変更します。`tester`はFlutter UIの実行コンテキストです。リポジトリに含まれるUIで試す場合は、[サンプルとテスト](#example-and-tests)を参照してください。

### 4. テストを実行する

実機やシミュレーターを起動し、アプリのルートで次のコマンドを実行します。

```bash
flutter devices
flutter test integration_test/todo_test.dart \
  -d <device-id> \
  --dart-define-from-file=jev.local.json
```

`<device-id>`を`flutter devices`に表示されたIDに置き換えてください。成功すると`JevisReport`を返します。目標を達成できなかった場合は`JevisTestFailure`をスローし、Flutterテストを失敗させます。

設定で問題が起きた場合は、まずローカル依存関係のパス、デバイスID、`--dart-define-from-file`の指定を確認してください。APIリクエストには現在のUIテキストとアクションの説明が含まれるため、テスト用のアカウントとデータを使ってください。

<a id="actions"></a>
## アクション

### 標準コントロールの自動検出

シナリオに必要な操作だけを登録してください。`JevisActions`が現在の画面から具体的な対象を検出します。

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

- `focus()`はフォーカスされていない入力欄を、`clearText()`は値が入っている編集可能な入力欄を候補にします。
- `keyboardAction()`は入力欄のIMEアクションを使用します。`action: TextInputAction.done`で明示的に指定することもできます。
- `selectOption()`はドロップダウンを開き、次の観察で画面上の有効な選択肢を提示します。`values: ['High priority']`で選択肢のラベルを制限できます。
- `adjustSlider()`はMaterial Sliderで可能な増加・減少方向を提示します。`direction`と`steps`で操作を設定します。
- `dragTo(destination: find.byKey(const ValueKey('catalog_drop_target')), holdDuration: const Duration(milliseconds: 650))`は移動元のDraggableを検出します。移動先と時間は開発者が指定します。
- `wait()`と`waitUntil(condition: ...)`で明示的に待機できます。アクションの`instruction`は候補の説明に指示を追加しますが、操作が成功した証拠にはなりません。

入力文字列は`values`または`value`で指定します。Jevisは任意の文字列を生成しません。実行可能な候補が254個を超えると明示的に失敗するため、必要に応じて入力値や登録する操作を絞ってください。

### 特定のウィジェットとカスタムアクション

自動検出アクションと、対象を明示する`JevisAction`を組み合わせられます。ウィジェットに安定したKeyを付けてください。

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

明示的なジェスチャーと待機条件も組み合わせられます。

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

対象を指定するアクションでは、`key`と`finder`のどちらか一方だけを指定します。Finderは画面上の対象を一つだけ見つける必要があります。アクションIDはパッケージが生成します。カスタムコントロールの追加の利用可能条件には`availableWhen: () => ...`を使えます。ピンチ操作は標準では提供していません。対応する対象、時間設定、サンプルは[アクションリファレンス](doc/actions.md)を参照してください。

<a id="goals-and-execution"></a>
## 目標と実行

### goal、instruction、attempts

`test()`は名前付き引数を使用します。`goal`と`attempts`は必須、`instruction`と`verify`は任意です。`instruction`を省略すると、`goal`を操作の指示としても使用します。

目標は観察可能な最終状態として、指示は実行する作業として記述してください。指示を別途指定する場合は、音量70%など、操作に必要な値も指示に含めます。

```dart
await agent.test(
  goal: 'The Widget Catalog displays "Drop status: Delivered".',
  instruction: 'Navigate to Widget Catalog. Find Parcel and drag it onto Drop zone.',
  attempts: 50,
);
```

`attempts: 20`は、**最大20回のUIアクション実行**を許可します。シナリオの20回の再実行や、APIの20回のリトライではありません。例えば、開く・入力・保存の手順で項目を10個作るには最低30回の操作が必要で、移動や完了処理には追加の回数が必要です。

アクションの実行前と、最後に許可されたアクションの後にも目標を評価します。1回の実行でNoulは最大`attempts + 1`回、Choiceは最大`attempts`回呼び出されます。成功するとすぐに返ります。目標未達成、進行不能、低い確信度、繰り返し、APIエラーはテストの失敗になります。

各`test()`呼び出しで、探索メモリー、アクション履歴、繰り返しカウンターを初期化します。アプリの状態は維持されるため、同じagentで目標を順番に実行できます。同じUI上で並列実行しないでください。

```dart
await agent.test(goal: 'A Buy milk todo exists.', instruction: 'Add a todo titled Buy milk.', attempts: 10);
await agent.test(goal: 'The Buy milk todo is completed.', instruction: 'Mark Buy milk complete.', attempts: 10);
```

### NoulとChoiceの連携

各ステップは、観察 → Noul → 必要ならChoice → 実行 → 再観察の順に進みます。

- **Noul**は`{goal, screen}`を受け取り、現在の画面が目標を満たすかを判断します。アクション候補や履歴は受け取りません。
- **Choice**は`{actionInstruction, previousActions, screen}`と実行可能な候補を受け取り、次の操作を選びます。`actionInstruction`には`instruction`を使い、省略された場合は`goal`を使います。

二つのリクエストは同じ現在の画面を使用します。Noulが`goalThreshold`に達すると、Choiceを呼ばずに成功します。目標が未達成で、残り回数と候補がある場合にのみChoiceを呼びます。`decisionTimeout`は、1ステップ内の二つのHTTP呼び出しを合わせた制限です。Noulリクエストが失敗した場合は、ChoiceやUIアクションを実行しません。

以下はNoulリクエストを簡略化した例です。実際のリクエストにはモデルとcriteriaも含まれます。

```json
{
  "state": {"goal": "Goal", "screen": {"visibleText": [], "widgets": []}},
  "questions": {"goal_reached": {"type": "noul", "instructions": "Is the goal already achieved on the current screen?"}}
}
```

画面データには現在のテキスト、表示されているコントロール、スクロール状態が含まれます。Choiceの候補は`questions.next_action.criteria`に渡されます。`previousActions`には実行に成功したアクションの要約を順番に保持し、繰り返しも別々の項目として残します。`historyLimit`では切り詰めません。

過去の画面、初期状態、探索メモリー、変更一覧、カスタム`observe`データ、過去の確率は、デフォルトのクライアントのリクエストには含まれません。ローカルの記録やカスタムbrainでは使用できます。`JevisRequest.toJson()`はローカルコンテキストのシリアライズであり、HTTPリクエストの本文ではありません。実際の本文は`onRequest`で確認できます。

Choiceは、指示を完了したと判断すると`__stop__`を選択できます。その場合、Jevisは画面を再観察し、Noulによる最終確認を1回行います。ChoiceやUIアクションの追加実行は行いません。目標を確認できれば成功し、できなければ`stopped`で失敗します。候補がなければ`noActions`、操作回数を使い切れば`attemptsExhausted`で失敗します。繰り返しと実行エラーの検査も適用されます。

### 結果の検証

デフォルトの成功基準は`goalThreshold: 0.95`です。これは**モデルによる確率的な判断であり、決定論的な保証ではありません。** レポートには`completionBasis: model`と記録されます。画面に現れない状態、保存の永続性、サーバー側の処理結果は、UIの証拠だけでは確認できません。

モデルが完了と判断した後に決定論的な検証を行う場合は、`verify`を追加します。

```dart
await agent.test(goal: 'The saved name is Alex.', instruction: 'Enter Alex and save the form.', attempts: 15,
  verify: () => repository.savedName == 'Alex',
);
```

`repository`はアプリまたはテスト側で用意する依存オブジェクトです。`verify`がfalseを返すか例外をスローすると、`verificationFailed`で失敗し、完了判定の根拠は`model+assertion`になります。

<a id="observation-and-limits"></a>
## 観察と制約

観察処理は、タッチ判定を通る標準Flutterコントロールを読み取り、項目のタップ、指定値の入力、スクロール、戻る操作などの具体的なアクションを生成します。無効な対象や画面外の対象を実行候補から除外し、実行直前にも対象の有効性を確認します。

最大100個の画面上の`Text`文字列、ラベル、入力値またはパスワード欄が空かどうか、チェックボックス・スイッチの状態、スライダー値、スクロール位置と境界を収集します。標準のボタン、リスト、入力欄、Material Slider、DropdownButton、Draggable、Dismissible、および対応するGestureDetector/InkWellのコールバックを観察できます。初期状態と最近の履歴はローカルで参照でき、`historyLimit`のデフォルトは8です。

リスト項目には`ValueKey(item.id)`のような、データに基づく安定したKeyを付けてください。同じラベルでも区別できます。並べ替えや削除が可能な項目にインデックスのKeyを使わないでください。Keyのないリスト項目も表示中は操作できますが、探索メモリーには蓄積しません。

`memory.elements`は、安定したKeyを持つ最大500個の対象の最終観察を保持し、上限を超えると`memory.truncated`を設定します。`changes`には新しく観察した対象と状態が変化した対象が入ります。`visible: false`は過去の記録であり、対象が現在も存在する、または同じ状態であることの証拠ではありません。スクロール範囲を項目数に換算しません。正確な最終件数には画面上の集計表示や`verify`を使ってください。

カスタムの観察データはJSONにシリアライズできる必要があります。ローカルに記録され、デフォルトの`JevisClient`からは送信されません。

```dart
final agent = JevisTester(
  tester: tester,
  actions: actions,
  observe: () => {'screen': currentScreen, 'saveStatus': saveStatus},
);
```

パスワードなどの非表示の入力値はデフォルトの収集対象から除外しますが、通常のUIテキストとアクションの説明はAPIに送信されます。説明にパスワードを含めず、テスト用のデータとアカウントを使ってください。

スクリーンショット、カスタムキャンバスやゲーム画面、WebView、任意のジェスチャーの業務上の意味は解釈しません。OSの権限ダイアログ、画像による検証、ピンチ操作、自由形式の入力生成は標準では提供していません。必要に応じて明示的なアクション、カスタムアクション、別の検証方法を使ってください。ヒットテストは、視覚的な重なりや遮蔽を完全に検査するものではありません。

デフォルトの待機では、終了しないアニメーションによって`pumpAndSettle`がタイムアウトすることがあります。継続的なアニメーションがある画面では、アクションの`waitFor`で特定の結果を待つように設定してください。サンプルの目標と指示は英語です。言語ごとの精度や、Noul/Choiceの分離による精度向上は、このプロジェクトのテストでは実証していません。

<a id="logging"></a>
## ログと調整

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

戻り値のレポート、`agent.lastReport`、`JevisTestFailure.report`には、観察記録、目標の確率、アクションの確信度と確率分布、応答のモデルID、実行したアクション、失敗の詳細が含まれます。APIキーはレポートに含めません。デバッグ時は`onRequest`と`onResponse`でHTTP本文を確認できますが、本文にはテストUIのデータが含まれる場合があります。

アクションの確信度は正答率ではありません。アプリのテストデータを使ってしきい値を調整してください。付属のcatalogテストは現在`goalThreshold: 0.6`と`actionThreshold: 0.2`を使用していますが、パッケージのデフォルトはそれぞれ`0.95`と`0.5`です。

<a id="example-and-tests"></a>
## サンプルとテスト

付属の[Widget Catalog統合テスト](example/integration_test/todo_agent_test.dart)は、実際のJev APIを使用します。リポジトリのルートから次を実行します。

```bash
cd example
flutter pub get
```

[How to start](#how-to-start)に従って、`example/jev.local.json`にAPIキーを設定します。次のコマンドは`example/`で実行してください。

```bash
flutter devices
flutter test integration_test/todo_agent_test.dart \
  -d <device-id> \
  --dart-define-from-file=jev.local.json
```

実際のAPIキーを使わずにパッケージの動作を確認するには、リポジトリのルートからモックを使うテストとウィジェットテストを実行します。

```bash
flutter test
flutter analyze
```

ローカルのテストはパッケージの動作を検証するもので、実際のモデル判断の精度を実証するものではありません。詳しくは[アクションリファレンス](doc/actions.md)と[変更履歴](CHANGELOG.md)を参照してください。

<a id="license-and-contributing"></a>
## ライセンスと貢献

Copyright (c) 2026 jevis contributors.

[Apache License 2.0](LICENSE)で公開されています。貢献にも同じライセンスが適用され、各コミットに[Developer Certificate of Origin (DCO) 1.1](DCO)のsign-offが必要です。手順は[貢献ガイド](CONTRIBUTING.md)を参照してください。
