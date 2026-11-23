# Mô tả phần CSDL của Võ Quốc Đại (dùng cho báo cáo BTL2)

> Khanh có thể chép các mục dưới đây vào báo cáo (T43–T45). Mọi số liệu khớp với script trong `sql/dai/`.
> Hệ quản trị: **SQL Server 2019+** (cần compatibility level ≥ 130 cho `OPENJSON`, `STRING_SPLIT`; `STRING_AGG` dùng trong kiểm thử cần 2017+).

## 1. Danh sách sản phẩm SQL của Đại

| Mã việc | Đối tượng | Loại | File | Mục BTL2 |
|---|---|---|---|---|
| T13 | 12 bảng đơn hàng / điểm / voucher / đánh giá / nhật ký | DDL | `13_DDL_DonHang_Diem.sql` | 1.1 |
| T17 | `sp_ThemBienThe` | Procedure | `22_CRUD_BienThe.sql` | 2.1 (insert) |
| T18 | `sp_SuaBienThe` | Procedure | `22_CRUD_BienThe.sql` | 2.1 (update) |
| T19 | `sp_XoaBienThe` | Procedure | `22_CRUD_BienThe.sql` | 2.1 (delete) |
| T20 | `sp_DiemDanhDangNhap` | Procedure | `23_QuyTrinh_DonHang.sql` | nghiệp vụ |
| T21 | `sp_TaoDonHang` | Procedure (transaction) | `23_QuyTrinh_DonHang.sql` | nghiệp vụ |
| T22 | `sp_CapNhatTrangThaiDon` | Procedure (transaction) | `23_QuyTrinh_DonHang.sql` | nghiệp vụ |
| T23 | `fn_KiemTraVoucher`, `trg_ApDungKhuyenMai_KiemTra` | Function + trigger | `20_…`, `21_…` | 1.1 (RB5, 6, 8) |
| T24 | `trg_DanhGia_KiemTraQuyen` | **Trigger nghiệp vụ** | `21_Trigger_Dai.sql` | **2.2.1** |
| T26 | `vw_TienDonHang`, `vw_DiemKhaDung` | View | `20_View_Function_Diem.sql` | hỗ trợ |
| T27 | `fn_TinhDiemKhaDung` | **Function (cursor, IF, LOOP)** | `20_View_Function_Diem.sql` | **2.4** |
| — | `trg_DonHang_KiemTra`, `trg_NhatKy_ChiThem`, `trg_NhatKy_KiemTraNhanVien`, `trg_ChinhSachDiem_KiemTra`, `trg_DiemDanh_KiemTraChinhSach` | Trigger ràng buộc | `21_Trigger_Dai.sql` | 1.1 (ràng buộc ngữ nghĩa) |
| T38 | Kiểm thử | Script | `90_…`, `91_…`, `92_…` | minh chứng |

Trigger thuộc tính dẫn xuất (2.2.2 — `SAN_PHAM.TongSoLuongDaBan`) là **T25 của Hưng**. Function thứ hai (2.4 — `fn_TinhTongThanhToan`) là **T29 của Bằng**.

## 2. Mục 2.1 — Thủ tục thêm / sửa / xóa trên bảng `BIEN_THE_SAN_PHAM`

Biến thể là **thực thể yếu** của sản phẩm, định danh bằng `(MaSanPham, MaBienTheNoiBo)`. Mọi thủ tục nhận đủ cặp khóa này.

### `sp_ThemBienThe(@MaSanPham, @MaBienTheNoiBo, @MauSac, @KichCo, @TonKhoRieng, @GiaBanRieng)`
Kiểm tra (mỗi lỗi một thông báo cụ thể, mã 50001–50013):
- Mã sản phẩm không trống và sản phẩm tồn tại.
- Mã biến thể: không trống; chỉ gồm `A–Z`, `0–9`, `-`; tối đa 20 ký tự (tự chuyển hoa, bỏ khoảng trắng hai đầu).
- Màu sắc, kích cỡ không trống, không quá độ dài cột.
- Tồn kho là số nguyên 0 … 1.000.000.
- Giá bán > 0 và nằm trong **50%–200% giá niêm yết** của sản phẩm (quy tắc nghiệp vụ, tương tự ví dụ "lương nhân viên < lương giám đốc").
- Không trùng khóa `(MaSanPham, MaBienTheNoiBo)`; không trùng phân loại `(MauSac, KichCo)` trong cùng sản phẩm.

Gọi thử: `EXEC dbo.sp_ThemBienThe 1, 'XANH-XL', N'Xanh', N'XL', 10, 209000;`

