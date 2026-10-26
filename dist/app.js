const catalog = {
  coffee: {
    kicker: 'Ready when you are', title: 'Brew with intention.', description: 'A guided tasting that stays out of the way.',
    suggestions: ['Worka Sakaro', 'El Paraíso', 'House espresso'],
    notes: ['Citrus', 'Stone fruit', 'Floral', 'Chocolate', 'Caramel', 'Nutty', 'Tea-like', 'Earthy'],
    detailTitle: 'How did you make it?',
    details: [['Method', 'select', ['V60', 'Espresso', 'AeroPress', 'Other']], ['Grinder', 'input', 'Timemore 078S'], ['Espresso machine', 'input', 'Not set'], ['Dose', 'input', '15 g'], ['Water', 'input', '250 g'], ['Grind', 'input', 'Setting 18'], ['Temperature', 'input', '199°F'], ['Total time', 'input', '2:45']]
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
const TASTINGS_KEY = 'palate-tastings';
const DRAFT_KEY = 'palate-draft';
const samples = [
  { id: 'sample-ethiopia', category: 'coffee', name: 'Ethiopia · Worka Sakaro', reaction: 'Lovely', notes: ['Bergamot', 'Peach'], date: 'Oct 23' },
  { id: 'sample-rioja', category: 'wine', name: 'Rioja Reserva · 2018', reaction: 'Memorable', notes: ['Cherry', 'Leather'], date: 'Oct 18' },
  { id: 'sample-talisker', category: 'scotch', name: 'Talisker 10', reaction: 'Interesting', notes: ['Smoke', 'Coastal'], date: 'Oct 12' }
];
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const dialog = $('#tastingDialog');
const productDialog = $('#productDialog');

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
  const draft = readDraft();
  state.step = 1; state.reaction = draft?.reaction || ''; state.notes = draft?.notes || [];
  if (draft?.category) setCategory(draft.category);
  $('#productName').value = draft?.name || '';
  $('#personalNote').value = draft?.personalNote || '';
  $$('.reactions button').forEach(b => b.classList.remove('selected'));
  buildCategoryFields();
  $$('.reactions button').forEach(b => b.classList.toggle('selected', b.dataset.reaction === state.reaction));
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
    const field = label.toLowerCase().replace(/[^a-z]+/g, '-').replace(/-$/, '');
    if (type === 'select') return `<div class="mini-field"><label>${label}</label><select data-detail="${field}">${value.map(v => `<option>${v}</option>`).join('')}</select></div>`;
    return `<div class="mini-field"><label>${label}</label><input data-detail="${field}" value="${value}"></div>`;
  }).join('');
  const existingGuidance = $('#ratioGuidance');
  if (state.category === 'coffee') {
    if (!existingGuidance) $('#detailPanel').insertAdjacentHTML('afterend', '<aside class="ratio-guidance" id="ratioGuidance"><span class="ratio-mark">↗</span><div><p class="eyebrow">Brew ratio</p><strong id="ratioValue">16.7:1</strong><p id="ratioCopy">A balanced V60 starting point is usually 15–17:1. You’re in range.</p></div></aside>');
    updateRatioGuidance();
    $('#detailPanel').querySelectorAll('[data-detail="dose"], [data-detail="water"], [data-detail="method"]').forEach(field => field.addEventListener('input', updateRatioGuidance));
    $('#detailPanel').querySelector('[data-detail="method"]')?.addEventListener('change', updateRatioGuidance);
  } else {
    existingGuidance?.remove();
  }
  $$('.suggestion').forEach(b => b.addEventListener('click', () => { $('#productName').value = b.textContent; }));
  $$('.note-chip').forEach(b => b.addEventListener('click', () => {
    b.classList.toggle('selected', !b.classList.contains('selected'));
    state.notes = $$('.note-chip.selected').map(n => n.dataset.note);
  }));
  $$('.note-chip').forEach(b => b.classList.toggle('selected', state.notes.includes(b.dataset.note)));
}

function numericValue(selector) { return Number.parseFloat($(selector)?.value?.replace(/[^0-9.]/g, '')); }

function updateRatioGuidance() {
  const dose = numericValue('[data-detail="dose"]');
  const water = numericValue('[data-detail="water"]');
  const method = $('[data-detail="method"]')?.value || 'V60';
  const ratio = water / dose;
  if (!Number.isFinite(ratio) || ratio <= 0) {
    $('#ratioValue').textContent = '—';
    $('#ratioCopy').textContent = 'Add a dose and water weight to see your brew ratio.';
    return;
  }
  $('#ratioValue').textContent = `${ratio.toFixed(1)}:1`;
  if (method === 'V60') {
    $('#ratioCopy').textContent = ratio < 15 ? 'A little concentrated for a V60. A common starting range is 15–17:1.' : ratio > 17 ? 'A little more dilute for a V60. A common starting range is 15–17:1.' : 'A balanced V60 starting point is usually 15–17:1. You’re in range.';
  } else if (method === 'Espresso') {
    $('#ratioCopy').textContent = 'For espresso, compare dose to beverage yield instead—1:2 is a useful first test.';
  } else {
    $('#ratioCopy').textContent = 'This is a reference point, not a rule. Let the cup guide the next adjustment.';
  }
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
  const saved = readTastings();
  localStorage.setItem(TASTINGS_KEY, JSON.stringify([entry, ...saved]));
  localStorage.removeItem(DRAFT_KEY);
  $('#successTitle').textContent = `${entry.name}, remembered.`;
  $('#successCopy').textContent = entry.notes.length ? `You noticed ${naturalList(entry.notes)}.` : 'A simple impression is still a useful one.';
  $('#successOrb').style.background = orbFor(entry.category);
  $('#summaryCard').innerHTML = `<strong>${entry.reaction}</strong>${capitalize(entry.category)}${entry.notes.length ? ` · ${entry.notes.join(' · ')}` : ''}`;
  addRecent(entry);
  renderJournal(activeFilter());
}

