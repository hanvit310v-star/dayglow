#!/bin/bash
# 캘린더 시작 버튼: 더블클릭하면 서버를 켜고 브라우저로 캘린더를 엽니다.
# 끄려면 이 터미널 창에서 Ctrl+C 를 누르거나 창을 닫으세요.

PORT=5001                                   # 포트 번호를 바꾸려면 여기 숫자를 고치세요
URL="http://localhost:$PORT/index.html"

cd "$(dirname "$0")" || exit 1              # 이 파일이 있는 폴더로 이동

# 이미 켜져 있으면 브라우저만 엽니다
if lsof -i :$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  echo "이미 캘린더 서버가 켜져 있어요. 브라우저를 엽니다."
  open "$URL"
  exit 0
fi

echo "캘린더를 시작합니다: $URL"
echo "끄려면 이 창에서 Ctrl+C 를 누르거나 창을 닫으세요."
echo

(sleep 1; open "$URL") &                    # 1초 뒤 브라우저 열기
python3 -m http.server $PORT --bind 127.0.0.1