### `sp_SuaBienThe(...)` — cùng tham số
- Khóa không đổi được (đã được đơn hàng / giỏ tham chiếu).
- Kiểm tra dữ liệu như khi thêm; không đổi sang phân loại đã thuộc biến thể khác.
- **Bảo toàn lịch sử:** đơn cũ đã chốt `DonGiaLucDat`, `MauSacChot`, `KichCoChot` nên đổi giá / tồn không ảnh hưởng đơn cũ. Tuy nhiên **không cho đổi màu / cỡ** của biến thể đã xuất hiện trong đơn (lỗi 50022), vì khi đó cùng một mã sẽ chỉ hai mặt hàng khác nhau trong lịch sử và đánh giá.

### `sp_XoaBienThe(@MaSanPham, @MaBienTheNoiBo)`
- **Mục đích:** xóa biến thể tạo nhầm, chưa phát sinh giao dịch.
- **Được xóa** khi: chưa có trong đơn hàng nào, không nằm trong giỏ hàng nào, và sản phẩm còn ít nhất một biến thể khác.
- **Không được xóa** khi: đã có trong `CHI_TIET_DON_HANG` (50031 — gợi ý đặt tồn kho = 0 để ngừng bán), đang trong giỏ (50032), là biến thể cuối cùng (50033).
- Chạy trong transaction, khóa `UPDLOCK, HOLDLOCK` để không có đơn / giỏ mới chen vào giữa lúc kiểm tra và xóa.

## 3. Mục 2.2.1 — Trigger nghiệp vụ `trg_DanhGia_KiemTraQuyen` (T24)

**Ràng buộc (RB1 của BTL1):** khách chỉ được đánh giá một dòng chi tiết đơn khi đơn đó **đã giao** (`DA_GIAO`), và thời gian đánh giá phải **sau** thời điểm nhật ký ghi nhận đơn chuyển sang `DA_GIAO`; không ghi thời gian đánh giá ở tương lai.
Không thể dùng CHECK vì điều kiện nằm ở bảng khác (`DON_HANG`, `NHAT_KY_XU_LY_DON`).

| Thao tác DML có thể vi phạm | Xử lý |
|---|---|
| `INSERT` vào `DANH_GIA` | `trg_DanhGia_KiemTraQuyen` (AFTER INSERT) |
| `UPDATE DANH_GIA` đổi `MaDonHang`, `SoThuTuDong`, `ThoiGianDanhGia` | `trg_DanhGia_KiemTraQuyen` (AFTER UPDATE; bỏ qua khi chỉ đổi lượt hữu ích / nội dung) |
| `UPDATE DON_HANG` đưa đơn đã giao về trạng thái khác | `trg_DonHang_KiemTra` — `DA_GIAO`, `DA_HUY` là trạng thái cuối |
| `UPDATE / DELETE NHAT_KY_XU_LY_DON` (sửa / xóa mốc giao) | `trg_NhatKy_ChiThem` — nhật ký chỉ được thêm |
| `DELETE` dòng chi tiết | FK từ `DANH_GIA` chặn |

Trigger xử lý **tập dòng** (JOIN `inserted`), đúng khi chèn nhiều đánh giá một lúc (ca kiểm thử D13).
Minh họa: ca D5 (đơn chưa giao → lỗi 50160), D11 (trước mốc giao → 50161), D12 (tương lai → 50162), D13 (hợp lệ).

## 4. Mục 2.4 — Hàm `fn_TinhDiemKhaDung(@MaKhachHang)` (T27)

| Yêu cầu | Hiện thực |
|---|---|
| Tham số đầu vào + kiểm tra | `NULL` / ≤ 0 → trả **−1**; không phải khách hàng → trả **−2** (hàm SQL Server không được THROW) |
| Con trỏ | `cur_DonHang` duyệt các đơn của khách kèm r, v của chính sách chốt |
| IF / LOOP | `WHILE @@FETCH_STATUS = 0`; `IF DA_GIAO` cộng E; `IF <> DA_HUY` trừ U |
| Truy vấn dữ liệu để tính | Mỗi đơn đã giao truy vấn H từ `CHI_TIET_DON_HANG`, V từ `AP_DUNG_KHUYEN_MAI`; cộng điểm đăng nhập từ `DIEM_DANH_DANG_NHAP ⨝ CHINH_SACH_DIEM` |

