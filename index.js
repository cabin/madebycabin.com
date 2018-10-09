import './base.styl';

import StaticCanvas from './static-canvas';

const body = document.querySelector('body');
const staticCanvas = new StaticCanvas(body.querySelector('#background'));

function randInt(min, max) {
  return Math.random() * (max - min) + min;
}

function glitchCanvas() {
  staticCanvas.cycle(randInt(200, 700));
  setTimeout(glitchCanvas, randInt(4000, 15000));
}

function glitchLogo() {
  body.classList.remove('glitch');
  setTimeout(() => body.classList.add('glitch'), 0);
  setTimeout(glitchLogo, randInt(6000, 16000));
}

setTimeout(glitchCanvas, randInt(1000, 4000));
setTimeout(glitchLogo, randInt(2000, 5000))
