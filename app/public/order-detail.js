import { actionButton, api, statusBadge, toast, vnd } from './common.js';

// Hộp chi tiết đơn, dùng chung cho người bán và khách.
const detail = document.createElement('dialog');
detail.className = 'order-detail';
detail.setAttribute('aria-labelledby', 'detail-title');
detail.innerHTML = `
  <div class="detail-head">
    <h2 id="detail-title"></h2>
    <button type="button" id="detail-close">Đóng</button>
  </div>
  <dl data-info></dl>
  <h3>Khách đặt</h3>
  <table>
    <thead><tr><th>Sản phẩm</th><th>Phân loại</th><th>Đơn giá</th><th>Số lượng</th><th>Thành tiền</th></tr></thead>
    <tbody data-items></tbody>
  </table>
  <h3>Tính tiền · T = H − V − G + F</h3>
  <table class="money"><tbody data-money></tbody><tfoot data-total></tfoot></table>`;
document.body.append(detail);
const number = new Intl.NumberFormat('vi-VN');
document.querySelector('#detail-close').addEventListener('click', () => detail.close());

function addRow(body, label, note, amount, head = 'th') {
  const row = body.insertRow();
  const cell = document.createElement(head);
  if (head === 'th') cell.scope = 'row';
  cell.textContent = label;
  if (note) {
    const small = document.createElement('small');
    small.textContent = ` ${note}`;
    cell.append(small);
  }
  row.append(cell);
  row.insertCell().textContent = amount;
  return row;
}
const minus = value => (Number(value) ? `− ${vnd(value)}` : vnd(0));

// Bấm nút mới gọi API: lấy mặt hàng, voucher và tính tiền cho đúng đơn đó.
const starText = count => '★'.repeat(count) + '☆'.repeat(5 - count);

function reviewView(item) {
  const box = document.createElement('div');
  box.className = 'review';
  const stars = document.createElement('span');
  stars.className = 'stars';
  stars.textContent = starText(item.soSao);
  stars.setAttribute('aria-label', `${item.soSao} trên 5 sao`);
  const note = document.createElement('small');
  note.textContent = [item.ngayDanhGia, item.dungMoTa].filter(Boolean).join(' · ');
  const text = document.createElement('p');
  text.textContent = item.binhLuan || '(Không có nhận xét)';
  box.append(stars, note, text);
  return box;
}

function reviewForm(path, item) {
  const form = document.createElement('form');
  form.className = 'review';
  form.innerHTML = `
    <div class="star-input" role="group" aria-label="Số sao"></div>
    <label>Sản phẩm so với mô tả <select name="dungMoTa">
      <option value="">Không chọn</option><option>Đúng với mô tả</option><option>Khác mô tả</option>
    </select></label>
    <label>Nhận xét <textarea name="binhLuan" rows="2" maxlength="2000"></textarea></label>
    <p class="form-error" role="alert" hidden></p>
    <button type="submit" class="primary">Gửi đánh giá</button>`;
  let chosen = 0;
  const group = form.querySelector('.star-input');
  const buttons = [1, 2, 3, 4, 5].map(count => actionButton('☆', '', () => {
    chosen = count;
    buttons.forEach((button, index) => {
      button.textContent = index < count ? '★' : '☆';
      button.setAttribute('aria-pressed', String(index + 1 === count));
    });
  }));
  buttons.forEach((button, index) => button.setAttribute('aria-label', `${index + 1} sao`));
  group.append(...buttons);
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const problem = form.querySelector('.form-error');
    const send = form.querySelector('[type="submit"]');
    problem.hidden = true;
    if (!chosen) {
      problem.textContent = 'Hãy chọn số sao.';
      problem.hidden = false;
      return;
    }
    send.disabled = true;
    try {
      await api(`${path}/danh-gia`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...Object.fromEntries(new FormData(form)), soSao: chosen, soThuTuDong: item.soThuTuDong })
      });
      // Chỉ thay ô này, giữ nguyên phần đang viết ở món khác.
      const saved = (await api(path)).matHang.find(other => other.soThuTuDong === item.soThuTuDong);
      form.replaceWith(reviewView(saved));
    } catch (error) {
      problem.textContent = error.message;
      problem.hidden = false;
      send.disabled = false;
    }
  });
  return form;
}

// Đơn đã giao: khách thấy ô đánh giá nếu chưa đánh giá, người bán chỉ xem.
function reviewCell(path, item, canReview) {
  if (item.soSao) return reviewView(item);
  if (canReview) return reviewForm(path, item);
  const text = document.createElement('p');
  text.className = 'review';
  text.textContent = 'Khách chưa đánh giá.';
  return text;
}

export async function showDetail(path, canReview = false) {
  let order;
  try {
    order = await api(path);
  } catch (error) {
    toast(error.message, true);
    return;
  }
  if (detail.open) return;
  document.querySelector('#detail-title').replaceChildren(`Đơn #${order.id} `, statusBadge(order.trangThai));

  const info = detail.querySelector('[data-info]');
  info.replaceChildren();
  for (const [label, text] of [
    ['Khách hàng', order.khachHang],
    ['Người nhận', `${order.nguoiNhan} · ${order.sdt}`],
    ['Địa chỉ', order.diaChi],
    ['Ngày đặt', order.ngayDat],
    ['Vận chuyển', `${order.vanChuyen}, dự kiến giao ${order.ngayGiaoDuKien}`],
    ['Thanh toán', order.thanhToan],
    ['Lời nhắn', order.loiNhan || '—']
  ]) {
    const term = document.createElement('dt');
    const value = document.createElement('dd');
    term.textContent = label;
    value.textContent = text;
    info.append(term, value);
  }

  const items = detail.querySelector('[data-items]');
  items.replaceChildren();
  for (const item of order.matHang) {
    const row = items.insertRow();
    for (const text of [item.ten, `${item.mauSac}, ${item.kichCo}`, vnd(item.donGia), item.soLuong, vnd(item.thanhTien)]) {
      row.insertCell().textContent = text;
    }
    if (order.trangThai === 'DA_GIAO') {
      const reviewRow = items.insertRow();
      reviewRow.className = 'review-row';
      const cell = reviewRow.insertCell();
      cell.colSpan = 5;
      cell.append(reviewCell(path, item, canReview));
    }
  }

  const { tien } = order;
  const money = detail.querySelector('[data-money]');
  const total = detail.querySelector('[data-total]');
  money.replaceChildren();
  total.replaceChildren();
  addRow(money, 'Tiền hàng (H)', '', vnd(tien.tongTienHang));
  addRow(money, 'Giảm từ voucher (V)', order.voucher.length ? '' : 'không áp dụng', minus(tien.giamVoucher));
  for (const { ma, ten, tienGiam } of order.voucher) addRow(money, ma, ten, minus(tienGiam), 'td').className = 'sub-row';
  addRow(money, 'Giảm bằng điểm (G)', `${number.format(tien.diemSuDung)} điểm × ${vnd(order.giaTriMotDiem)}`, minus(tien.giamBangDiem));
  addRow(money, 'Phí vận chuyển (F)', order.vanChuyen, vnd(tien.phiVanChuyen));
  addRow(total, 'Tổng thanh toán (T)', '', vnd(tien.tongThanhToan));
  detail.showModal();
  detail.scrollTop = 0;
}
