# Robotics Agent Skills — 수동 주입 절차

`external/robotics-agent-skills/` 는 3rd-party 심볼 (arpitg1304/robotics-agent-skills). 9개 로봇 스킬 포함:

- `ros2`
- `docker-ros2-development`
- `ros2-web-integration`
- `robotics-design-patterns`
- `robotics-testing`
- `robot-perception`
- `robot-bringup`
- `robotics-security`
- `robotics-software-principles`

Claude Code 세션에서 description trigger로 auto-load (progressive disclosure — 세션 시작 오버헤드는 description 합계만, 본문은 호출 시 로드).

## child 프로젝트에 주입

**Conservative boundary 정책**: distribution은 자동 주입 안 함 (spec AC-4 portability + 스코프 discipline). 사용자가 **각 child에 명시적으로** 심링크 (약 10초).

### 방법

```bash
cd ~/robot/<child>
mkdir -p .claude/skills
for skill in ros2 docker-ros2-development ros2-web-integration \
             robotics-design-patterns robotics-testing robot-perception \
             robot-bringup robotics-security robotics-software-principles; do
  ln -sfn ../../external/robotics-agent-skills/$skill .claude/skills/$skill
done
ls .claude/skills/  # 9 symlinks
```

### 한 줄 커맨드 (셸 alias 권장)

```bash
# ~/.bashrc 추가 (선택)
alias robot-inject-skills='for s in ros2 docker-ros2-development ros2-web-integration robotics-design-patterns robotics-testing robot-perception robot-bringup robotics-security robotics-software-principles; do mkdir -p .claude/skills && ln -sfn $HOME/robot/external/robotics-agent-skills/$s .claude/skills/$s; done'

# child 디렉토리에서:
robot-inject-skills
```

## 왜 자동이 아닌가?

Spec Round 6 (Conservative boundary): distribution은 child의 **필수** 자산만 자동화. robotics-agent-skills는:

1. **Optional** — ROS2/Isaac 관련 프로젝트에만 유용. 순수 데이터 처리 child에는 불필요.
2. **3rd-party licensed** — arpitg1304의 별도 MIT 레포. distribution이 바인딩하지 않고 사용자 선택 존중.
3. **Skill 충돌 가능** — 이미 `.claude/skills/` 에 사용자 custom skill 있을 수 있음.

`bootstrap-child.sh --with-robotics-skills` 플래그는 **iter 2 스코프에서 의도적 제외** (spec Round 6 discipline). 향후 수요가 집중되면 도입 재검토.

## 업스트림 업데이트

```bash
cd ~/robot/external/robotics-agent-skills
git pull origin main
cd ~/robot
git add external/robotics-agent-skills
git commit -m "chore(external): update robotics-agent-skills submodule to <sha>"
```

Submodule SHA pin이므로 일반 `git pull` 에서는 변경되지 않음 — 명시적 업데이트 필요. 이것이 **버전 안정성**의 근거.

## 개별 skill 사용 확인

```bash
cd ~/robot/<child>
claude
# Claude Code 세션 내에서 description trigger 언급 (예: "ros2 humble launch file 작성")
# → .claude/skills/ros2/ 가 자동 로드됨
```

`doctor.sh` 에서 명시적 체크는 없으나, `external/robotics-agent-skills/` submodule 상태는 `doctor.sh --layer=vendor` 에서 확인.

## 기여

robotics-agent-skills 자체에 PR은 upstream (`github.com/arpitg1304/robotics-agent-skills`) 으로. 이 distribution 측에는 submodule SHA 업데이트만.
