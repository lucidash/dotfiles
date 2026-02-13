---
name: stt
description: 오디오 파일을 텍스트로 변환(Speech-to-Text)합니다. "음성 분석", "오디오 텍스트 변환", "STT", "음성 인식", "받아쓰기" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<파일경로 또는 Slack 파일 URL>"
allowed-tools: Bash, Read
---

# Speech-to-Text (STT)

오디오 파일을 텍스트로 변환합니다.

**Arguments:** `$ARGUMENTS`

---

## 지원 입력

1. **로컬 파일 경로**: `/path/to/audio.m4a`, `/tmp/audio.wav` 등
2. **Slack 파일 URL**: `url_private_download` 형식의 Slack 파일 URL

---

## 워크플로우

```
1. 입력 분석 → 로컬 파일 or Slack URL 판별
2. (Slack URL인 경우) Bot Token으로 파일 다운로드
3. ffmpeg으로 wav 변환 (16kHz, mono)
4. Google Speech Recognition API로 STT 수행
5. 결과 텍스트 출력
```

---

## 1. 입력 판별

- 로컬 파일 경로: 파일 존재 여부 확인
- Slack URL (`files.slack.com`): 다운로드 필요

### Slack 파일 다운로드

```bash
SLACK_TOKEN=$(cat ~/.claude.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['slack']['env']['SLACK_BOT_TOKEN'])")
curl -sL -H "Authorization: Bearer $SLACK_TOKEN" "{url}" -o "/tmp/stt-input-audio"
```

---

## 2. WAV 변환

```bash
ffmpeg -i "{입력파일}" -ar 16000 -ac 1 /tmp/stt-audio.wav -y
```

- Sample rate: 16000Hz
- Channels: 1 (mono)
- 지원 포맷: m4a, mp3, mp4, ogg, webm, wav 등 ffmpeg 지원 포맷 전체

---

## 3. STT 실행

### venv 확인 및 생성

```bash
# venv 존재 확인, 없으면 생성
if [ ! -f /tmp/stt-env/bin/python3 ]; then
    python3 -m venv /tmp/stt-env
    /tmp/stt-env/bin/pip install SpeechRecognition
fi
```

### STT 수행

```python
/tmp/stt-env/bin/python3 -c "
import speech_recognition as sr
r = sr.Recognizer()
with sr.AudioFile('/tmp/stt-audio.wav') as source:
    audio = r.record(source)
try:
    text = r.recognize_google(audio, language='ko-KR')
    print(text)
except sr.UnknownValueError:
    print('ERROR: 음성을 인식할 수 없습니다')
except sr.RequestError as e:
    print(f'ERROR: Google API 요청 실패 - {e}')
"
```

- 기본 언어: `ko-KR` (한국어)
- 사용자가 다른 언어를 지정하면 해당 언어 코드 사용 (예: `en-US`, `ja-JP`)

---

## 4. 결과 출력

**반드시 아래 형식으로 출력:**

```
STT 결과:

> {변환된 텍스트}

소스: {파일명}
길이: {duration}초
언어: {사용된 언어}
```

---

## 주의사항

- ffmpeg이 설치되어 있어야 함
- Google Speech Recognition API 사용 (인터넷 연결 필요, API 키 불필요)
- 긴 오디오(1분 이상)는 정확도가 떨어질 수 있음
- venv는 `/tmp/stt-env`에 캐시되어 재사용됨
