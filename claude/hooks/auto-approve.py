#!/usr/bin/env python3
"""
PermissionRequest 훅: settings.json의 permissions.allow를 대체
허용된 도구/명령은 자동 승인, 그 외는 사용자에게 물어봄
"""

import json
import os
import re
import sys
from fnmatch import fnmatch


def get_project_dir():
    """CLAUDE_PROJECT_DIR 환경변수 반환"""
    return os.environ.get("CLAUDE_PROJECT_DIR", "")


def match_glob_pattern(pattern: str, value: str) -> bool:
    """글로브 패턴 매칭 (${CLAUDE_PROJECT_DIR} 치환 포함)"""
    project_dir = get_project_dir()
    expanded = pattern.replace("${CLAUDE_PROJECT_DIR}", project_dir)
    return fnmatch(value, expanded)


def check_bash_ask(command: str) -> bool:
    """Bash 명령이 사용자에게 물어봐야 하는 패턴인지 확인"""
    ask_patterns = [
        "git commit --amend*",
        "git commit -a --amend*",
        "git rebase*",
        "git push --force*",
        "git push -f*",
        "git push origin --force*",
        "git push origin -f*",
        "git reset --hard*",
        "git reset HEAD~*",
    ]
    for pattern in ask_patterns:
        if fnmatch(command, pattern):
            return True
    return False


def check_bash_permission(command: str) -> bool:
    """Bash 명령이 허용된 패턴과 일치하는지 확인"""
    # 먼저 ask 패턴 확인 (ask 패턴은 허용하지 않음)
    if check_bash_ask(command):
        return False

    allowed_patterns = [
        # Git 명령
        "git --no-pager *",
        "git status*",
        "git log*",
        "git diff*",
        "git show*",
        "git branch*",
        "git fetch*",
        "git pull*",
        "git checkout*",
        "git switch*",
        "git stash*",
        "git add*",
        "git commit -m*",
        "git push*",
        # npm 명령
        "npm run*",
        "npm test*",
        "npm install*",
        # 기타
        "ln*",
        "command gh pr*",
        "command gh api*",
        # npx 명령
        "npx eslint*",
        "npx vitest*",
        "npx tsc*",
        "npx l10n*",
    ]

    for pattern in allowed_patterns:
        if fnmatch(command, pattern):
            return True
    return False


def check_bash_denied(command: str) -> bool:
    """Bash 명령이 거부 패턴과 일치하는지 확인"""
    denied_patterns = [
        "npm run*deploy*",
    ]
    for pattern in denied_patterns:
        if fnmatch(command, pattern):
            return True
    return False


def check_file_permission(tool_name: str, file_path: str) -> bool:
    """Edit/Write 도구의 파일 경로가 허용되는지 확인"""
    project_dir = get_project_dir()
    if not project_dir:
        return False

    # 프로젝트 디렉토리 내 파일인지 확인
    abs_path = os.path.abspath(file_path)
    abs_project = os.path.abspath(project_dir)

    if not abs_path.startswith(abs_project + os.sep) and abs_path != abs_project:
        return False

    # ask 패턴 확인 (.env, .conf, .config 파일은 사용자에게 물어봄)
    ask_patterns = [
        "**/.env",
        "**/.env.*",
        "**/*.conf",
        "**/*.config",
        "**/*.config.*",
    ]

    for pattern in ask_patterns:
        if fnmatch(abs_path, os.path.join(project_dir, pattern.lstrip("**/"))):
            return False  # ask 패턴은 허용하지 않음 (사용자에게 물어봄)

        # 간단한 패턴 매칭
        filename = os.path.basename(abs_path)
        if pattern == "**/.env" and filename == ".env":
            return False
        if pattern == "**/.env.*" and filename.startswith(".env."):
            return False
        if pattern == "**/*.conf" and filename.endswith(".conf"):
            return False
        if pattern == "**/*.config" and filename.endswith(".config"):
            return False
        if "*.config.*" in pattern and ".config." in filename:
            return False

    return True


def check_mcp_permission(tool_name: str) -> bool:
    """MCP 도구가 허용되는지 확인"""
    allowed_mcp_tools = [
        "mcp__ide__getDiagnostics",
        "mcp__notion__API-get-block-children",
        "mcp__notion__API-retrieve-a-data-source",
        "mcp__notion__API-retrieve-a-page",
        "mcp__notion__notion-create-pages",
        "mcp__notion__notion-fetch",
        "mcp__notion__notion-search",
        "mcp__notion__notion-update-page",
    ]
    return tool_name in allowed_mcp_tools


def allow():
    """권한 허용 응답 출력"""
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "decision": {"behavior": "allow"},
        }
    }
    print(json.dumps(output))
    sys.exit(0)


def deny(message: str, interrupt: bool = False):
    """권한 거부 응답 출력"""
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "decision": {"behavior": "deny", "message": message, "interrupt": interrupt},
        }
    }
    print(json.dumps(output))
    sys.exit(0)


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Read 도구: 항상 허용
    if tool_name == "Read":
        allow()

    # Skill 도구: 항상 허용
    if tool_name == "Skill":
        allow()

    # Task 도구: 항상 허용
    if tool_name == "Task":
        allow()

    # Edit 도구: 프로젝트 디렉토리 내 파일만 허용 (특정 파일 제외)
    if tool_name == "Edit":
        file_path = tool_input.get("file_path", "")
        if file_path and check_file_permission(tool_name, file_path):
            allow()
        # 허용되지 않으면 사용자에게 물어봄 (아무것도 출력 안함)

    # Write 도구: 프로젝트 디렉토리 내 파일만 허용 (특정 파일 제외)
    if tool_name == "Write":
        file_path = tool_input.get("file_path", "")
        if file_path and check_file_permission(tool_name, file_path):
            allow()

    # Bash 도구: 허용된 명령만 허용
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        # 먼저 거부 패턴 확인
        if check_bash_denied(command):
            deny(f"This command matches a denied pattern: {command}")
        # 허용 패턴 확인
        if check_bash_permission(command):
            allow()

    # MCP 도구: 허용 목록 확인
    if tool_name.startswith("mcp__"):
        if check_mcp_permission(tool_name):
            allow()

    # 허용되지 않으면 아무것도 출력하지 않음 → 사용자에게 물어봄
    sys.exit(0)


if __name__ == "__main__":
    main()
