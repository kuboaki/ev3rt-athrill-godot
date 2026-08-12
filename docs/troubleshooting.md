# トラブルシューティング

## 調査の基本方針

問題を次の境界で分離する。

1. EV3RTアプリケーションがセンサー値を取得できるか
2. EV3RTが左右モーター値を出力できるか
3. VDEV共有ファイルへ値が反映されているか
4. Godotが共有ファイルを正しく読み書きしているか
5. Godotの物理・幾何モデルが正しいか

ライントレースが失敗した場合でも、最初から制御コードや速度を変更しない。
固定値をVDEVへ直接書き込み、入力、制御、出力、物理を順番に切り分ける。

## Athrill設定ファイルを解析できない

### 症状

```text
ERROR: can not parse data on device_config_mmap_sync.txt...
```

または:

```text
ERROR: can not parse data on memory_mmap.txt...
```

### 原因

Athrillの`file_getline()`が`fgetc()`の戻り値を`char`へ格納していた。
Ubuntu ARM64環境では`char`が符号なしとなり、EOFの`-1`を認識できず、
ファイル末尾を不正データとして解析していた。

### 対処

`scripts/build_athrill.sh`を使ってAthrillをビルドする。

```bash
./scripts/build_athrill.sh
```

このスクリプトは次のパッチを適用する。

```text
patches/athrill-target-v850e2m/0001-fix-eof-handling-on-arm64.patch
```

手動確認では、`file_getline()`内の変数が`char c`ではなく`int c`になっている
ことを確認する。

## Athrillは起動するがEV3RTタスクが期待どおり動かない

### 確認事項

AthrillをEV3RT向けのオプションでビルドしているか確認する。

```text
timer32=true
etrobo_optimize=true
```

MMAP VDEVを使用するため、`vdev_disable=true`は指定しない。

推奨手順:

```bash
./scripts/build_athrill.sh
```

## Athrillの終了コードが1になる

### 症状

```text
EXIT for timeout(...).
run_exit=1
```

### 説明

指定クロックへ到達したタイムアウト終了でも、Athrillは終了コード1を返す。
ログに`EXIT for timeout`があり、それ以前に例外やエラーがなければ、現在の
検証手順では正常なタイムアウト終了として扱う。

## Athrillを停止できない

フォアグラウンドで起動した端末では`Ctrl+C`を押す。

別の端末から停止する場合:

```bash
pkill -TERM -x athrill2
```

停止確認:

```bash
pgrep -a athrill2
echo "athrill_pgrep_exit=$?"
```

`athrill_pgrep_exit=1`なら停止している。

## GNUV850ではなくホストGCCでビルドされる

### 症状

生成物のGCCバージョンがホストのGCC 10などになっている。

### 確認

```bash
toolchain_dir=toolchain/work/install/v850-elf-gcc-linux-arm64
"$toolchain_dir/bin/v850-elf-gcc" --version | head -1
```

期待値:

```text
v850-elf-gcc (GCC) 4.9-GNUV850_v14.01
```

sampleビルドには次を使う。

```bash
./scripts/build_sample03.sh
./scripts/build_sample04_stm.sh
```

スクリプトが正しいツールチェーンを`PATH`へ追加する。

## EV3RT向けパッチが適用されていない

### 確認

```bash
./scripts/prepare_ev3rt.sh
```

適用済みの場合の例:

```text
Already applied: 0001-ruby3-and-configure-fixes.patch
Already applied: 0002-emulate-lcd-on-console.patch
```

ビルドスクリプトは`prepare_ev3rt.sh`を自動的に呼び出す。

## Godotで画像のpreloadに失敗する

### 症状

```text
Preload file "res://assets/robot_top.png" does not exist.
```

### 主な原因

古いGodotプロジェクト`auto-transporter-godot`を開いている。

### 確認

```bash
pgrep -a -f Godot_v4.7.1
```

`--path`が次を指していることを確認する。

```text
.../ev3rt-athrill-godot/godot
```

正しい起動例:

```bash
~/Applications/Godot-4.7.1/Godot_v4.7.1-stable_linux.arm64 \
  --editor \
  --path ~/Projects/ev3rt_godot/ev3rt-athrill-godot/godot \
  --rendering-method gl_compatibility
```

