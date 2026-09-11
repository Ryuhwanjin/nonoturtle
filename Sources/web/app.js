// NoNoTurtle Core Logic

// State
let isTimerActive = false;
let durationMinutes = 30;
let remainingSeconds = 30 * 60;
let currentProgress = 1.0; // 1.0 = Good, 0.0 = Bad
let timerInterval = null;
let idleAnimationId = null;
let idleStartTime = Date.now();
const IDLE_PERIOD = 8000; // 8초 주기

// DOM Elements
const canvas = document.getElementById('posture-canvas');
const ctx = canvas.getContext('2d');
const statusBadge = document.getElementById('status-badge');
const statusText = document.getElementById('status-text');
const timerToggle = document.getElementById('timer-toggle');
const timerPanel = document.getElementById('timer-panel');
const timerHint = document.getElementById('timer-hint');
const countdownDisplay = document.getElementById('countdown-display');
const progressFill = document.getElementById('progress-fill');
const resetBtn = document.getElementById('reset-btn');
const exerciseBtn = document.getElementById('exercise-btn');
const quitBtn = document.getElementById('quit-btn');
const durButtons = document.querySelectorAll('.dur-btn');

// Exercise Modal Elements
const exerciseModal = document.getElementById('exercise-modal');
const closeModalBtn = document.getElementById('close-modal-btn');
const startExerciseBtn = document.getElementById('start-exercise-btn');
const exerciseCanvas = document.getElementById('exercise-canvas');
const exerciseCtx = exerciseCanvas.getContext('2d');
const exerciseStepTitle = document.getElementById('exercise-step-title');
const exerciseStepDesc = document.getElementById('exercise-step-desc');
const exerciseTimer = document.getElementById('exercise-timer');
let exerciseState = { active: false, step: 0, rep: 1, count: 5, progress: 0.0, timer: null };

// 네이티브 동기화 헬퍼
function syncToNative() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.native) {
    window.webkit.messageHandlers.native.postMessage({
      action: 'syncTimerState',
      timerActive: isTimerActive,
      totalSeconds: durationMinutes * 60,
      remainingSeconds: remainingSeconds
    });
  }
}

// 1. 사람 옆모습 그리기 (Canvas 렌더러)
function drawHumanSideProfile(c, p, size) {
  const w = size.width;
  const h = size.height;
  c.clearRect(0, 0, w, h);

  const isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  
  let color = '#34c759'; // 초록
  let colorText = '바른 자세 유지 중';
  if (p < 0.35) {
    color = '#ff3b30'; // 빨강
    colorText = '심한 거북목 상태! 턱을 당겨주세요';
  } else if (p < 0.7) {
    color = '#ff9500'; // 주황
    colorText = '머리가 앞으로 나오고 있어요';
  }

  // 1. 수직 기준선 (Plumb Line)
  const shoulderX = w * 0.44;
  c.save();
  c.setLineDash([4, 4]);
  c.strokeStyle = isDark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.18)';
  c.lineWidth = 1.5;
  c.beginPath();
  c.moveTo(shoulderX, 15);
  c.lineTo(shoulderX, h - 15);
  c.stroke();
  c.restore();

  // 2. 좌표 계산
  const forwardShift = (1.0 - p) * 38.0;
  const downShift = (1.0 - p) * 8.0;
  const chinLift = (1.0 - p) * 8.0;

  const headCenterX = shoulderX + forwardShift;
  const headCenterY = h * 0.32 + downShift;
  const shoulderY = h * 0.68;

  // 3. 등/흉추 & 목/경추 라인 (스파인)
  c.save();
  c.strokeStyle = color;
  c.lineWidth = 4.5;
  c.lineCap = 'round';
  c.lineJoin = 'round';
  c.shadowColor = color;
  c.shadowBlur = 8;

  c.beginPath();
  const headBackX = headCenterX - 18;
  const headBackY = headCenterY + 4;
  c.moveTo(headBackX, headBackY);

  const neckControlX = shoulderX - 10 + (1.0 - p) * 20.0;
  c.quadraticCurveTo(neckControlX, h * 0.50, shoulderX - 6, shoulderY - 8);

  const backBulge = (1.0 - p) * 16.0;
  c.quadraticCurveTo(shoulderX - 22 - backBulge, h * 0.82, shoulderX - 10, h * 0.96);
  c.stroke();
  c.restore();

  // 4. 머리 및 얼굴 옆모습 실루엣
  c.save();
  c.beginPath();
  c.moveTo(headCenterX - 22, headCenterY);
  c.bezierCurveTo(headCenterX - 22, headCenterY - 24, headCenterX - 12, headCenterY - 32, headCenterX - 2, headCenterY - 32);
  c.bezierCurveTo(headCenterX + 10, headCenterY - 32, headCenterX + 18, headCenterY - 20, headCenterX + 18, headCenterY - 14);
  c.lineTo(headCenterX + 26, headCenterY - 2);
  c.lineTo(headCenterX + 18, headCenterY + 4);
  const chinX = headCenterX + 16 + chinLift;
  const chinY = headCenterY + 18 - chinLift * 0.4;
  c.lineTo(headCenterX + 19, headCenterY + 9);
  c.lineTo(chinX, chinY);
  const throatX = headCenterX - 2 + chinLift * 0.7;
  const throatY = headCenterY + 22;
  c.lineTo(throatX, throatY);
  c.quadraticCurveTo(throatX + 4, throatY + 16, shoulderX + 16, shoulderY);
  c.lineTo(shoulderX - 6, shoulderY);
  c.closePath();

  c.fillStyle = color + '2a';
  c.fill();
  c.strokeStyle = color;
  c.lineWidth = 3;
  c.stroke();
  c.restore();

  // 5. 귀(Ear) 마커
  const earX = headCenterX - 1;
  const earY = headCenterY;
  c.save();
  c.fillStyle = '#ffffff';
  c.strokeStyle = color;
  c.lineWidth = 2.5;
  c.beginPath();
  c.arc(earX, earY, 4.5, 0, Math.PI * 2);
  c.fill();
  c.stroke();

  // 6. 어깨(Shoulder) 마커
  c.fillStyle = color;
  c.beginPath();
  c.arc(shoulderX, shoulderY, 5, 0, Math.PI * 2);
  c.fill();

  // 7. 귀-어깨 전방 이탈 가이드선 & 수치 표시
  if (p < 0.95) {
    c.setLineDash([3, 3]);
    c.strokeStyle = color;
    c.lineWidth = 1.5;
    c.beginPath();
    c.moveTo(earX, earY);
    c.lineTo(shoulderX, earY);
    c.stroke();

    const cm = ((1.0 - p) * 5.0).toFixed(1);
    const textX = (earX + shoulderX) / 2;
    const textY = earY - 8;
    c.font = 'bold 10px ui-monospace, sans-serif';
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    c.fillStyle = color;
    c.fillText(`+${cm} cm`, textX, textY);
  }
  c.restore();

  return { color, colorText };
}

