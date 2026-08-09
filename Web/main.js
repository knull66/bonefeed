(() => {
  // Boot splash — one line at a time, slow enough to read
  const boot = document.getElementById("boot");
  if (boot) {
    const fill = boot.querySelector("[data-boot-fill]");
    const pctEl = boot.querySelector("[data-boot-pct]");
    const lineEl = boot.querySelector("[data-boot-line]");
    const lines = [
      "Loading your bags…",
      "Checking if it's still early…",
      "Asking Binance very politely…",
      "Watching charts so you don't have to…",
      "Warming up the notch…",
      "Not placing trades. Promise.",
      "Feeding the skull…",
    ];
    const lineHoldMs = 1800;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const setLine = (text) => {
      if (!lineEl) return;
      lineEl.classList.add("is-swap");
      window.setTimeout(() => {
        lineEl.textContent = text;
        lineEl.classList.remove("is-swap");
      }, 180);
    };

    const setProgress = (pct) => {
      const value = Math.max(1, Math.min(100, Math.round(pct)));
      if (pctEl) pctEl.textContent = String(value);
      if (fill) fill.style.width = `${value}%`;
    };

    const finish = () => {
      boot.classList.add("is-done");
      boot.setAttribute("aria-busy", "false");
      document.body.classList.remove("is-booting");
      window.setTimeout(() => boot.remove(), 600);
    };

    if (reduce) {
      setProgress(100);
      setLine("Radar online.");
      window.setTimeout(finish, 250);
    } else {
      let index = 0;
      const showNext = () => {
        if (index >= lines.length) {
          setProgress(100);
          setLine("Radar online.");
          window.setTimeout(finish, 1100);
          return;
        }
        setLine(lines[index]);
        setProgress(((index + 1) / (lines.length + 1)) * 100);
        index += 1;
        window.setTimeout(showNext, lineHoldMs);
      };
      setProgress(1);
      showNext();
    }
  }

  document.querySelectorAll(".ticker").forEach((el) => {
    el.innerHTML = el.innerHTML + el.innerHTML;
  });

  // Notch mode slider: Ticker <-> P2P dock
  const notchRoot = document.querySelector("[data-notch-slider]");
  if (notchRoot) {
    const slides = [...notchRoot.querySelectorAll(".notch-slide")];
    const tabs = [...notchRoot.querySelectorAll(".notch-tab")];
    const caption = notchRoot.querySelector("[data-notch-caption]");
    const captions = [
      "Prices in the notch · hover for a quick peek",
      "Open P2P · timer stays so you don't miss it",
    ];
    let index = 0;
    let timer;

    const go = (i) => {
      index = (i + slides.length) % slides.length;
      notchRoot.dataset.index = String(index);
      slides.forEach((slide, si) => slide.classList.toggle("is-active", si === index));
      tabs.forEach((tab, ti) => {
        const on = ti === index;
        tab.classList.toggle("is-active", on);
        tab.setAttribute("aria-selected", on ? "true" : "false");
      });
      if (caption) caption.textContent = captions[index] || "";
    };

    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        go(Number(tab.dataset.goto || 0));
        restart();
      });
    });

    const restart = () => {
      clearInterval(timer);
      timer = setInterval(() => go(index + 1), 5200);
    };

    notchRoot.addEventListener("mouseenter", () => clearInterval(timer));
    notchRoot.addEventListener("mouseleave", restart);
    go(0);
    restart();
  }

  // Demo countdown on P2P dock
  const countdowns = document.querySelectorAll("[data-countdown]");
  if (countdowns.length) {
    let seconds = 3 * 60 + 57;
    const tick = () => {
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      const label = `${m}:${String(s).padStart(2, "0")}`;
      countdowns.forEach((el) => {
        el.textContent = label;
      });
      seconds = seconds > 0 ? seconds - 1 : 3 * 60 + 57;
    };
    tick();
    setInterval(tick, 1000);
  }

  const themes = [
    {
      id: "blvck",
      title: "BLVCK",
      blurb: "Matte black, bright gold signals",
      vars: {
        "--pm-bg": "#0a0a0a",
        "--pm-bg-mid": "#121212",
        "--pm-panel": "#1a1a1a",
        "--pm-text": "#f5f2eb",
        "--pm-muted": "#7f7d78",
        "--pm-accent": "#faf7f0",
        "--pm-cool": "#d1d1cc",
        "--pm-up": "#8cdb9e",
        "--pm-warn": "#ffd647",
        "--pm-danger": "#f2515c",
        "--pm-tab-on-fg": "#0a0a0a",
      },
    },
    {
      id: "binance",
      title: "BINANCE",
      blurb: "Binance yellow & dark UI",
      vars: {
        "--pm-bg": "#0b0e11",
        "--pm-bg-mid": "#171a1f",
        "--pm-panel": "#1e2026",
        "--pm-text": "#eaecf0",
        "--pm-muted": "#848e9c",
        "--pm-accent": "#f0b90b",
        "--pm-cool": "#0ecb81",
        "--pm-up": "#0ecb81",
        "--pm-warn": "#f0b90b",
        "--pm-danger": "#f6465d",
        "--pm-tab-on-fg": "#0b0e11",
      },
    },
    {
      id: "cyber-dim",
      title: "CYBER DIM",
      blurb: "Soft neon, less eye strain",
      vars: {
        "--pm-bg": "#0d0a12",
        "--pm-bg-mid": "#140d1c",
        "--pm-panel": "#17121f",
        "--pm-text": "#d1d6e6",
        "--pm-muted": "#6b6685",
        "--pm-accent": "#c75294",
        "--pm-cool": "#47adc0",
        "--pm-up": "#47adc0",
        "--pm-warn": "#d1ad47",
        "--pm-danger": "#d1596b",
        "--pm-tab-on-fg": "#0d0a12",
      },
    },
    {
      id: "cyber-neon",
      title: "CYBER NEON",
      blurb: "Strong magenta / cyan",
      vars: {
        "--pm-bg": "#0a0514",
        "--pm-bg-mid": "#1a082e",
        "--pm-panel": "#140a24",
        "--pm-text": "#ebf2ff",
        "--pm-muted": "#8c7ab8",
        "--pm-accent": "#ff33b8",
        "--pm-cool": "#00f2ff",
        "--pm-up": "#00f2ff",
        "--pm-warn": "#ffeb26",
        "--pm-danger": "#ff476b",
        "--pm-tab-on-fg": "#0a0514",
      },
    },
    {
      id: "phosphor",
      title: "PHOSPHOR",
      blurb: "Green CRT terminal",
      vars: {
        "--pm-bg": "#0a0d0a",
        "--pm-bg-mid": "#0f1410",
        "--pm-panel": "#121712",
        "--pm-text": "#b8e6ad",
        "--pm-muted": "#597a57",
        "--pm-accent": "#66d961",
        "--pm-cool": "#73bfa6",
        "--pm-up": "#66d961",
        "--pm-warn": "#d9b340",
        "--pm-danger": "#d95947",
        "--pm-tab-on-fg": "#0a0d0a",
      },
    },
    {
      id: "noir",
      title: "NOIR",
      blurb: "Near monochrome",
      vars: {
        "--pm-bg": "#0a0a0b",
        "--pm-bg-mid": "#121214",
        "--pm-panel": "#151517",
        "--pm-text": "#c7c7cc",
        "--pm-muted": "#66666e",
        "--pm-accent": "#8c9eb2",
        "--pm-cool": "#73949e",
        "--pm-up": "#8c9eb2",
        "--pm-warn": "#b89e66",
        "--pm-danger": "#b86b6b",
        "--pm-tab-on-fg": "#0a0a0b",
      },
    },
    {
      id: "mac-dark",
      title: "MAC DARK",
      blurb: "Native macOS dark",
      vars: {
        "--pm-bg": "#1c1c1e",
        "--pm-bg-mid": "#242426",
        "--pm-panel": "#2c2c2e",
        "--pm-text": "#ebebf0",
        "--pm-muted": "#8e8e93",
        "--pm-accent": "#0a84ff",
        "--pm-cool": "#30d158",
        "--pm-up": "#30d158",
        "--pm-warn": "#ffd60a",
        "--pm-danger": "#ff453a",
        "--pm-tab-on-fg": "#ffffff",
      },
    },
    {
      id: "mac-light",
      title: "MAC LIGHT",
      blurb: "Native macOS light",
      vars: {
        "--pm-bg": "#f2f2f7",
        "--pm-bg-mid": "#fafafa",
        "--pm-panel": "#ffffff",
        "--pm-text": "#1c1c1e",
        "--pm-muted": "#8e8e93",
        "--pm-accent": "#007aff",
        "--pm-cool": "#34c759",
        "--pm-up": "#34c759",
        "--pm-warn": "#ff9f0a",
        "--pm-danger": "#ff3b30",
        "--pm-tab-on-fg": "#ffffff",
      },
    },
  ];

  const chrome = document.querySelector(".panel-chrome");
  const themeTitle = document.querySelector(".theme-title");
  const themeBlurb = document.querySelector(".theme-blurb");
  const themeBadge = document.querySelector(".panel-theme");
  const dots = document.querySelector(".theme-dots");
  const prev = document.querySelector(".theme-nav.prev");
  const next = document.querySelector(".theme-nav.next");
  if (!chrome || !themeTitle || !themeBlurb || !dots || !prev || !next) return;

  let themeIndex = 0;

  themes.forEach((theme, i) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.setAttribute("aria-label", theme.title);
    btn.addEventListener("click", () => applyTheme(i));
    dots.appendChild(btn);
  });

  function applyTheme(i) {
    themeIndex = (i + themes.length) % themes.length;
    const theme = themes[themeIndex];
    Object.entries(theme.vars).forEach(([key, value]) => {
      chrome.style.setProperty(key, value);
    });
    chrome.dataset.theme = theme.id;
    themeTitle.textContent = theme.title;
    themeBlurb.textContent = theme.blurb;
    if (themeBadge) themeBadge.textContent = theme.title;
    dots.querySelectorAll("button").forEach((btn, di) => {
      btn.classList.toggle("on", di === themeIndex);
    });
  }

  prev.addEventListener("click", () => applyTheme(themeIndex - 1));
  next.addEventListener("click", () => applyTheme(themeIndex + 1));

  let autoTimer = setInterval(() => applyTheme(themeIndex + 1), 4200);
  const slider = document.querySelector(".theme-slider");
  const pause = () => clearInterval(autoTimer);
  const resume = () => {
    pause();
    autoTimer = setInterval(() => applyTheme(themeIndex + 1), 4200);
  };
  slider?.addEventListener("mouseenter", pause);
  slider?.addEventListener("mouseleave", resume);
  chrome.addEventListener("mouseenter", pause);
  chrome.addEventListener("mouseleave", resume);

  applyTheme(0);
})();
