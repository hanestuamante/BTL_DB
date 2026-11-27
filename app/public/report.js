import { api, filters, loadLookups, renderTable, reportColumns, toast, vnd } from './common.js';

const form = document.querySelector('#filters');
const results = document.querySelector('#results');
const textColumns = new Set(['TenSanPham', 'TenDanhMuc', 'TenThuongHieu']);
const collator = new Intl.Collator('vi', { numeric: true });
let lastReport = 0;
let rows = [];
let sort = { key: 'DoanhThu', direction: 'descending' };

function draw() {
  const { key, direction } = sort;
  const sign = direction === 'ascending' ? 1 : -1;
  const sorted = [...rows].sort((a, b) => {
    const difference = textColumns.has(key)
      ? collator.compare(a[key], b[key])
      : Number(a[key]) - Number(b[key]);
    return sign * difference || a.MaSanPham - b.MaSanPham;
  });
  const total = rows.reduce((sum, row) => sum + Number(row.DoanhThu), 0);
  renderTable(results, sorted, { columns: reportColumns, sort, onSort: sortBy, total: vnd(total) });
}

function sortBy(key) {
  const direction = sort.key === key && sort.direction === 'ascending' ? 'descending' : 'ascending';
  sort = { key, direction };
  draw();
  results.querySelector('th[aria-sort] button')?.focus();
}

async function report() {
  const request = ++lastReport;
  try {
    const data = await api(`/thong-ke?${filters(form)}`);
    if (request !== lastReport) return;
    rows = data;
    draw();
  } catch (error) {
    if (request === lastReport) toast(error.message, true);
  }
}

form.addEventListener('submit', event => {
  event.preventDefault();
  report();
});
loadLookups().catch(error => toast(error.message, true));
await report();
