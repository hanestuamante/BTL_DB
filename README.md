# BTL2 Hệ CSDL — L04 Nhóm 07 — Phần của Võ Quốc Đại

Mảng phụ trách: **nghiệp vụ điểm, đơn hàng, CRUD biến thể** (T03, T13, T17–T24, T26, T27, T38).
Hệ quản trị: **SQL Server 2019+** (chờ Hưng xác nhận ở T10).

> ⚠️ **Chưa chạy kiểm chứng trên SQL Server.** Script mới được rà soát tĩnh (cú pháp, tên cột, công thức tính tay).
> Lần chạy đầu tiên trên DB thật có thể phát sinh lỗi nhỏ cần sửa — xem `docs/ChoNguoiKhac.md` mục N1.

## Trạng thái từng đầu việc

| Mã | Việc | Trạng thái | Ở đâu |
|---|---|---|---|
| T03 | Chốt công thức điểm, đăng nhập, hủy đơn, làm tròn, ví dụ tính tay | ✅ Xong (chờ Khanh rà, giảng viên xác nhận số liệu) | `docs/T03_DacTa_CongThucDiem.md` |
| T13 | DDL 12 bảng nghiệp vụ | ✅ Xong (chờ DDL thật của Hưng để thay stub) | `sql/dai/13_DDL_DonHang_Diem.sql` |
| T17 | `sp_ThemBienThe` | ✅ Xong | `sql/dai/22_CRUD_BienThe.sql` |
| T18 | `sp_SuaBienThe` | ✅ Xong | `sql/dai/22_CRUD_BienThe.sql` |
| T19 | `sp_XoaBienThe` | ✅ Xong | `sql/dai/22_CRUD_BienThe.sql` |
| T20 | Điểm danh đăng nhập | ✅ Xong | `sql/dai/23_QuyTrinh_DonHang.sql` |
| T21 | Giao dịch tạo đơn | ✅ Xong (chờ Hưng review) | `sql/dai/23_QuyTrinh_DonHang.sql` |
| T22 | Chuyển trạng thái / hủy đơn | ✅ Xong (phối hợp T25 của Hưng) | `sql/dai/23_QuyTrinh_DonHang.sql` |
| T23 | Kiểm tra voucher, ngưỡng, hiệu lực, tổng giảm | ✅ Xong | `sql/dai/20_…` (`fn_KiemTraVoucher`), `sql/dai/21_…` (trigger) |
| T24 | Trigger quyền đánh giá | ✅ Xong | `sql/dai/21_Trigger_Dai.sql` |
| T26 | View điểm khả dụng | ✅ Xong | `sql/dai/20_View_Function_Diem.sql` |
| T27 | `fn_TinhDiemKhaDung` (cursor, IF, LOOP) | ✅ Xong | `sql/dai/20_View_Function_Diem.sql` |
| T38 | Kiểm thử điểm, đăng nhập lặp, chính sách mới, hủy đơn, hai phiên đồng thời | ✅ Đã viết 60+ ca — ⏳ **chưa chạy** | `sql/dai/90_…`, `91_…`, `92_…` |
| — | Dữ liệu mẫu miền Đại (≥ 5 dòng/bảng) | ✅ Xong (chờ Bằng hợp nhất T16) | `sql/dai/30_DuLieuMau_Dai.sql` |
| — | Mô tả cho báo cáo + data dictionary 12 bảng | ✅ Xong | `docs/MoTa_Routine_Dai.md` |

Việc đang chờ người khác: **`docs/ChoNguoiKhac.md`**.

## Thứ tự chạy

| Bước | File | Nội dung |
|---|---|---|
| 0 | `sql/dai/00_TAM_BangGiaDinh_CuaHung.sql` | **TẠM**: 10 bảng của Hưng + dữ liệu tối giản. Bỏ khi có T11/T12 thật. |
| 1 | `sql/dai/13_DDL_DonHang_Diem.sql` | 12 bảng của Đại |
| 2 | `sql/dai/20_View_Function_Diem.sql` | hàm tiện ích, `fn_KiemTraVoucher`, 2 view, `fn_TinhDiemKhaDung` |
| 3 | `sql/dai/21_Trigger_Dai.sql` | 7 trigger |
| 4 | `sql/dai/22_CRUD_BienThe.sql` | 3 thủ tục CRUD + thủ tục kiểm tra dùng chung |
| 5 | `sql/dai/23_QuyTrinh_DonHang.sql` | điểm danh, tạo đơn, chuyển trạng thái |
| 6 | `sql/dai/30_DuLieuMau_Dai.sql` | dữ liệu mẫu (sau trigger để trigger kiểm tra luôn dữ liệu mẫu) |
| 7 | `sql/dai/90_KiemThu_Dai.sql` | kiểm thử tự động, in PASS/FAIL + bảng tổng hợp |
| 8 | `sql/dai/91_…` + `92_…` | kiểm thử hai phiên (chạy lại từ bước 1 trước, mở 2 cửa sổ) |

Với `sqlcmd` (file lưu UTF-8 nên phải có `-f 65001` để tiếng Việt không lỗi):

```bash
for f in 00_TAM_BangGiaDinh_CuaHung 13_DDL_DonHang_Diem 20_View_Function_Diem 21_Trigger_Dai 22_CRUD_BienThe 23_QuyTrinh_DonHang 30_DuLieuMau_Dai 90_KiemThu_Dai; do sqlcmd -S localhost -U sa -d BTL2 -f 65001 -b -i "sql/dai/$f.sql" || break; done
```

Trong SSMS / Azure Data Studio: mở lần lượt từng file và Execute. DB cần `COMPATIBILITY_LEVEL >= 130`.

## Quy ước dùng chung (đề nghị cả nhóm theo)

- Biến thể luôn định danh bằng **`(MaSanPham, MaBienTheNoiBo)`**.
- Mã trạng thái đơn (ASCII): `CHO_THANH_TOAN`, `CHO_XAC_NHAN`, `CHO_LAY_HANG`, `DANG_GIAO`, `DA_GIAO`, `DA_HUY`; giao diện tự đổi sang chữ có dấu.
- Thời điểm lưu theo **giờ Việt Nam** (`dbo.fn_ThoiDiemVN()`).
- Lỗi nghiệp vụ dùng `THROW` với mã ≥ 50000 và thông báo tiếng Việt cụ thể: 500xx CRUD biến thể, 501xx đơn hàng / voucher / đánh giá / chính sách.
- Trạng thái đơn chỉ đổi qua `sp_CapNhatTrangThaiDon`; đơn chỉ tạo qua `sp_TaoDonHang`.
