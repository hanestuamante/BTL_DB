const adminPages = [
  ['/', 'Biến thể sản phẩm'],
  ['/thong-ke.html', 'Thống kê bán hàng'],
  ['/don-hang.html', 'Đơn hàng'],
  ['/diem-kha-dung.html', 'Điểm khả dụng']
];
const navigation = document.querySelector('[data-navigation]');
function addLink(path, label) {
  const link = document.createElement('a');
  link.href = path;
  link.textContent = label;
  if (location.pathname === path || (path === '/' && location.pathname === '/index.html')) {
    link.setAttribute('aria-current', 'page');
  }
  navigation.append(link);
  return link;
}

// Nút bên phải chuyển qua lại giữa trang quản trị và trang đặt hàng.
if (['/dat-hang.html', '/don-cua-toi.html'].includes(location.pathname)) {
  addLink('/dat-hang.html', 'Cửa hàng');
  addLink('/don-cua-toi.html', 'Đơn của tôi');
  addLink('/', 'Quản trị').className = 'switch-button';
} else {
  for (const [path, label] of adminPages) addLink(path, label);
  addLink('/dat-hang.html', 'Đặt hàng').className = 'switch-button';
}

export async function api(path, options) {
  const response = await fetch(`/api${path}`, options);
  const data = await response.json();
  if (!response.ok) throw new Error(data.message || 'Không thể thực hiện yêu cầu');
  return data;
}

let toastTimeout;
export function toast(message, error = false) {
  const element = document.querySelector('[data-toast]');
  element.textContent = message;
  element.dataset.error = String(error);
  element.hidden = false;
  clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => { element.hidden = true; }, 6000);
}

export async function loadLookups() {
  await Promise.all([...document.querySelectorAll('[data-lookup]')].map(async select => {
    const rows = await api(`/lookup/${select.dataset.lookup}`);
    for (const { id, ten } of rows) select.add(new Option(ten, id));
  }));
}

export function filters(form) {
  const params = new URLSearchParams();
  for (const [name, value] of new FormData(form)) {
    if (value.trim() !== '') params.set(name, value.trim());
  }
  return params.toString();
}

const money = new Intl.NumberFormat('vi-VN', {
  style: 'currency', currency: 'VND', maximumFractionDigits: 2
});
export const vnd = value => money.format(Number(value));

export const variantColumns = [
  'MaSanPham', 'MaBienTheNoiBo', 'TenSanPham', 'TenDanhMuc', 'TenThuongHieu',
  'MauSac', 'KichCo', 'GiaBanRieng', 'TonKhoRieng'
];
export const reportColumns = [
  'MaSanPham', 'TenSanPham', 'TenDanhMuc', 'TenThuongHieu', 'SoBienTheDaBan',
  'SoDonHang', 'TongSoLuongBan', 'GiaBanTrungBinh', 'DoanhThu'
];

const columnOptions = {
  MaSanPham: { label: 'Mã sản phẩm' },
  MaBienTheNoiBo: { label: 'Mã biến thể' },
  TenSanPham: { label: 'Sản phẩm' },
  TenDanhMuc: { label: 'Danh mục' },
  TenThuongHieu: { label: 'Thương hiệu' },
  MauSac: { label: 'Màu sắc' },
  KichCo: { label: 'Kích cỡ' },
  GiaBanRieng: { label: 'Giá bán', format: vnd },
  TonKhoRieng: { label: 'Tồn kho' },
  SoBienTheDaBan: { label: 'Biến thể đã bán' },
  SoDonHang: { label: 'Số đơn hàng' },
  TongSoLuongBan: { label: 'Số lượng bán' },
  DoanhThu: { label: 'Doanh thu', format: vnd },
  GiaBanTrungBinh: { label: 'Giá bán trung bình', format: vnd }
};

function appendCell(row, tag, value) {
  const cell = document.createElement(tag);
  if (value instanceof Node) cell.append(value);
  else cell.textContent = value;
  row.append(cell);
  return cell;
}

