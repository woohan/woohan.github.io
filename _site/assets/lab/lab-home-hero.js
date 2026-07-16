(() => {
  const scene = document.querySelector('[data-lab-cyber-scene]');
  if (!scene) return;
  const interactionSurface = document.querySelector('.lab-hero') || scene.parentElement;

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const mobileViewport = window.matchMedia('(max-width: 860px), (pointer: coarse)');
  const layers = Array.from(scene.querySelectorAll('.lab-scene-layer')).map((layer) => ({
    element: layer,
    image: layer.querySelector('.lab-scene-layer__image'),
    depth: Number(layer.dataset.depth) || 0,
    ambient: layer.dataset.ambient || ''
  }));
  const neonImages = Array.from(scene.querySelectorAll('[data-neon] .lab-scene-layer__image'));

  let frameId = 0;
  let currentX = 0;
  let currentY = 0;
  let targetX = 0;
  let targetY = 0;
  let lastInputAt = performance.now();
  let orientationActive = false;
  let orientationListening = false;
  let orientationOriginBeta = null;
  let orientationOriginGamma = null;
  let destroyed = false;
  let lastNeonIndex = -1;
  let lastRenderAt = 0;
  const timers = new Set();

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  const setTimer = (callback, delay) => {
    const timer = window.setTimeout(() => {
      timers.delete(timer);
      callback();
    }, delay);
    timers.add(timer);
    return timer;
  };

  const clearTimers = () => {
    timers.forEach((timer) => window.clearTimeout(timer));
    timers.clear();
    neonImages.forEach((image) => image.classList.remove('is-neon-dim'));
  };

  const positionFromPoint = (clientX, clientY) => {
    const bounds = interactionSurface.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return;
    targetX = clamp(((clientX - bounds.left) / bounds.width) * 2 - 1, -1, 1);
    targetY = clamp(((clientY - bounds.top) / bounds.height) * 2 - 1, -1, 1);
    lastInputAt = performance.now();
  };

  const onPointerMove = (event) => {
    if (mobileViewport.matches || reduceMotion.matches) return;
    positionFromPoint(event.clientX, event.clientY);
  };

  const onPointerLeave = () => {
    if (mobileViewport.matches) return;
    targetX = 0;
    targetY = 0;
  };

  const onTouchMove = (event) => {
    if (!mobileViewport.matches || orientationActive || reduceMotion.matches || !event.touches[0]) return;
    positionFromPoint(event.touches[0].clientX, event.touches[0].clientY);
  };

  const onOrientation = (event) => {
    if (reduceMotion.matches || event.gamma == null || event.beta == null) return;
    if (orientationOriginGamma == null || orientationOriginBeta == null) {
      orientationOriginGamma = event.gamma;
      orientationOriginBeta = event.beta;
    }
    orientationActive = true;
    targetX = clamp((event.gamma - orientationOriginGamma) / 28, -1, 1);
    targetY = clamp((event.beta - orientationOriginBeta) / 32, -1, 1);
    lastInputAt = performance.now();
  };

  const listenForOrientation = () => {
    if (orientationListening || typeof DeviceOrientationEvent === 'undefined') return;
    window.addEventListener('deviceorientation', onOrientation, { passive: true });
    orientationListening = true;
  };

  const requestOrientation = () => {
    if (!mobileViewport.matches || typeof DeviceOrientationEvent === 'undefined') return;
    if (typeof DeviceOrientationEvent.requestPermission !== 'function') {
      listenForOrientation();
      return;
    }
    DeviceOrientationEvent.requestPermission()
      .then((permission) => {
        if (permission === 'granted') listenForOrientation();
      })
      .catch(() => {});
  };

  const renderFrame = (now) => {
    if (destroyed || reduceMotion.matches) return;

    const isMobile = mobileViewport.matches;
    if (isMobile && now - lastRenderAt < 48) {
      frameId = window.requestAnimationFrame(renderFrame);
      return;
    }
    lastRenderAt = now;

    if (isMobile && !orientationActive && now - lastInputAt > 2400) {
      targetX = Math.sin(now / 4200) * 0.16;
      targetY = Math.cos(now / 5100) * 0.1;
    }

    const smoothing = isMobile ? 0.06 : 0.085;
    const amplitude = isMobile ? 0.5 : 2.15;
    const layerScale = isMobile ? 1.055 : 1.075;
    currentX += (targetX - currentX) * smoothing;
    currentY += (targetY - currentY) * smoothing;

    layers.forEach((layer) => {
      let ambientX = 0;
      let ambientY = 0;
      if (!isMobile && layer.ambient === 'drones') {
        ambientX = Math.sin(now / 2100) * 2.2;
        ambientY = Math.cos(now / 2700) * 0.8;
      } else if (!isMobile && layer.ambient === 'rain') {
        ambientX = Math.sin(now / 1600) * 0.8;
        ambientY = Math.sin(now / 1250) * 4;
        layer.image.style.opacity = String(0.42 + Math.sin(now / 2400) * 0.04);
      } else if (!isMobile && layer.ambient === 'glow') {
        layer.image.style.opacity = String(0.52 + Math.sin(now / 3100) * 0.04);
      }

      const x = currentX * layer.depth * amplitude + ambientX * amplitude;
      const y = currentY * layer.depth * 0.82 * amplitude + ambientY * amplitude;
      layer.image.style.transform = `translate3d(${x.toFixed(2)}px, ${y.toFixed(2)}px, 0) scale(${layerScale})`;
    });

    frameId = window.requestAnimationFrame(renderFrame);
  };

  const scheduleNeonBurst = () => {
    if (destroyed || reduceMotion.matches || document.hidden) {
      if (!destroyed && !reduceMotion.matches) setTimer(scheduleNeonBurst, 3000);
      return;
    }

    let index = Math.floor(Math.random() * neonImages.length);
    if (neonImages.length > 1 && index === lastNeonIndex) index = (index + 1) % neonImages.length;
    lastNeonIndex = index;
    const image = neonImages[index];
    const changes = 2 + Math.floor(Math.random() * 3);
    let change = 0;

    const flicker = () => {
      image.classList.toggle('is-neon-dim');
      change += 1;
      if (change < changes) {
        setTimer(flicker, 55 + Math.random() * 75);
        return;
      }
      setTimer(() => {
        image.classList.remove('is-neon-dim');
        setTimer(scheduleNeonBurst, 4200 + Math.random() * 6200);
      }, 70 + Math.random() * 80);
    };

    flicker();
  };

  const resetLayers = () => {
    currentX = 0;
    currentY = 0;
    targetX = 0;
    targetY = 0;
    layers.forEach((layer) => {
      layer.image.style.transform = 'translate3d(0, 0, 0) scale(1.05)';
      if (layer.ambient === 'rain') layer.image.style.opacity = '0.46';
      if (layer.ambient === 'glow') layer.image.style.opacity = '0.56';
    });
  };

  const startMotion = () => {
    if (frameId || reduceMotion.matches || destroyed) return;
    frameId = window.requestAnimationFrame(renderFrame);
  };

  const onMotionPreferenceChange = () => {
    window.cancelAnimationFrame(frameId);
    frameId = 0;
    clearTimers();
    resetLayers();
    if (!reduceMotion.matches) {
      startMotion();
      setTimer(scheduleNeonBurst, 3400 + Math.random() * 2400);
    }
  };

  const destroy = () => {
    destroyed = true;
    window.cancelAnimationFrame(frameId);
    clearTimers();
    interactionSurface.removeEventListener('pointermove', onPointerMove);
    interactionSurface.removeEventListener('pointerleave', onPointerLeave);
    interactionSurface.removeEventListener('touchmove', onTouchMove);
    interactionSurface.removeEventListener('pointerdown', requestOrientation);
    window.removeEventListener('deviceorientation', onOrientation);
    window.removeEventListener('pagehide', destroy);
    if (reduceMotion.removeEventListener) reduceMotion.removeEventListener('change', onMotionPreferenceChange);
    else reduceMotion.removeListener(onMotionPreferenceChange);
  };

  interactionSurface.addEventListener('pointermove', onPointerMove, { passive: true });
  interactionSurface.addEventListener('pointerleave', onPointerLeave, { passive: true });
  interactionSurface.addEventListener('touchmove', onTouchMove, { passive: true });
  interactionSurface.addEventListener('pointerdown', requestOrientation, { passive: true, once: true });
  window.addEventListener('pagehide', destroy, { once: true });
  if (reduceMotion.addEventListener) reduceMotion.addEventListener('change', onMotionPreferenceChange);
  else reduceMotion.addListener(onMotionPreferenceChange);

  if (mobileViewport.matches && typeof DeviceOrientationEvent !== 'undefined' &&
      typeof DeviceOrientationEvent.requestPermission !== 'function') {
    listenForOrientation();
  }

  if (!reduceMotion.matches) {
    startMotion();
    setTimer(scheduleNeonBurst, 3400 + Math.random() * 2400);
  } else {
    resetLayers();
  }
})();
