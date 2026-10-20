shader_type canvas_item;

// 천공 세트(tower_abyss_set) 전용 무지개 틴트. 아이콘 빌드 스크립트
// (tools/build_item_icons.py 의 Palette.ramp rainbow 분기)와 같은 발상 —
// 세로 위치로 색조가 한 바퀴 돌게 해 캐릭터 위에서도 세트가 알아보이게
// 한다. modulate 로는 픽셀별 색조를 낼 수 없어 셰이더가 필요하다
// (INBOX O 조각 1 요구사항).
// 2026-09-04: 원본 색을 통째로 버리고 Y좌표 색 하나로 덮어써서 얼굴 이목구비,
// 칼날 하이라이트, 칼집/칼날 경계, 외곽선이 같은 줄에서 전부 뭉개지는 버그가
// 있었다("얼굴이 안 보인다", "칼날/칼집이 없어 보인다" 피드백). 명도(V)만 대체하고
// 색상(H)은 완전히 버리는 방식이라 형태 정보가 사라졌던 것 - RGB<->HSV 변환으로
// 원본의 명도(V)/채도(S)는 그대로 두고 색상(H)만 세로 위치만큼 회전시키는 방식으로
// 바꿨다. 이러면 검은 외곽선(V=0)은 계속 검게, 흰 하이라이트(S=0)는 계속 희게 남고
// 눈/마스크/칼날/칼집의 명암 경계가 원본 그대로 보존된다.
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float shift = fract(UV.y * 0.95 + 0.02 + TIME * 0.15);
	hsv.x = fract(hsv.x + shift);
	hsv.y = clamp(hsv.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 color = hsv2rgb(hsv);
	COLOR = vec4(color, tex.a);
}
