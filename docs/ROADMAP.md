# 🗺️ 로드맵

| Phase | 이름 | 내용 | 완료 기준 |
| :---: | :--- | :--- | :--- |
| **0** | 설계 ✅ | 아키텍처, UI/UX 가이드, 목업, 프로젝트 골격 | 이 문서들 |
| **1** | MVP – 말하기 ✅ | 투명 오버레이 + 입력 바 + 번역/한글 발음 결과 카드, API 키 저장, 단축키, 트레이 | 게임 위에서 입력 → 번역이 1초 내 표시, 포커스 복귀 |
| **2** | 듣기 ✅ | Process Loopback 캡처, Silero/스펙트럼 VAD, Gemini 오디오 번역, 자막 스택, 레이트 리미터, 사용량 미터 | 영어 음성 → 2초 내 한국어 자막, 무음 시 요청 0 |
| **3** | 보내기 ✅ | edge-tts → VB-Cable 출력, 모니터링, 빠른 문구, 마이크 믹서 + 덕킹 | 버튼 → 상대방에게 음성 송출 |
| **4** | 다듬기 ✅ | 설정 창 전체, 온보딩 탭, Local 모드(faster-whisper), 히스토리 창, 용어집, 예산 가드 | 처음 쓰는 사람도 5분 안에 세팅 |
| **5** | 배포 | PyInstaller/Nuitka 단일 exe, 자동 업데이트 확인, (선택) OAuth 로그인 | GitHub Releases에 설치 파일 |

## Phase 1–4 구현 체크리스트

- [x] `pyproject.toml` 의존성 확정 (PySide6, qasync, google-genai, keyring, proc-tap, miniaudio 등)
- [x] `platform/window.py` – 클릭 통과 / NOACTIVATE 창 스타일
- [x] `platform/hotkeys.py` – `RegisterHotKey` 기반 전역 단축키
- [x] `ui/qml/Theme.qml` – Material 3 다크 디자인 토큰
- [x] `ui/qml/InputBar.qml`, `CaptionOverlay.qml`, `StatusPill.qml`, `HistoryWindow.qml`, `SettingsWindow.qml`
- [x] `ai/gemini_client.py` – `interpret_audio()`, `translate_text()`, `translate_outgoing()` 구조화 출력
- [x] `audio/capture.py`, `vad.py`, `output.py`, `tts/*`, `ai/usage.py` – 캡처·VAD·TTS 폴백·가상 마이크·SQLite 사용량
- [ ] 실제 Roblox 창 + VB-Cable 환경에서 엔드투엔드 수동 UX 검증
