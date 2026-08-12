# EV3RT + Athrill + Godot

EV3RTアプリケーションをAthrill上で実行し、Godotの走行体シミュレータと
VDEV MMAPでセンサー値・モーター値を交換するための統合プロジェクト。

制御ロジックと状態機械はEV3RT/Athrill上のCコードで実行する。
Godotは走行体、コース、壁、センサー、VDEVアダプターを担当するため、
実機とシミュレータで同じEV3RTアプリケーションコードを使用できる。

## 現在の到達点

Ubuntu 24.04 ARM64上で以下を確認済み。

- Athrill v850e2mターゲットをARM64ネイティブビルド
- GNUV850 v14.01（GCC 4.9.2）をARM64ホスト向けにビルド
- EV3RT sample03によるVDEV MMAP双方向通信
- EV3RT sample04-01-stmの荷物運搬ステートマシン
- Godot 4.7.1 ARM64版による差動二輪走行モデル
- 実寸を基準にした車体、車輪、カラーセンサー、コースの配置
- カラーセンサーによる角丸矩形コースのライントレース
- 右向き超音波センサーによる配達先側壁の検出
- 前方バンパーによる車庫正面壁の検出
- EV3 LCD文字列のAthrillコンソール出力
- 上面写真を使った走行体表示

荷物運搬シーケンスでは次の状態遷移を確認済み。

```text
P_INIT
P_WAIT_FOR_LOADING
P_TRANSPORTING
P_WAIT_FOR_UNLOADING
P_RETURNING
P_ARRIVED
```

配達先と車庫では、いずれも次の停止出力を確認した。

```text
POWER_A(left)=0
POWER_C(right)=0
```

sample03による反射値とモーター出力の基本確認結果は次のとおり。

```text
REFLECT=5  -> POWER_A=0,  POWER_C=20
REFLECT=50 -> POWER_A=20, POWER_C=0
```

## 依存リポジトリと固定コミット

- `athrill-target-v850e2m`
  - `dff01d79d13a4625dab6c86e82710e7eaebed4ef`
- `ev3rt-athrill-v850e2m`
  - `eaa870b4e68413649d50e1b6d09d832b7de3af78`
- `athrill-gcc-v850e2m`
  - `181a8e08fbbe452311c577057078fe7cc5a6a678`
- `ev3rt-athrill-mujoco`（VDEV資料の出典）
  - `ff15e101917ed44ed72ee45d78b5d1068b542e17`

既定では、このリポジトリと依存リポジトリを同じ親ディレクトリに配置する。

```text
ev3rt_godot/
├── ev3rt-athrill-godot/
├── athrill-target-v850e2m/
├── ev3rt-athrill-v850e2m/
├── athrill-gcc-v850e2m/
└── ev3rt-athrill-mujoco/
```

別の配置を使う場合は`EV3RT_GODOT_DEPS_DIR`で依存リポジトリの親を指定する。

## このリポジトリのディレクトリ

- `patches/`
  - AthrillのARM64対応、EV3RTのRuby 3対応、LCDコンソール出力用パッチ
- `toolchain/`
  - Ubuntu ARM64用GNUV850 v14.01ビルドスクリプト
- `workspace/sample03/`
  - VDEV双方向通信の基本確認用EV3RTアプリケーション
- `uml_seminar_ev3/sample04-01-stm/`
  - 荷物運搬ステートマシンのEV3RTアプリケーション
- `uml_seminar_ev3/util/`
  - 演習用タイマー、LCD表示、ホーンのユーティリティ
- `godot/`
  - Godot側の走行体、コース、センサー、VDEVアダプター
- `docs/`
  - VDEV仕様、物理モデル、コース資料
- `scripts/`
  - パッチ準備、ビルド、起動、VDEV確認スクリプト

## GNUV850ツールチェーンの構築

Ubuntu 24.04 ARM64上で、GNUV850 v14.01（GCC 4.9.2）を
クリーン状態から構築できることを確認済み。

```bash
./toolchain/build_gcc_rh850_arm64.sh
```

