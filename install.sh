#!/usr/bin/env bash
#
# WSL (Ubuntu/Debian系) 環境初期セットアップおよび Zsh, Starship, Sheldon, fzf, uv, 指定バージョンの Hugo をセットアップし、
# このスクリプトが置かれているディレクトリ (dotfilesリポジトリのルートを想定) の設定ファイルを適用します。
#
# 事前準備:
# 1. このスクリプトを含む dotfiles リポジトリをクローンします。
#    例: git clone https://github.com/forblgac/dotfile.git ~/dotfile
# 2. クローンしたディレクトリに移動します。
#    例: cd ~/dotfile
# 3. このスクリプトに実行権限を付与します: chmod +x install.sh
# 4. スクリプトを実行します: ./install.sh
#
# 注意:
# - 実行には sudo 権限が必要です。
# - スクリプトは冪等性をある程度考慮していますが、予期せぬ問題を避けるため、
#   クリーンな環境での実行を推奨します。
# - 既存の設定ファイル (.zshrc, plugins.toml, starship.toml) がある場合、
#   `.bak` という拡張子をつけてバックアップします。
# - CUDA Toolkit のインストールはこのスクリプトでは行いません。別途インストールしてください。

set -euo pipefail

# --- 色付け用関数 (オプション) ---
Green='\033[0;32m'
Yellow='\033[0;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${Green}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${Yellow}[WARN]${NC} $1"
}

# スクリプトが置かれているディレクトリを取得
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
log_info "Script directory: $SCRIPT_DIR"
log_info "Assuming this directory is the root of the dotfiles repository."

# --- システム初期セットアップ ---
log_info "Performing initial system setup (apt update, upgrade, install essentials)..."
sudo apt update
# upgrade は時間がかかる可能性があるのでコメントアウトも検討。ただし、クリーン環境想定なら実行推奨。
sudo apt upgrade -y
# 基本ツール、ビルドツール、zsh、git、wsl-notify-sendに必要なものをインストール
sudo apt install -y build-essential curl wget git file procps zsh wsl-utils

# --- Homebrewのインストール (Linuxbrew) ---
# Zshrc で Homebrew の設定が使われているためインストールします[16]
if ! command -v brew &> /dev/null; then
  log_info "Installing Homebrew (Linuxbrew)..."
  # Homebrew の公式インストールスクリプトを実行
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # インストール後、現在のシェルで brew コマンドを使えるように設定
  # (.zshrc にも同様の設定がありますが、スクリプト内で brew を使うために必要)
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  log_info "Homebrew installed successfully."
else
  log_info "Homebrew is already installed."
  # 既存のHomebrew環境変数を読み込む
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- Homebrew経由でのツールインストール (Hugoを除く) ---
# fzf, sheldon, uv を brew でインストールします
log_info "Installing tools via Homebrew (fzf, sheldon, uv)..."
brew install fzf sheldon uv

# --- Hugoの特定バージョンインストール ---
# 指定されたバージョン v0.145.0 extended をインストールします
HUGO_VERSION="0.145.0"
HUGO_EXPECTED_VERSION_STRING="hugo v${HUGO_VERSION}" # 確認用の部分文字列
HUGO_DEB_URL="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb"
HUGO_INSTALL_PATH="/usr/local/bin/hugo" # dpkgでインストールされる標準的なパス

# 現在インストールされているHugoのバージョンを確認
CURRENT_HUGO_VERSION=""
if command -v hugo &> /dev/null; then
    CURRENT_HUGO_VERSION=$(hugo version)
fi

# 指定バージョンがインストールされていない場合にインストールを実行
# `+extended` やビルドハッシュまで厳密に比較するのは難しいため、バージョン番号部分文字列で判断
if [[ "$CURRENT_HUGO_VERSION" != *"$HUGO_EXPECTED_VERSION_STRING"* ]]; then
    log_info "Installing Hugo version ${HUGO_VERSION} extended..."
    log_info "Downloading Hugo deb package from $HUGO_DEB_URL"
    wget "$HUGO_DEB_URL" -O /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb

    log_info "Installing Hugo deb package..."
    # 既存のHugoがあれば上書きされる (dpkgの仕様)
    sudo dpkg -i /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb

    log_info "Cleaning up downloaded deb file..."
    rm /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb

    # 依存関係の問題があれば修正
    log_info "Checking for and fixing potential broken dependencies..."
    sudo apt --fix-broken install -y

    # インストールされたか確認 (念のため)
    if command -v hugo &> /dev/null && [[ "$(hugo version)" == *"$HUGO_EXPECTED_VERSION_STRING"* ]]; then
        log_info "Hugo version ${HUGO_VERSION} extended installed successfully."
        hugo version # インストールされたバージョンを表示
    else
        log_warn "Hugo installation might have failed. Please check manually."
        # 必要に応じてエラー処理を追加
    fi