// 2. 애니메이션 렌더 루프
function render() {
  const result = drawHumanSideProfile(ctx, currentProgress, { width: 280, height: 180 });
  statusBadge.style.color = result.color;
  statusText.textContent = result.colorText;
}

// 타이머 미설정 시: 8초 동안 정자세 ↔ 거북목 왕복 루프
function startIdleLoop() {
  cancelAnimationFrame(idleAnimationId);
  idleStartTime = Date.now();
  syncToNative();
  
  function loop() {
    if (isTimerActive || exerciseState.active) return;
    const elapsed = Date.now() - idleStartTime;
    const angle = (elapsed / IDLE_PERIOD) * Math.PI * 2;
    currentProgress = (Math.cos(angle) + 1.0) / 2.0;
    render();
    idleAnimationId = requestAnimationFrame(loop);
  }
  idleAnimationId = requestAnimationFrame(loop);
}

function stopIdleLoop() {
  cancelAnimationFrame(idleAnimationId);
  idleAnimationId = null;
}

// 3. 타이머 로직
function startTimer() {
  stopIdleLoop();
  remainingSeconds = durationMinutes * 60;
  currentProgress = 1.0;
  updateTimerUI();
  render();
  syncToNative();

  clearInterval(timerInterval);
  timerInterval = setInterval(() => {
    if (remainingSeconds > 0) {
      remainingSeconds--;
      currentProgress = remainingSeconds / (durationMinutes * 60);
      updateTimerUI();
      render();
      syncToNative();
    } else {
      clearInterval(timerInterval);
      currentProgress = 0.0;
      updateTimerUI();
      render();
      syncToNative();
      notifyUser();
    }
  }, 1000);
}

function stopTimer() {
  clearInterval(timerInterval);
  timerInterval = null;
  syncToNative();
  startIdleLoop();
}

function updateTimerUI() {
  const m = Math.floor(remainingSeconds / 60);
  const s = remainingSeconds % 60;
  countdownDisplay.textContent = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  
  const pct = (currentProgress * 100).toFixed(1);
  progressFill.style.width = `${pct}%`;
  progressFill.style.backgroundColor = currentProgress > 0.35 ? '#34c759' : '#ff3b30';
}

function notifyUser() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.native) {
    window.webkit.messageHandlers.native.postMessage({
      action: 'sendNotification',
      title: '⚠️ 거북목 주의! 자세를 바로잡을 시간입니다',
      body: '턱을 당기고 가슴을 활짝 펴주세요. 30초 스트레칭을 해볼까요?'
    });
  }
}

