# system-actions

macOS `Lock` / `Logout` / `Restart` / `Shutdown` / `Sleep` 5종 세트의
**Apple Silicon 네이티브(유니버설) 동등 재구현.**

이 repo 루트의 `mac_system_scripts.tar.gz` 에 들어있던 `system/*.app` 5종을 대체합니다.

원본은 `com.siong1987.*` (Teng Siong Ong, 2014)로, `x86_64` 단일 슬라이스만 담고 있어
Rosetta 지원이 종료되는 **macOS 28부터 실행 불가**입니다.
([Apple 지원 102527](https://support.apple.com/ko-kr/102527))
2017년 11월 이후 서명·빌드가 갱신되지 않았고 App Store 경유도 아니라 업데이트 통로가 없습니다.

## 원본 동작 (역분석 결과)

`otool -L` / `nm -u` / `otool -tvV` 로 확인한 원본 구현:

| 앱 | 링크 | 구현 |
|---|---|---|
| Lock | Foundation, AppKit, CoreFoundation | `NSAppleScript` → `activate application "ScreenSaverEngine"` |
| Logout | + CoreServices | AppleEvent `aevt`/`rlgo` → `kSystemProcess` |
| Restart | + CoreServices | AppleEvent `aevt`/`rest` → `kSystemProcess` |
| Shutdown | + CoreServices | AppleEvent `aevt`/`shut` → `kSystemProcess` |
| Sleep | + CoreServices | AppleEvent `aevt`/`slep` → `kSystemProcess` |

4종은 `AECreateDesc` + `AECreateAppleEvent` + `AESendMessage` 로 loginwindow
(`ProcessSerialNumber{0, kSystemProcess}`)에 코어 이벤트를 던지는 얇은 래퍼입니다.

## 이 구현이 달라진 점

- **유니버설 바이너리** (`arm64` + `x86_64`) — Rosetta 불필요.
- **Lock 은 구현을 교체**했습니다. 원본의 스크린세이버 우회책은 "스크린세이버 시작 후 암호 요구"
  설정에 의존하고 즉시 잠기지도 않습니다. 대신 `login.framework` 의
  `SACLockScreenImmediate()` 를 씁니다 — Apple 메뉴의 '화면 잠금'과 동일한 경로입니다.
  실패 시 원본과 같은 `ScreenSaverEngine` 폴백으로 내려갑니다.
  (참고: 원본이 쓸 수 있었던 `CGSession -suspend` 는 macOS 26 에서 이미 삭제됨.)
- **Sleep 에 `pmset sleepnow` 폴백** 추가.
- 나머지 4종은 동일한 4문자 이벤트 코드를 그대로 사용 — **동작이 완전히 동등**합니다.
- **`LSUIElement`** 를 켜서 실행 시 Dock 아이콘이 튀지 않습니다.
- 바이너리 하나를 5개 번들이 공유하고, 동작은 각 `Info.plist` 의 `SAAction` 키로 결정됩니다.

### TCC(자동화 권한) 관련

`ProcessSerialNumber` 기반 주소 지정은 10.9 에서 deprecated 됐지만 macOS 26.6.1 에서
정상 동작하며, 번들 ID 로 지정하는 방식과 달리 **자동화 권한 프롬프트를 띄우지 않습니다.**
파괴적이지 않은 `aevt`/`oapp` 로 전송 경로를 검증했습니다 (`AESendMessage` → `noErr`).

## 빌드

```sh
./build.sh          # → build/{Lock,Sleep,Logout,Restart,Shutdown}.app
```

Xcode 툴체인(`swiftc`, `iconutil`, `sips`)만 필요하고 Xcode 프로젝트는 없습니다.
아이콘은 SF Symbols 에서 `Tools/make-icons.swift` 가 렌더링합니다.

애드혹 서명(`codesign -s -`)이므로 공증되어 있지 않습니다. 로컬 빌드는 quarantine 속성이
붙지 않아 Gatekeeper 경고 없이 실행됩니다. 다른 머신으로 옮길 경우에는
우클릭 → 열기가 한 번 필요합니다.

## 설치

```sh
cp -R build/*.app /Applications/
```

원본을 대체하려면 먼저 기존 5종을 지운 뒤 복사하세요. 번들 ID 가
`local.sysaction.*` 로 달라 충돌하지는 않지만, 같은 이름의 앱이 둘 있으면
Spotlight/Alfred 에서 헷갈립니다.

## 테스트

```sh
build/Shutdown.app/Contents/MacOS/SystemAction --dry-run
# [dry-run] shutdown (시스템 종료) → aevt/shut
```

`--dry-run` 은 이벤트를 실제로 보내지 않고 무엇을 보낼지만 출력합니다.
`--action=<lock|logout|restart|shutdown|sleep>` 으로 번들 밖에서도 지정할 수 있습니다.

## 주의

`Logout` 은 원본과 같이 `kAEReallyLogOut`(`rlgo`)을 보냅니다 — **확인 대화상자가 없습니다.**
`Restart` / `Shutdown` 도 loginwindow 의 표준 경로를 타므로 저장하지 않은 문서가 있으면
각 앱이 물어보지만, 앱 자체는 되묻지 않습니다.
