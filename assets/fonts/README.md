# 폰트

`NotoSansKR-Game.ttf` 는 Google Noto Sans KR(OFL 1.1)에서 필요한 영역만 남긴 것이다.
원본은 가변 폰트 10MB라 그대로 넣기엔 크다.

남긴 유니코드 영역: ASCII, 라틴 보충, 일반 구두점, 화살표, 괘선, 도형,
CJK 기호, 한글 음절 전체(U+AC00-D7A3), 한글 자모, 반각·전각.

macOS 는 시스템 폰트로 한글이 나오지만 **웹과 안드로이드에는 한글 폰트가 없어
글자가 전부 두부 박스로 나온다.** 그래서 폰트를 프로젝트에 넣고
`project.godot` 의 `gui/theme/custom_font` 로 기본 폰트를 지정한다.

라이선스 전문은 `OFL.txt`.

## 다시 만드는 법

```sh
curl -L -o /tmp/noto.ttf "https://github.com/google/fonts/raw/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf"
python3 -m fontTools.subset /tmp/noto.ttf \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-21FF,U+2500-257F,U+25A0-25FF,U+3000-303F,U+AC00-D7A3,U+1100-11FF,U+3130-318F,U+FF00-FFEF" \
  --output-file=assets/fonts/NotoSansKR-Game.ttf --layout-features='*' --drop-tables+=DSIG --no-hinting
```
