# nomachine-gksdud · NoMachine Hangul Bridge

Windows 한영키로 NoMachine 원격 Mac의 입력 소스를 전환하는 작은 도구입니다.
Mac 한영 전환 도구 [gksdud](https://github.com/codingnoye/gksdud)에서 영감을 받았습니다.
독립 프로젝트이며 NoMachine 또는 gksdud의 공식 구성품이 아닙니다.

**0.1.3-alpha · Windows용 · 설치판과 portable에는 AutoHotkey runtime 포함**

설치 파일/런타임 포함 ZIP의 자동 빌드 구성은 [BUILDING.md](BUILDING.md), 실제 검사 결과와 남은 제한은 [VALIDATION.md](VALIDATION.md)에 있습니다.

## 동작

1. 실행 중인 NoMachine 연결 프로세스의 `--session` 경로와 시작 시간을 읽습니다.
2. 해당 PID의 현재 연결 로그에서 서버 OS와 데스크톱 Agent mode가 모두 Mac인지 확인합니다.
3. 해당 연결의 데스크톱 창이 활성화됐을 때만 등록한 한영키를 변환합니다.
4. 누른 뒤 약 30ms 후 Mac의 입력 소스 전환 단축키를 한 번 보냅니다. 키를 길게 눌러도 반복 전환하지 않습니다.

일반 Windows 앱, Windows/Linux 원격 연결, NoMachine 초기 화면, 확인되지 않는 연결은 매핑하지 않습니다.
예약된 전송 전에 다른 창으로 이동하면 전송을 취소합니다. 전역 Scancode Map과 레지스트리 키 매핑을 변경하지 않습니다.

gksdud나 SSH는 필요 없습니다. 이 도구는 Mac 입력기를 직접 변경하지 않고 NoMachine을 통해 키보드 단축키를 보냅니다.

## 시작하기

1. [GitHub Releases](https://github.com/WithClawler/nomachine-gksdud/releases)에서 `windows-x64-setup.exe`를 내려받아 실행합니다. 관리자 권한 없이 현재 사용자에게 설치되며 AutoHotkey를 별도로 설치할 필요가 없습니다. 설치 후 시작 메뉴의 **NoMachine Hangul Bridge**를 실행합니다.
2. 최초 실행에만 **한영키 감지 / 변경**을 누르고 실제 한영키를 누릅니다. 감지한 즉시 저장되며, 창을 닫거나 다시 실행해도 재등록할 필요가 없습니다. VK15를 일괄 가정하지 않고 실제 VK와 스캔 코드를 저장합니다. 매핑에는 측정한 VK를 사용합니다. 키보드를 바꿨다면 같은 버튼으로 다시 등록합니다.
3. Mac의 **시스템 설정 → 키보드 → 키보드 단축키 → 입력 소스**에 설정된 단축키와 도구의 선택을 맞춥니다. 기본값은 `Control+Space`입니다. 도구가 Mac 설정을 자동 변경하지는 않습니다.
4. NoMachine에서 Mac에 연결합니다. 도구의 연결 상태에 `Mac 판별 완료`가 표시되는지 확인합니다.
5. NoMachine에서 한영키를 짧게 누르고 길게 눌러 실제 입력 소스가 각각 한 번 바뀌는지 확인합니다. Windows 앱에서도 기존 한영키 동작을 확인합니다.

설치 없이 쓰려면 `windows-x64-portable.zip`을 계속 사용할 폴더에 풀고 `Start.cmd`를 실행하세요. `runtime/`과 `third-party/`를 포함한 전체 폴더를 유지해야 합니다.
소스 ZIP 또는 Git checkout으로 실행할 때만 [공식 AutoHotkey v2](https://www.autohotkey.com/) 설치가 필요합니다.

현재 배포는 **서명되지 않은 alpha 빌드**입니다. Windows 보안 경고가 표시될 수 있습니다. 다운로드 파일은 같은 릴리스의 `SHA256SUMS.txt`와 `Get-FileHash -Algorithm SHA256 <파일>` 결과로 대조할 수 있습니다.

등록된 키는 `%LOCALAPPDATA%\NoMachineHangulBridge\settings.ini`에서 자동 복원합니다. 앱 폴더 이동이나 업데이트로 설정을 초기화하지 않습니다. 키 변경과 달리 출력 단축키·로그 폴더·자동 시작 옵션 변경은 저장 버튼으로 확정합니다.

기본 로그 폴더는 `%USERPROFILE%\.nx`입니다. NoMachine에서 다른 위치를 사용한다면 설정에서 그 폴더를 지정합니다.
기본 설치 위치가 아닌 AutoHotkey를 사용한다면 `NoMachineHangulBridge.ahk`를 AutoHotkey v2로 직접 실행하세요.

## 업데이트

알림 영역에서 앱을 종료한 뒤 새 설치 파일을 실행합니다. 키 설정은 설치 폴더 밖에 있으므로 다시 등록할 필요가 없습니다.
자동 시작을 이미 선택했다면 설치기가 기존 앱 전용 바로가기를 새 설치 경로로 갱신합니다. 선택하지 않았다면 새로 등록하지 않습니다.
portable은 종료 후 전체 폴더를 새 버전으로 교체하세요. portable 폴더 자체를 옮겼다면 설정에서 자동 시작을 다시 저장해 새 경로를 반영하세요.

0.1.3부터 동일 Windows 세션에서 여러 폴더의 사본을 실행해도 첫 사본만 매핑합니다. 두 번째 사본은 기존 사본을 종료하지 않습니다.
0.1.2 이전 사본에는 이 보호 장치가 없으므로 첫 업데이트 전에 기존 사본을 모두 트레이에서 종료하세요.
실행 중인 0.1.3 이상 사본이 있으면 설치·제거가 종료를 안내하며, 무인 설치는 실패로 반환합니다. 다른 AutoHotkey 프로그램을 일괄 종료하지 않습니다.

## 실행 중인지 확인하기

이 도구는 **로컬 Windows에서 실행**됩니다. 원격 Mac에 이 도구를 실행할 필요는 없습니다.
실행하면 설정 창과 시작 알림을 표시하고, Windows 우측 하단 알림 영역에 **‘한’ 아이콘**을 둡니다.
Windows가 아이콘을 숨겼다면 알림 영역의 **∧(숨겨진 아이콘 표시)** 안에서 찾을 수 있습니다.
아이콘을 두 번 클릭하면 설정 창을 열고, 마우스를 올리면 현재 상태를 보여 줍니다.

| 아이콘 색 | 상태 |
| --- | --- |
| 청록색 | 실행 중이며 Mac 연결을 인식함. 해당 Mac 창에서만 매핑 |
| 파란색 | 실행 중이며 Mac 연결 대기 또는 키 등록 필요. 마우스를 올려 구체적인 상태 확인 |
| 회색 | 프로그램은 실행 중이나 매핑은 일시 중지됨 |
| 아이콘 없음 | 프로그램 실행 여부를 확인하고 `Start.cmd`로 실행. 숨겨진 아이콘 목록도 확인 |

설정 창 상단에도 같은 상태를 표시합니다. 시작 알림은 Windows 알림 설정에 따라 표시되지 않을 수 있으므로 아이콘과 설정 창을 기준으로 확인하세요.
**자동 시작은 기본으로 등록하지 않습니다.** 선택하지 않았다면 PC 재부팅 후 `Start.cmd`로 직접 실행해야 합니다.
자동 실행하려면 설정의 **Windows 로그인 시 실행**을 선택하고 저장하세요.

## 중지와 제거

- 알림 영역 **‘한’ 아이콘** 우클릭 → **일시 중지** 또는 **종료**.
- 설정 창을 닫으면 알림 영역에서 계속 실행됩니다.
- 자동 시작은 기본으로 등록하지 않습니다. 설정에서 `Windows 로그인 시 실행`을 선택하고 저장했을 때만 현재 사용자 시작프로그램에 바로가기를 만듭니다.
- 설치판은 앱을 종료한 뒤 **Windows 설정 → 앱 → 설치된 앱 → NoMachine Hangul Bridge → 제거**를 사용합니다. 해당 설치판의 자동 시작 바로가기도 제거하며 사용자 키 설정은 남깁니다.
- portable은 자동 시작 선택을 해제하고 저장한 뒤 종료하고 압축 해제한 폴더를 삭제합니다.
- 설정도 제거하려면 `%LOCALAPPDATA%\NoMachineHangulBridge`를 삭제합니다.
- 실행을 종료하면 재매핑이 해제됩니다. Mac 단축키는 도구가 변경하지 않습니다.

## Mac 판별의 범위

창 제목에 `Mac`이 있는지 또는 `.nxs`의 `Platform of the last connection` 값만 보고 판단하지 않습니다.
프로세스 시작 시간·연결 파일·실행 중인 세션·서버 OS·Agent mode를 대조하고, PID 재사용에 따른 오래된 로그도 거부합니다.
NoMachine 설정/대화상자를 피하기 위해 연결 파일 이름과 정확히 일치하는 데스크톱 창 제목만 허용합니다.
슬래시 경로로 실행한 NoMachine이 전체 경로를 창 제목에 표시하는 경우에는, 그 실행 명령의 정확한 경로도 허용합니다.

이 판별은 **현재 관측한 NoMachine 로그 형식에 의존하며 공식 OS 판별 API는 아닙니다.**
로그를 읽을 수 없거나, 로그가 과도하게 크거나, 여러 로그가 모호하게 일치하거나, 창 제목 형식이 다르면 전환하지 않습니다.
서버 또는 로그를 악의적으로 조작한 경우까지 보장하는 보안 경계는 아닙니다.
연결 직후에는 판별을 위해 약 1.5초 정도 기다릴 수 있습니다. 30ms는 예약 지연이며 네트워크와 키 전송 시간은 별도입니다.

## 지원과 알려진 제한

- 전달본에서 보고된 실기 환경: G5 KC의 한영키 VK15/SC138, AutoHotkey 2.0.28, NoMachine Windows client 9.6.3 / Mac server 9.10.3, macOS 27.0.1. 이번 변경의 Windows CI 검증과 별개입니다.
- 검증된 출력은 `Control+Space`입니다. `Control+Option+Space`는 설정 선택지를 제공하지만 이 환경에서는 실기 검증하지 않았습니다.
- Mac이 입력 소스 전환을 F19로 설정했다면 기본 출력과 맞지 않습니다. 이번 환경에서는 NoMachine의 F19 전달이 확인되지 않아 첫 버전 출력으로 제공하지 않습니다.
- gksdud 등 다른 앱이 Mac 입력 소스 단축키를 변경하면 도구의 출력과 Mac 설정이 일치하는지 다시 확인하세요.
- 처음부터 한영키가 개별 키 이벤트로 들어오지 않거나 오른쪽 Alt 등 보조키로만 들어오는 키보드는 이 버전의 키 감지 대상으로 지원하지 않습니다.
- 여러 NoMachine 창, 전체 화면, 다른 언어의 창 제목, 다른 NoMachine 버전은 추가 실기 검증이 필요합니다. 인식되지 않으면 기본 동작을 유지합니다.
- 다른 키 매핑 프로그램이 같은 키를 처리하면 충돌할 수 있습니다. 이전 한영키 실험 스크립트를 함께 실행하지 마세요.

## 개인정보

네트워크 연결, 텔레메트리, 입력한 문장 기록을 추가하지 않습니다.
사용자가 등록한 키 코드·출력 단축키·로그 폴더 경로만 사용자 설정 파일에 저장합니다.
NoMachine 연결 로그는 읽기만 하며, 로그에 포함될 수 있는 인증 정보나 원문을 복사·출력하지 않습니다.
프로젝트 배포 파일에는 사용자 설정, SSH 키, 개인 NoMachine 연결 파일을 포함하지 않습니다.

## 개발과 진단

`lib/SessionDetector.ahk`는 세션 판별, `lib/BridgeApp.ahk`는 키 처리와 설정 UI, `NoMachineHangulBridge.ahk`는 실행 진입점을 담당합니다.

```text
AutoHotkey64.exe /ErrorStdOut tests\SessionDetector.Tests.ahk
AutoHotkey64.exe /ErrorStdOut tests\BridgeApp.Tests.ahk
AutoHotkey64.exe /ErrorStdOut tests\Lifecycle.Tests.ahk
AutoHotkey64.exe /ErrorStdOut Diagnose.ahk
```

테스트는 Mac 허용, Windows/Linux 거부, 오래된 로그, PID 재사용, 종료된 세션, 다른 연결과 포커스 변경 등을 검사합니다.
진단 출력에는 PID·OS·판별 결과만 포함하며 호스트명, 연결 파일 경로, 인증 정보는 출력하지 않습니다.
개발용 환경 변수 `NMHB_DEBUG=1`을 명시한 경우에만 사용자 설정 폴더에 누름/뗌/전송 시각의 진단 로그를 기록합니다. 입력한 문장은 기록하지 않습니다. 일반 실행에서는 꺼져 있습니다.
실제 Windows/Linux 서버에 연결한 실기 검증은 별도로 필요합니다.

소스는 MIT 라이선스입니다. 설치판과 portable에는 별도 라이선스의 AutoHotkey runtime을 포함합니다.
`third-party/AutoHotkey/`의 원본 라이선스와 같은 버전 전체 소스 ZIP을 함께 배포하며 제거하지 마세요. [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)에 구성과 출처를 기록했습니다.
