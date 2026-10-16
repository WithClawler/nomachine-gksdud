# Spec Delta

## Purpose

사용자가 처음 측정한 한영키와 자동 시작 선택을 설치 위치와 분리해 보존하고, 여러 사본을 실행해도 현재 Mac 연결에서만 누름당 한 번 전환하도록 한다.

## ADDED Requirements

### Requirement: Persist and restore measured keys
앱은 실제 감지한 VK/스캔 코드를 즉시 사용자 설정에 저장하고 재실행·로그인·업데이트 후 복원해야 한다(SHALL). 키보드 변경 시 재등록을 제공하고 최초 값은 가정하지 않아야 한다(MUST).

#### Scenario: Close immediately after learning
- **WHEN** 키 감지가 끝난 뒤 저장 버튼 없이 창을 닫고 앱을 다시 실행한다
- **THEN** 동일 키가 복원되며 새 등록을 요구하지 않는다

#### Scenario: Updated copy uses existing profile
- **WHEN** 다른 앱 폴더 또는 새 버전에서 동일 사용자로 실행한다
- **THEN** 기존 사용자 설정의 키와 출력 단축키를 복원한다

### Requirement: One mapping instance per interactive session
앱은 동일 Windows 세션에서 설치·portable·개발 사본 사이에 하나의 매핑 인스턴스만 허용해야 한다(SHALL). 다른 AutoHotkey 스크립트를 종료해서는 안 된다(MUST NOT).

#### Scenario: Launch another folder
- **WHEN** 한 사본이 실행 중일 때 다른 폴더의 사본을 실행한다
- **THEN** 새 사본은 매핑하지 않고 기존 사본은 계속 동작한다

### Requirement: Preserve focused Mac routing
앱은 현재 PID·시작 시간·연결 경로·서버 OS·Agent mode로 확인된 Mac 창에서만 전환해야 한다(SHALL). 누름 후 30ms 예약과 전송 직전 재검사를 유지하고 길게 누름·키 뗌에 추가 전환하지 않아야 한다(MUST).

#### Scenario: Focus changes during delay
- **WHEN** 예약 전송 전에 다른 창이나 다른 연결로 전환한다
- **THEN** 예약 전송을 취소한다

#### Scenario: Other operating systems and unknown windows
- **WHEN** Windows 앱, Windows/Linux 원격 세션 또는 증거가 모호한 창에서 키를 누른다
- **THEN** 키를 가로채거나 대체 단축키를 보내지 않는다

### Requirement: Explicit startup choice and lifecycle preservation
자동 시작은 사용자 선택으로만 등록해야 한다(MUST). 설치·업데이트는 설정을 보존하고 이미 선택된 앱 전용 바로가기를 새 설치 경로로 갱신해야 한다(SHALL). 제거는 해당 설치를 가리키는 바로가기를 정리하고 설정을 보존해야 한다(SHALL).

#### Scenario: Clean install without startup choice
- **WHEN** 일반 사용자로 처음 설치하고 실행한다
- **THEN** 관리자 권한과 자동 시작 등록 없이 실행된다

#### Scenario: Install after portable opt-in
- **WHEN** 사용자가 portable 사본에서 자동 시작을 선택한 뒤 설치판으로 이동한다
- **THEN** 등록 키를 유지하며 바로가기가 설치판 런타임과 스크립트를 가리킨다

#### Scenario: Uninstall
- **WHEN** 설치판을 제거한다
- **THEN** 사용자 키 설정은 남고 제거된 설치판의 자동 시작 링크는 남지 않는다
