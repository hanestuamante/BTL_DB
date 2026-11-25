import { actionButton, api, statuses, toast, vnd } from './common.js';

const form = document.querySelector('#order-form');
const variant = document.querySelector('#variant');
const quantity = document.querySelector('#quantity');
const itemsBox = document.querySelector('#items');
const result = document.querySelector('#order-result');
const preview = document.querySelector('#preview');
const useMax = document.querySelector('#use-max');
const submit = form.querySelector('[type="submit"]');
const number = new Intl.NumberFormat('vi-VN');
let variants = [];
let items = [];

const keyOf = row => `${row.maSanPham}/${row.maBienTheNoiBo}`;
const findVariant = key => variants.find(row => keyOf(row) === key);

let lastPreview = 0;
let maxPoints = 0;
const orderBody = () => ({ ...Object.fromEntries(new FormData(form)), matHang: items });
const post = (path, body) => api(path, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body)
});

async function updatePreview() {
  const request = ++lastPreview;
  preview.hidden = !items.length;
  useMax.disabled = !items.length;
  if (!items.length) return;
  const problem = preview.querySelector('[data-preview-error]');
  let data;
  try {
    data = await post('/dat-hang/tam-tinh', orderBody());
  } catch (error) {
    if (request !== lastPreview) return;
    for (const cell of preview.querySelectorAll('[data-preview]')) cell.textContent = '—';
    problem.textContent = error.message;
    useMax.disabled = true;
    return;
  }
  if (request !== lastPreview) return;
  maxPoints = data.diemToiDa;
  for (const cell of preview.querySelectorAll('[data-preview]')) {
    const value = Number(data[cell.dataset.preview]);
    cell.textContent = ['V', 'G'].includes(cell.dataset.preview) && value ? `− ${vnd(value)}` : vnd(value);
  }
  const voucher = form.elements.maVoucher.value;
  preview.querySelector('[data-voucher-note]').textContent = voucher && !data.loiVoucher ? voucher : '';
  preview.querySelector('[data-points-note]').textContent =
    `${number.format(data.U)} điểm × ${vnd(data.giaTriMotDiem)}`;
  preview.querySelector('[data-policy]').replaceChildren(...[
    `Tỉ lệ quy đổi: 1 điểm = ${vnd(data.giaTriMotDiem)}`,
    `Điểm giảm tối đa ${number.format(data.phanTramToiDa)}% tiền hàng sau voucher. Đơn này dùng được tối đa ${number.format(maxPoints)} điểm (bạn có ${number.format(data.diemKhaDung)} điểm)`,
    `Tích điểm ${number.format(data.phanTramTich)}% tiền hàng thực trả: dự kiến nhận ${number.format(data.diemSeNhan)} điểm khi giao thành công`
  ].map(text => Object.assign(document.createElement('li'), { textContent: text })));
  const used = Number(form.elements.diemSuDung.value);
  const errors = [];
  if (data.loiVoucher) errors.push(data.loiVoucher);
  if (used > maxPoints || used < 0) errors.push(`Số điểm phải từ 0 đến ${number.format(maxPoints)}, nên chưa được trừ vào tạm tính.`);
  problem.textContent = errors.join(' ');
}
useMax.addEventListener('click', () => {
  form.elements.diemSuDung.value = maxPoints;
  updatePreview();
});
for (const name of ['maVoucher', 'maPhuongThucVC', 'diemSuDung']) {
  form.elements[name].addEventListener('input', updatePreview);
}

// Cụm − số + để tăng giảm số lượng, từ 1 đến tồn kho.
function stepper(item, name, stock) {
  const group = document.createElement('div');
  group.className = 'stepper';
  const count = document.createElement('span');
  count.textContent = item.soLuong;
  const step = (label, change, title) => {
    const button = actionButton(label, '', () => {
      item.soLuong += change;
      drawItems();
      const row = itemsBox.querySelectorAll('tbody tr')[items.indexOf(item)];
      row?.querySelector(`[data-change="${change}"]:enabled`)?.focus();
    });
    button.dataset.change = change;
    button.setAttribute('aria-label', `${title} số lượng ${name}`);
    const next = item.soLuong + change;
    button.disabled = change < 0 ? next < 1 : next > stock;
    return button;
  };
  group.append(step('−', -1, 'Giảm'), count, step('+', 1, 'Tăng'));
  return group;
}