Ý nghĩa: số điểm khách được dùng khi đặt đơn; dùng trong `sp_TaoDonHang` và có thể hiển thị ở giao diện (mục 3.3).
Gọi thử: `SELECT dbo.fn_TinhDiemKhaDung(1);` → 1073 trên dữ liệu mẫu. Đối chiếu: `SELECT * FROM dbo.vw_DiemKhaDung;`

## 5. Quy trình nghiệp vụ (procedure)

### `sp_DiemDanhDangNhap(@MaKhachHang, @ThoiDiem = NULL, @DiemThuong OUTPUT, @ThongBao OUTPUT)` — T20
Lần đầu trong ngày (giờ VN) được +L theo chính sách hiệu lực; lần sau +0 kèm thông báo; hai phiên cùng lúc thì phiên thua gặp lỗi trùng khóa 2627 và được xử lý như "đã nhận thưởng".

### `sp_TaoDonHang` — T21
Tham số: khách, địa chỉ, vận chuyển, thanh toán, `@DanhSachMuc` (JSON), `@DanhSachVoucher` (chuỗi phân tách dấu phẩy), `@DiemSuDung`, lời nhắn, `@MaDonHang OUTPUT`.
Ví dụ: 
```sql
DECLARE @id INT;
EXEC dbo.sp_TaoDonHang 1, 1, 2, 2,
     N'[{"MaSanPham":3,"MaBienTheNoiBo":"TRANG-20W","SoLuong":1},{"MaSanPham":5,"MaBienTheNoiBo":"DEN-2M","SoLuong":1}]',
     'GIAM50K', 1000, NULL, NULL, @id OUTPUT;   -- T = 370.000đ
```
Một transaction (`XACT_ABORT ON`, TRY/CATCH + ROLLBACK): khóa khách (chống tiêu điểm đồng thời) → kiểm tra địa chỉ thuộc khách, vận chuyển, thanh toán, chính sách → khóa biến thể, kiểm tồn → voucher → giới hạn điểm → ghi đơn, chi tiết (chốt giá, phân loại, giao nhận, chính sách), áp dụng voucher → trừ tồn → xóa khỏi giỏ → nhật ký. Trả về bảng H, V, U, G, F, T, E.

### `sp_CapNhatTrangThaiDon(@MaDonHang, @TrangThaiMoi, @NguonThaoTac, @MaNhanVien, @GhiChu)` — T22
Máy trạng thái RB15, RB16; hủy chỉ trước `DANG_GIAO`; hoàn tồn đúng một lần; ghi nhật ký.

| Từ | Sang | Ai được làm |
|---|---|---|
| CHO_THANH_TOAN | CHO_XAC_NHAN | HeThong (thanh toán thành công) |
| CHO_XAC_NHAN | CHO_LAY_HANG | NhanVien |
| CHO_LAY_HANG | DANG_GIAO | NhanVien |
| DANG_GIAO | DA_GIAO | NhanVien |
| CHO_THANH_TOAN / CHO_XAC_NHAN / CHO_LAY_HANG | DA_HUY | KhachHang, NhanVien, HeThong |

Đơn COD bắt đầu ở `CHO_XAC_NHAN`, đơn trả trước bắt đầu ở `CHO_THANH_TOAN` (cột `PHUONG_THUC_THANH_TOAN.LaThanhToanKhiNhan`).

## 6. Bảng ràng buộc ngữ nghĩa BTL1 thuộc phần Đại → cách hiện thực

| RB | Nội dung | Hiện thực |
|---|---|---|
| 1 | Chỉ đánh giá dòng của đơn đã giao, sau mốc giao | Trigger `trg_DanhGia_KiemTraQuyen` + `trg_DonHang_KiemTra` + `trg_NhatKy_ChiThem` |
| 2 | Ngày giao dự kiến ≥ ngày đặt | `CHECK CK_DON_HANG_NgayGiao` |
| 3 | Số lượng mua ≤ tồn; trừ khi đặt, cộng khi hủy | `sp_TaoDonHang`, `sp_CapNhatTrangThaiDon`; `CHECK TonKhoRieng >= 0` |
| 5 | Đơn đạt giá trị tối thiểu của voucher | `fn_KiemTraVoucher` + `trg_ApDungKhuyenMai_KiemTra` |
| 6 | Tiền giảm ≤ giá trị voucher; tổng giảm ≤ tiền hàng | `trg_ApDungKhuyenMai_KiemTra`, `sp_TaoDonHang` |
| 7 | Ngày kết thúc voucher sau ngày bắt đầu | `CHECK CK_KM_ThoiGian` |
| 8 | Voucher còn hiệu lực lúc đặt | `fn_KiemTraVoucher` + trigger |
| 11 (sửa) | Điểm sử dụng ≤ điểm khả dụng và ≤ trần c | `sp_TaoDonHang` (khóa khách), `vw_DiemKhaDung`, `fn_TinhDiemKhaDung` |
| 12 | Số sao 1–5 | `CHECK CK_DANH_GIA_SoSao` |
| 14 | Địa chỉ giao thuộc khách đặt | **FK ghép** `(MaDiaChi, MaKhachHang)` → `DIA_CHI` |
| 15 | Thứ tự trạng thái, ai được chuyển, ghi nhật ký | `sp_CapNhatTrangThaiDon`, `CHECK` trạng thái, `trg_DonHang_KiemTra` |
| 16 | Nhân viên không xử lý đơn của chính mình | `sp_CapNhatTrangThaiDon` + `trg_NhatKy_KiemTraNhanVien` |
| 17 (sửa) | Tổng thanh toán ≥ 0 | `sp_TaoDonHang` (G ≤ c(H−V)) |
| mới | Mỗi khách thưởng đăng nhập ≤ 1 lần/ngày | PK `(MaKhachHang, NgayTinhThuongVN)` |
| mới | Chính sách không chồng lấn, không sửa khi đã chốt | `trg_ChinhSachDiem_KiemTra` |

