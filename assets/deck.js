/* Initialisation commune des diapositives Formini · Formation DevOps */
(function () {
  const dayLabel = document.body.dataset.deck || 'Formation DevOps';
  const base = document.body.dataset.assets || '../assets/';
  const isPrint = /print-pdf/gi.test(window.location.search);

  function makeFooter() {
    const f = document.createElement('div');
    f.className = 'deck-footer';
    f.innerHTML =
      '<img class="logo-dark" src="' + base + 'formini-logo.svg" alt="Formini">' +
      '<img class="logo-light" src="' + base + 'formini-logo-light.svg" alt="Formini">' +
      '<span class="lbl">' + dayLabel + '</span>' +
      '<span class="n"></span>';
    return f;
  }

  const slidesEl = document.querySelector('.reveal .slides');
  const sections = Array.from(slidesEl.querySelectorAll(':scope > section'));
  let footer = null;

  // Photos : data-photo="nom.jpg" -> fond de diapositive (couverture, séparateurs)
  //          data-side-photo="nom.jpg" -> bandeau photo à droite (diapos de contenu)
  sections.forEach((s) => {
    if (s.dataset.photo) {
      s.setAttribute('data-background-image', base + 'img/' + s.dataset.photo);
      s.setAttribute('data-background-size', 'cover');
      s.setAttribute('data-background-position', s.dataset.photoPosition || 'center');
    }
    if (s.dataset.sidePhoto) {
      s.classList.add('has-photo');
      const d = document.createElement('div');
      d.className = 'side-photo';
      d.style.backgroundImage = 'url("' + base + 'img/' + s.dataset.sidePhoto + '")';
      if (s.dataset.photoPosition) d.style.backgroundPosition = s.dataset.photoPosition;
      s.appendChild(d);
    }
  });

  if (isPrint) {
    sections.forEach((s, i) => {
      const f = makeFooter();
      if (s.classList.contains('dark')) f.classList.add('dark');
      f.querySelector('.n').textContent = (i + 1) + ' / ' + sections.length;
      s.appendChild(f);
    });
  } else {
    footer = makeFooter();
    slidesEl.appendChild(footer);
  }

  Reveal.initialize({
    width: 1280,
    height: 720,
    margin: 0,
    minScale: 0.2,
    maxScale: 2.0,
    center: false,
    hash: true,
    controls: true,
    controlsLayout: 'edges',
    progress: true,
    slideNumber: false,
    transition: 'fade',
    transitionSpeed: 'fast',
    backgroundTransition: 'none',
    pdfSeparateFragments: false,
    plugins: [RevealHighlight, RevealNotes],
    highlight: { highlightOnLoad: true }
  });

  function sync(ev) {
    if (!footer) return;
    const cur = ev ? ev.currentSlide : Reveal.getCurrentSlide();
    footer.classList.toggle('dark', cur.classList.contains('dark'));
    const vp = document.querySelector('.reveal-viewport');
    if (vp) {
      vp.classList.toggle('on-dark', cur.classList.contains('dark'));
      vp.classList.toggle('on-atelier', cur.classList.contains('atelier'));
    }
    const idx = Reveal.getIndices();
    footer.querySelector('.n').textContent = (idx.h + 1) + ' / ' + sections.length;
  }
  Reveal.on('ready', sync);
  Reveal.on('slidechanged', sync);
})();
