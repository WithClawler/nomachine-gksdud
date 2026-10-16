# GitHub 빌드와 설치 파일

이 폴더 자체를 GitHub 저장소 루트로 사용합니다. `.github/`, `tools/`, `installer/`가 저장소 바로 아래에 있어야 합니다.

## 자동 빌드

- main/master push, PR, Actions의 수동 실행: 테스트 후 설치 EXE, 런타임 포함 portable ZIP, 소스 ZIP, SHA256SUMS 생성.
- `VERSION`과 같은 `v` 태그 push: 위 파일을 **초안 GitHub Release**에 첨부. 공개 게시 여부는 GitHub에서 검토합니다.
- 예: VERSION이 `0.1.2-alpha`이면 태그는 `v0.1.2-alpha`입니다.
- GitHub Actions의 `Windows packages` → `windows-distribution` 아티팩트에서도 다운로드할 수 있습니다.
- 개인 토큰이나 SSH 키는 필요하지 않습니다. 태그의 릴리스 작업에서만 기본 GITHUB_TOKEN에 contents:write를 부여합니다.

## 로컬 빌드

Windows, PowerShell, Inno Setup 6의 ISCC.exe가 필요합니다. GitHub의 windows-2022 러너에는 Inno Setup이 제공됩니다.

```powershell
./tools/Build.ps1
# 설치 컴파일러 없이 테스트와 ZIP 생성만 검사
./tools/Build.ps1 -SkipInstaller
```

실행 정책이 로컬 스크립트를 차단한다면 시스템 정책을 일괄 변경하지 말고 GitHub Actions에서 빌드하세요.

빌드는 공식 AutoHotkey 2.0.28 런타임과 해당 소스를 다운로드하고 `build-dependencies.json`의 SHA-256과 대조합니다.
테스트를 통과해야 배포 파일을 생성합니다. 설치 EXE와 portable ZIP에는 런타임이 포함되어 사용자에게 별도 AutoHotkey 설치를 요구하지 않습니다.
소스 ZIP에는 다운로드한 런타임, 개인 설정, NoMachine 연결 파일 및 SSH 키가 들어가지 않습니다.
런타임을 포함하는 배포물에는 원본 라이선스와 해당 버전의 전체 소스 ZIP도 동봉합니다.

## 설치와 설정 유지

- 관리자 권한 없이 현재 사용자의 `%LOCALAPPDATA%\Programs\NoMachineHangulBridge`에 설치합니다.
- 앱 설정은 별도의 `%LOCALAPPDATA%\NoMachineHangulBridge\settings.ini`에 유지합니다.
- 한영키는 최초 감지 즉시 저장되며 이후 실행/업데이트 때 재등록하지 않습니다.
- 설치와 제거가 사용자 설정을 덮어쓰거나 삭제하지 않습니다. 완전 초기화는 사용자가 해당 설정 폴더를 직접 삭제합니다.
- 자동 시작은 기본으로 등록하지 않고 앱 설정에서 사용자가 선택합니다.
- 다른 폴더의 개발용/portable 사본은 설치 실행 전에 트레이에서 종료하세요. 다른 사용자의 AutoHotkey 스크립트를 일괄 종료하면 안 됩니다.

## 이번 전달본에서 확인한 범위

앱의 로컬 자동 테스트와 `-SkipInstaller` 경로를 검증합니다. 설치 컴파일러는 이 작업 PC에 설치하지 않습니다.
실제 GitHub Actions 실행, 설치 EXE 컴파일, 설치·업그레이드·제거 실기 검사는 다음 GitHub 환경에서 확인해야 합니다.
설치 EXE 코드 서명은 아직 구성하지 않았습니다. 워크플로는 결과물을 초안 릴리스에만 첨부합니다.

빌드 산출물은 `dist/`, 다운로드/임시 파일은 `build/`에 생성되며 Git에 포함하지 않습니다.
