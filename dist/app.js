const catalog = {
  coffee: {
    kicker: 'Ready when you are', title: 'Brew with intention.', description: 'A guided tasting that stays out of the way.',
    suggestions: ['Worka Sakaro', 'El Paraíso', 'House espresso'],
    notes: ['Citrus', 'Stone fruit', 'Floral', 'Chocolate', 'Caramel', 'Nutty', 'Tea-like', 'Earthy'],
    detailTitle: 'How did you make it?',
    details: [['Method', 'select', ['V60', 'Espresso', 'AeroPress', 'Other']], ['Dose', 'input', '15 g'], ['Water', 'input', '250 g'], ['Grind', 'input', 'Setting 18'], ['Temperature', 'input', '94°C'], ['Total time', 'input', '2:45']]
  },
  wine: {
    kicker: 'Open a bottle, notice more', title: 'Meet the wine in front of you.', description: 'A few prompts. Your own point of view.',
    suggestions: ['Rioja Reserva 2018', 'Willamette Pinot Noir', 'Loire Chenin Blanc'],
    notes: ['Red fruit', 'Dark fruit', 'Floral', 'Herbal', 'Earthy', 'Oak', 'Spice', 'Mineral'],
    detailTitle: 'A little context?',
    details: [['Setting', 'select', ['At home', 'Restaurant', 'Tasting', 'Other']], ['Vintage', 'input', '2018'], ['Glass', 'select', ['Universal', 'Burgundy', 'Bordeaux', 'Other']], ['Opened', 'input', '30 min ago'], ['With food', 'input', 'Optional'], ['Serving temp.', 'input', 'Cellar cool']]
  },
  scotch: {
    kicker: 'Take your time', title: 'Follow the finish.', description: 'Capture the character without overthinking it.',
    suggestions: ['Talisker 10', 'GlenDronach 12', 'Ardbeg Uigeadail'],
    notes: ['Smoke', 'Coastal', 'Honey', 'Dried fruit', 'Vanilla', 'Spice', 'Oak', 'Malt'],
    detailTitle: 'How did you taste it?',
    details: [['Serve', 'select', ['Neat', 'With water', 'Over ice']], ['Pour', 'input', '1 oz'], ['Water added', 'input', 'None'], ['Glass', 'select', ['Glencairn', 'Tumbler', 'Other']], ['Setting', 'input', 'At home'], ['Rested', 'input', '10 min']]
  }
};

const state = { category: 'coffee', step: 1, reaction: '', notes: [] };
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const dialog = $('#tastingDialog');

function setCategory(category) {
  state.category = category;
  const item = catalog[category];
  $$('.category').forEach(btn => {
    const selected = btn.dataset.category === category;
    btn.classList.toggle('active', selected);
    btn.setAttribute('aria-selected', selected);
  });
  $('#focusKicker').textContent = item.kicker;
  $('#focusTitle').textContent = item.title;
  $('#focusDescription').textContent = item.description;
  $('#specimen').className = `specimen ${category}`;
  $('#focusCard').className = `focus-card ${category === 'coffee' ? '' : category + '-theme'}`;
}