## 7. Data dictionary — 12 bảng của Đại

Ký hiệu: PK khóa chính, FK khóa ngoại, NN = NOT NULL, N = cho phép NULL.

### PHUONG_THUC_VAN_CHUYEN
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaPhuongThucVC | INT | NN | PK | định danh |
| TenPhuongThucVC | NVARCHAR(100) | NN | UNIQUE | hiển thị, không trùng |
| PhiVanChuyenThamChieu | DECIMAL(14,2) | NN | CHECK ≥ 0 | phí tham chiếu khi chốt đơn |
| ThoiLuongGiaoDuKien | INT | NN | CHECK > 0 (ngày) | tính ngày giao dự kiến |

### PHUONG_THUC_THANH_TOAN
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaPhuongThucTT | INT | NN | PK | |
| TenPhuongThucTT | NVARCHAR(100) | NN | UNIQUE | |
| LaThanhToanKhiNhan | BIT | NN | DEFAULT 0 | xác định trạng thái đầu của đơn (RB15) — **cột mới** |

### CHINH_SACH_DIEM (mới)
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaChinhSach | INT | NN | PK | phiên bản |
| TenChinhSach | NVARCHAR(100) | NN | | mô tả |
| HieuLucTu | DATETIME2(0) | NN | | |
| HieuLucDen | DATETIME2(0) | N | CHECK NULL hoặc > HieuLucTu | NULL = chưa kết thúc |
| TyLeTichDiem | DECIMAL(5,4) | NN | CHECK 0..1 | r |
| GiaTriMotDiem | DECIMAL(14,2) | NN | CHECK > 0 | v (chia cho v) |
| TyLeGiamToiDa | DECIMAL(5,4) | NN | CHECK 0..1 | c |
| DiemThuongDangNhap | INT | NN | CHECK ≥ 0 | L |

### DIEM_DANH_DANG_NHAP (mới)
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaKhachHang | INT | NN | PK, FK → KHACH_HANG | |
| NgayTinhThuongVN | DATE | NN | PK; CHECK = ngày của ThoiDiemDangNhap | tối đa 1 lần/ngày |
| ThoiDiemDangNhap | DATETIME2(0) | NN | | giờ VN |
| MaChinhSachDiemChot | INT | NN | FK → CHINH_SACH_DIEM | L chốt theo phiên bản |

### KHUYEN_MAI
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaVoucher | VARCHAR(20) | NN | PK | |
| TenChuongTrinh | NVARCHAR(200) | NN | | |
| GiaTriGiamGia | DECIMAL(14,2) | NN | CHECK > 0 | |
| GiaTriDonToiThieu | DECIMAL(14,2) | NN | DEFAULT 0, CHECK ≥ 0 | RB5 |
| NgayBatDau | DATETIME2(0) | NN | | |
| NgayKetThuc | DATETIME2(0) | NN | CHECK > NgayBatDau | RB7 |

### GIO_HANG
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaKhachHang | INT | NN | PK, FK → KHACH_HANG | |
| MaSanPham | INT | NN | PK, FK ghép → BIEN_THE_SAN_PHAM | biến thể là thực thể yếu |
| MaBienTheNoiBo | VARCHAR(20) | NN | PK, FK ghép | |
| SoLuongDuMua | INT | NN | CHECK > 0 | |