画像の存在確認:

```bash
ls -l godot/assets/robot_top.png
```

## Godotエディターを操作できない・実行画面が残る

### 原因

Godotエディターと実行シーンは別プロセスになる。実行シーンが入力を保持して
いたり、エディター終了後に実行シーンだけが孤児として残る場合がある。

### 確認

```bash
pgrep -a -f Godot_v4.7.1
```

通常は次の2種類が見える。

- `--editor --path ...`: エディター
- `--scene ...`: 実行シーン

実行シーンをGodotの停止ボタンで終了する。操作できない場合は対象PIDを確認して
`kill -TERM PID`で終了する。

複数の実行シーンが同じ`unity_mmap.bin`へ書き込まないようにする。

## GodotのLキーまたはSpaceキーが効かない

Godotの実行画面を一度クリックし、キーボードフォーカスを与える。

- `L`: 荷物の積載・荷下ろし
- `Space`: Godot側の車体位置・姿勢だけを初期化

FinderやホストOSがF5/F8などを取得する環境では、Godotエディター上の実行・停止
ボタンを使用する。

## Spaceを押してもEV3RT状態が最初に戻らない

### 説明

現在の`Space`はGodot側の位置と姿勢だけを戻す。次はリセットしない。

- EV3RTカーネル
- 状態機械
- タイマー
- 周期ハンドラ
- Athrill内部状態

完全に最初から実行するには、Athrillを停止して再起動し、Godotの車体位置も
初期化する。

## Lキーを押しても走行を開始しない

### 確認1: Godot側表示

```text
CARGO LOADED: true
```

になっているか確認する。

### 確認2: Athrill状態名

```text
P_WAIT_FOR_LOADING
P_TRANSPORTING
```

へ変化するか確認する。

### 確認3: VDEV入力

`TOUCH_1`は荷物搭載確認であり、ON値は4095である。

GodotとAthrillが異なるVDEVディレクトリを参照していないかも確認する。

## Godot画面ではREFLECTが変わるがモーターが切り替わらない

### 過去に確認した原因

Godotが`reflect_value`を計算して表示していたが、`write_vdev_rx()`で
REFLECTスロットへ書き込んでいなかった。

### 確認

`write_vdev_rx()`に次があることを確認する。

```gdscript
file.seek(sensor_file_offset(REFLECT_INDEX))
file.store_32(reflect_value)
```

Godot側の値だけでなく、共有ファイルへ実際に書かれた値を確認する。

## 左右モーターが個別に動くか確認したい

Godotを停止し、センサー値を共有ファイルへ直接書いて切り分ける。

期待する対応:

```text
REFLECT=5  -> POWER_A=0,  POWER_C=20
REFLECT=50 -> POWER_A=20, POWER_C=0
```

TX値の読み取り:

```bash
python3 scripts/vdev_poke.py \
  read_tx \
  ../ev3rt-athrill-v850e2m/sdk/uml_seminar_ev3/sample04-01-stm/athrill_mmap.bin
```

この固定値試験で切り替わる場合、Athrill/EV3RT制御とモーター出力は正常で、
Godot側のセンサー生成、書き込み、時間処理を調査する。

## 共有ファイルの値がAthrillへ反映されない

### 確認1: 同じファイルか

Athrillプロセスが開いているファイルを確認する。

```bash
athrill_pid=$(pgrep -n athrill2)
ls -l "/proc/$athrill_pid/fd" | grep 'mmap.bin'
```

必要ならinodeを比較する。

```bash
stat -Lc '%d:%i %s %n' \
  path/to/unity_mmap.bin \
  "/proc/$athrill_pid/fd/5"
```

### 確認2: Godotのflush

`write_vdev_rx()`が書き込み後に次を呼んでいるか確認する。

```gdscript
file.flush()
file.close()
```

### 確認3: 書き手が複数いないか

複数のGodot実行シーンや診断スクリプトが同じRXファイルへ同時に書き込むと、
値が上書きされる。書き手を1つにする。

## ライントレース中に逸脱・反転する

### 確認1: 固定物理周期

走行体更新が`_process()`ではなく`_physics_process()`にあることを確認する。

