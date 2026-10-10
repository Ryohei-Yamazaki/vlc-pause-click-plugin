# Apple Silicon (arm64) macOS 版

[nurupo/vlc-pause-click-plugin](https://github.com/nurupo/vlc-pause-click-plugin)（VLC の映像をクリックすると再生／一時停止できるプラグイン）のフォークです。本家に次の 2 点を追加しています。

1. **Apple Silicon (arm64) ネイティブ版 VLC 3.0.x 用のビルド**
   本家の macOS 版は Intel (x86_64) 用だけなので、arm64 版の VLC では読み込めません。
2. **macOS でダブルクリックしても一時停止しないように改修**
   本家のままだと、macOS ではダブルクリックでフルスクリーンにしたときに一緒に一時停止してしまいます。
   このフォークでは **単クリック = 再生／一時停止、ダブルクリック = フルスクリーン切替のみ** になります。

Windows / Linux の動作は変えていません（変更はすべて `#ifdef __APPLE__` の中です）。

## インストール（ビルド済みバイナリ）

macOS 上の VLC 3.0.18 / 3.0.23 (arm64) で動作確認しています。

1. [Releases](https://github.com/Ryohei-Yamazaki/vlc-pause-click-plugin/releases) から `libpause_click_plugin.dylib` をダウンロードします。
2. 隔離属性を外します（アドホック署名のみで公証していないため）。
   ```sh
   xattr -d com.apple.quarantine ~/Downloads/libpause_click_plugin.dylib
   ```
3. VLC を終了してからコピーします。
   ```sh
   cp ~/Downloads/libpause_click_plugin.dylib /Applications/VLC.app/Contents/MacOS/plugins/
   ```
4. 一度だけプラグインキャッシュをリセットして起動します。
   ```sh
   /Applications/VLC.app/Contents/MacOS/VLC --reset-plugins-cache
   ```
5. VLC の設定で有効にします。
   `環境設定 → 設定の表示: すべて` を開き、次の **2 か所の両方** にチェックを入れて保存し、VLC を再起動します（片方だけだと動きません）。
   - `インターフェース → 制御インターフェース` の **Pause/Play video on mouse click**
   - `ビデオ → フィルター` の **Pause/Play video on mouse click**

## ソースからビルド

Xcode Command Line Tools（`xcode-select --install`）と、`/Applications` にある arm64 版 VLC 3.0.x が必要です。

```sh
macos/build-arm64.sh            # ビルドのみ -> build/dist/libpause_click_plugin.dylib
macos/build-arm64.sh --install  # ビルドして VLC.app にインストール（VLC は終了しておく）
```

インストール済みの VLC のバージョンを自動で検出し、対応するヘッダを download.videolan.org から取得してビルドと署名を行います。VLC を更新したときも再実行すれば作り直せます。

## ダブルクリック対応の仕組み

詳しくは [double-click.ja.md](double-click.ja.md) を参照してください。

| 直前の状態 | 操作 | 結果 |
|---|---|---|
| 再生中 | 単クリック | すぐ一時停止 |
| 再生中 | ダブルクリック | フルスクリーン切替のみ |
| 一時停止中 | ダブルクリック | フルスクリーン切替のみ（一時停止のまま） |
| 一時停止中 | 単クリック | 約 300ms 後に再生 |

ダブルクリックが遅めの人は、`ビデオ → フィルター → Pause/Play...` の **Custom double click interval** を 400〜500 に上げると判定の取りこぼしが減ります。