### DON_HANG
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDonHang | INT IDENTITY | NN | PK | |
| NgayDatHang | DATETIME2(0) | NN | DEFAULT giờ VN hiện tại | |
| TrangThaiDon | VARCHAR(20) | NN | CHECK ∈ 6 mã trạng thái | |
| NgayGiaoDuKien | DATE | NN | CHECK ≥ ngày đặt | RB2 |
| DiemSuDung | INT | NN | DEFAULT 0, CHECK ≥ 0 | U |
| PhiVanChuyenChot | DECIMAL(14,2) | NN | CHECK ≥ 0 | F chốt |
| LoiNhanNguoiBan | NVARCHAR(500) | N | | không bắt buộc |
| TenNguoiNhan, DiaChiGiaoHang, SdtNguoiNhan | NVARCHAR / VARCHAR | NN | SĐT: CHECK 10 chữ số bắt đầu bằng 0 | giao nhận chốt |
| MaKhachHang | INT | NN | FK → KHACH_HANG | |
| MaDiaChi | INT | NN | FK ghép (MaDiaChi, MaKhachHang) → DIA_CHI | RB14 |
| MaPhuongThucVC, MaPhuongThucTT | INT | NN | FK | |
| MaChinhSachDiemChot | INT | NN | FK → CHINH_SACH_DIEM | thay `TyLeQuyDoiDiemChot` |

### CHI_TIET_DON_HANG
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDonHang | INT | NN | PK, FK → DON_HANG | thực thể yếu |
| SoThuTuDong | INT | NN | PK (khóa riêng phần), CHECK > 0 | |
| SoLuongMua | INT | NN | CHECK > 0 | |
| DonGiaLucDat | DECIMAL(14,2) | NN | CHECK ≥ 0 | giá chốt |
| MauSacChot, KichCoChot | NVARCHAR | NN | | phân loại chốt |
| MaSanPham, MaBienTheNoiBo | INT, VARCHAR(20) | NN | FK ghép → BIEN_THE_SAN_PHAM; UNIQUE (MaDonHang, MaSanPham, MaBienTheNoiBo) | mỗi biến thể 1 dòng/đơn |

### AP_DUNG_KHUYEN_MAI
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDonHang | INT | NN | PK, FK → DON_HANG | |
| MaVoucher | VARCHAR(20) | NN | PK, FK → KHUYEN_MAI | |
| TienGiamChot | DECIMAL(14,2) | NN | CHECK > 0 | RB6 (phần liên bảng ở trigger) |

### DANH_GIA
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDanhGia | INT IDENTITY | NN | PK | |
| SoSao | TINYINT | NN | CHECK 1..5 | RB12 |
| ThoiGianDanhGia | DATETIME2(0) | NN | DEFAULT giờ VN hiện tại | RB1 |
| NoiDungBinhLuan | NVARCHAR(2000) | N | | không bắt buộc |
| DanhGiaDungMoTa | NVARCHAR(100) | N | | không bắt buộc |
| SoLuotBamHuuIch | INT | NN | DEFAULT 0, CHECK ≥ 0 | |
| MaDonHang, SoThuTuDong | INT | NN | FK ghép → CHI_TIET_DON_HANG; UNIQUE | 1:1 với dòng chi tiết |

### TEP_DANH_GIA
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDanhGia | INT | NN | PK, FK → DANH_GIA ON DELETE CASCADE | đa trị |
| UriTep | VARCHAR(400) | NN | PK | |
| LoaiTep | VARCHAR(10) | NN | CHECK ∈ (HinhAnh, Video) | |

### NHAT_KY_XU_LY_DON
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaNhatKy | INT IDENTITY | NN | PK | |
| ThoiDiem | DATETIME2(0) | NN | DEFAULT giờ VN hiện tại | mốc giao dùng cho RB1 |
| ThaoTac | NVARCHAR(100) | NN | | |
| TrangThaiTruoc | VARCHAR(20) | N | CHECK ∈ 6 mã; NULL ở dòng tạo đơn | |
| TrangThaiSau | VARCHAR(20) | NN | CHECK ∈ 6 mã; ≠ TrangThaiTruoc | |
| GhiChu | NVARCHAR(500) | N | | |
| MaDonHang | INT | NN | FK → DON_HANG | |
| NguonThaoTac | VARCHAR(10) | NN | CHECK ∈ (NhanVien, KhachHang, HeThong) | **cột mới** |
| MaNhanVien | VARCHAR(10) | N | FK → NHAN_VIEN(MaNhanVien); CHECK bắt buộc ⇔ nguồn là NhanVien | |
