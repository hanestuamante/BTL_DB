import { api, toast } from './common.js';

const form = document.querySelector('#points-form');
const customers = form.elements.maKhachHang;
const result = document.querySelector('#points-result');
const output = document.querySelector('#points');
const format = new Intl.NumberFormat('vi-VN');
let lastRequest = 0;

form.addEventListener('submit', event => event.preventDefault());
customers.addEventListener('change', async () => {
  const request = ++lastRequest;
  result.hidden = true;
  if (!customers.value) return;
  try {
    const { diemKhaDung } = await api(`/khach-hang/${encodeURIComponent(customers.value)}/diem`);
    if (request !== lastRequest) return;
    output.value = format.format(diemKhaDung);
    result.hidden = false;
  } catch (error) {
    if (request === lastRequest) toast(error.message, true);
  }
});

try {
  for (const { id, ten } of await api('/khach-hang')) {
    customers.add(new Option(`${ten} · #${id}`, id));
  }
} catch (error) {
  toast(error.message, true);
}
