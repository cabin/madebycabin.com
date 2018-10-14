import './base.styl';

const videoEl = document.querySelector('.background');
const loopStart = 8.1;
const loopEnd = 11.5;  // videoLength = videoEl.seekable.end(videoEl.seekable.length - 1);
const loopDuration = (loopEnd - loopStart) * 2;
let direction = 1;  // 1 for forward, -1 for backward
let iterationStart;

// Ease in/out when looping to avoid glitchiness, but ease only out on the
// first pass to maintain linear motion.
const easeOutQuad = t => t * (2 - t);
const easeInOutQuad = t => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
let ease = easeOutQuad;

function waitForLoopStart() {
  let fn = waitForLoopStart;
  if (videoEl.currentTime >= loopStart) {
    iterationStart = performance.now();
    videoEl.pause();
    fn = loopVideo;
  }
  requestAnimationFrame(fn);
}

function loopVideo() {
  const now = performance.now();
  const delta = (now - iterationStart) / 1000;
  const t = delta / loopDuration;
  const easedDelta = ease(t) * (loopEnd - loopStart);
  const newTime = (direction > 0 ? loopStart : loopEnd) + easedDelta * direction;
  if (t >= 1) {
    ease = easeInOutQuad;
    iterationStart = now;
    direction *= -1;
  }
  else {
    videoEl.currentTime = newTime;
  }
  requestAnimationFrame(loopVideo);
}

videoEl.addEventListener('loadeddata', waitForLoopStart);

// Hack for Mobile Safari; 100vh doesn't account for header/footer, so the page still scrolls.
if (window.innerHeight && window.screen && window.screen.availHeight && window.innerHeight < window.screen.availHeight) {
  const resize = () => document.querySelector('main').style.height = window.innerHeight + 'px';
  window.addEventListener('orientationchange', resize);
  window.addEventListener('resize', resize);
  resize();
}
