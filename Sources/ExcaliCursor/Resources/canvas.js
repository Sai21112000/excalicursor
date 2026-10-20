(function () {
  "use strict";

  const canvas = document.getElementById("drawing-canvas");
  const ctx = canvas.getContext("2d");
  const rc = window.rough.canvas(canvas);
  const excaliDock = document.getElementById("excali-dock");
  const dragHandle = document.getElementById("drag-handle");
  const lockBtn = document.getElementById("lock-btn");
  const colorTriggerBtn = document.getElementById("color-trigger-btn");
  const activeColorDot = document.getElementById("active-color-dot");
  const colorPopover = document.getElementById("color-popover");
  const moreToolsBtn = document.getElementById("more-tools-btn");
  const moreToolsMenu = document.getElementById("more-tools-menu");
  const fillToggleBtn = document.getElementById("fill-toggle-btn");
  const clearBtn = document.getElementById("clear-btn");
  const toastBanner = document.getElementById("toast-banner");
  const textInput = document.getElementById("floating-text-input");
  const themeLabel = document.getElementById("theme-label");

  const LASER_DECAY_MS = 820;
  const STORAGE_KEY = "ExcaliCursor.dockPrefs.v1";

  const state = {
    isActive: false,
    hideWhenInactive: false,
    isToolLocked: false,
    currentTool: "pen",
    strokeColor: "#e03131",
    fillEnabled: false,
    strokeWidth: 3.2,
    roughness: 1.2,
    panX: 0,
    panY: 0,
    elements: [],
    redoStack: [],
    selectedIndices: [],
    activeElement: null,
    isPointerDown: false,
    dragStartX: 0,
    dragStartY: 0,
    selectionBox: null,
    lassoPoints: null,
    // Slick Laser Pointer state
    laserTrails: [],
    activeLaserTrail: null,
    hoverLaserTrail: { points: [] },
    laserRafId: null,
    laserCursorPos: null,
    // Toolbar Dragging & Adaptive Orientation state
    isDraggingDock: false,
    dockGrabRatioX: 0.05,
    dockGrabRatioY: 0.5,
    isVertical: false,
    darkMode: false,
    toastTimer: null
  };

  function postToNative(payload) {
    if (
      window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.excaliCursorBridge
    ) {
      window.webkit.messageHandlers.excaliCursorBridge.postMessage(payload);
    }
  }

  function showToast(msg) {
    if (!toastBanner) return;
    toastBanner.textContent = msg;
    toastBanner.classList.add("visible");
    if (state.toastTimer) clearTimeout(state.toastTimer);
    state.toastTimer = setTimeout(() => {
      toastBanner.classList.remove("visible");
    }, 1400);
  }

  // Persistence for Dock Position, Orientation & Theme
  function saveDockPrefs() {
    try {
      const isCustom = excaliDock.classList.contains("custom-pos");
      const prefs = {
        isCustom,
        left: excaliDock.style.left,
        top: excaliDock.style.top,
        isVertical: state.isVertical,
        dockClasses: Array.from(excaliDock.classList).filter((c) =>
          ["vertical", "dock-left", "dock-right", "dock-bottom", "custom-pos"].includes(c)
        ),
        darkMode: state.darkMode
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch (_) {}
  }

  function loadDockPrefs() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const prefs = JSON.parse(raw);
      if (typeof prefs.darkMode === "boolean") {
        setDarkTheme(prefs.darkMode, false);
      }
      if (prefs.isCustom && prefs.left && prefs.top) {
        excaliDock.classList.remove("vertical", "dock-left", "dock-right", "dock-bottom", "custom-pos");
        (prefs.dockClasses || []).forEach((c) => excaliDock.classList.add(c));
        state.isVertical = Boolean(prefs.isVertical);
        excaliDock.style.left = prefs.left;
        excaliDock.style.top = prefs.top;
        clampDockInsideViewport();
      }
    } catch (_) {}
  }

  function setDarkTheme(dark, persist = true) {
    state.darkMode = Boolean(dark);
    document.body.classList.toggle("dark-ui", state.darkMode);
    if (themeLabel) {
      themeLabel.textContent = state.darkMode ? "Light Toolbar Theme" : "Dark Toolbar Theme";
    }
    if (persist) saveDockPrefs();
  }

  function resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    const width = window.innerWidth;
    const height = window.innerHeight;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    clampDockInsideViewport();
    renderScene();
  }

  // Screen-Side Adaptive Vertical / Horizontal Orientation
  function applyDockOrientation(vertical, edgeSide) {
    state.isVertical = vertical;
    excaliDock.classList.toggle("vertical", vertical);
    excaliDock.classList.remove("dock-left", "dock-right", "dock-bottom");
    if (edgeSide === "left") excaliDock.classList.add("dock-left");
    if (edgeSide === "right") excaliDock.classList.add("dock-right");
    if (edgeSide === "bottom") excaliDock.classList.add("dock-bottom");
  }

  function clampDockInsideViewport() {
    if (!excaliDock.classList.contains("custom-pos")) return;
    const rect = excaliDock.getBoundingClientRect();
    const clampedX = Math.max(10, Math.min(window.innerWidth - rect.width - 10, rect.left));
    const clampedY = Math.max(10, Math.min(window.innerHeight - rect.height - 10, rect.top));
    excaliDock.style.left = `${clampedX}px`;
    excaliDock.style.top = `${clampedY}px`;
  }

  dragHandle.addEventListener("pointerdown", function (e) {
    if (e.button !== 0) return;
    e.stopPropagation();
    closeAllPopovers();

    const rect = excaliDock.getBoundingClientRect();
    excaliDock.classList.add("custom-pos");
    excaliDock.style.left = `${rect.left}px`;
    excaliDock.style.top = `${rect.top}px`;

    // Record grab ratios along the grip so morphing between horizontal & vertical stays anchored to the cursor
    state.isDraggingDock = true;
    state.dockGrabRatioX = Math.max(0.02, Math.min(0.98, (e.clientX - rect.left) / rect.width));
    state.dockGrabRatioY = Math.max(0.02, Math.min(0.98, (e.clientY - rect.top) / rect.height));
    dragHandle.setPointerCapture(e.pointerId);
  });

  dragHandle.addEventListener("pointermove", function (e) {
    if (!state.isDraggingDock) return;

    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const cx = e.clientX;
    const cy = e.clientY;

    // Detect proximity to Left/Right screen edges vs Top/Bottom edges
    const EDGE_THRESHOLD = 115;
    const distLeft = cx;
    const distRight = vw - cx;
    const distTop = cy;
    const distBottom = vh - cy;

    const nearLeft = distLeft < EDGE_THRESHOLD && distLeft < distTop && distLeft < distBottom;
    const nearRight = distRight < EDGE_THRESHOLD && distRight < distTop && distRight < distBottom;
    const nearBottom = distBottom < 140;

    if (nearLeft) {
      applyDockOrientation(true, "left");
    } else if (nearRight) {
      applyDockOrientation(true, "right");
    } else {
      applyDockOrientation(false, nearBottom ? "bottom" : "top");
    }

    const rect = excaliDock.getBoundingClientRect();
    let nextX, nextY;
    if (state.isVertical) {
      nextX = cx - 18;
      nextY = cy - 18;
    } else {
      nextX = cx - 18;
      nextY = cy - 22;
    }

    nextX = Math.max(10, Math.min(vw - rect.width - 10, nextX));
    nextY = Math.max(10, Math.min(vh - rect.height - 10, nextY));

    excaliDock.style.left = `${nextX}px`;
    excaliDock.style.top = `${nextY}px`;
  });

  function stopDockDrag() {
    if (!state.isDraggingDock) return;
    state.isDraggingDock = false;
    saveDockPrefs();
  }

  dragHandle.addEventListener("pointerup", stopDockDrag);
  dragHandle.addEventListener("pointercancel", stopDockDrag);

  dragHandle.addEventListener("dblclick", function (e) {
    e.stopPropagation();
    excaliDock.classList.remove("custom-pos", "vertical", "dock-left", "dock-right", "dock-bottom");
    state.isVertical = false;
    excaliDock.style.left = "50%";
    excaliDock.style.top = "18px";
    saveDockPrefs();
    showToast("Toolbar reset to Top Center");
  });

  function flipOrientationManually() {
    const rect = excaliDock.getBoundingClientRect();
    excaliDock.classList.add("custom-pos");
    const nextVertical = !state.isVertical;
    const side = nextVertical
      ? rect.left > window.innerWidth / 2
        ? "right"
        : "left"
      : rect.top > window.innerHeight - 160
      ? "bottom"
      : "top";

    applyDockOrientation(nextVertical, side);
    excaliDock.style.left = `${rect.left}px`;
    excaliDock.style.top = `${rect.top}px`;
    clampDockInsideViewport();
    saveDockPrefs();
    showToast(nextVertical ? "Vertical Toolbar" : "Horizontal Toolbar");
  }

  function randomSeed() {
    return Math.floor(Math.random() * 1000000) + 1;
  }

  function screenToWorld(sx, sy) {
    return [sx - state.panX, sy - state.panY];
  }

  function simplifyPoints(points, minDistance) {
    if (points.length <= 2) return points;
    const out = [points[0]];
    for (let i = 1; i < points.length - 1; i++) {
      const prev = out[out.length - 1];
      const curr = points[i];
      const dist = Math.hypot(curr[0] - prev[0], curr[1] - prev[1]);
      if (dist >= minDistance) {
        out.push(curr);
      }
    }
    out.push(points[points.length - 1]);
    return out;
  }

  function getElementBounds(el) {
    if (el.type === "pen") {
      if (!el.points || el.points.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (const [px, py] of el.points) {
        if (px < minX) minX = px;
        if (py < minY) minY = py;
        if (px > maxX) maxX = px;
        if (py > maxY) maxY = py;
      }
      return { x: minX, y: minY, w: Math.max(8, maxX - minX), h: Math.max(8, maxY - minY) };
    }

    if (el.type === "text") {
      const lines = (el.text || "").split("\n");
      const fontSize = el.fontSize || 22;
      const maxChars = Math.max(...lines.map((l) => l.length), 1);
      const w = maxChars * fontSize * 0.58;
      const h = lines.length * fontSize * 1.28;
      return { x: el.x1, y: el.y1, w, h };
    }

    const minX = Math.min(el.x1, el.x2);
    const minY = Math.min(el.y1, el.y2);
    const w = Math.abs(el.x2 - el.x1);
    const h = Math.abs(el.y2 - el.y1);
    return { x: minX, y: minY, w, h };
  }

  function isPointNearElement(wx, wy, el, tolerance = 10) {
    const b = getElementBounds(el);
    if (
      wx < b.x - tolerance ||
      wx > b.x + b.w + tolerance ||
      wy < b.y - tolerance ||
      wy > b.y + b.h + tolerance
    ) {
      return false;
    }

    if (el.type === "pen" && el.points) {
      for (const [px, py] of el.points) {
        if (Math.hypot(wx - px, wy - py) <= tolerance + 4) return true;
      }
      return false;
    }

    if (el.type === "line" || el.type === "arrow") {
      const A = wx - el.x1;
      const B = wy - el.y1;
      const C = el.x2 - el.x1;
      const D = el.y2 - el.y1;
      const dot = A * C + B * D;
      const lenSq = C * C + D * D;
      const param = lenSq !== 0 ? Math.max(0, Math.min(1, dot / lenSq)) : 0;
      const xx = el.x1 + param * C;
      const yy = el.y1 + param * D;
      return Math.hypot(wx - xx, wy - yy) <= tolerance;
    }

    return true;
  }

  function translateElement(el, dx, dy) {
    if (el.type === "pen" && el.points) {
      el.points = el.points.map(([px, py]) => [px + dx, py + dy]);
    } else {
      el.x1 += dx;
      el.y1 += dy;
      if (typeof el.x2 === "number") el.x2 += dx;
      if (typeof el.y2 === "number") el.y2 += dy;
    }
  }

  function recognizeShapeFromPoints(points, baseProps) {
    if (!points || points.length < 5) {
      return Object.assign({}, baseProps, { type: "pen", points });
    }

    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const [px, py] of points) {
      if (px < minX) minX = px;
      if (py < minY) minY = py;
      if (px > maxX) maxX = px;
      if (py > maxY) maxY = py;
    }

    const w = maxX - minX;
    const h = maxY - minY;
    const diag = Math.hypot(w, h);
    if (diag < 20) {
      return Object.assign({}, baseProps, { type: "pen", points });
    }

    const first = points[0];
    const last = points[points.length - 1];
    const endDist = Math.hypot(last[0] - first[0], last[1] - first[1]);

    let pathLen = 0;
    for (let i = 1; i < points.length; i++) {
      pathLen += Math.hypot(
        points[i][0] - points[i - 1][0],
        points[i][1] - points[i - 1][1]
      );
    }

    if (endDist > diag * 0.85 && pathLen < endDist * 1.22) {
      return Object.assign({}, baseProps, {
        type: "line",
        x1: first[0],
        y1: first[1],
        x2: last[0],
        y2: last[1]
      });
    }

    if (endDist < diag * 0.42) {
      const cx = (minX + maxX) / 2;
      const cy = (minY + maxY) / 2;
      const rx = Math.max(w / 2, 1);
      const ry = Math.max(h / 2, 1);

      let radialErr = 0;
      let diamondErr = 0;
      for (const [px, py] of points) {
        const nx = (px - cx) / rx;
        const ny = (py - cy) / ry;
        radialErr += Math.abs(Math.hypot(nx, ny) - 1);
        diamondErr += Math.abs(Math.abs(nx) + Math.abs(ny) - 1);
      }
      radialErr /= points.length;
      diamondErr /= points.length;

      if (radialErr < 0.17) {
        return Object.assign({}, baseProps, {
          type: "ellipse",
          x1: minX,
          y1: minY,
          x2: maxX,
          y2: maxY
        });
      }
      if (diamondErr < 0.16) {
        return Object.assign({}, baseProps, {
          type: "diamond",
          x1: minX,
          y1: minY,
          x2: maxX,
          y2: maxY
        });
      }
      return Object.assign({}, baseProps, {
        type: "rectangle",
        x1: minX,
        y1: minY,
        x2: maxX,
        y2: maxY
      });
    }

    return Object.assign({}, baseProps, { type: "pen", points });
  }

  function drawElement(el) {
    const opts = {
      seed: el.seed,
      stroke: el.strokeColor,
      strokeWidth: el.strokeWidth,
      roughness: el.roughness,
      bowing: 1.15,
      fill: el.fillColor || undefined,
      fillStyle: "hachure"
    };

    switch (el.type) {
      case "pen":
      case "draw-to-shape": {
        if (!el.points || el.points.length === 0) return;
        if (el.points.length === 1) {
          rc.ellipse(el.points[0][0], el.points[0][1], 3, 3, opts);
        } else {
          const pts = simplifyPoints(el.points, 3.2);
          rc.curve(pts, Object.assign({}, opts, { roughness: Math.min(1.0, el.roughness * 0.55) }));
        }
        break;
      }

      case "line": {
        rc.line(el.x1, el.y1, el.x2, el.y2, opts);
        break;
      }

      case "arrow": {
        rc.line(el.x1, el.y1, el.x2, el.y2, opts);
        const dx = el.x2 - el.x1;
        const dy = el.y2 - el.y1;
        const len = Math.hypot(dx, dy);
        if (len > 4) {
          const angle = Math.atan2(dy, dx);
          const headLength = Math.min(22, Math.max(12, len * 0.25));
          const spread = Math.PI / 6.5;

          const xLeft = el.x2 - headLength * Math.cos(angle - spread);
          const yLeft = el.y2 - headLength * Math.sin(angle - spread);
          const xRight = el.x2 - headLength * Math.cos(angle + spread);
          const yRight = el.y2 - headLength * Math.sin(angle + spread);

          rc.line(el.x2, el.y2, xLeft, yLeft, Object.assign({}, opts, { seed: el.seed + 1 }));
          rc.line(el.x2, el.y2, xRight, yRight, Object.assign({}, opts, { seed: el.seed + 2 }));
        }
        break;
      }

      case "rectangle": {
        const rx = Math.min(el.x1, el.x2);
        const ry = Math.min(el.y1, el.y2);
        const rw = Math.abs(el.x2 - el.x1);
        const rh = Math.abs(el.y2 - el.y1);
        if (rw > 1 || rh > 1) {
          rc.rectangle(rx, ry, rw, rh, opts);
        }
        break;
      }

      case "diamond": {
        const mx = (el.x1 + el.x2) / 2;
        const my = (el.y1 + el.y2) / 2;
        const pts = [
          [mx, el.y1],
          [el.x2, my],
          [mx, el.y2],
          [el.x1, my]
        ];
        if (Math.abs(el.x2 - el.x1) > 1 || Math.abs(el.y2 - el.y1) > 1) {
          rc.polygon(pts, opts);
        }
        break;
      }

      case "ellipse": {
        const cx = (el.x1 + el.x2) / 2;
        const cy = (el.y1 + el.y2) / 2;
        const ew = Math.abs(el.x2 - el.x1);
        const eh = Math.abs(el.y2 - el.y1);
        if (ew > 1 || eh > 1) {
          rc.ellipse(cx, cy, ew, eh, opts);
        }
        break;
      }

      case "text": {
        if (!el.text) return;
        ctx.save();
        const fontSize = el.fontSize || 22;
        ctx.font = `${fontSize}px "Comic Sans MS", "Chalkboard SE", "Marker Felt", cursive, sans-serif`;
        ctx.fillStyle = el.strokeColor;
        ctx.textBaseline = "top";
        const lines = el.text.split("\n");
        for (let i = 0; i < lines.length; i++) {
          ctx.fillText(lines[i], el.x1, el.y1 + i * fontSize * 1.28);
        }
        ctx.restore();
        break;
      }
    }
  }

  // Ultra-Slick Spline Laser Ribbon Renderer
  function drawSmoothLaserTrail(pts, now, maxThickness, decayMs) {
    if (pts.length < 2) return;

    const smooth = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) {
      const p0 = pts[i];
      const p1 = pts[i + 1];
      const midX = (p0.x + p1.x) * 0.5;
      const midY = (p0.y + p1.y) * 0.5;
      const midT = (p0.t + p1.t) * 0.5;
      smooth.push(p0, { x: midX, y: midY, t: midT });
    }
    smooth.push(pts[pts.length - 1]);

    for (let i = 1; i < smooth.length; i++) {
      const p0 = smooth[i - 1];
      const p1 = smooth[i];
      const age = now - p1.t;
      const rawLife = Math.max(0, 1 - age / decayMs);
      const life = 1 - Math.pow(1 - rawLife, 3);
      const tailFactor = Math.pow(i / smooth.length, 0.85);
      const radius = Math.max(0.8, maxThickness * life * tailFactor);

      // 1. Soft Neon Crimson Outer Glow
      ctx.beginPath();
      ctx.moveTo(p0.x, p0.y);
      ctx.lineTo(p1.x, p1.y);
      ctx.strokeStyle = `rgba(255, 25, 25, ${(life * 0.28).toFixed(3)})`;
      ctx.lineWidth = radius * 2.8;
      ctx.stroke();

      // 2. Vibrant Red Laser Body
      ctx.beginPath();
      ctx.moveTo(p0.x, p0.y);
      ctx.lineTo(p1.x, p1.y);
      ctx.strokeStyle = `rgba(255, 43, 43, ${(life * 0.92).toFixed(3)})`;
      ctx.lineWidth = radius * 1.25;
      ctx.stroke();

      // 3. White-Hot Inner Filament Core
      ctx.beginPath();
      ctx.moveTo(p0.x, p0.y);
      ctx.lineTo(p1.x, p1.y);
      ctx.strokeStyle = `rgba(255, 235, 235, ${(life * 0.95).toFixed(3)})`;
      ctx.lineWidth = Math.max(0.7, radius * 0.48);
      ctx.stroke();
    }
  }

  function renderLaserTrails(now) {
    let hasActivePoints = false;

    ctx.save();
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    for (let tIdx = state.laserTrails.length - 1; tIdx >= 0; tIdx--) {
      const trail = state.laserTrails[tIdx];
      trail.points = trail.points.filter((pt) => now - pt.t < LASER_DECAY_MS);

      if (trail.points.length === 0) {
        if (trail !== state.activeLaserTrail) {
          state.laserTrails.splice(tIdx, 1);
        }
        continue;
      }

      hasActivePoints = true;
      drawSmoothLaserTrail(trail.points, now, 8.5, LASER_DECAY_MS);
    }

    const HOVER_DECAY_MS = 320;
    state.hoverLaserTrail.points = state.hoverLaserTrail.points.filter(
      (pt) => now - pt.t < HOVER_DECAY_MS
    );
    if (state.hoverLaserTrail.points.length > 1) {
      hasActivePoints = true;
      drawSmoothLaserTrail(state.hoverLaserTrail.points, now, 5.2, HOVER_DECAY_MS);
    }

    if (state.currentTool === "laser" && state.laserCursorPos && state.isActive) {
      const { x, y } = state.laserCursorPos;
      const isDown = state.isPointerDown;
      const headRadius = isDown ? 6.5 : 5.0;

      const grad = ctx.createRadialGradient(x, y, 1, x, y, headRadius * 3.6);
      grad.addColorStop(0, "rgba(255, 40, 40, 0.65)");
      grad.addColorStop(0.45, "rgba(255, 30, 30, 0.22)");
      grad.addColorStop(1, "rgba(255, 30, 30, 0)");

      ctx.beginPath();
      ctx.arc(x, y, headRadius * 3.6, 0, Math.PI * 2);
      ctx.fillStyle = grad;
      ctx.fill();

      ctx.beginPath();
      ctx.arc(x, y, headRadius, 0, Math.PI * 2);
      ctx.fillStyle = "#ff2424";
      ctx.fill();

      ctx.beginPath();
      ctx.arc(x, y, headRadius * 0.52, 0, Math.PI * 2);
      ctx.fillStyle = "#ffffff";
      ctx.fill();
    }

    ctx.restore();
    return hasActivePoints;
  }

  function ensureLaserLoop() {
    if (state.laserRafId !== null) return;
    function tick() {
      const hasPoints = renderScene();
      if (hasPoints) {
        state.laserRafId = requestAnimationFrame(tick);
      } else {
        state.laserRafId = null;
      }
    }
    state.laserRafId = requestAnimationFrame(tick);
  }

  function renderScene() {
    const now = performance.now();
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

    ctx.save();
    ctx.translate(state.panX, state.panY);

    for (let i = 0; i < state.elements.length; i++) {
      const el = state.elements[i];
      drawElement(el);

      if (state.selectedIndices.includes(i) && state.isActive) {
        const b = getElementBounds(el);
        ctx.save();
        ctx.strokeStyle = "#6965db";
        ctx.lineWidth = 1.5;
        ctx.setLineDash([5, 4]);
        ctx.strokeRect(b.x - 6, b.y - 6, b.w + 12, b.h + 12);
        ctx.restore();
      }
    }

    if (state.activeElement) {
      drawElement(state.activeElement);
    }

    if (state.selectionBox) {
      ctx.save();
      ctx.fillStyle = "rgba(105, 101, 219, 0.1)";
      ctx.strokeStyle = "#6965db";
      ctx.lineWidth = 1;
      const sx = Math.min(state.selectionBox.x1, state.selectionBox.x2);
      const sy = Math.min(state.selectionBox.y1, state.selectionBox.y2);
      const sw = Math.abs(state.selectionBox.x2 - state.selectionBox.x1);
      const sh = Math.abs(state.selectionBox.y2 - state.selectionBox.y1);
      ctx.fillRect(sx, sy, sw, sh);
      ctx.strokeRect(sx, sy, sw, sh);
      ctx.restore();
    }

    if (state.lassoPoints && state.lassoPoints.length > 1) {
      ctx.save();
      ctx.strokeStyle = "#6965db";
      ctx.fillStyle = "rgba(105, 101, 219, 0.08)";
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(state.lassoPoints[0][0], state.lassoPoints[0][1]);
      for (let i = 1; i < state.lassoPoints.length; i++) {
        ctx.lineTo(state.lassoPoints[i][0], state.lassoPoints[i][1]);
      }
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }

    ctx.restore();

    return renderLaserTrails(now);
  }

  function pushElement(el) {
    state.elements.push(el);
    state.redoStack = [];
  }

  function commitActiveTextInput() {
    if (textInput.style.display !== "block") return;
    const raw = textInput.value.trim();
    const wx = parseFloat(textInput.dataset.wx || "0");
    const wy = parseFloat(textInput.dataset.wy || "0");
    textInput.value = "";
    textInput.style.display = "none";

    if (raw.length > 0) {
      pushElement({
        type: "text",
        seed: randomSeed(),
        strokeColor: state.strokeColor,
        strokeWidth: state.strokeWidth,
        roughness: state.roughness,
        x1: wx,
        y1: wy,
        text: raw,
        fontSize: 22
      });
      if (!state.isToolLocked) {
        selectTool("select");
      }
      renderScene();
    }
  }

  function openTextInputAt(screenX, screenY) {
    commitActiveTextInput();
    const [wx, wy] = screenToWorld(screenX, screenY);
    textInput.dataset.wx = String(wx);
    textInput.dataset.wy = String(wy);
    textInput.style.left = `${screenX}px`;
    textInput.style.top = `${screenY - 12}px`;
    textInput.style.color = state.strokeColor;
    textInput.style.display = "block";
    textInput.value = "";
    setTimeout(() => textInput.focus(), 10);
  }

  textInput.addEventListener("keydown", function (e) {
    e.stopPropagation();
    if (e.key === "Escape" || (e.key === "Enter" && (e.metaKey || e.ctrlKey))) {
      e.preventDefault();
      commitActiveTextInput();
    }
  });

  textInput.addEventListener("blur", function () {
    commitActiveTextInput();
  });

  // Pointer Events on Canvas
  canvas.addEventListener("pointerdown", function (e) {
    if (!state.isActive || e.button !== 0) return;

    closeAllPopovers();
    if (textInput.style.display === "block") {
      commitActiveTextInput();
      return;
    }

    const sx = e.clientX;
    const sy = e.clientY;
    const [wx, wy] = screenToWorld(sx, sy);

    state.isPointerDown = true;
    state.dragStartX = sx;
    state.dragStartY = sy;
    canvas.setPointerCapture(e.pointerId);

    if (state.currentTool === "text") {
      state.isPointerDown = false;
      openTextInputAt(sx, sy);
      return;
    }

    if (state.currentTool === "hand") {
      document.body.classList.add("dragging");
      return;
    }

    if (state.currentTool === "laser") {
      state.hoverLaserTrail.points = [];
      const trail = { points: [{ x: sx, y: sy, t: performance.now() }] };
      state.laserTrails.push(trail);
      state.activeLaserTrail = trail;
      state.laserCursorPos = { x: sx, y: sy };
      ensureLaserLoop();
      return;
    }

    if (state.currentTool === "eraser") {
      eraseAtPoint(wx, wy);
      return;
    }

    if (state.currentTool === "bucket") {
      for (let i = state.elements.length - 1; i >= 0; i--) {
        if (isPointNearElement(wx, wy, state.elements[i], 8)) {
          state.elements[i].fillColor = state.strokeColor;
          state.elements[i].strokeColor = state.strokeColor;
          renderScene();
          break;
        }
      }
      state.isPointerDown = false;
      return;
    }

    if (state.currentTool === "select") {
      let hitIndex = -1;
      for (let i = state.elements.length - 1; i >= 0; i--) {
        if (isPointNearElement(wx, wy, state.elements[i], 10)) {
          hitIndex = i;
          break;
        }
      }

      if (hitIndex !== -1) {
        if (!state.selectedIndices.includes(hitIndex)) {
          state.selectedIndices = [hitIndex];
        }
        state.selectionBox = null;
      } else {
        state.selectedIndices = [];
        state.selectionBox = { x1: wx, y1: wy, x2: wx, y2: wy };
      }
      renderScene();
      return;
    }

    if (state.currentTool === "lasso") {
      state.selectedIndices = [];
      state.lassoPoints = [[wx, wy]];
      renderScene();
      return;
    }

    state.selectedIndices = [];
    state.activeElement = {
      type: state.currentTool,
      seed: randomSeed(),
      strokeColor: state.strokeColor,
      fillColor: state.fillEnabled ? state.strokeColor : undefined,
      strokeWidth: state.strokeWidth,
      roughness: state.roughness,
      x1: wx,
      y1: wy,
      x2: wx,
      y2: wy,
      points:
        state.currentTool === "pen" || state.currentTool === "draw-to-shape"
          ? [[wx, wy]]
          : undefined
    };

    renderScene();
  });

  canvas.addEventListener("pointermove", function (e) {
    const sx = e.clientX;
    const sy = e.clientY;
    const [wx, wy] = screenToWorld(sx, sy);

    if (state.currentTool === "laser") {
      const now = performance.now();
      state.laserCursorPos = { x: sx, y: sy };
      if (state.isPointerDown && state.activeLaserTrail) {
        state.activeLaserTrail.points.push({ x: sx, y: sy, t: now });
      } else {
        state.hoverLaserTrail.points.push({ x: sx, y: sy, t: now });
      }
      ensureLaserLoop();
      return;
    }

    if (!state.isPointerDown) return;

    if (state.currentTool === "hand") {
      state.panX += sx - state.dragStartX;
      state.dragStartX = sx;
      state.panY += sy - state.dragStartY;
      state.dragStartY = sy;
      renderScene();
      return;
    }

    if (state.currentTool === "eraser") {
      eraseAtPoint(wx, wy);
      return;
    }

    if (state.currentTool === "select") {
      if (state.selectionBox) {
        state.selectionBox.x2 = wx;
        state.selectionBox.y2 = wy;
        const bx = Math.min(state.selectionBox.x1, state.selectionBox.x2);
        const by = Math.min(state.selectionBox.y1, state.selectionBox.y2);
        const bw = Math.abs(state.selectionBox.x2 - state.selectionBox.x1);
        const bh = Math.abs(state.selectionBox.y2 - state.selectionBox.y1);

        state.selectedIndices = [];
        state.elements.forEach((el, idx) => {
          const b = getElementBounds(el);
          if (b.x + b.w >= bx && b.x <= bx + bw && b.y + b.h >= by && b.y <= by + bh) {
            state.selectedIndices.push(idx);
          }
        });
      } else if (state.selectedIndices.length > 0) {
        const dx = sx - state.dragStartX;
        const dy = sy - state.dragStartY;
        state.dragStartX = sx;
        state.dragStartY = sy;
        for (const idx of state.selectedIndices) {
          if (state.elements[idx]) {
            translateElement(state.elements[idx], dx, dy);
          }
        }
      }
      renderScene();
      return;
    }

    if (state.currentTool === "lasso" && state.lassoPoints) {
      state.lassoPoints.push([wx, wy]);
      renderScene();
      return;
    }

    if (!state.activeElement) return;

    if (state.activeElement.type === "pen" || state.activeElement.type === "draw-to-shape") {
      state.activeElement.points.push([wx, wy]);
    } else {
      let targetX = wx;
      let targetY = wy;
      if (e.shiftKey) {
        const dx = wx - state.activeElement.x1;
        const dy = wy - state.activeElement.y1;
        if (
          state.activeElement.type === "rectangle" ||
          state.activeElement.type === "diamond" ||
          state.activeElement.type === "ellipse"
        ) {
          const side = Math.max(Math.abs(dx), Math.abs(dy));
          targetX = state.activeElement.x1 + Math.sign(dx || 1) * side;
          targetY = state.activeElement.y1 + Math.sign(dy || 1) * side;
        } else if (
          state.activeElement.type === "line" ||
          state.activeElement.type === "arrow"
        ) {
          const angle = Math.atan2(dy, dx);
          const snapped = Math.round(angle / (Math.PI / 4)) * (Math.PI / 4);
          const dist = Math.hypot(dx, dy);
          targetX = state.activeElement.x1 + Math.cos(snapped) * dist;
          targetY = state.activeElement.y1 + Math.sin(snapped) * dist;
        }
      }
      state.activeElement.x2 = targetX;
      state.activeElement.y2 = targetY;
    }

    renderScene();
  });

  function finishPointerInteraction() {
    if (!state.isPointerDown) return;
    state.isPointerDown = false;
    document.body.classList.remove("dragging");

    if (state.currentTool === "laser") {
      state.activeLaserTrail = null;
      ensureLaserLoop();
      return;
    }

    if (state.currentTool === "select") {
      state.selectionBox = null;
      renderScene();
      return;
    }

    if (state.currentTool === "lasso" && state.lassoPoints) {
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (const [px, py] of state.lassoPoints) {
        if (px < minX) minX = px;
        if (py < minY) minY = py;
        if (px > maxX) maxX = px;
        if (py > maxY) maxY = py;
      }
      state.selectedIndices = [];
      state.elements.forEach((el, idx) => {
        const b = getElementBounds(el);
        const cx = b.x + b.w / 2;
        const cy = b.y + b.h / 2;
        if (cx >= minX && cx <= maxX && cy >= minY && cy <= maxY) {
          state.selectedIndices.push(idx);
        }
      });
      state.lassoPoints = null;
      selectTool("select");
      renderScene();
      return;
    }

    if (!state.activeElement) return;
    let el = state.activeElement;
    state.activeElement = null;

    if (el.type === "draw-to-shape") {
      el = recognizeShapeFromPoints(el.points, {
        seed: el.seed,
        strokeColor: el.strokeColor,
        fillColor: el.fillColor,
        strokeWidth: el.strokeWidth,
        roughness: el.roughness
      });
      pushElement(el);
    } else if (el.type === "pen") {
      if (el.points && el.points.length > 0) {
        pushElement(el);
      }
    } else {
      const dist = Math.hypot(el.x2 - el.x1, el.y2 - el.y1);
      if (dist > 2) {
        pushElement(el);
      }
    }

    renderScene();
  }

  canvas.addEventListener("pointerup", finishPointerInteraction);
  canvas.addEventListener("pointercancel", finishPointerInteraction);

  function eraseAtPoint(wx, wy) {
    let removed = false;
    for (let i = state.elements.length - 1; i >= 0; i--) {
      if (isPointNearElement(wx, wy, state.elements[i], 12)) {
        const [erased] = state.elements.splice(i, 1);
        state.redoStack.push(erased);
        removed = true;
      }
    }
    if (removed) {
      state.selectedIndices = [];
      renderScene();
    }
  }

  // Copy Canvas PNG to macOS NSPasteboard
  function copyCanvasToClipboard() {
    const prevSelected = [...state.selectedIndices];
    state.selectedIndices = [];
    renderScene();

    const dataURL = canvas.toDataURL("image/png");
    state.selectedIndices = prevSelected;
    renderScene();

    postToNative({ action: "copyImage", dataURL });
    showToast("Copied sketch PNG to Clipboard");
  }

  // Toolbar UI Event Listeners
  excaliDock.addEventListener("pointerdown", (e) => e.stopPropagation());

  function closeAllPopovers() {
    moreToolsMenu.classList.remove("open");
    colorPopover.classList.remove("open");
  }

  lockBtn.addEventListener("click", function () {
    toggleLock();
  });

  document.querySelectorAll(".tool-icon-btn[data-tool]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      closeAllPopovers();
      selectTool(btn.getAttribute("data-tool"));
    });
  });

  colorTriggerBtn.addEventListener("click", function (e) {
    e.stopPropagation();
    moreToolsMenu.classList.remove("open");
    colorPopover.classList.toggle("open");
  });

  moreToolsBtn.addEventListener("click", function (e) {
    e.stopPropagation();
    colorPopover.classList.remove("open");
    moreToolsMenu.classList.toggle("open");
  });

  clearBtn.addEventListener("click", function () {
    closeAllPopovers();
    clearCanvas();
  });

  document.querySelectorAll(".menu-item-btn[data-menu-tool]").forEach(function (item) {
    item.addEventListener("click", function () {
      const tool = item.getAttribute("data-menu-tool");
      closeAllPopovers();
      selectTool(tool);
    });
  });

  document.getElementById("menu-undo-btn").addEventListener("click", function () {
    closeAllPopovers();
    undo();
  });

  document.getElementById("menu-redo-btn").addEventListener("click", function () {
    closeAllPopovers();
    redo();
  });

  document.getElementById("menu-copy-btn").addEventListener("click", function () {
    closeAllPopovers();
    copyCanvasToClipboard();
  });

  document.getElementById("menu-orientation-btn").addEventListener("click", function () {
    closeAllPopovers();
    flipOrientationManually();
  });

  document.getElementById("menu-theme-btn").addEventListener("click", function () {
    closeAllPopovers();
    setDarkTheme(!state.darkMode, true);
  });

  document.getElementById("menu-clear-btn").addEventListener("click", function () {
    closeAllPopovers();
    clearCanvas();
  });

  document.getElementById("menu-exit-btn").addEventListener("click", function () {
    closeAllPopovers();
    postToNative({ action: "deactivate" });
  });

  // Stroke Color Swatches
  document.querySelectorAll(".color-swatch").forEach(function (swatch) {
    swatch.addEventListener("click", function () {
      const color = swatch.getAttribute("data-color");
      state.strokeColor = color;
      activeColorDot.style.background = color;
      document.querySelectorAll(".color-swatch").forEach((s) =>
        s.classList.toggle("active", s === swatch)
      );
      if (state.selectedIndices.length > 0) {
        for (const idx of state.selectedIndices) {
          if (state.elements[idx]) {
            state.elements[idx].strokeColor = color;
            if (state.elements[idx].fillColor) {
              state.elements[idx].fillColor = color;
            }
          }
        }
        renderScene();
      }
    });
  });

  // Stroke Width Controls
  document.querySelectorAll(".stroke-width-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      const w = parseFloat(btn.getAttribute("data-width") || "3.2");
      state.strokeWidth = w;
      document.querySelectorAll(".stroke-width-btn").forEach((b) =>
        b.classList.toggle("active", b === btn)
      );
      if (state.selectedIndices.length > 0) {
        for (const idx of state.selectedIndices) {
          if (state.elements[idx]) state.elements[idx].strokeWidth = w;
        }
        renderScene();
      }
    });
  });

  // Sloppiness / Roughness Controls
  document.querySelectorAll(".roughness-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      const r = parseFloat(btn.getAttribute("data-roughness") || "1.2");
      state.roughness = r;
      document.querySelectorAll(".roughness-btn").forEach((b) =>
        b.classList.toggle("active", b === btn)
      );
      if (state.selectedIndices.length > 0) {
        for (const idx of state.selectedIndices) {
          if (state.elements[idx]) state.elements[idx].roughness = r;
        }
        renderScene();
      }
    });
  });

  fillToggleBtn.addEventListener("click", function () {
    state.fillEnabled = !state.fillEnabled;
    fillToggleBtn.classList.toggle("active", state.fillEnabled);
    fillToggleBtn.textContent = state.fillEnabled ? "Fill: Hachure Sketch" : "Fill: Off";
    if (state.selectedIndices.length > 0) {
      for (const idx of state.selectedIndices) {
        if (state.elements[idx]) {
          state.elements[idx].fillColor = state.fillEnabled
            ? state.elements[idx].strokeColor
            : undefined;
        }
      }
      renderScene();
    }
  });

  function toggleLock() {
    state.isToolLocked = !state.isToolLocked;
    lockBtn.classList.toggle("active", state.isToolLocked);
  }

  // Keyboard Shortcuts while Active
  window.addEventListener("keydown", function (e) {
    if (!state.isActive) return;
    if (document.activeElement === textInput) return;

    if (e.key === "Escape") {
      e.preventDefault();
      if (
        moreToolsMenu.classList.contains("open") ||
        colorPopover.classList.contains("open")
      ) {
        closeAllPopovers();
      } else if (state.selectedIndices.length > 0) {
        state.selectedIndices = [];
        renderScene();
      } else {
        postToNative({ action: "deactivate" });
      }
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "z") {
      e.preventDefault();
      if (e.shiftKey) {
        redo();
      } else {
        undo();
      }
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "y") {
      e.preventDefault();
      redo();
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "c") {
      e.preventDefault();
      copyCanvasToClipboard();
      return;
    }

    if (e.key === "Backspace" || e.key === "Delete") {
      e.preventDefault();
      if (state.selectedIndices.length > 0) {
        const sorted = [...state.selectedIndices].sort((a, b) => b - a);
        for (const idx of sorted) {
          const [deleted] = state.elements.splice(idx, 1);
          if (deleted) state.redoStack.push(deleted);
        }
        state.selectedIndices = [];
        renderScene();
      } else {
        clearCanvas();
      }
      return;
    }

    if (e.shiftKey && e.key.toLowerCase() === "x") {
      e.preventDefault();
      selectTool("draw-to-shape");
      return;
    }

    if (!e.metaKey && !e.ctrlKey && !e.altKey) {
      switch (e.key.toLowerCase()) {
        case "q":
          e.preventDefault();
          toggleLock();
          break;
        case "h":
          e.preventDefault();
          selectTool("hand");
          break;
        case "v":
        case "1":
          e.preventDefault();
          selectTool("select");
          break;
        case "r":
        case "2":
          e.preventDefault();
          selectTool("rectangle");
          break;
        case "d":
        case "3":
          e.preventDefault();
          selectTool("diamond");
          break;
        case "o":
        case "4":
          e.preventDefault();
          selectTool("ellipse");
          break;
        case "a":
        case "5":
          e.preventDefault();
          selectTool("arrow");
          break;
        case "l":
        case "6":
          e.preventDefault();
          selectTool("line");
          break;
        case "p":
        case "7":
          e.preventDefault();
          selectTool("pen");
          break;
        case "t":
        case "8":
          e.preventDefault();
          selectTool("text");
          break;
        case "e":
        case "0":
          e.preventDefault();
          selectTool("eraser");
          break;
        case "k":
          e.preventDefault();
          selectTool("laser");
          break;
        case "b":
          e.preventDefault();
          selectTool("bucket");
          break;
        case "c":
          e.preventDefault();
          clearCanvas();
          break;
      }
    }
  });

  function selectTool(tool) {
    commitActiveTextInput();
    state.currentTool = tool;
    if (tool !== "laser") {
      state.laserCursorPos = null;
      state.hoverLaserTrail.points = [];
    }

    document.body.className = document.body.className
      .split(" ")
      .filter((c) => !c.startsWith("tool-"))
      .join(" ");
    document.body.classList.add(`tool-${tool}`);

    document.querySelectorAll(".tool-icon-btn[data-tool]").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tool") === tool);
    });

    document.querySelectorAll(".menu-item-btn[data-menu-tool]").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-menu-tool") === tool);
    });

    renderScene();
  }

  function undo() {
    if (state.elements.length > 0) {
      const popped = state.elements.pop();
      if (popped) state.redoStack.push(popped);
      state.selectedIndices = [];
      renderScene();
    }
  }

  function redo() {
    if (state.redoStack.length > 0) {
      const restored = state.redoStack.pop();
      if (restored) state.elements.push(restored);
      state.selectedIndices = [];
      renderScene();
    }
  }

  function clearCanvas() {
    commitActiveTextInput();
    if (state.elements.length > 0) {
      state.redoStack.push(...state.elements);
    }
    state.elements = [];
    state.selectedIndices = [];
    state.activeElement = null;
    state.laserTrails = [];
    state.hoverLaserTrail.points = [];
    state.panX = 0;
    state.panY = 0;
    renderScene();
  }

  function setActive(active, hideDrawingsWhenInactive) {
    commitActiveTextInput();
    closeAllPopovers();
    state.isActive = Boolean(active);
    state.hideWhenInactive = Boolean(hideDrawingsWhenInactive);
    document.body.classList.toggle("inactive", !state.isActive);
    document.body.classList.toggle("hide-when-inactive", state.hideWhenInactive);
    renderScene();
  }

  window.addEventListener("resize", resizeCanvas);
  loadDockPrefs();
  resizeCanvas();

  window.excaliCursor = {
    setActive: setActive,
    selectTool: selectTool,
    undo: undo,
    redo: redo,
    copyCanvasToClipboard: copyCanvasToClipboard,
    clearCanvas: clearCanvas
  };
})();