スクリプトはTOPPERSのv1.1リリースから改修済みBinutils 2.24を取得し、
GCC 4.9.2とNewlib 2.1.0をC言語用に構築する。生成先は次のとおり。

```text
toolchain/work/install/v850-elf-gcc-linux-arm64
```

Parallelsの2コアARM64 VMでの初回構築時間は約22分。
`toolchain/work/`はGit管理対象外である。

## Athrillのビルド

```bash
./scripts/build_athrill.sh
```

このスクリプトはARM64でEOFを正しく検出するため、Athrillコアの
`file_getline()`で`fgetc()`の戻り値を`int`として保持するパッチを適用する。

EV3RT公式手順に基づき`timer32=true`および`etrobo_optimize=true`を
有効にする。MMAP VDEVを使うため`vdev_disable=true`は指定しない。

## sample03のビルドと起動

```bash
./scripts/build_sample03.sh
./scripts/run_sample03.sh
```

生成された`asp`は依存リポジトリ側の
`sdk/workspace/sample03/asp`へ配置される。

既定のタイムアウトクロックは`3000000000`。変更例:

```bash
ATHRILL_TIMEOUT_CLOCKS=60000000000 \
  ./scripts/run_sample03.sh
```

Athrillはタイムアウト終了時にも終了コード`1`を返す。

## 荷物運搬ステートマシン

`uml_seminar_ev3/`は、EV3RT SDK内で標準の`workspace/`と並べて使う
別ワークスペースである。`sample04-01-stm`は次のセンサーを使用する。

| ポート | センサー | 用途 |
|---|---|---|
| 1 | タッチセンサー | 前方バンパーによる車庫正面壁の検出 |
| 2 | タッチセンサー | 左側荷台の荷物搭載確認 |
| 3 | カラーセンサー | ライントレース |
| 4 | 超音波センサー | 右側の配達先側壁の検出 |

元の演習ソースでは初期状態`P_INIT`の処理が欠落していたため、移植版では
`porter_init()`を実行して`P_WAIT_FOR_LOADING`へ遷移する処理を追加している。

ビルド:

```bash
./scripts/build_sample04_stm.sh
```

起動:

```bash
ATHRILL_TIMEOUT_CLOCKS=60000000000 \
  ./scripts/run_sample04_stm.sh
```

起動した端末はAthrillの実行中に占有される。停止するときは、その端末で
`Ctrl+C`を押す。別の端末から停止する場合は次を使う。

```bash
pkill -TERM -x athrill2
```

停止確認:

```bash
pgrep -a athrill2
echo "athrill_pgrep_exit=$?"
```

`athrill_pgrep_exit=1`なら停止している。

## Godotの起動

正しいプロジェクトは、このリポジトリ内の`godot/`である。

```bash
~/Applications/Godot-4.7.1/Godot_v4.7.1-stable_linux.arm64 \
  --editor \
  --path ~/Projects/ev3rt_godot/ev3rt-athrill-godot/godot \
  --rendering-method gl_compatibility
```

古い`auto-transporter-godot`プロジェクトを開くと、現在の画像やスクリプトを
参照できないので注意する。

既定では、VDEVファイルを次の場所から読み書きする。

```text
../ev3rt-athrill-v850e2m/sdk/uml_seminar_ev3/sample04-01-stm
```

別の場所を使用する場合は、Godot起動前に`EV3RT_VDEV_DIR`を設定する。

## Godotの操作

| 操作 | 動作 |
|---|---|
| `L` | 荷物の積載・荷下ろしを切り替える |
| `Space` | Godot側の車体位置と姿勢だけを初期位置へ戻す |

完全に最初から繰り返す場合は、Godotの位置を戻すだけでなく、Athrillを
停止して再起動する。`Space`はEV3RTカーネル、アプリ状態、タイマーを
リセットしない。

完全動作の操作順は次のとおり。

1. Athrillを起動する。
2. Godotのプロジェクトを実行する。
3. 実行画面をクリックしてキーボードフォーカスを与える。
4. `L`を押して荷物を積載する。
5. 配達先側壁を検出して停止するまで待つ。
6. `L`を押して荷物を下ろす。
7. 回送後、車庫正面壁を検出して停止することを確認する。

