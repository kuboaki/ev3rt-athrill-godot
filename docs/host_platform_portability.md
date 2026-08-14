# ホストプラットフォーム移植方針

更新日: 2026-08-14

## 目的

`ev3rt-athrill-godot`を、現在動作確認済みのUbuntu ARM64以外のホストでも
実行するための見通しと確認項目を整理する。

対象候補:

- Ubuntu x86_64（Intel/AMD）
- macOS ARM64 / x86_64
- Windows + WSL2
- Windowsネイティブ

## 用語上の注意

V850E2MはAthrillがエミュレートする「ターゲットCPU」であり、Ubuntu、macOS、
WindowsはAthrill自身を実行する「ホストOS」である。

したがって、`athrill-target-v850e2m/`の対応だけでホスト移植が完了するとは
限らない。実際には次の層を確認する必要がある。

```text
EV3RTのビルド環境
        ↓
V850実行イメージ
        ↓
Athrill本体とホストOS依存層
        ↓
athrill_mmap.bin / unity_mmap.bin
        ↓
Godot VDEVアダプター
```

## 現在の確認済み環境

- Parallels Desktop上のUbuntu 24.04 ARM64
- Godot `4.7.1.stable.official.a13da4feb`
- AthrillとGodot 3Dを同じUbuntu環境で実行
- タグ`godot-3d-integration-v2`で完全シーケンスを確認

```text
P_INIT
P_WAIT_FOR_LOADING
P_TRANSPORTING
P_WAIT_FOR_UNLOADING
P_RETURNING
P_ARRIVED
```

Mac上のGodotからUbuntu上のAthrillへ接続する構成ではない。編集済みのGodot
プロジェクトをUbuntuへ持ち込み、Ubuntu上でAthrillと一緒に実行している。

## プラットフォーム別の見通し

| ホスト | 見通し | 主な課題 |
|---|---|---|
| Ubuntu x86_64 | 最も容易 | ビルドと固定依存版の再現確認 |
| Ubuntu ARM64 | 動作確認済み | 現行基準環境 |
| macOS | 実現可能性が高い | Linux固有API、ツールチェーン、起動スクリプト |
| Windows + WSL2 | Athrill側は容易 | Windows版GodotとのMMAP共有方法 |
| Windowsネイティブ | 可能だが作業量が多い | POSIX API、MMAP、タイマー、プロセス起動の置換 |

## Ubuntu x86_64

Ubuntu x86_64は、既存AthrillやV850クロスツールチェーンが想定してきた環境に
近く、最初に試すべき追加ホストである。

構成:

```text
Ubuntu x86_64
├── V850クロスツールチェーン
├── Athrill x86_64ビルド
├── EV3RT実行イメージ
├── MMAPファイル
└── Godot 4.7.1 x86_64
```

見込みとしては新規ポーティングより、依存リポジトリ、コンパイラー、ビルド手順を
再現して動作確認する作業に近い。

確認項目:

1. x86_64版Godot 4.7.1を使用する
2. Athrillをx86_64向けにビルドできる
3. V850クロスコンパイラーが実行できる
4. `athrill_mmap.bin`と`unity_mmap.bin`が生成される
5. `EV3RT_VDEV_DIR`または既定相対パスが正しい
6. 依存リポジトリの固定コミットが一致する
7. 2D版と3D版で完全シーケンスを実行する

## MMAPプロトコルの移植性

Godot側は固定オフセットへ明示的な32ビット値を読み書きしている。このため、
ARM64からx86_64へホストCPUが変わっても、原則としてプロトコルは変わらない。

ただし、Athrill/C側でMMAP領域へC構造体を直接配置している箇所は確認する。

注意対象:

- `long`のサイズ
- ポインターを含む構造体
- 暗黙のパディング
- `sizeof(struct)`依存
- アラインメント依存
- ホストエンディアン依存

MMAP上のデータは、可能な限り固定幅整数型と明示オフセットで定義する。

## macOS

macOSはPOSIX系であるため、Windowsネイティブより移植しやすい見込み。
Godot側はすでに動作しているため、主な対象はAthrill、EV3RTビルド環境、VDEV。

調査対象:

- Linux固有ヘッダーとシステムコール
- `mmap`、`msync`、ファイルロック
- pthread、signal、clock/timer
- V850クロスツールチェーンのmacOS実行形式
- `run_sample04_stm.sh`が使う外部コマンド
- GNU/Linux固有オプション
- Apple SiliconとIntel Macの差

現在Ubuntu ARM64で動作しているため、macOS ARM64ではCPUアーキテクチャ差より
ホストOS差の吸収が中心になる。

## Windows

### WSL2

AthrillとEV3RTをLinux環境として動かす最短経路。ただし、Windowsネイティブ版
GodotとWSL2内Athrillが同じMMAPファイルを安定して共有できるかは別途検証する。

候補:

- GodotもWSLg/Linux版で動かす
- Windows版GodotとWSL2の間に明示的な通信ブリッジを置く
- ファイルMMAPではなくソケット等へ抽象化する

### Windowsネイティブ

次のPOSIX依存部分をWin32またはクロスプラットフォーム層へ置き換える必要がある。

- `mmap` → `CreateFileMapping` / `MapViewOfFile`
- pthread
- signal
- POSIXタイマー
- fork/exec系のプロセス起動
- Bash/Make中心の起動手順
- パスと実行ファイル名

Godot自体はWindowsをサポートしているため、主な移植作業はAthrillと周辺ツール。

## 推奨する進め方

1. Ubuntu x86_64で無変更ビルド・実行を試す
2. 失敗箇所をホスト依存、ツールチェーン依存、設定依存へ分類する
3. Athrillのホスト依存APIを一覧化する
4. MMAPプロトコルの固定幅・固定オフセット性を確認する
5. macOS向けホスト層を実装する
6. WindowsはWSL2案とネイティブ案を比較してから選ぶ

一度に全OSへ対応せず、Ubuntu x86_64を第2の基準環境として確立してからmacOSへ
進むのが安全である。

## Ubuntu x86_64の受け入れ条件

- AthrillとEV3RTサンプルをビルドできる
- AthrillがV850実行イメージを起動できる
- MMAPファイルをGodotが読み書きできる
- 2D版が`P_ARRIVED`まで完走する
- 3D版が`P_ARRIVED`まで完走する
- Cargo表示と`TOUCH_1`が同期する
- 超音波検出と台形状バンパー判定が動作する
- 既存タグ`godot-3d-integration-v2`と同じ結果になる

## 未確定事項

- Athrill本体に残るLinux専用APIの正確な範囲
- V850クロスツールチェーンのmacOS/Windows配布状況
- Windows版GodotとWSL2間のファイルMMAP整合性
- Windowsネイティブ対応を行う価値と保守コスト
- VDEV通信をファイルMMAP以外へ抽象化するか