function showView(name) {
  $$('.view').forEach(v => v.classList.remove('is-active'));
  $$('.nav-item').forEach(v => v.classList.remove('active'));
  if (name === 'journal') {
    $('#journalView').classList.add('is-active');
    $('[data-nav="journal"]').classList.add('active');
    renderJournal();
  } else {
    $('#homeView').classList.add('is-active');
    $('[data-nav="home"]').classList.add('active');
  }
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function openTasting() {
  state.step = 1; state.reaction = ''; state.notes = [];
  $('#productName').value = '';
  $('#personalNote').value = '';
  $$('.reactions button').forEach(b => b.classList.remove('selected'));
  buildCategoryFields();
  updateStep();
  dialog.showModal();
  setTimeout(() => $('#productName').focus(), 180);
}

function buildCategoryFields() {
  const item = catalog[state.category];
  $('#stepEyebrow').textContent = `${capitalize(state.category)} tasting`;
  $('#suggestions').innerHTML = item.suggestions.map(s => `<button type="button" class="suggestion">${s}</button>`).join('');
  $('#noteCloud').innerHTML = item.notes.map(n => `<button type="button" class="note-chip" data-note="${n}">${n}</button>`).join('');
  $('#detailTitle').textContent = item.detailTitle;
  $('#detailPanel').innerHTML = item.details.map(([label, type, value]) => {
    if (type === 'select') return `<div class="mini-field"><label>${label}</label><select>${value.map(v => `<option>${v}</option>`).join('')}</select></div>`;
    return `<div class="mini-field"><label>${label}</label><input value="${value}"></div>`;
  }).join('');
  $$('.suggestion').forEach(b => b.addEventListener('click', () => { $('#productName').value = b.textContent; }));
  $$('.note-chip').forEach(b => b.addEventListener('click', () => {
    b.classList.toggle('selected');
    state.notes = $$('.note-chip.selected').map(n => n.dataset.note);
  }));
}

function updateStep() {
  $$('.step').forEach(s => s.classList.toggle('is-active', Number(s.dataset.step) === state.step));
  const final = state.step === 5;
  $('#stepCount').textContent = final ? 'Complete' : `${state.step} of 4`;
  $('#progressBar').style.width = `${Math.min(state.step, 4) * 25}%`;
  $('#prevStep').style.visibility = state.step === 1 || final ? 'hidden' : 'visible';
  $('#saveExit').style.visibility = final ? 'hidden' : 'visible';
  $('#nextStep').innerHTML = final ? 'Return home' : state.step === 4 ? 'Save tasting <span>✓</span>' : 'Continue <span>→</span>';
}

function nextStep() {
  if (state.step === 1 && !$('#productName').value.trim()) {
    $('#productName').focus(); showToast('Add a name—or choose a suggestion.'); return;
  }
  if (state.step === 5) { dialog.close(); showView('home'); return; }
  if (state.step === 4) { saveTasting(); state.step = 5; updateStep(); return; }
  state.step += 1; updateStep();
}

function saveTasting() {
  const entry = {
    id: Date.now(), category: state.category, name: $('#productName').value.trim(),
    reaction: state.reaction || 'Noted', notes: state.notes,
    personalNote: $('#personalNote').value.trim(), date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  };
  const saved = JSON.parse(localStorage.getItem('palate-tastings') || '[]');
  localStorage.setItem('palate-tastings', JSON.stringify([entry, ...saved]));
  $('#successTitle').textContent = `${entry.name}, remembered.`;
  $('#successCopy').textContent = entry.notes.length ? `You noticed ${naturalList(entry.notes)}.` : 'A simple impression is still a useful one.';
  $('#successOrb').style.background = orbFor(entry.category);
  $('#summaryCard').innerHTML = `<strong>${entry.reaction}</strong>${capitalize(entry.category)}${entry.notes.length ? ` · ${entry.notes.join(' · ')}` : ''}`;
  addRecent(entry);
}

function addRecent(entry) {
  const row = document.createElement('button');
  row.className = 'tasting-row';
  row.innerHTML = `<span class="drink-dot ${entry.category}-dot"></span><span class="tasting-main"><strong>${entry.name}</strong><small>${capitalize(entry.category)} · ${entry.reaction.toLowerCase()}</small></span><span class="tasting-date">Today</span><span class="chevron">›</span>`;
  $('#tastingList').prepend(row);
}

function renderJournal() {
  const saved = JSON.parse(localStorage.getItem('palate-tastings') || '[]');
  const samples = [
    { category: 'coffee', name: 'Ethiopia · Worka Sakaro', reaction: 'Lovely', notes: ['Bergamot', 'Peach'], date: 'Oct 23' },
    { category: 'wine', name: 'Rioja Reserva · 2018', reaction: 'Memorable', notes: ['Cherry', 'Leather'], date: 'Oct 18' },
    { category: 'scotch', name: 'Talisker 10', reaction: 'Interesting', notes: ['Smoke', 'Coastal'], date: 'Oct 12' }
  ];
  $('#journalGrid').innerHTML = [...saved, ...samples].map(e => `<article class="journal-card"><div><span class="drink-dot ${e.category}-dot"></span><h3>${e.name}</h3><p>${e.notes?.length ? e.notes.join(' · ') : 'A first impression, saved.'}</p></div><footer><span>${e.reaction}</span><span>${e.date}</span></footer></article>`).join('');
}

function showToast(message) {
  const toast = $('#toast'); toast.textContent = message; toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 2200);
}

function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function naturalList(a) { return a.length === 1 ? a[0] : `${a.slice(0,-1).join(', ')} and ${a.at(-1)}`; }
function orbFor(category) { return category === 'wine' ? 'radial-gradient(circle at 40% 35%, #aa5a65, #652832 55%, #281317)' : category === 'scotch' ? 'radial-gradient(circle at 40% 35%, #e4a452, #965621 55%, #352014)' : 'radial-gradient(circle at 40% 35%, #b87b59, #613927 55%, #1f1713)'; }

$$('.category').forEach(b => b.addEventListener('click', () => setCategory(b.dataset.category)));
$('#beginTasting').addEventListener('click', openTasting);
$('#quickAdd').addEventListener('click', openTasting);
$('#nextStep').addEventListener('click', nextStep);
$('#prevStep').addEventListener('click', () => { if (state.step > 1) { state.step -= 1; updateStep(); } });
$('#saveExit').addEventListener('click', () => { showToast('Draft saved for later.'); dialog.close(); });
$$('.reactions button').forEach(b => b.addEventListener('click', () => { $$('.reactions button').forEach(x => x.classList.remove('selected')); b.classList.add('selected'); state.reaction = b.dataset.reaction; }));
$$('[data-home]').forEach(b => b.addEventListener('click', () => showView('home')));
$('#viewJournal').addEventListener('click', () => showView('journal'));
$$('.nav-item').forEach(b => b.addEventListener('click', () => {
  if (['home', 'journal'].includes(b.dataset.nav)) showView(b.dataset.nav);
  else showToast(`${capitalize(b.dataset.nav)} is intentionally out of scope—for now.`);
}));
$$('.filter').forEach(b => b.addEventListener('click', () => { $$('.filter').forEach(x => x.classList.remove('active')); b.classList.add('active'); showToast(`${b.textContent} filter selected.`); }));
setCategory('coffee');
renderJournal();
