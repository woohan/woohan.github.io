(() => {
  const models = Array.from(document.querySelectorAll('[data-publications-cat]')).map((cat) => ({
    cat,
    head: cat.querySelector('.lab-publications-cat__head'),
    pupils: Array.from(cat.querySelectorAll('.lab-publications-cat__pupil')),
    currentX: 0,
    currentY: 0,
    targetX: 0,
    targetY: 0,
    isTracking: false,
    velocityX: 0,
    velocityY: 0,
    width: 0,
    height: 0
  }));

  if (!models.length) return;

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const coarsePointer = window.matchMedia('(pointer: coarse)');
  const clamp = (value, minimum, maximum) => (
    Math.min(maximum, Math.max(minimum, value))
  );

  let animationFrame = 0;
  let lastFrameTime = performance.now();
  let mobileIdleTimer = 0;
  let mobileResetTimer = 0;
  let mobileIdleIndex = 0;

  const mobileIdleLooks = [
    { x: -0.32, y: -0.2 },
    { x: 0.18, y: -0.92 },
    { x: 0.42, y: 0.04 },
    { x: 0, y: 0 }
  ];

  const measure = (model) => {
    const rect = model.cat.getBoundingClientRect();
    model.width = rect.width;
    model.height = rect.height;
    return rect;
  };

  const applyPose = (model) => {
    const lookX = model.currentX;
    const lookY = model.currentY;
    const lookUp = clamp((-lookY - 0.04) / 0.96, 0, 1);
    const headX = model.width * 0.018;
    const headY = model.height * 0.018;
    const headLift = model.height * 0.078;
    const gazeMagnitude = Math.hypot(lookX, lookY);
    const gazeStrength = model.isTracking
      ? clamp(0.88 + gazeMagnitude, 0, 1)
      : clamp(gazeMagnitude * 2.5, 0, 1);
    let pupilX = 0;
    let pupilY = 0;

    if (gazeMagnitude > 0.001) {
      const directionX = lookX / gazeMagnitude;
      const directionY = lookY / gazeMagnitude;
      const horizontalLimit = directionX < 0 ? 30 : 13;
      const verticalLimit = directionY < 0 ? 17 : 39;
      const edgeDistance = 1 / Math.sqrt(
        (directionX / horizontalLimit) ** 2
        + (directionY / verticalLimit) ** 2
      );

      pupilX = directionX * edgeDistance * gazeStrength;
      pupilY = directionY * edgeDistance * gazeStrength;
    }

    model.head.style.transform = [
      `translate(${lookX * headX}px, ${lookY * headY - lookUp * headLift}px)`,
      `rotate(${lookX * 3.4}deg)`,
      `scale(${1 + lookUp * 0.04})`
    ].join(' ');

    model.pupils.forEach((pupil) => {
      pupil.style.transform = `translate(${pupilX}px, ${pupilY}px)`;
    });
  };

  const requestAnimation = () => {
    if (reduceMotion.matches || animationFrame) return;
    lastFrameTime = performance.now();
    animationFrame = window.requestAnimationFrame(animate);
  };

  const animate = (time) => {
    animationFrame = 0;
    const elapsed = Math.min(40, time - lastFrameTime);
    const seconds = elapsed / 1000;
    const stiffness = 170;
    const damping = 22;
    let stillMoving = false;

    models.forEach((model) => {
      const accelerationX = (
        (model.targetX - model.currentX) * stiffness
        - model.velocityX * damping
      );
      const accelerationY = (
        (model.targetY - model.currentY) * stiffness
        - model.velocityY * damping
      );

      model.velocityX += accelerationX * seconds;
      model.velocityY += accelerationY * seconds;
      model.currentX += model.velocityX * seconds;
      model.currentY += model.velocityY * seconds;
      applyPose(model);

      if (
        Math.abs(model.targetX - model.currentX) > 0.001
        || Math.abs(model.targetY - model.currentY) > 0.001
        || Math.abs(model.velocityX) > 0.001
        || Math.abs(model.velocityY) > 0.001
      ) {
        stillMoving = true;
      }
    });

    lastFrameTime = time;
    if (stillMoving) {
      animationFrame = window.requestAnimationFrame(animate);
    }
  };

  const setTargets = (clientX, clientY) => {
    if (reduceMotion.matches) return;

    models.forEach((model) => {
      const rect = measure(model);
      if (!rect.width || !rect.height) return;

      const headX = rect.left + rect.width * 0.395;
      const headY = rect.top + rect.height * 0.47;
      model.targetX = clamp(
        (clientX - headX) / Math.max(window.innerWidth * 0.3, rect.width * 1.9),
        -1,
        1
      );
      model.targetY = clamp(
        (clientY - headY) / Math.max(window.innerHeight * 0.32, rect.height * 2.1),
        -1,
        1
      );
      model.isTracking = true;
    });

    requestAnimation();
  };

  const resetGaze = () => {
    models.forEach((model) => {
      model.targetX = 0;
      model.targetY = 0;
      model.isTracking = false;
    });
    requestAnimation();
  };

  const resetImmediately = () => {
    if (animationFrame) {
      window.cancelAnimationFrame(animationFrame);
      animationFrame = 0;
    }

    models.forEach((model) => {
      measure(model);
      model.currentX = 0;
      model.currentY = 0;
      model.targetX = 0;
      model.targetY = 0;
      model.isTracking = false;
      model.velocityX = 0;
      model.velocityY = 0;
      model.head.style.removeProperty('transform');
      model.pupils.forEach((pupil) => pupil.style.removeProperty('transform'));
    });
  };

  const startMobileIdle = () => {
    window.clearInterval(mobileIdleTimer);
    mobileIdleTimer = 0;

    if (!coarsePointer.matches || reduceMotion.matches || document.hidden) {
      resetGaze();
      return;
    }

    mobileIdleTimer = window.setInterval(() => {
      mobileIdleIndex = (mobileIdleIndex + 1) % mobileIdleLooks.length;
      const look = mobileIdleLooks[mobileIdleIndex];
      models.forEach((model) => {
        measure(model);
        model.targetX = look.x;
        model.targetY = look.y;
        model.isTracking = true;
      });
      requestAnimation();
    }, 2600);
  };

  const blink = (model) => {
    if (!reduceMotion.matches && !document.hidden) {
      model.cat.classList.add('is-blinking');
      window.setTimeout(() => model.cat.classList.remove('is-blinking'), 230);
    }
    window.setTimeout(() => blink(model), 2500 + Math.random() * 3400);
  };

  document.addEventListener('pointermove', (event) => {
    if (!coarsePointer.matches) {
      setTargets(event.clientX, event.clientY);
    }
  }, { passive: true });

  document.addEventListener('pointerdown', (event) => {
    if (!coarsePointer.matches) return;
    window.clearTimeout(mobileResetTimer);
    setTargets(event.clientX, event.clientY);
    mobileResetTimer = window.setTimeout(resetGaze, 1800);
  }, { passive: true });

  document.documentElement.addEventListener('pointerleave', resetGaze, { passive: true });
  window.addEventListener('blur', resetGaze);
  window.addEventListener('resize', () => {
    models.forEach(measure);
    requestAnimation();
  }, { passive: true });
  document.addEventListener('visibilitychange', startMobileIdle);

  const handleMediaChange = () => {
    resetImmediately();
    startMobileIdle();
  };

  if (coarsePointer.addEventListener) {
    coarsePointer.addEventListener('change', handleMediaChange);
    reduceMotion.addEventListener('change', handleMediaChange);
  } else {
    coarsePointer.addListener(handleMediaChange);
    reduceMotion.addListener(handleMediaChange);
  }

  models.forEach((model, index) => {
    measure(model);
    window.setTimeout(() => blink(model), 1500 + index * 480);
  });
  startMobileIdle();
})();