function addRecent(entry) {
  const row = document.createElement('button');
  row.className = 'tasting-row';
  row.innerHTML = `<span class="drink-dot ${entry.category}-dot"></span><span class="tasting-main"><strong>${escapeHtml(entry.name)}</strong><small>${capitalize(entry.category)} · ${escapeHtml(entry.reaction.toLowerCase())}</small></span><span class="tasting-date">Today</span><span class="chevron">›</span>`;
  $('#tastingList').prepend(row);
}

function renderRecent() {
  const saved = readTastings();
  const recent = [...saved, ...samples.filter(sample => !saved.some(entry => entry.name === sample.name))].slice(0, 3);
  $('#tastingList').innerHTML = '';
  recent.slice().reverse().forEach(addRecent);
}

function activeFilter() { return $('.filter.active')?.dataset.filter || 'all'; }

function productKey(entry) { return `${entry.category}:${entry.name.trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()}`; }

function groupedProducts(filter = 'all') {
  const grouped = new Map();
  [...readTastings(), ...samples].forEach(entry => {
    if (filter !== 'all' && entry.category !== filter) return;
    const key = productKey(entry);
    const product = grouped.get(key) || { key, category: entry.category, name: entry.name, tastings: [] };
    product.tastings.push(entry);
    grouped.set(key, product);
  });
  return [...grouped.values()];
}

function renderJournal(filter = 'all') {
  const products = groupedProducts(filter);
  $('#journalGrid').innerHTML = products.map(product => {
    const latest = product.tastings[0];
    const count = product.tastings.length;
    const notes = latest.notes?.length ? latest.notes.map(escapeHtml).join(' · ') : 'A first impression, saved.';
    return `<button class="journal-card product-card" data-product-key="${escapeHtml(product.key)}"><div><span class="drink-dot ${product.category}-dot"></span><h3>${escapeHtml(product.name)}</h3><p>${notes}</p></div><footer><span>${count} tasting${count === 1 ? '' : 's'}</span><span>${escapeHtml(latest.date)}</span></footer></button>`;
  }).join('') || '<p class="empty-state">Nothing here yet. Your next tasting will find its place.</p>';
  $$('.product-card').forEach(card => card.addEventListener('click', () => openProduct(card.dataset.productKey)));
}

function openProduct(key) {
  const product = groupedProducts().find(item => item.key === key);
  if (!product) return;
  const count = product.tastings.length;
  const latest = product.tastings[0];
  $('#productDot').className = `drink-dot ${product.category}-dot`;
  $('#productCategory').textContent = capitalize(product.category);
  $('#productDialogTitle').textContent = product.name;
  $('#productSummary').textContent = count === 1 ? `One ${capitalize(product.category).toLowerCase()} tasting, ready to become a useful reference point.` : `${count} tastings across time. Notice what stays, and what changes.`;
  $('#historyCount').textContent = `${count} tasting${count === 1 ? '' : 's'}`;
  $('#historyList').innerHTML = product.tastings.map(entry => `<article class="history-entry"><div><strong>${escapeHtml(entry.reaction)}</strong><p>${entry.notes?.length ? entry.notes.map(escapeHtml).join(' · ') : 'A simple impression, saved.'}${entry.personalNote ? ` — ${escapeHtml(entry.personalNote)}` : ''}</p></div><time>${escapeHtml(entry.date)}</time></article>`).join('');
  productDialog.showModal();
}

function readTastings() { return JSON.parse(localStorage.getItem(TASTINGS_KEY) || '[]'); }
function readDraft() { return JSON.parse(localStorage.getItem(DRAFT_KEY) || 'null'); }
function saveDraft() {
  const draft = { category: state.category, name: $('#productName').value.trim(), reaction: state.reaction, notes: state.notes, personalNote: $('#personalNote').value.trim() };
  localStorage.setItem(DRAFT_KEY, JSON.stringify(draft));
}
function escapeHtml(value) { const node = document.createElement('span'); node.textContent = value || ''; return node.innerHTML; }

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
$('#saveExit').addEventListener('click', () => { saveDraft(); showToast('Draft saved for later.'); dialog.close(); });
$('#closeProduct').addEventListener('click', () => productDialog.close());
$('#historyDone').addEventListener('click', () => productDialog.close());
$$('.reactions button').forEach(b => b.addEventListener('click', () => { $$('.reactions button').forEach(x => x.classList.remove('selected')); b.classList.add('selected'); state.reaction = b.dataset.reaction; }));
$$('[data-home]').forEach(b => b.addEventListener('click', () => showView('home')));
$('#viewJournal').addEventListener('click', () => showView('journal'));
$$('.nav-item').forEach(b => b.addEventListener('click', () => {
  if (['home', 'journal'].includes(b.dataset.nav)) showView(b.dataset.nav);
  else showToast(`${capitalize(b.dataset.nav)} is intentionally out of scope—for now.`);
}));
$$('.filter').forEach(b => b.addEventListener('click', () => { $$('.filter').forEach(x => x.classList.remove('active')); b.classList.add('active'); renderJournal(b.dataset.filter); }));
setCategory('coffee');
renderRecent();
renderJournal();
