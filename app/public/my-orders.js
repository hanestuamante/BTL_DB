import { actionButton, api, canCancel, confirmBox, statusBadge, toast, vnd } from './common.js';
import { showDetail } from './order-detail.js';

const box = document.querySelector('#orders');

function draw(orders) {
  box.replaceChildren();
  if (!orders.length) {
    box.innerHTML = '<p>Bạn chưa có đơn hàng nào.</p>';
    return;
  }
  const table = document.createElement('table');
  table.innerHTML = `<thead><tr><th>Mã đơn</th><th>Ngày đặt</th><th>Sản phẩm</th><th>Tổng thanh toán</th>
    <th>Trạng thái</th><th>Thao tác</th></tr></thead>`;
  const body = table.createTBody();
  for (const order of orders) {
    const row = body.insertRow();
    for (const text of [`#${order.id}`, order.ngayDat, order.sanPham ?? '—', vnd(order.tong)]) row.insertCell().textContent = text;
    row.insertCell().append(statusBadge(order.trangThai));
    const actions = document.createElement('div');
    actions.className = 'actions';
    actions.append(actionButton('Chi tiết đơn hàng', '', () => showDetail(`/don-cua-toi/${order.id}`, true)));
    if (order.trangThai === 'DA_GIAO') {
      if (order.chuaDanhGia) {
        actions.append(actionButton('Đánh giá', 'primary', async () => {
          await showDetail(`/don-cua-toi/${order.id}`, true);
          document.querySelector('form.review')?.scrollIntoView({ block: 'center' });
        }));
      } else {
        actions.append('Đã đánh giá');
      }
    }
    if (order.trangThai === 'DANG_GIAO') {
      actions.append(actionButton('Đã nhận hàng', 'primary', async () => {
        if (await confirmBox(`Xác nhận đã nhận đơn #${order.id}?`, 'Đã nhận hàng')) change(order.id, 'nhan-hang', 'Đã xác nhận nhận hàng');
      }));
    }
    if (canCancel.includes(order.trangThai)) {
      actions.append(actionButton('Hủy đơn', 'danger', async () => {
        if (await confirmBox(`Hủy đơn #${order.id}? Không thể hoàn tác.`, 'Hủy đơn', true)) change(order.id, 'huy', 'Đã hủy đơn');
      }));
    }
    row.insertCell().append(actions);
  }
  box.append(table);
}

async function load() {
  const [orders, shop] = await Promise.all([api('/don-cua-toi'), api('/dat-hang')]);
  document.querySelector('[data-customer]').textContent = shop.khachHang.ten;
  document.querySelector('[data-points]').textContent = new Intl.NumberFormat('vi-VN').format(shop.khachHang.diemKhaDung);
  draw(orders);
}

async function change(id, action, message) {
  for (const button of box.querySelectorAll('button')) button.disabled = true;
  try {
    await api(`/don-cua-toi/${id}/${action}`, { method: 'PUT' });
    toast(`${message} #${id}`);
  } catch (error) {
    toast(error.message, true);
  }
  await refresh();
}

async function refresh() {
  try {
    await load();
  } catch (error) {
    toast(error.message, true);
    for (const button of box.querySelectorAll('button')) button.disabled = false;
  }
}

// Quay lại tab này thì tải lại, để thấy trạng thái người bán vừa chuyển.
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
await refresh();
document.querySelector('.order-detail').addEventListener('close', refresh);
