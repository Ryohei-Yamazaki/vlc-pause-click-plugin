# 仕様書: macOS ダブルクリック対応（pause-click-plugin カスタム版）

最終更新: 2026-10-10 / 対象: VLC 3.0.x (Apple Silicon arm64 ネイティブ) / 対象ファイル: `src/pause_click.c`

## 1. 目的

VLC の「クリックで再生／一時停止」プラグイン（[nurupo/vlc-pause-click-plugin](https://github.com/nurupo/vlc-pause-click-plugin)）を macOS で使うと、
**ダブルクリックでフルスクリーンを切り替える際に一緒に一時停止してしまう**問題があった。
これを「**単クリック＝再生／一時停止、ダブルクリック＝フルスクリーン切替のみ（一時停止しない）**」になるよう改修した、その仕様をまとめる。

## 2. 背景: macOS 固有の制約（重要）

実機デバッグログ（`VLC -vv`）で判明した、本改修の前提となる事実:

- macOS 版 VLC の映像出力は **Cocoa (`macosx`) vout**。**ダブルクリックの 2 回目のクリックは OS 側でフルスクリーン化に消費され、ビデオフィルタには届かない**。
- そのためフィルタの mouse コールバックに来るのは、**単クリックでもダブルクリックでも「press 1 回」だけ**。`b_double_click` フラグも、2 つ目の press も**来ない**。
  → **press の時点では単クリックとダブルクリックを区別できない**。
- 本家プラグインのダブルクリック判定（`b_double_click` フラグ／2 連 press のタイマーペアリング）は Windows/Linux 前提であり、**macOS では一切作動しない**。これが「ダブルクリック無視」設定が macOS で効かなかった根本原因。
- 一方、**フルスクリーン状態はプラグインから読める**（`playlist` の `fullscreen` 変数）。実測で「**ダブルクリック時のみ、press 直後（約 300ms 以内）にフルスクリーン状態が変化する**／単クリックでは変化しない」ことを確認。
  → これを**ダブルクリックの事後判定**に利用する。

`t=N`（vout の `VoutDisplayEvent 'mouse button'` のイベント種別）は macOS では `FULLSCREEN`/`WINDOW_STATE` が `#ifdef _WIN32` で除外されるため番号がずれ、**t=6=MOUSE_PRESSED, t=7=MOUSE_RELEASED**（DOUBLE_CLICK=8）となる。

## 3. 動作仕様（macOS, `__APPLE__` ビルド）

設定 `pause-click-ignore-double-click`（既定 **true**）が有効、かつ対象ボタンが**左クリック**のときに以下が適用される。

### 基本アルゴリズム
1. **press（クリック）時**: 直前の再生状態で分岐し、現在のフルスクリーン状態を記録、判定タイマー（既定 300ms）を開始する。
   - **再生中だった場合** → 即座に `pause_play()` で一時停止（キビキビ）。「press で操作済み」フラグを立てる。
   - **一時停止中だった場合** → **何もしない**（即時トグルしない）。「press で操作済み」フラグは下ろす。
2. **タイマー満了時**: フルスクリーン状態が press 時から**変化したか**で単／ダブルを判定し、press 時の操作と突き合わせて整合をとる。

### 4 ケースの確定動作

| 直前状態 | 操作 | press 時の挙動 | タイマー満了時 | 最終結果 |
|---|---|---|---|---|
| 再生中 | 単クリック | 即一時停止 | FS変化なし→何もしない | **即・一時停止**（遅延なし） |
| 再生中 | ダブルクリック | 即一時停止 | FS変化あり→`pause_play()`で再生に戻す | **フルスクリーン切替のみ**（停止blipはアニメ中で不可視） |
| 一時停止中 | ダブルクリック | 何もしない | FS変化あり→何もしない | **フルスクリーン切替のみ・再生blipなし** |
| 一時停止中 | 単クリック | 何もしない | FS変化なし→`pause_play()`で再生 | **再生**（約300ms後・blipなし） |

### 設計の肝（なぜ状態で分岐するか）
- press 時点で単／ダブルを判別できない以上、「とりあえずトグル → ダブルなら打ち消し」方式が基本。
- ただし**一時停止中**にこれをやると、ダブルクリックで「一瞬再生（動きが見える）→停止」という**目立つ再生blip**が出る。
- **再生中**の打ち消しは「一瞬停止→再生」で、フルスクリーンアニメ中のため気付かれない。
- よって**再生中は即時トグル（スナッピー優先）、一時停止中は遅延（blip回避優先）**という非対称設計とした。

### トレードオフ
- **一時停止中の単クリック→再生のみ**、約 300ms 遅延する（再生中の一時停止は即時）。再生blipよりはるかに自然との判断。
- ダブルクリック判定の待ち時間 = `Custom double click interval`（既定 300ms、設定で変更可）。**長くしても単クリックの一時停止遅延には影響しない**（打ち消し判定の窓が伸びるだけ）。マウスのダブルクリック速度が遅い環境では 400〜500ms に上げると取りこぼしが減る。

## 4. 設定（VLC 詳細設定: すべて → ビデオ → フィルター → Pause/Play...）

| 設定キー | 既定（本改修後） | 説明 |
|---|---|---|
| `pause-click-ignore-double-click` | **true**（macOS のみ。Windows/Linux は本家どおり false） | true: 上記 macOS ロジック有効。false: 全クリックで素直に再生/一時停止（ダブルでも停止する従来挙動）＝エスケープハッチ |
| `pause-click-double-click-delay` | 300 (ms) | ダブルクリック事後判定の待ち時間 |
| `pause-click-mouse-button` | 1 (Left) | 再生/一時停止のボタン |

## 5. 実装メモ

- 追加要素: `get_fullscreen()`（playlist の `fullscreen` 変数を読む）、`is_playing()`（再生状態 1/0/-1）、`atomic_int fs_at_click`（press時FS状態）、`atomic_int toggled_on_click`（press で操作したか）。判定ロジックは `mouse()` の `#ifdef __APPLE__` 分岐と `timer_callback()` の `#ifdef __APPLE__` 分岐。
- **非 Apple プラットフォーム（Windows/Linux）は本家ロジックを完全維持**（`#else` 側）。本改修は macOS 専用。
- DVD メニュー中は `pause_play()` が `is_in_menu()` で抑止されるため安全。
- スレッド: `mouse()` は vout スレッド、`timer_callback()` はタイマースレッドで動くため、共有状態は atomic で受け渡し。

## 6. ビルド／インストール

```sh
macos/build-arm64.sh            # build/dist/ にビルドのみ
macos/build-arm64.sh --install  # ビルドして VLC.app にインストール（VLC は終了しておくこと）
```
インストール先: `/Applications/VLC.app/Contents/MacOS/plugins/libpause_click_plugin.dylib`（arm64・アドホック署名）。
反映されない場合は一度だけ `VLC --reset-plugins-cache` で起動。

## 7. デバッグ手順（再調査が必要になった場合）

```sh
# タイムスタンプ付き・autoflush で全ログ採取（バッファ滞留を回避）
/Applications/VLC.app/Contents/MacOS/VLC -vv 2>&1 \
  | perl -ne 'BEGIN{$|=1} use Time::HiRes; printf "%.3f %s", Time::HiRes::time(), $_' > vlc.log
# 注目ログ: "PRESSED" / "click: playing=.. toggled_on_press=.." / "double click (fs ..)" / "single click (deferred)"
```
