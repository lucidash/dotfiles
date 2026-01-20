현재 브랜치의 PR에 `preview-real` 라벨을 추가해주세요.

1. `gh pr view --json labels,number`로 현재 PR 정보 확인
2. PR이 없으면 `/open-pr` 커맨드를 실행하여 PR 먼저 생성
3. `preview-real` 라벨이 이미 있으면 "이미 preview-real 라벨이 있습니다" 메시지 출력
4. 라벨이 없으면 `gh pr edit --add-label preview-real`로 추가
