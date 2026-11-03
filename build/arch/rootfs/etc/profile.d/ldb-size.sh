# The browser terminal talks over a serial line, which has no window size.
# Ask the terminal for its size (cursor position report) before each prompt.
if [ "$(tty 2>/dev/null)" = /dev/ttyS0 ] && [ -n "$BASH_VERSION" ]; then
  __ldb_size() {
    local IFS='[;' _e r c
    printf '\e7\e[999;999H\e[6n\e8' > /dev/tty
    if read -rs -t 0.4 -d R _e r c < /dev/tty && [ -n "$c" ]; then
      stty rows "$r" cols "$c" 2>/dev/null
    fi
  }
  __ldb_size
  case "$PROMPT_COMMAND" in *__ldb_size*) ;; *) PROMPT_COMMAND="__ldb_size${PROMPT_COMMAND:+; $PROMPT_COMMAND}";; esac
fi
