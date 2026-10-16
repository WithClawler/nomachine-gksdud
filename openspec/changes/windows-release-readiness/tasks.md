# Tasks

## 1. Baseline and profile lifecycle

- [x] 1.1 원본 압축을 지정 루트에 보존하고 공개 저장소 위치를 확인한다. 원본 커밋과 GitHub 공개 상태로 확인한다.
- [x] 1.2 수정 전 Windows 테스트를 실행해 즉시 키 저장과 복원 결과를 Actions 로그에서 확인한다.
- [x] 1.3 폴더 간 단일 인스턴스와 설정 복원 회귀 검사를 구현하고 실제 AHK 프로세스 테스트로 확인한다.
- [x] 1.4 지연 전송·길게 누름·포커스 변경·Mac 외 거부 검사를 실행하고 기존 동작을 문서에 유지한다.

## 2. Installer and distribution

- [x] 2.1 명시적 자동 시작의 설치 경로 갱신과 제거를 구현하고 임시 프로필 테스트로 확인한다.
- [x] 2.2 일반 사용자 설치·실행·업데이트·제거를 CI에서 검사해 설정과 다른 AHK 프로세스가 보존됨을 확인한다.
- [x] 2.3 패키지 파일 목록·라이선스·원본 소스·해시 검증을 추가하고 Windows 빌드를 통과시킨다.
- [x] 2.4 README·BUILDING·VALIDATION과 변경 기록에 실제 결과 및 gksdud 영감을 명시한다.

## 3. Delivery and integration evidence

- [ ] 3.1 최종 커밋과 태그를 push하고 Actions 성공·릴리스 파일·다운로드 체크섬을 확인한다.
- [ ] 3.2 실제 Windows/NoMachine 환경에서 물리 키 등록, Mac 전환, 다른 OS/창 유지 여부를 확인하고 관측 결과를 기록한다.
- [ ] 3.3 OpenSpec strict validation과 최종 저장소 상태를 확인하고 남은 제한을 보고한다.

## Workflow follow-up

- 실기 검증을 포함한 요구 사항이 모두 충족됐을 때 변경을 archive한다.

검증 근거: Actions 38883919479 (`9e6e524`)에서 AHK/프로세스 92개, 비관리자 설치 34개, 패키지 검사 통과. 실제 원격 연결은 접근 가능한 Windows 실기 환경이 없어 미완료다.
