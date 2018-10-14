import './base.styl';

const videoEl = document.querySelector('.background');
const loopStart = 8.1;
const loopEnd = 11.5;  // videoLength = videoEl.seekable.end(videoEl.seekable.length - 1);
let direction = 1;  // 1 for forward, -1 for backward
let iterationStart;

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
  const delta = (now - iterationStart) / 1000 * direction;
  const newTime = (direction > 0 ? loopStart : loopEnd) + delta;
  if (newTime >= loopEnd || newTime <= loopStart) {
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
  resize();
}
