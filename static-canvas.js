export default class StaticCanvas {
  constructor(el) {
    this.canvas = el;
    this.ctx = this.canvas.getContext('2d', {alpha: false});

    this.resize();
    window.addEventListener('resize', () => this.resize());

    this.rgbHandlers = [
      [45, [0, 0, 0]],
      [90, [128, 128, 128]],
      [100, [255, 255, 255]],
    ];
    this.cycling = false;
  }

  resize() {
    this.canvas.width = this.canvas.scrollWidth;
    this.canvas.height = this.canvas.scrollHeight;
    this.id = this.ctx.createImageData(this.canvas.width, this.canvas.height);
    this.d = this.id.data;
  }

  draw() {
    for (let i = 0; i < this.d.length; i += 4) {
      const rand = Math.random() * 100;
      for (let j = 0; j < this.rgbHandlers.length; ++j) {
        if (rand <= this.rgbHandlers[j][0]) {
          [this.d[i], this.d[i + 1], this.d[i + 2]] = this.rgbHandlers[j][1];
          break;
        }
      }
      this.d[i + 3] = 255;
    }
    this.ctx.putImageData(this.id, 0, 0);
  }

  clear() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }

  cycle(duration) {
    if (this.cycling) return;
    this.canvas.classList.add('visible');
    this.cycling = true;
    const start = Date.now();
    const _cycle = () => {
      if (Date.now() - start >= duration) {
        this.cycling = false;
        this.canvas.classList.remove('visible');
        this.clear();
      }
      else {
        this.draw();
        requestAnimationFrame(_cycle)
      }
    }
    _cycle();
  }
}
