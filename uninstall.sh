#!/usr/bin/env bash
#
# このスクリプトは、install.sh によって作成された設定ファイルのシンボリックリンクを削除し、
# バックアップがあれば元の設定ファイル (.bak) を復元します。
#
# 注意:
# - このスクリプトはインストールされたパッケージ (zsh, brew, hugo, etc.) を削除しません。
# - デフォルトシェルは変更しません。元のシェルに戻したい場合は手動で行ってください。
#   (例: chsh -s /bin/bash)
# - install.sh が実行されたユーザーで実行してください。
# - このスクリプトは dotfiles リポジトリのルートディレクトリから実行することを想定していますが、
#   ホームディレクトリ内のファイルを対象とするため、どこから実行しても動作します。
#
# 実行方法:
# 1. このスクリプトに実行権限を付与します: chmod +x uninstall.sh
# 2. スクリプトを実行します: ./uninstall.sh

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

# --- 設定ファイルの復元 ---
log_info "Starting restoration of original configuration files..."
log_warn "This script only restores backed-up files (.bak) and removes symlinks created by install.sh."
log_warn "Installed packages and default shell settings will NOT be changed."

# 復元関数
# 引数1: 現在のパス (シンボリックリンクまたはファイル)
# 引数2: バックアップファイルのパス (.bak)
restore_config() {
  local current_path="$1"
  local backup_path="$2"
  local current_dir=$(dirname "$current_path")

  # 親ディレクトリが存在するか確認 (例: ~/.config/sheldon)
  if [ ! -d "$current_dir" ]; then
      log_info "Directory $current_dir does not exist. Skipping restoration for $current_path."
      return
  fi

  # シンボリックリンクが存在するか確認して削除
  # -L: シンボリックリンクかどうか
  if [ -L "$current_path" ]; then
    log_info "Removing symlink: $current_path"
    rm -f "$current_path"
  elif [ -e "$current_path" ]; then
    # シンボリックリンクではないが、ファイルが存在する場合
    # install.sh は基本的にリンクを作成するので、これは手動で変更された場合など
    log_warn "Found a non-symlink file/directory at $current_path."
    log_warn "This script will not remove it to avoid unintended data loss."
    log_warn "If you want to restore the backup, please remove $current_path manually first."
  else
    # シンボリックリンクも通常のファイルも存在しない場合
    log_info "No file or symlink found at $current_path. Skipping removal."
  fi

  # バックアップファイルが存在し、かつ現在のパスにファイルが存在しない場合に復元
  if [ -f "$backup_path" ]; then
    if [ ! -e "$current_path" ]; then # 復元先にファイルがないことを確認
      log_info "Restoring backup file $backup_path to $current_path..."
      mv "$backup_path" "$current_path"
      log_info "Restored $current_path from backup."
    else
      log_warn "Backup file $backup_path exists, but $current_path already exists (and is not a symlink)."
      log_warn "Skipping restoration to prevent overwriting. Please check manually."
    fi
  else
    log_info "No backup file found at $backup_path. No restoration needed for $current_path."
  fi
}

# 1. .zshrc の復元
ZSHRC_PATH="$HOME/.zshrc"
ZSHRC_BACKUP_PATH="$HOME/.zshrc.bak"
log_info "--- Processing $ZSHRC_PATH ---"
restore_config "$ZSHRC_PATH" "$ZSHRC_BACKUP_PATH"

# 2. Sheldon config (plugins.toml) の復元
SHELDON_CONFIG_FILE="$HOME/.config/sheldon/plugins.toml"
SHELDON_CONFIG_BACKUP_PATH="$HOME/.config/sheldon/plugins.toml.bak"
log_info "--- Processing $SHELDON_CONFIG_FILE ---"
restore_config "$SHELDON_CONFIG_FILE" "$SHELDON_CONFIG_BACKUP_PATH"
# ~/.config/sheldon ディレクトリ自体は、他のファイル (sheldon.lock など) が存在する可能性があるため削除しません。

# 3. Starship config (starship.toml) の復元
STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"
STARSHIP_CONFIG_BACKUP_PATH="$HOME/.config/starship.toml.bak"
log_info "--- Processing $STARSHIP_CONFIG_FILE ---"
restore_config "$STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_BACKUP_PATH"
# ~/.config ディレクトリ自体は削除しません。

echo ""
log_info "-------------------------------------"
log_info "Uninstallation process (restoration) complete."
log_info "Attempted to remove symlinks and restore original config files where backups were found:"
log_info " - Checked $ZSHRC_PATH (backup: $ZSHRC_BACKUP_PATH)"
log_info " - Checked $SHELDON_CONFIG_FILE (backup: $SHELDON_CONFIG_BACKUP_PATH)"
log_info " - Checked $STARSHIP_CONFIG_FILE (backup: $STARSHIP_CONFIG_BACKUP_PATH)"
log_warn "Please review the logs above to see what actions were taken."
log_warn "Remember:"
log_warn " - Installed packages (apt, brew, hugo, uv, fzf, sheldon, starship) were NOT removed."
log_warn " - Default shell was NOT changed back. If you changed it to Zsh using install.sh, you might want to change it back manually (e.g., 'chsh -s /bin/bash')."
log_warn " - Generated files like ~/.fzf.zsh were NOT removed."
log_warn " - The dotfiles repository clone itself was NOT removed."
log_info "-------------------------------------"

exit 0
