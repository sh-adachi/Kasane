# かさね — Kasane

曜日ごとのルーティンを決め、できた日・できなかった日と実施時間を残すiPhoneアプリです。SwiftUI / iOS 17以降。アカウントや外部ライブラリは不要です。

## できること

- **今日**：月曜始まりの週表示。過去の日付も選べます。「できた」「できなかった」を記録し、未記録と区別します。
- **ルーティン**：名前、月〜日の実施曜日、目安時間、任意の時刻、アイコン、色を設定。読書・ストレッチ・英語のテンプレートも使えます。
- **実施時間**：手入力はその日の合計時間を編集。タイマーは終了したセッションを既存の時間に加算します。アプリを閉じても計測を復元し、同時に1件を計測できます。
- **積み重ね**：今週・今月・全期間の合計時間、日別グラフ、達成率、内容ごとの時間・回数・日々の記録を確認できます。
- **休止・再開**：過去の記録を残したまま習慣を休止できます。曜日変更と休止の履歴を保持するため、過去の予定が後から変わりません。

初回は空のデータから始まります。実際に記録した時間だけを合計に含めます。「できなかった」日でも実施時間があれば合計に含めます。未来の日付には結果を保存できません。

達成率は「できた回数 ÷ 今日までの予定件数（記録済みの予定外実績を含む）」です。未記録を自動で「できなかった」に変えることはありません。全期間のグラフは直近30日までを表示し、合計と内容別の内訳は全期間を対象にします。

## 起動

`Kasane.xcodeproj` をXcodeで開き、Schemeを **Kasane**、実行先を **iPhone 17 Pro** 等のシミュレータにして Run（⌘R）します。

```sh
xcodebuild -project Kasane.xcodeproj -scheme Kasane \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

実機で実行する場合はSigning & Capabilitiesで自分のTeamを選ぶか、`Config/Signing.local.xcconfig.example` を `Config/Signing.local.xcconfig` にコピーしてTeam IDを設定します。必要に応じてBundle Identifierを変更してください。

## 保存と仕様

- Application Support/Kasane/habits.json にアトミックに保存します。
- 保存に失敗した場合は画面にエラーを表示し、成功前のデータを保持します。
- 読み込みに失敗したファイルは上書きしません。
- クラウド同期・通知・データ書き出しは未実装です。アプリ削除時には端末内の記録も削除されます。
- タイマーは目安時間で自動停止しません。日をまたいだ分は開始した日にまとめて計上します。
- 時間は秒単位で保存し、一覧では分単位の切り捨て表示です。1分未満はその旨を表示します。

## 検証

```sh
swift test --scratch-path .build/swift-tests

xcodebuild -project Kasane.xcodeproj -scheme Kasane \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derivedData -parallel-testing-enabled NO \
  -resultBundlePath Artifacts/UITests.xcresult CODE_SIGNING_ALLOWED=NO test
```

UIテストは `--uitesting` で通常の保存先と分離されます。`--reset-data` はUIテスト用の保存先だけを初期化し、`--sample-data` は空のテスト領域に架空のサンプルを追加します。

`--demo` を起動引数に指定すると、メモリ上の架空データで試せます。実際の記録を読み書きせず、再起動でデモ内容が初期化されます。

## 構成

- App/：画面、アプリ状態、手入力とタイマー
- Core/：モデル、曜日・日付、集計、データ検証、JSON保存
- Tests/：日付境界、履歴、集計、保存・復元のユニットテスト
- UITests/：作成・保存・再起動・タイマー・画面表示のテスト
- Artifacts/：ビルド結果と画面キャプチャ

## 画面例

架空の体験データを表示した画面です。

[今日](Artifacts/Today.png) · [ルーティン](Artifacts/Routines.png) · [積み重ね](Artifacts/Progress.png) · [全期間](Artifacts/AllTime.png) · [初回画面](Artifacts/Welcome.png)