function drawItems() {
  updatePreview();
  itemsBox.replaceChildren();
  if (!items.length) {
    itemsBox.innerHTML = '<p>Chưa có sản phẩm trong đơn.</p>';
    return;
  }
  const table = document.createElement('table');
  table.innerHTML = '<thead><tr><th>Sản phẩm</th><th>Đơn giá</th><th>Số lượng</th><th>Thành tiền</th><th></th></tr></thead>';
  const body = table.createTBody();
  let total = 0;
  for (const item of items) {
    const { ten, gia, tonKho } = findVariant(keyOf(item));
    total += gia * item.soLuong;
    const row = body.insertRow();
    for (const text of [ten, vnd(gia)]) row.insertCell().textContent = text;
    row.insertCell().append(stepper(item, ten, tonKho));
    row.insertCell().textContent = vnd(gia * item.soLuong);
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.className = 'danger';
    remove.textContent = 'Bỏ';
    remove.setAttribute('aria-label', `Bỏ ${ten}`);
    remove.addEventListener('click', () => {
      items = items.filter(other => other !== item);
      drawItems();
    });
    row.insertCell().append(remove);
  }
  const foot = table.createTFoot().insertRow();
  foot.innerHTML = '<th colspan="3" scope="row">Tiền hàng tạm tính</th>';
  foot.insertCell().textContent = vnd(total);
  foot.insertCell();
  itemsBox.append(table);
}

function fill(select, rows) {
  for (const { id, ten, phi } of rows) select.add(new Option(phi === undefined ? ten : `${ten} · ${vnd(phi)}`, id));
}

function showStock(data) {
  variants = data.bienThe;
  const selected = variant.value;
  variant.replaceChildren();
  for (const row of variants) variant.add(new Option(`${row.ten} · ${vnd(row.gia)} · còn ${row.tonKho}`, keyOf(row)));
  if (selected) variant.value = selected;
  document.querySelector('[data-customer]').textContent = data.khachHang.ten;
  for (const element of document.querySelectorAll('[data-points]')) {
    element.textContent = number.format(data.khachHang.diemKhaDung);
  }
}

function addItem() {
  const count = Number(quantity.value);
  if (!Number.isInteger(count) || count < 1) return toast('Số lượng phải là số nguyên dương', true);
  const row = findVariant(variant.value);
  if (!row) return toast('Hãy chọn sản phẩm', true);
  const existing = items.find(item => keyOf(item) === keyOf(row));
  if (existing) existing.soLuong += count;
  else items.push({ maSanPham: row.maSanPham, maBienTheNoiBo: row.maBienTheNoiBo, soLuong: count });
  quantity.value = 1;
  drawItems();
}
document.querySelector('#add-item').addEventListener('click', addItem);
quantity.addEventListener('keydown', event => {
  if (event.key !== 'Enter') return;
  event.preventDefault();
  addItem();
});

form.addEventListener('submit', async event => {
  event.preventDefault();
  submit.disabled = true;
  result.hidden = true;
  let order;
  try {
    order = await post('/dat-hang', orderBody());
  } catch (error) {
    toast(error.message, true);
  }
  if (order) {
    result.querySelector('[data-order-id]').textContent = order.MaDonHang;
    result.querySelector('[data-status]').textContent = statuses[order.TrangThaiDon] ?? order.TrangThaiDon;
    result.querySelector('[data-used]').textContent = number.format(order.U);
    for (const cell of result.querySelectorAll('[data-amount]')) cell.textContent = vnd(order[cell.dataset.amount]);
    result.hidden = false;
    items = [];
    form.elements.diemSuDung.value = 0;
    form.elements.maVoucher.value = '';
    form.elements.loiNhan.value = '';
    drawItems();
    result.scrollIntoView({ block: 'nearest' });
    toast(`Đặt hàng thành công, mã đơn ${order.MaDonHang}`);
    try {
      showStock(await api('/dat-hang'));
    } catch {
      toast(`Đã đặt đơn ${order.MaDonHang}, nhưng chưa tải lại được điểm và tồn kho`, true);
    }
  }
  submit.disabled = false;
});

try {
  const data = await api('/dat-hang');
  showStock(data);
  fill(form.elements.maDiaChi, data.diaChi);
  fill(form.elements.maPhuongThucVC, data.vanChuyen);
  fill(form.elements.maPhuongThucTT, data.thanhToan);
  fill(form.elements.maVoucher, data.voucher);
  items = data.gioHang;
  drawItems();
  submit.disabled = false;
} catch (error) {
  toast(error.message, true);
}
