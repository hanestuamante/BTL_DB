import { actionButton, confirmBox, api, filters, loadLookups, renderTable, toast, variantColumns } from './common.js';

const filterForm = document.querySelector('#filters');
const results = document.querySelector('#results');
const dialog = document.querySelector('#variant-dialog');
const form = document.querySelector('#variant-form');
const formError = document.querySelector('#variant-error');
const title = document.querySelector('#variant-title');
const addButton = document.querySelector('#add-variant');
const submitButton = form.querySelector('[type="submit"]');
let editing;
let lastSearch = 0;

const variantPath = row =>
  `/bien-the/${encodeURIComponent(row.MaSanPham)}/${encodeURIComponent(row.MaBienTheNoiBo)}`;

// Tên ô nhập trùng tên cột và tên tham số của thủ tục.
const editableFields = ['MauSac', 'KichCo', 'GiaBanRieng', 'TonKhoRieng'];

function openEditor(row = null) {
  editing = row;
  form.reset();
  formError.hidden = true;
  form.elements.MaSanPham.disabled = Boolean(row);
  form.elements.MaBienTheNoiBo.readOnly = Boolean(row);
  title.textContent = row ? 'Sửa biến thể' : 'Thêm biến thể';
  if (row) {
    form.elements.MaSanPham.value = row.MaSanPham;
    form.elements.MaBienTheNoiBo.value = row.MaBienTheNoiBo;
    for (const field of editableFields) form.elements[field].value = row[field] ?? '';
  }
  dialog.showModal();
}

function rowActions(row) {
  const group = document.createElement('div');
  group.className = 'actions';
  const edit = document.createElement('button');
  edit.textContent = 'Sửa';
  edit.addEventListener('click', () => openEditor(row));
  const remove = document.createElement('button');
  remove.textContent = 'Xóa';
  remove.className = 'danger';
  remove.addEventListener('click', async () => {
    if (!(await confirmBox(`Xóa biến thể “${row.MaBienTheNoiBo}” của “${row.TenSanPham}” (mã sản phẩm ${row.MaSanPham})?`, 'Xóa', true))) return;
    remove.disabled = true;
    try {
      const response = await api(variantPath(row), { method: 'DELETE' });
      toast(response.message);
      await search();
    } catch (error) {
      toast(error.message, true);
    } finally {
      remove.disabled = false;
    }
  });
  group.append(edit, remove);
  return group;
}

// Nút − + cạnh tồn kho: mỗi lần bấm gọi sp_SuaBienThe và lưu ngay.
function stockCell(row) {
  const group = document.createElement('div');
  group.className = 'stepper';
  const count = document.createElement('span');
  const show = () => {
    count.textContent = row.TonKhoRieng;
    minus.disabled = row.TonKhoRieng <= 0;
    plus.disabled = false;
  };
  const change = async amount => {
    const clicked = document.activeElement;
    minus.disabled = plus.disabled = true;
    try {
      // Lấy số mới nhất trước, phòng khi khách vừa đặt hàng.
      const latest = (await api('/bien-the')).find(other => variantPath(other) === variantPath(row));
      if (!latest) throw new Error('Biến thể không còn tồn tại.');
      Object.assign(row, latest);
      const values = Object.fromEntries(editableFields.map(field => [field, row[field]]));
      values.TonKhoRieng = Math.max(0, row.TonKhoRieng + amount);
      await api(variantPath(row), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(values)
      });
      row.TonKhoRieng = values.TonKhoRieng;
      toast(`Đã lưu tồn kho ${row.MaBienTheNoiBo}: ${row.TonKhoRieng}`);
    } catch (error) {
      toast(error.message, true);
    }
    show();
    if (clicked?.isConnected) clicked.focus();
  };
  const minus = actionButton('−', '', () => change(-1));
  const plus = actionButton('+', '', () => change(1));
  minus.setAttribute('aria-label', `Giảm tồn kho ${row.MaBienTheNoiBo}`);
  plus.setAttribute('aria-label', `Tăng tồn kho ${row.MaBienTheNoiBo}`);
  group.append(minus, count, plus);
  show();
  return group;
}

async function search() {
  const request = ++lastSearch;
  try {
    const rows = await api(`/bien-the?${filters(filterForm)}`);
    if (request === lastSearch) renderTable(results, rows, { columns: variantColumns, actions: rowActions, cells: { TonKhoRieng: stockCell } });
  } catch (error) {
    if (request === lastSearch) toast(error.message, true);
  }
}

filterForm.addEventListener('submit', event => {
  event.preventDefault();
  search();
});
addButton.addEventListener('click', () => openEditor());
document.querySelector('#cancel-edit').addEventListener('click', () => dialog.close());
dialog.addEventListener('cancel', event => { if (submitButton.disabled) event.preventDefault(); });
form.elements.MaBienTheNoiBo.addEventListener('input', event => {
  const input = event.currentTarget;
  const start = input.selectionStart;
  const end = input.selectionEnd;
  input.value = input.value.toUpperCase();
  input.setSelectionRange(start, end);
});

form.addEventListener('submit', async event => {
  event.preventDefault();
  const values = Object.fromEntries(new FormData(form));
  const editingRow = editing;
  const cancelButton = document.querySelector('#cancel-edit');
  formError.hidden = true;
  submitButton.disabled = true;
  cancelButton.disabled = true;
  try {
    const response = await api(editingRow ? variantPath(editingRow) : '/bien-the', {
      method: editingRow ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(values)
    });
    dialog.close();
    toast(response.message);
    await search();
  } catch (error) {
    formError.textContent = error.message;
    formError.hidden = false;
  } finally {
    submitButton.disabled = false;
    cancelButton.disabled = false;
  }
});

addButton.disabled = true;
try {
  await loadLookups();
  addButton.disabled = false;
} catch (error) {
  toast(error.message, true);
}
await search();
