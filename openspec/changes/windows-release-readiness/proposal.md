# Proposal

## Why

0.1.2-alpha에는 즉시 키 저장과 Mac 연결 판별이 있지만 폴더가 다른 사본의 중복 실행, 설치 경로 변경 시 자동 시작 복구, 실제 Windows 설치 검증이 남아 있다. 기존에 확인한 지연 전송을 보존하면서 공개 배포와 반복 가능한 검증을 완성한다.

## What Changes

- 동일 Windows 세션에서 폴더와 버전에 관계없이 한 사본만 매핑한다.
- 측정 키의 즉시 저장·재실행 복원, 명시적으로 선택한 자동 시작의 설치 경로 갱신을 검사한다.
- 30ms 지연, 누름당 한 번 전송, 포커스·현재 Mac 로그 재검사를 회귀 검사한다.
- 실제 Windows CI에서 테스트, 사용자별 설치·업데이트·제거, 배포물 내용·해시를 검증한다.
- 공개 저장소와 태그 릴리스에 설치 EXE, portable ZIP, 소스 ZIP, SHA256SUMS를 제공하고 실기 검증 범위를 구분한다.

## Capabilities

### New Capabilities

- `bridge-lifecycle`: 저장된 키와 자동 시작 선택을 보존하며 사본 간 중복 매핑을 방지한다.
- `windows-distribution`: Windows 테스트와 개인정보 없는 배포물을 검증하고 GitHub에 제공한다.

### Modified Capabilities

없음. 기존 OpenSpec 명세가 없는 전달본이다.

## Impact

AHK 진입점·설정/키 처리, Inno Setup 정의, PowerShell 테스트/빌드, GitHub Actions, 사용자 문서가 대상이다. runtime과 원본 소스·라이선스 동봉을 유지한다. NoMachine 또는 Mac 설정과 전역 Windows 키 설정은 변경하지 않는다.
