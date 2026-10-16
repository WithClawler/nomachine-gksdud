# Windows 빌드와 배포

공개 저장소는 [doctor-clawler/nomachine-gksdud](https://github.com/doctor-clawler/nomachine-gksdud)입니다.
전달된 `nomachine-hangul-bridge` 폴더 자체가 저장소 루트이며 `.github/`, `tools/`, `installer/`가 바로 아래에 있습니다.

## GitHub Actions

- main/master push, PR, 수동 실행: AHK·프로세스 검사, 설치 EXE·portable·소스 ZIP·SHA256SUMS 생성, 비관리자 설치 검사.
- `VERSION`과 같은 `v` 태그 push: 검사를 통과한 네 파일을 **초안 Release**에 첨부합니다. 이미 공개된 릴리스 파일은 덮어쓰지 않습니다.
- alpha 태그는 prerelease로 표시합니다. 첨부 파일과 체크섬 확인 후 초안을 공개합니다.
- 일반 빌드 결과는 `Windows packages` 실행의 `windows-distribution` 아티팩트에서 내려받습니다.
- 태그 릴리스 작업만 기본 `GITHUB_TOKEN`의 `contents:write`를 사용합니다. 앱에는 GitHub 토큰이나 SSH 자격 증명이 필요 없습니다.

Action 버전은 commit SHA로 고정했습니다. AutoHotkey 런타임과 원본 소스는 `build-dependencies.json`의 공식 URL·버전·SHA256을 사용합니다.
Inno Setup은 `windows-2022` runner에 제공되는 6.x를 사용하며 정확한 컴파일러 버전은 각 빌드 로그에 남습니다.

## 로컬 빌드

Windows x64, PowerShell, Inno Setup 6의 `ISCC.exe`가 필요합니다.

```powershell
./tools/Build.ps1
# 설치 EXE 없이 테스트와 ZIP만 생성
./tools/Build.ps1 -SkipInstaller
# 설치 컴파일러를 다른 위치에 설치했다면
./tools/Build.ps1 -IsccPath 'C:\BuildTools\Inno Setup 6\ISCC.exe'
```

실행 정책이 스크립트를 막으면 시스템 정책을 일괄 변경하지 말고 GitHub Actions를 이용하세요.
`build/`는 다운로드·임시 파일, `dist/`는 결과물이며 Git에 포함하지 않습니다.
이 도구의 기존 배포 파일은 다시 빌드할 때 교체합니다. 예상하지 못한 파일이 `dist/`에 있으면 패키지 검사가 실패합니다.

## 검사 구성

1. `BridgeApp.Tests.ahk`: 즉시 저장, 새 인스턴스 복원, 설정 UI 생성, 핫키 등록/해제, 아이콘 로딩.
2. `SessionDetector.Tests.ahk`: 현재 Mac 증거, Windows/Linux·오래된 로그·다른 연결·대화상자 거부, 같은 로그의 재연결 식별.
3. `Lifecycle.Tests.ahk`: 실제 타이머와 누름/뗌 처리, 가짜 대상·출력 관찰기로 지연/중복/포커스 취소 검사. 실제 원격 전환 검사가 아닙니다.
4. `Process.Tests.ps1`: 별도 AHK 프로세스의 즉시 저장·종료·복원, 다른 폴더의 실제 앱 중복 실행 거부, 기존 사본 종료 후 새 사본 실행, 무관한 AHK 보존.
5. `Test-Packages.ps1`: 정확한 ZIP 파일 목록, 패키지 내 소스 내용, upstream 소스 해시, 라이선스, 배포 파일 해시.
6. `Test-Install.ps1`: 일회용 GitHub runner에 일반 사용자 계정을 만들고 비관리자 토큰을 검사합니다. 원본 0.1.2 설치기를 빌드해 신규 설치 → 새 버전 업데이트 → 실행 중 업데이트/제거 거부 → 경로 이동 → 시작 명령 실행 → 제거 → 재설치를 검사합니다. 새 계정의 shell 폴더를 준비하며 일반 개발 PC에서는 계정 생성 경로를 실행하지 않습니다.

설치 검사는 전체 git 이력이 있는 checkout과 원본 커밋 `19b98f7266bc95709f257a4232afac5a54d0b261`을 사용합니다.
소스 ZIP만으로도 일반 `Build.ps1`은 실행할 수 있습니다. CI 전용 설치 검사에는 git 이력이 필요합니다.
CI는 실제 로그인/재부팅 대신 동일 시작프로그램 명령을 실행합니다. 물리 한영키, 원격 Mac 입력 소스, 실제 Windows/Linux 서버는 별도 실기 검증입니다.

## 패키징과 개인정보

`distribution-files.json`에 적힌 파일만 소스/portable 패키지로 복사합니다. 설치기는 검사한 portable staging을 그대로 사용합니다.
설정, NoMachine 로그와 `.nxs`, SSH 키, 개발 기록은 포함하지 않습니다.
설치판과 portable에는 다음을 함께 넣습니다.

- 수정하지 않은 공식 `runtime/AutoHotkey64.exe`
- `third-party/AutoHotkey/license.txt`
- 해당 버전의 전체 upstream 소스 ZIP

소스 ZIP에는 runtime이 없습니다. 프로젝트는 MIT, AutoHotkey는 별도 라이선스입니다. 재배포 시 라이선스와 소스 ZIP을 유지하세요.

## 설치 수명주기

현재 사용자 `%LOCALAPPDATA%\Programs\NoMachineHangulBridge`에 관리자 권한 없이 설치합니다.
`%LOCALAPPDATA%\NoMachineHangulBridge\settings.ini`는 설치·업데이트·제거 대상에 포함하지 않습니다.
자동 시작은 앱에서 명시적으로 선택한 경우만 등록합니다. 설치 후에는 이미 존재하는 앱 전용 링크만 새 설치 경로로 갱신합니다.
제거는 자신을 가리키는 링크만 삭제합니다. 실행 중 앱은 mutex로 감지하며 다른 AutoHotkey 프로세스를 일괄 종료하지 않습니다.

코드 서명은 구성하지 않았습니다. 실제 실행 결과와 남은 실기 범위는 [VALIDATION.md](VALIDATION.md)를 확인하세요.
