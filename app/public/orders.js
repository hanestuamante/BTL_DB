import { actionButton, api, canCancel, confirmBox, statusBadge, statuses, toast, vnd } from './common.js';
import { showDetail } from './order-detail.js';

const tabs = document.querySelector('#tabs');
const box = document.querySelector('#orders');
const employee = document.querySelector('#employee');
// Bước tiếp theo của mỗi trạng thái. DB vẫn kiểm tra lại.
const nextStep = {
  CHO_THANH_TOAN: { to: 'CHO_XAC_NHAN', label: 'Đã thanh toán', bySystem: true },
  CHO_XAC_NHAN: { to: 'CHO_LAY_HANG', label: 'Xác nhận đơn' },
  CHO_LAY_HANG: { to: 'DANG_GIAO', label: 'Bàn giao vận chuyển' }
};
let orders = [];
let current = 'CHO_XAC_NHAN';

function drawTabs() {
  tabs.replaceChildren();
  for (const [key, label] of [['', 'Tất cả'], ...Object.entries(statuses)]) {
    const count = orders.filter(order => !key || order.trangThai === key).length;
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = `${label} (${count})`;
    button.setAttribute('aria-pressed', String(key === current));
    button.addEventListener('click', () => {
      current = key;
      draw();
    });
    tabs.append(button);
  }
}

function draw() {
  drawTabs();
  box.replaceChildren();
  const rows = orders.filter(order => !current || order.trangThai === current);
  if (!rows.length) {
    box.innerHTML = '<p>Không có đơn hàng nào.</p>';
    return;
  }
  const table = document.createElement('table');
  table.innerHTML = `<thead><tr><th>Mã đơn</th><th>Ngày đặt</th><th>Khách hàng</th>
    <th>Tổng thanh toán</th><th>Trạng thái</th><th>Thao tác</th></tr></thead>`;
  const body = table.createTBody();
  for (const order of rows) {
    const row = body.insertRow();
    for (const text of [`#${order.id}`, order.ngayDat, order.khachHang, vnd(order.tong)]) {
      row.insertCell().textContent = text;
    }
    row.insertCell().append(statusBadge(order.trangThai));
    const actions = document.createElement('div');
    actions.className = 'actions';
    actions.append(actionButton('Chi tiết đơn hàng', '', () => showDetail(`/quan-ly-don/${order.id}`)));
    const step = nextStep[order.trangThai];
    if (step) actions.append(actionButton(step.label, 'primary', () => change(order, step.to, step.bySystem)));
    if (canCancel.includes(order.trangThai)) {
      actions.append(actionButton('Hủy', 'danger', async () => {
        if (await confirmBox(`Hủy đơn #${order.id}? Không thể hoàn tác.`, 'Hủy đơn', true)) change(order, 'DA_HUY');
      }));
    }
    if (order.trangThai === 'DANG_GIAO') actions.append('Chờ khách nhận');
    row.insertCell().append(actions);
  }
  box.append(table);
}

async function load() {
  const data = await api('/quan-ly-don');
  orders = data.donHang;
  if (!employee.options.length) for (const { id, ten } of data.nhanVien) employee.add(new Option(ten, id));
  draw();
}

async function change(order, status, bySystem = false) {
  for (const button of box.querySelectorAll('button')) button.disabled = true;
  try {
    await api(`/quan-ly-don/${order.id}/trang-thai`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ trangThaiMoi: status, maNhanVien: bySystem ? null : employee.value })
    });
    toast(`Đơn #${order.id}: ${statuses[order.trangThai]} → ${statuses[status]}`);
  } catch (error) {
    toast(error.message, true);
  }
  try {
    await load();
  } catch (error) {
    toast(error.message, true);
    draw();
  }
}

try {
  await load();
} catch (error) {
  toast(error.message, true);
}

// Quay lại tab này thì tải lại, để thấy đơn khách vừa đặt, hủy hoặc nhận.
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) load().catch(error => toast(error.message, true));
});
