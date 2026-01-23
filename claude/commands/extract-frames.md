# 동영상 프레임 추출 스킬

동영상 파일에서 프레임을 이미지로 추출합니다.

## 입력 정보

$ARGUMENTS

## 작업 지침

1. **입력 파싱**: 사용자 입력에서 다음 정보를 추출하세요:
   - `video_path`: 동영상 파일 경로 (필수)
   - `resolution`: 해상도 옵션 (선택, 기본값: original)
     - `hd`: 1280px 너비
     - `fhd`: 1920px 너비
     - `original`: 원본 해상도 유지
   - `fps`: 초당 프레임 수 (선택, 기본값: 1)
   - `output_dir`: 출력 디렉토리 (선택, 기본값: 동영상과 같은 디렉토리에 `frames_동영상이름` 폴더)

2. **경로 처리**:
   - 상대 경로인 경우 현재 작업 디렉토리 기준으로 절대 경로로 변환
   - 동영상 파일 존재 여부 확인

3. **출력 디렉토리 생성**:
   - 지정된 출력 디렉토리가 없으면 생성

4. **ffmpeg 명령어 구성**:
   ```bash
   # 기본 형태
   ffmpeg -i <video_path> -vf "fps=<fps>[,scale=<width>:-1]" <output_dir>/frame_%04d.png
   ```

   해상도별 scale 옵션:
   - `hd`: `scale=1280:-1`
   - `fhd`: `scale=1920:-1`
   - `original`: scale 옵션 생략

5. **실행 및 결과 보고**:
   - ffmpeg 명령어 실행
   - 추출된 프레임 개수 확인
   - 출력 디렉토리 경로와 결과 요약 제공

## 입력 예시

```
/path/to/video.mp4 fhd fps=0.5
./video.mp4 hd
~/Downloads/movie.mov original fps=2
video.mp4
```

## 출력 형식

작업 완료 후 다음 정보를 보고:
- 입력 동영상 경로
- 적용된 해상도
- 적용된 FPS
- 출력 디렉토리 경로
- 추출된 프레임 개수
- 샘플 파일명 (처음 몇 개)