## EV3 LCDのコンソールエミュレーション

実機とシミュレータで同じアプリケーションコードを使用できるように、
EV3RTアプリは通常どおり`ev3_lcd_draw_string()`を呼び出す。

Athrill向けEV3APIではLCD文字列をAthrillの標準出力へ転送する。
LCDの行ごとに直前の文字列を保持し、内容が変化した場合だけ出力するため、
50ms周期で同じ状態を表示してもログが増え続けない。

`sample04-01-stm`は現在状態を状態名で表示する。

```text
P_INIT
P_WAIT_FOR_LOADING
P_TRANSPORTING
P_WAIT_FOR_UNLOADING
P_RETURNING
P_ARRIVED
```

この変更は次のパッチとして管理する。

```text
patches/ev3rt-athrill-v850e2m/0002-emulate-lcd-on-console.patch
```

`build_sample03.sh`と`build_sample04_stm.sh`はビルド前に
`prepare_ev3rt.sh`を呼び出し、EV3RT用パッチを未適用の場合だけ適用する。

## 実時間同期

MMAP用設定では次を有効化している。

```text
DEBUG_FUNC_ENABLE_SKIP_CLOCK 1
DEBUG_FUNC_ENABLE_SYNC_TIME  1
```

2コアのParallels VMでは、Athrillを`taskset -c 1`と`nice -n 15`で
起動すると安定する。起動スクリプトがこの設定を行う。

Godot側の`unity_simtime`を使った正式なシミュレーション時間同期は未実装。

## GodotとVDEV MMAP

Godotは次の値をVDEV RXへ書き込む。

- ライン上・ライン外の反射値
- 配達先側壁までの超音波距離
- 前方バンパーのON/OFF
- 荷台の荷物搭載状態

Athrillからは左右モーターのpower値をVDEV TX経由で読み取る。

Godotで`unity_mmap.bin`を更新した後は、Athrillの共有マッピングへ確実に
反映させるため`FileAccess.flush()`を呼び出す。

走行体は描画周期に依存する`_process()`ではなく、固定時間刻みの
`_physics_process()`で更新する。VDEV交換は物理フレームごとに行う。

Godotエディターを強制終了した場合、実行シーンだけが孤児プロセスとして
残る場合がある。異常時は次で確認する。

```bash
pgrep -a -f Godot_v4.7.1
```

## 物理モデルとコース

走行体・モーター・センサー・コース・壁の寸法と、速度換算の根拠は
[`docs/physical_model.md`](docs/physical_model.md)に記載している。

関連資料:

- [`docs/a1_course_layout.png`](docs/a1_course_layout.png)
- [`docs/a1_course_layout.pdf`](docs/a1_course_layout.pdf)
- [`docs/a1_course_layout.pptx`](docs/a1_course_layout.pptx)
- [`docs/sample04_stm_behavior.png`](docs/sample04_stm_behavior.png)
- [`docs/vdev_protocol.md`](docs/vdev_protocol.md)

## 制御コードの方針

最終的な制御・状態機械は自動生成したCコードとしてEV3RT/Athrill上で動かす。
GodotのGDScriptは、走行体、ワールド、センサー表現、VDEVアダプターのみを
担当する。シミュレーションを成立させるためにC側の制御ロジックを変更しない。

## 既知の制約と今後の作業

- power値と実機速度の対応を実機走行距離から再校正する
- 超音波センサー検出面と前方バンパー先端の位置を再測定する
- カラーセンサーの点判定を実際の検出領域へ拡張する
- 加減速、慣性、タイヤの滑りを走行モデルへ追加する
- Godot画面へ操作説明と状態・センサー表示を整理して配置する
- 必要に応じてEV3RT状態をVDEV経由でGodotへ表示する
- Athrillを含む完全リセット手順を将来ランチャーへ統合する
- BlenderモデルをglTF/GLBへ変換し、3D表示モデルとして取り込む
- Ubuntu x86_64環境で構築・実行を検証する
- 完全な荷物運搬シーケンスの自動回帰試験を追加する
