//
//  SystemAction — Lock / Logout / Restart / Shutdown / Sleep
//
//  단일 유니버설 바이너리를 5개 앱 번들이 공유한다.
//  수행할 동작은 각 번들의 Info.plist `SAAction` 키로 결정된다.
//
//  com.siong1987 의 2014년 Intel 전용 5종 세트를 동등 대체하기 위해 작성.
//  원본 동작(역분석):
//    Lock     : NSAppleScript `activate application "ScreenSaverEngine"`
//    Logout   : AppleEvent aevt/rlgo → kSystemProcess
//    Restart  : AppleEvent aevt/rest → kSystemProcess
//    Shutdown : AppleEvent aevt/shut → kSystemProcess
//    Sleep    : AppleEvent aevt/slep → kSystemProcess
//

import Foundation
import CoreServices

// MARK: - FourCharCode

/// "aevt" 같은 4글자 코드를 FourCharCode 로 변환한다.
private func fourCC(_ string: String) -> FourCharCode {
    precondition(string.utf8.count == 4, "FourCharCode 는 정확히 4바이트여야 한다: \(string)")
    return string.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
}

// MARK: - Action

enum Action: String, CaseIterable {
    case lock
    case logout
    case restart
    case shutdown
    case sleep

    /// loginwindow 로 보낼 Apple Event ID. lock 은 Apple Event 를 쓰지 않는다.
    var eventID: FourCharCode? {
        switch self {
        case .lock:     return nil
        case .logout:   return fourCC("rlgo")   // kAEReallyLogOut — 확인 대화상자 없음
        case .restart:  return fourCC("rest")   // kAERestart
        case .shutdown: return fourCC("shut")   // kAEShutDown
        case .sleep:    return fourCC("slep")   // kAESleep
        }
    }

    var describedInKorean: String {
        switch self {
        case .lock:     return "화면 잠금"
        case .logout:   return "로그아웃"
        case .restart:  return "재시동"
        case .shutdown: return "시스템 종료"
        case .sleep:    return "잠자기"
        }
    }
}

// MARK: - Apple Event 전송

/// loginwindow(kSystemProcess) 에 코어 이벤트를 보낸다.
///
/// ProcessSerialNumber 기반 주소 지정은 10.9 에서 deprecated 됐지만 macOS 26 까지 동작하며,
/// 번들 ID 로 지정하는 방식과 달리 자동화(TCC) 권한 프롬프트를 띄우지 않는다.
func sendEventToLoginWindow(_ eventID: FourCharCode) -> OSStatus {
    let kSystemProcessPSN: UInt32 = 1  // Processes.h: kSystemProcess

    var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: kSystemProcessPSN)
    var target = AEAddressDesc()

    var status = OSStatus(AECreateDesc(fourCC("psn "),           // typeProcessSerialNumber
                                      &psn,
                                      MemoryLayout<ProcessSerialNumber>.size,
                                      &target))
    guard status == noErr else { return status }
    defer { AEDisposeDesc(&target) }

    var event = AppleEvent()
    status = OSStatus(AECreateAppleEvent(fourCC("aevt"),         // kCoreEventClass
                                         eventID,
                                         &target,
                                         AEReturnID(kAutoGenerateReturnID),
                                         AETransactionID(kAnyTransactionID),
                                         &event))
    guard status == noErr else { return status }
    defer { AEDisposeDesc(&event) }

    var reply = AppleEvent()
    status = AESendMessage(&event, &reply, AESendMode(kAENormalPriority), kAEDefaultTimeout)
    AEDisposeDesc(&reply)
    return status
}

// MARK: - 화면 잠금

/// 화면을 즉시 잠근다.
///
/// 원본은 스크린세이버를 띄우는 우회책을 썼지만, 그 방식은 "스크린세이버 시작 후 암호 요구"
/// 설정에 의존하고 즉시 잠기지도 않는다. login.framework 의 SACLockScreenImmediate 는
/// 메뉴의 '화면 잠금'과 동일한 경로다.
func lockScreen() -> Bool {
    let loginFramework = "/System/Library/PrivateFrameworks/login.framework/login"

    if let handle = dlopen(loginFramework, RTLD_LAZY) {
        defer { dlclose(handle) }
        if let symbol = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFn = @convention(c) () -> Int32
            let lock = unsafeBitCast(symbol, to: LockFn.self)
            if lock() == 0 { return true }
        }
    }

    // 폴백: 스크린세이버 (원본과 동일한 경로)
    return runTool("/usr/bin/open", ["-a", "ScreenSaverEngine"])
}

// MARK: - 보조

@discardableResult
func runTool(_ path: String, _ arguments: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

func resolveAction() -> (action: Action, dryRun: Bool)? {
    var requested: String? = Bundle.main.object(forInfoDictionaryKey: "SAAction") as? String
    var dryRun = false

    for argument in CommandLine.arguments.dropFirst() {
        switch argument {
        case "--dry-run", "-n":
            dryRun = true
        case let value where value.hasPrefix("--action="):
            requested = String(value.dropFirst("--action=".count))
        case "--help", "-h":
            let names = Action.allCases.map(\.rawValue).joined(separator: "|")
            print("사용법: SystemAction [--action=\(names)] [--dry-run]")
            exit(0)
        default:
            break   // -psn_… 등 LaunchServices 인자는 무시
        }
    }

    guard let name = requested, let action = Action(rawValue: name.lowercased()) else {
        return nil
    }
    return (action, dryRun)
}

// MARK: - main

guard let (action, dryRun) = resolveAction() else {
    FileHandle.standardError.write(Data("""
        오류: 수행할 동작을 결정할 수 없습니다.
        Info.plist 의 SAAction 키 또는 --action= 인자가 필요합니다.
        가능한 값: \(Action.allCases.map(\.rawValue).joined(separator: ", "))\n
        """.utf8))
    exit(EXIT_FAILURE)
}

if dryRun {
    let event = action.eventID.map { id -> String in
        let bytes = [24, 16, 8, 0].map { UInt8((id >> UInt32($0)) & 0xFF) }
        return "aevt/\(String(decoding: bytes, as: UTF8.self))"
    } ?? "login.framework/SACLockScreenImmediate"
    print("[dry-run] \(action.rawValue) (\(action.describedInKorean)) → \(event)")
    exit(EXIT_SUCCESS)
}

switch action {
case .lock:
    guard lockScreen() else {
        FileHandle.standardError.write(Data("화면 잠금 실패\n".utf8))
        exit(EXIT_FAILURE)
    }

case .logout, .restart, .shutdown:
    let status = sendEventToLoginWindow(action.eventID!)
    guard status == noErr else {
        FileHandle.standardError.write(Data("\(action.describedInKorean) 실패 (OSStatus \(status))\n".utf8))
        exit(EXIT_FAILURE)
    }

case .sleep:
    let status = sendEventToLoginWindow(action.eventID!)
    if status != noErr {
        // 폴백: pmset 은 콘솔 사용자에게 root 없이 허용된다.
        guard runTool("/usr/bin/pmset", ["sleepnow"]) else {
            FileHandle.standardError.write(Data("잠자기 실패 (OSStatus \(status))\n".utf8))
            exit(EXIT_FAILURE)
        }
    }
}

exit(EXIT_SUCCESS)