export function renderTable(container, rows, { columns, actions, cells = {}, total, sort, onSort }) {
  container.replaceChildren();
  if (!rows.length) {
    const empty = document.createElement('p');
    empty.textContent = 'Không có kết quả.';
    container.append(empty);
    if (total !== undefined) {
      const summary = document.createElement('p');
      summary.textContent = `Tổng doanh thu: ${total}`;
      container.append(summary);
    }
    return;
  }

  const table = document.createElement('table');
  const head = table.createTHead().insertRow();
  for (const key of columns) {
    const label = columnOptions[key].label;
    const cell = appendCell(head, 'th', label);
    cell.scope = 'col';
    if (onSort) {
      const button = document.createElement('button');
      const direction = sort?.key === key ? sort.direction : null;
      if (direction) cell.setAttribute('aria-sort', direction);
      button.className = 'sort-heading';
      button.textContent = direction ? `${label} ${direction === 'ascending' ? '↑' : '↓'}` : label;
      button.addEventListener('click', () => onSort(key));
      cell.replaceChildren(button);
    }
  }
  if (actions) appendCell(head, 'th', 'Thao tác').scope = 'col';

  const body = table.createTBody();
  for (const data of rows) {
    const row = body.insertRow();
    for (const key of columns) {
      if (cells[key]) {
        appendCell(row, 'td', cells[key](data));
        continue;
      }
      const value = data[key];
      const format = columnOptions[key]?.format;
      appendCell(row, 'td', value == null ? '—' : format ? format(value) : String(value));
    }
    if (actions) appendCell(row, 'td', actions(data));
  }

  if (total !== undefined) {
    const row = table.createTFoot().insertRow();
    const label = appendCell(row, 'th', 'Tổng doanh thu');
    label.scope = 'row';
    label.colSpan = Math.max(1, columns.length - 1);
    appendCell(row, 'td', total);
  }
  container.append(table);
}

export const statuses = {
  CHO_THANH_TOAN: 'Chờ thanh toán',
  CHO_XAC_NHAN: 'Chờ xác nhận',
  CHO_LAY_HANG: 'Chờ lấy hàng',
  DANG_GIAO: 'Đang giao',
  DA_GIAO: 'Đã giao',
  DA_HUY: 'Đã hủy'
};
export const canCancel = ['CHO_THANH_TOAN', 'CHO_XAC_NHAN', 'CHO_LAY_HANG'];

export function statusBadge(status) {
  const badge = document.createElement('span');
  badge.className = 'badge';
  badge.dataset.status = status;
  badge.textContent = statuses[status] ?? status;
  return badge;
}

export function actionButton(label, className, handler) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = className;
  button.textContent = label;
  button.addEventListener('click', handler);
  return button;
}

// Hộp xác nhận của web; trả về true nếu người dùng đồng ý.
export function confirmBox(message, okLabel, danger = false) {
  return new Promise(resolve => {
    const dialog = document.createElement('dialog');
    dialog.className = 'confirm-box';
    const text = document.createElement('p');
    text.textContent = message;
    const actions = document.createElement('div');
    actions.className = 'actions';
    const no = actionButton('Quay lại', '', () => dialog.close());
    const yes = actionButton(okLabel, danger ? 'primary danger-fill' : 'primary', () => dialog.close('yes'));
    actions.append(no, yes);
    dialog.append(text, actions);
    dialog.addEventListener('close', () => {
      dialog.remove();
      resolve(dialog.returnValue === 'yes');
    });
    document.body.append(dialog);
    dialog.setAttribute('aria-label', message);
    dialog.showModal();
    no.focus();
  });
}

// Bấm vào ô số thì bôi đen sẵn, gõ số mới sẽ thay luôn số cũ.
document.addEventListener('focusin', ({ target }) => {
  if (!target.matches('input[type="number"]')) return;
  target.select();
  // Chặn lần nhả chuột đầu tiên, nếu không trình duyệt sẽ bỏ bôi đen.
  const keepSelection = event => event.preventDefault();
  target.addEventListener('mouseup', keepSelection, { once: true });
  target.addEventListener('blur', () => target.removeEventListener('mouseup', keepSelection), { once: true });
});

// Nút − bên trái, + bên phải của ô số.
document.addEventListener('click', ({ target }) => {
  const button = target.closest('[data-step]');
  if (!button) return;
  const input = button.parentElement.querySelector('input');
  const smallest = Number(input.min || 0);
  input.value = Math.max(smallest, Math.trunc(Number(input.value)) + Number(button.dataset.step));
  input.dispatchEvent(new Event('input', { bubbles: true }));
});
