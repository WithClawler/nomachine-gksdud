# Spec Delta

## Purpose

Windows 사용자가 별도 AutoHotkey 설치 없이 도구를 설치하거나 portable로 실행하도록 하고, 공개 GitHub 배포물의 내용과 검증 범위를 반복해서 확인할 수 있게 한다.

## ADDED Requirements

### Requirement: Build and test on Windows
CI는 push·PR·수동 실행에서 고정된 공식 런타임의 해시를 확인하고 자동 테스트 및 설치 EXE 빌드를 실행해야 한다(SHALL). 설치 수명주기 검사는 비관리자 사용자 토큰으로 수행해야 한다(SHALL).

#### Scenario: Build succeeds
- **WHEN** 소스가 CI 검사에 통과한다
- **THEN** 설치 EXE, runtime 포함 portable ZIP, 소스 ZIP, 각 파일의 SHA256SUMS가 생성된다

#### Scenario: Download or test fails
- **WHEN** 의존성 해시 또는 자동 검사가 실패한다
- **THEN** 성공한 배포물로 게시하지 않는다

### Requirement: Publish auditable release assets
버전과 같은 v 태그 릴리스에는 검증한 모든 배포 파일과 체크섬을 첨부해야 한다(SHALL). 기존 공개 릴리스 파일을 조용히 덮어쓰지 않아야 한다(MUST NOT).

#### Scenario: Matching version tag
- **WHEN** VERSION과 일치하는 태그를 push한다
- **THEN** Windows 빌드 결과와 같은 파일이 해당 릴리스에 첨부된다

### Requirement: Preserve notices and exclude private data
runtime 포함 배포물은 원본 라이선스와 해당 버전 전체 소스 ZIP을 포함해야 한다(MUST). 저장소와 패키지에 사용자 설정·SSH 키·실제 NoMachine 로그·개인 호스트명을 포함해서는 안 된다(MUST NOT).

#### Scenario: Package inspection
- **WHEN** 설치 및 portable 내용과 소스 ZIP을 검사한다
- **THEN** 정해진 파일 목록만 포함하고 runtime 배포물에는 라이선스와 검증된 upstream 소스가 존재한다

### Requirement: Document actual verification and attribution
README와 검증 문서는 실제 실행한 검사, 이전 전달본의 보고, 남은 실기 검증을 구분해야 한다(SHALL). gksdud에서 영감을 받았음을 명시하고 공식 제품이라는 인상을 주어서는 안 된다(MUST NOT).

#### Scenario: Release documentation
- **WHEN** 사용자가 설치법과 검증 기록을 읽는다
- **THEN** 설치 방법, 한 번만 필요한 키 등록, 지원 범위, 코드 서명·실기 검사 한계와 프로젝트 출처를 확인할 수 있다