// 4. 이벤트 리스너 바인딩
timerToggle.addEventListener('change', (e) => {
  isTimerActive = e.target.checked;
  if (isTimerActive) {
    timerPanel.classList.remove('hidden');
    timerHint.classList.add('hidden');
    startTimer();
  } else {
    timerPanel.classList.add('hidden');
    timerHint.classList.remove('hidden');
    stopTimer();
  }
});

durButtons.forEach(btn => {
  btn.addEventListener('click', () => {
    durButtons.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    durationMinutes = parseInt(btn.dataset.minutes, 10);
    if (isTimerActive) {
      startTimer();
    }
  });
});

resetBtn.addEventListener('click', () => {
  if (isTimerActive) {
    startTimer();
  } else {
    currentProgress = 1.0;
    idleStartTime = Date.now();
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.native) {
      window.webkit.messageHandlers.native.postMessage({ action: 'resetPosture' });
    }
    render();
  }
});

quitBtn.addEventListener('click', () => {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.native) {
    window.webkit.messageHandlers.native.postMessage({ action: 'terminateApp' });
  }
});

// 5. 30초 턱 당기기 인터랙션
exerciseBtn.addEventListener('click', () => {
  exerciseModal.classList.remove('hidden');
  resetExerciseModal();
});

closeModalBtn.addEventListener('click', () => {
  stopExercise();
  exerciseModal.classList.add('hidden');
  if (!isTimerActive) startIdleLoop();
});

function resetExerciseModal() {
  exerciseState = { active: false, step: 0, rep: 1, count: 5, progress: 0.0, timer: null };
  exerciseStepTitle.textContent = '준비되셨나요?';
  exerciseStepDesc.textContent = '의자에 허리를 펴고 턱을 가볍게 당길 준비를 하세요';
  exerciseTimer.textContent = '';
  startExerciseBtn.textContent = '시작하기';
  drawHumanSideProfile(exerciseCtx, 0.0, { width: 240, height: 170 });
}

startExerciseBtn.addEventListener('click', () => {
  if (exerciseState.step === 0) {
    exerciseState.active = true;
    stopIdleLoop();
    startExerciseCycle();
  } else if (exerciseState.step === 3) {
    exerciseModal.classList.add('hidden');
    if (isTimerActive) {
      startTimer();
    } else {
      currentProgress = 1.0;
      startIdleLoop();
    }
    stopExercise();
  }
});

function startExerciseCycle() {
  exerciseState.step = 1;
  exerciseState.rep = 1;
  exerciseState.count = 5;
  exerciseState.progress = 1.0;
  updateExerciseStepUI();

  clearInterval(exerciseState.timer);
  exerciseState.timer = setInterval(() => {
    if (exerciseState.count > 1) {
      exerciseState.count--;
      updateExerciseStepUI();
    } else {
      if (exerciseState.step === 1) {
        if (exerciseState.rep < 3) {
          exerciseState.step = 2;
          exerciseState.count = 3;
          exerciseState.progress = 0.5;
        } else {
          exerciseState.step = 3;
          clearInterval(exerciseState.timer);
          exerciseState.progress = 1.0;
        }
      } else if (exerciseState.step === 2) {
        exerciseState.rep++;
        exerciseState.step = 1;
        exerciseState.count = 5;
        exerciseState.progress = 1.0;
      }
      updateExerciseStepUI();
    }
  }, 1000);
}

function updateExerciseStepUI() {
  drawHumanSideProfile(exerciseCtx, exerciseState.progress, { width: 240, height: 170 });
  if (exerciseState.step === 1) {
    exerciseStepTitle.textContent = `턱을 목 쪽으로 지그시 당기세요! (${exerciseState.rep}/3회)`;
    exerciseStepDesc.textContent = '정수리는 천장 방향으로 곧게 세웁니다';
    exerciseTimer.textContent = exerciseState.count;
    startExerciseBtn.textContent = '운동 진행 중...';
  } else if (exerciseState.step === 2) {
    exerciseStepTitle.textContent = '힘을 빼고 편안히 호흡하세요';
    exerciseStepDesc.textContent = `다음 반복 준비 (${exerciseState.count}초)`;
    exerciseTimer.textContent = exerciseState.count;
  } else if (exerciseState.step === 3) {
    exerciseStepTitle.textContent = '🎉 자세 리셋 완료!';
    exerciseStepDesc.textContent = '바른 자세로 다시 상쾌하게 집중해보세요';
    exerciseTimer.textContent = '✓';
    startExerciseBtn.textContent = '완료하고 자세 리셋';
  }
}

function stopExercise() {
  clearInterval(exerciseState.timer);
  exerciseState.active = false;
}

// 최초 실행
startIdleLoop();