else
    log_info "Hugo version ${HUGO_VERSION} (or compatible) is already installed."
    hugo version # 現在のバージョンを表示
fi

# --- Starshipのインストール ---
# プロンプト表示のための Starship をインストールします[5][9][15][18][20]
if ! command -v starship &> /dev/null; then
  log_info "Installing Starship..."
  # --yes オプションで確認プロンプトをスキップ
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
  log_info "Starship installed successfully."
else
  log_info "Starship is already installed."
fi

# --- 設定ファイルのシンボリックリンク作成 ---
# スクリプトが置かれているディレクトリ内の設定ファイルへのリンクを作成
log_info "Creating symbolic links for configuration files from $SCRIPT_DIR..."

# .zshrc
ZSHRC_PATH="$HOME/.zshrc"
DOTFILES_ZSHRC="$SCRIPT_DIR/.zshrc"
if [ -f "$DOTFILES_ZSHRC" ]; then
    if [ -f "$ZSHRC_PATH" ] && [ ! -L "$ZSHRC_PATH" ]; then
      log_warn "Backing up existing $ZSHRC_PATH to $ZSHRC_PATH.bak"
      mv "$ZSHRC_PATH" "$ZSHRC_PATH.bak"
    elif [ -L "$ZSHRC_PATH" ]; then
      # 既存のシンボリックリンクは上書きするので削除は不要だが、念のためログ表示
      log_info "Replacing existing symlink $ZSHRC_PATH."
      rm -f "$ZSHRC_PATH" # リンク先がおかしくなっている場合に備えて削除
    fi
    ln -snf "$DOTFILES_ZSHRC" "$ZSHRC_PATH" # -n: リンク先のディレクトリが存在する場合にその中ではなくリンク自体を置き換える, -f: 強制上書き
    log_info "$ZSHRC_PATH linked to $DOTFILES_ZSHRC."
else
    log_warn ".zshrc not found in $SCRIPT_DIR. Skipping link."
fi


# Sheldon config (plugins.toml)
# Sheldon は $XDG_CONFIG_HOME/sheldon/plugins.toml または ~/.config/sheldon/plugins.toml を参照します[4][11]
SHELDON_CONFIG_DIR="$HOME/.config/sheldon"
SHELDON_CONFIG_FILE="$SHELDON_CONFIG_DIR/plugins.toml"
DOTFILES_SHELDON_CONFIG="$SCRIPT_DIR/.config/sheldon/plugins.toml"
if [ -f "$DOTFILES_SHELDON_CONFIG" ]; then
    mkdir -p "$SHELDON_CONFIG_DIR"
    if [ -f "$SHELDON_CONFIG_FILE" ] && [ ! -L "$SHELDON_CONFIG_FILE" ]; then
      log_warn "Backing up existing $SHELDON_CONFIG_FILE to $SHELDON_CONFIG_FILE.bak"
      mv "$SHELDON_CONFIG_FILE" "$SHELDON_CONFIG_FILE.bak"
    elif [ -L "$SHELDON_CONFIG_FILE" ]; then
      log_info "Replacing existing symlink $SHELDON_CONFIG_FILE."
      rm -f "$SHELDON_CONFIG_FILE"
    fi
    ln -snf "$DOTFILES_SHELDON_CONFIG" "$SHELDON_CONFIG_FILE"
    log_info "$SHELDON_CONFIG_FILE linked to $DOTFILES_SHELDON_CONFIG."
else
    log_warn "plugins.toml not found in $SCRIPT_DIR/.config/sheldon/. Skipping link."
fi

# Starship config (starship.toml)
# Starship はデフォルトで ~/.config/starship.toml を参照します[12][18]
STARSHIP_CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"
DOTFILES_STARSHIP_CONFIG="$SCRIPT_DIR/.config/starship.toml"
if [ -f "$DOTFILES_STARSHIP_CONFIG" ]; then
  mkdir -p "$STARSHIP_CONFIG_DIR"
  if [ -f "$STARSHIP_CONFIG_FILE" ] && [ ! -L "$STARSHIP_CONFIG_FILE" ]; then
    log_warn "Backing up existing $STARSHIP_CONFIG_FILE to $STARSHIP_CONFIG_FILE.bak"
    mv "$STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_FILE.bak"
  elif [ -L "$STARSHIP_CONFIG_FILE" ]; then
    log_info "Replacing existing symlink $STARSHIP_CONFIG_FILE."
    rm -f "$STARSHIP_CONFIG_FILE"
  fi
  ln -snf "$DOTFILES_STARSHIP_CONFIG" "$STARSHIP_CONFIG_FILE"
  log_info "$STARSHIP_CONFIG_FILE linked to $DOTFILES_STARSHIP_CONFIG."