可変描画周期では、I/Oなどで`delta`が大きくなったとき、カラーセンサーが
1ステップでラインを横断することがあった。

### 確認2: VDEV交換周期

EV3RTの50 ms周期とVDEV交換を同じ50 msに固定すると、位相によって短い
センサー変化を取りこぼす場合がある。現在は10 msを指定し、実際には固定
物理フレームごとに交換する。

### 確認3: 速度換算

現在値:

```gdscript
const MOTOR_SPEED_SCALE := 1.5
```

power 20で約6 cm/sに相当する。根拠は`physical_model.md`を参照する。
単に動作を安定させるためだけに速度を下げず、実機測定値から再校正する。

## 意図しない場所でP_WAIT_FOR_UNLOADINGになる

### 過去に確認した原因

超音波センサーを前向きとして扱い、配達先壁と車庫壁を1本の無限縦線
`WALL_X`で共用していた。このため実在しない壁を検出した。

### 現在の実装

- 配達先側壁: 幅8 cmの有限線分
- 超音波センサー: 車体右向き
- 車庫正面壁: 幅12 cmの別の有限線分
- バンパー: 車体前方

壁判定を無効化して`P_TRANSPORTING`のまま複数周できるか確認すると、
ライントレースと到着検出を分離して診断できる。

## P_WAIT_FOR_UNLOADINGまたはP_ARRIVEDで停止しない

まず共有ファイルの実出力を確認する。

```bash
python3 scripts/vdev_poke.py \
  read_tx \
  ../ev3rt-athrill-v850e2m/sdk/uml_seminar_ev3/sample04-01-stm/athrill_mmap.bin
```

期待値:

```text
POWER_A(left)=0 POWER_C(right)=0
```

TXが0ならEV3RT側は停止している。Godot側が古い出力を保持していないか、
正しいTXファイルを読んでいるかを確認する。

## LCD状態名が表示されない

### 確認1: パッチ

```bash
./scripts/prepare_ev3rt.sh
```

`0002-emulate-lcd-on-console.patch`が適用済みであることを確認する。

### 確認2: 再ビルド

```bash
./scripts/build_sample04_stm.sh
```

### 確認3: アプリケーション

`porter_transport()`が次を呼んでいることを確認する。

```c
msg_f(p_state_name[p_state], 2);
```

同じ状態名が毎周期表示されないのは正常である。LCDエミュレーション層が
同一行の同一文字列を抑止する。

## Godotの外部テキストエディター警告

### 症状

```text
Couldn't open external text editor, falling back to the internal editor.
```

### 説明

Godotで設定された外部エディターを起動できず、内部エディターへ切り替えた
という警告である。プロジェクトの実行には影響しない。

GodotのEditor Settingsにある外部テキストエディター設定を無効化するか、
実在するエディターの実行パスへ修正する。

## Godotがハングしたように見える

次を順に確認する。

1. 実行シーンだけ終了していないか
2. エディターとは別の実行ウィンドウが前面にないか
3. Athrillがタイムアウト終了していないか
4. Godot実行シーンが複数残っていないか
5. 端末で直接起動したGodotにエラーが出ていないか

プロセス確認:

```bash
pgrep -a -f Godot_v4.7.1
pgrep -a athrill2
```

直接実行してエラーを見る例:

```bash
~/Applications/Godot-4.7.1/Godot_v4.7.1-stable_linux.arm64 \
  --path ~/Projects/ev3rt_godot/ev3rt-athrill-godot/godot \
  --rendering-method gl_compatibility
```

## 診断時に記録する情報

問題を再現したら、次を保存する。

- Athrillの起動コマンド
- Athrillログ
- GodotのDebugger出力
- `pgrep -a -f Godot_v4.7.1`
- `pgrep -a athrill2`
- RXヘッダーと対象センサー値
- TXヘッダーと`POWER_A`、`POWER_C`
- 使用したリポジトリのコミットID
- 使用したGodot、GCC、OSのバージョン

## 関連文書

- [`README.md`](../README.md)
- [`architecture.md`](architecture.md)
- [`vdev_protocol.md`](vdev_protocol.md)
- [`physical_model.md`](physical_model.md)
