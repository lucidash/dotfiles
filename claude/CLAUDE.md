# Global Instructions

## Command Aliases

GitHub CLI `gh`:  현재 로컬에서 gh 는 git history ... 으로 aliased 되어있습니다.
때문에 `gh` 대신 `command gh` 로 실행해야 합니다.

- GitHub CLI를 사용할 때는 항상 `command gh`를 사용하세요
- 예: `command gh pr create`, `command gh issue list` 등

## Git Push 전 필수 확인

`git push` 실행 전에 반드시 다음을 확인하세요:

1. **빌드 확인**: workspace의 build script 실행 (예: `npm run build`, `yarn build` 등)
2. **린트 확인**: lint script 실행 (예: `npm run lint`, `npm run lint:prod` 등)

빌드 또는 린트가 실패하면 push하지 말고 먼저 문제를 해결하세요.

## 파일 삭제 시 주의사항

다음 파일을 삭제할 때는 반드시 사용자에게 확인을 받으세요:

- Git repository가 아닌 디렉토리의 파일
- Git repository 내 untracked 파일 (git에서 추적하지 않는 파일)

이러한 파일은 복구가 불가능할 수 있으므로 삭제 전 항상 확인이 필요합니다.