else
  log_warn "starship.toml not found in $SCRIPT_DIR/.config/. Skipping link."
fi

# --- Sheldonプラグインのインストール ---
# plugins.toml に基づいてプラグインをインストール・ロックします[4][11]
if [ -f "$SHELDON_CONFIG_FILE" ]; then
    log_info "Installing Sheldon plugins (running 'sheldon lock')..."
    # sheldon lock を実行するユーザーで $HOME/.config/sheldon ディレクトリに書き込み権限があることを確認
    # 通常は問題ないはず
    sheldon lock
    log_info "Sheldon plugins processed."
else
    log_warn "Sheldon config file ($SHELDON_CONFIG_FILE) not found or not linked. Skipping 'sheldon lock'."
fi


# --- fzf 追加設定 ---
# .zshrc に source <(fzf --zsh) がありキーバインドと補完は有効化されます[6][13]。
# さらに、 .zshrc は [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh も読み込もうとします。
# Homebrew で fzf をインストールした場合、対応するスクリプトを実行して ~/.fzf.zsh を生成させます。
FZF_INSTALL_SCRIPT="$(brew --prefix)/opt/fzf/install"
FZF_ZSH_CONFIG="$HOME/.fzf.zsh"
if [ -f "$FZF_INSTALL_SCRIPT" ]; then
    # .fzf.zsh が存在しないか、シンボリックリンクでない場合に生成を実行
    if [ ! -e "$FZF_ZSH_CONFIG" ] || [ -L "$FZF_ZSH_CONFIG" ]; then
        log_info "Running fzf install script to generate $FZF_ZSH_CONFIG..."
        # --no-update-rc オプションで .zshrc への自動追記を防ぎます (dotfilesで管理しているため)
        # --all オプションでキーバインドと補完の両方を有効にするスクリプトを生成
        "$FZF_INSTALL_SCRIPT" --all --no-update-rc
        log_info "$FZF_ZSH_CONFIG generated."
    else
        log_info "$FZF_ZSH_CONFIG already exists and is a regular file (not generating)."
    fi
else
    log_warn "fzf install script not found at $FZF_INSTALL_SCRIPT. Cannot generate $FZF_ZSH_CONFIG."
fi

# --- デフォルトシェルをZshに変更 ---
# ログインシェルを Zsh に変更します[1][8][9][16][20]
ZSH_PATH=$(which zsh)
if [ -z "$ZSH_PATH" ]; then
    log_warn "Zsh not found in PATH. Cannot change default shell."
elif [ "$SHELL" != "$ZSH_PATH" ]; then
  log_info "Changing default shell to Zsh ($ZSH_PATH)..."
  # chsh コマンドでデフォルトシェルを変更
  # sudo を使わずに実行 (ユーザー自身のシェルを変更)
  if chsh -s "$ZSH_PATH"; then
      log_info "Default shell changed to Zsh."
      log_warn "Please restart your WSL instance or log out and back in for the change to take full effect."
  else
      log_warn "Failed to change default shell using 'chsh'. You might need to do it manually."
      log_warn "You can try running 'sudo chsh -s \"$ZSH_PATH\" \"$USER\"' manually if needed."
  fi
else
  log_info "Default shell is already Zsh ($SHELL)."
fi

echo ""
log_info "-------------------------------------"
log_info "Setup complete!"
log_info "The following tools and configurations have been set up from $SCRIPT_DIR:"
log_info " - System essentials and Zsh shell"
log_info " - Homebrew (Linuxbrew)"
log_info " - fzf (fuzzy finder)"
log_info " - Sheldon (plugin manager) with plugins defined in dotfiles"
log_info " - Starship (prompt)"
log_info " - Hugo v${HUGO_VERSION} extended (static site generator)"
log_info " - uv (Python package manager)"
log_info " - Dotfiles (.zshrc, sheldon config, starship config) linked"
log_warn "Remember to restart your WSL instance or terminal for all changes to apply (especially the default shell)."
log_info "-------------------------------------"

exit 0
