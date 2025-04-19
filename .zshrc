# ~/.zshrc

# ----- 基本設定 -----

# 自動補完の初期化
autoload -Uz compinit
compinit

# 履歴の設定
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt append_history         # 履歴を追記モードに

# シェルオプション
setopt autocd                # 単にディレクトリ名を入力するだけで移動
setopt correct               # コマンドのタイプミスを自動修正
setopt no_beep               # エラー時のビープ音を無効化

# エイリアス設定（お好みで追加）
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# ----- プラグインの読み込み -----

# zsh-autosuggestions (※インストール先のパスに合わせて調整)
if [ -f ${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source ${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# zsh-syntax-highlighting (※インストール先のパスに合わせて調整)
if [ -f ${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source ${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# fzf の初期化（fzf インストール済みの場合）
if [ -f ${HOME}/.fzf.zsh ]; then
  source ${HOME}/.fzf.zsh
fi

# ----- Starship プロンプト -----
# Starship のインストールが必要です (https://starship.rs)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ----- 環境変数の設定 -----
export VISUAL=vim
export EDITOR="$VISUAL"

bindkey -e

bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[O5D' backward-word
bindkey '^[O5C' forward-word

# ----- その他カスタム設定 -----
#
# 必要に応じて他のツールや設定を追加してください

eval "$(sheldon source)"

export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

source <(fzf --zsh)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# ----- 長時間コマンド完了通知 (preexec/precmd フック) -----
notify-send() { wsl-notify-send.exe --category $WSL_DISTRO_NAME "${@}"; }
# コマンド実行前に実行される関数
preexec() {
  __timer=${(%):-%D{%s}}
  # 実行コマンド全体を記録 (必要なら後で整形)
  __command_line="$1"
}

# コマンド実行後にプロンプトが表示される前に実行される関数
precmd() {
  if [[ -n $__timer ]]; then
    local now=${(%):-%D{%s}}
    local elapsed_time=$((now - __timer))
    local notify_threshold=15 # 通知の閾値 (秒)

    if [[ $elapsed_time -ge $notify_threshold ]]; then
      # コマンド名の取得 (最初の単語)
      # preexec で記録したコマンドライン全体から最初の単語を抽出
      local cmd_name="${${(z)__command_line}[1]}"
      # もしコマンド名が空なら、代替テキストを設定
      if [[ -z "$cmd_name" ]]; then
         cmd_name="Unknown"
      fi

      # 通知タイトルと本文を作成
      local notify_title="Complete (${elapsed_time} sec): ${cmd_name}"

      # 定義済みの notify-send 関数で通知を実行
      # タイトルと本文を別々の引数として渡す
      notify-send $notify_title
    fi
  fi
  # 変数をクリア
  unset __timer
  unset __command_line
}