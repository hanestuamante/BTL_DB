# Phần việc của Đại đang CHỜ người khác

> Cập nhật: 23/11/2026. Mọi phần Đại tự làm được đã xong (xem `README.md`). Các mục dưới đây cần người khác làm / xác nhận
> trước khi phần của Đại được coi là hoàn tất trên DB thống nhất.

## 1. Chờ Hưng (Khưu Huỳnh Gia Hưng)

| # | Việc | Liên quan | Đại cần gì |
|---|---|---|---|
| H1 | **T10** — chốt hệ quản trị và quy ước | Toàn bộ script | Đại đã viết theo **SQL Server 2019+**. Hưng xác nhận; nếu nhóm chọn MySQL thì Đại phải viết lại toàn bộ routine. Xác nhận kiểu khóa: `MaNguoiDung`, `MaDiaChi`, `MaSanPham` là `INT`; `MaBienTheNoiBo VARCHAR(20)`; `MaNhanVien VARCHAR(10)`; tiền `DECIMAL(14,2)`; thời điểm lưu giờ VN. |
| H2 | **T11, T12** — DDL thật 10 bảng người dùng / sản phẩm | Thay `00_TAM_BangGiaDinh_CuaHung.sql` | Giữ đúng 5 điểm ghi ở đầu file 00: bỏ `DiemTichLuy`; `UNIQUE (MaDiaChi, MaKhachHang)` ở `DIA_CHI`; PK ghép + `UNIQUE (MaSanPham, MauSac, KichCo)` ở `BIEN_THE_SAN_PHAM`; `NHAN_VIEN.MaNhanVien UNIQUE`; `SAN_PHAM.TongSoLuongDaBan`. Nếu khác tên cột → báo Đại sửa. |
| H3 | **T06, T07** — cập nhật EERD và lược đồ theo DDL của Đại | `13_DDL_DonHang_Diem.sql` | Thêm 2 bảng `CHINH_SACH_DIEM`, `DIEM_DANH_DANG_NHAP`; `DON_HANG.MaChinhSachDiemChot` (bỏ `TyLeQuyDoiDiemChot`); `PHUONG_THUC_THANH_TOAN.LaThanhToanKhiNhan`; `NHAT_KY_XU_LY_DON.NguonThaoTac` và `MaNhanVien` cho phép NULL (liên kết "Thực hiện" chuyển thành tham gia **một phần** phía nhật ký); FK ghép biến thể ở `GIO_HANG`, `CHI_TIET_DON_HANG`. Tổng 22 bảng. |
| H4 | **T08** — data dictionary toàn schema | `docs/MoTa_Routine_Dai.md` mục 7 | Đại đã viết sẵn cho 12 bảng của mình, Hưng gộp vào. |
| H5 | **T25** — trigger `TongSoLuongDaBan` | `sp_CapNhatTrangThaiDon` | Trigger dùng mã trạng thái **`DA_GIAO`** (không dùng chữ có dấu). Trạng thái đơn chỉ đổi qua `sp_CapNhatTrangThaiDon` (UPDATE một dòng `DON_HANG`); dữ liệu mẫu chèn thẳng đơn `DA_GIAO` rồi mới chèn chi tiết ⇒ trigger cần bắt cả INSERT `CHI_TIET_DON_HANG`. `DA_GIAO` và `DA_HUY` là trạng thái cuối (trigger `trg_DonHang_KiemTra` chặn quay lui). |
| H6 | **T15** — ràng buộc liên bảng phần Hưng | — | Không chặn Đại; chỉ lưu ý `trg_NhatKy_KiemTraNhanVien` (RB16) Đại đã làm, Hưng không cần làm lại. |
| H7 | Review transaction **T21–T23** | `23_QuyTrinh_DonHang.sql` | Theo bảng phối hợp: Hưng review khóa `UPDLOCK/HOLDLOCK`, `XACT_ABORT`, rollback. |

## 2. Chờ Bằng (Lê Viễn Bằng)

| # | Việc | Đại cần gì |
|---|---|---|
| B1 | **T16** — hợp nhất dữ liệu mẫu | Lấy `30_DuLieuMau_Dai.sql`; nếu ID khách / địa chỉ / biến thể / nhân viên thật khác stub thì đổi cho khớp và giữ nguyên các con số của đơn 4 (ví dụ tính tay). Nạp dữ liệu SAU khi tạo trigger. `GIO_HANG` là miền dữ liệu của Bằng (≥ 5 dòng). |
| B2 | **T32, T33** — form & danh sách biến thể | Gọi đúng `sp_ThemBienThe`, `sp_SuaBienThe`, `sp_XoaBienThe`, luôn truyền đủ `(MaSanPham, MaBienTheNoiBo)`; hiển thị nguyên văn `ERROR_MESSAGE()` (bảng mã lỗi ở đầu `22_CRUD_BienThe.sql`). Ô khóa phải khóa (read-only) khi sửa. |
| B3 | **T29** — `fn_TinhTongThanhToan` | Phải khớp công thức `T = H − V − U×v + F` với v của chính sách **chốt** trên đơn; đối chiếu với cột `TongThanhToan` của `vw_TienDonHang` (đơn 4 = 370.000). |
| B4 | **T34** — màn hình tính điểm (tùy chọn) | Có thể gọi `fn_TinhDiemKhaDung` / `vw_DiemKhaDung` / `sp_TaoDonHang` cho mục 3.3. |
| B5 | **T40** — kiểm thử UI → DB | Ca lỗi của CRUD biến thể (G2–G19 trong `90_KiemThu_Dai.sql`) nên được thử lại qua giao diện. |

## 3. Chờ Khanh (Hoàng Đình Vĩnh Khanh)

| # | Việc | Đại cần gì |
|---|---|---|
| K1 | **T03 (rà văn bản)** | Đọc `docs/T03_DacTa_CongThucDiem.md`, kiểm tra lại ví dụ tính tay. |
| K2 | **T09** — viết lại BTL1 | Thay RB11, RB17 và bước 9 mục 3.1 theo mục 8 của T03; sửa số bảng (22), số thành viên (4), số ràng buộc ở kết luận. |
| K3 | **T36** — kiểm thử độc lập 3 CRUD | Tự viết ca riêng, không chỉ chạy lại G1–G19 của Đại. |
| K4 | Dữ liệu đánh giá / tệp đánh giá | Rà 6 đánh giá + 6 tệp trong `30_DuLieuMau_Dai.sql` (miền chung Khanh + Đại). |
| K5 | **T43–T45** — báo cáo | Lấy nội dung từ `docs/MoTa_Routine_Dai.md`. |

## 4. Chờ cả nhóm / giảng viên

| # | Việc | Ghi chú |
|---|---|---|
| N1 | **Chạy thật toàn bộ script** | Theo lựa chọn hôm nay, Đại **chưa chạy** script trên SQL Server nào (chỉ rà soát tĩnh). Cần chạy `00 → 13 → 20 → 21 → 22 → 23 → 30 → 90` trên một DB và sửa lỗi nếu có. |
| N2 | **Kiểm thử hai phiên đồng thời** (`91` + `92`) | Cần hai cửa sổ truy vấn trên DB thật. |
| N3 | Xác nhận chính sách điểm với giảng viên | r = 1%, v = 100đ, c = 30%, L = 5 là đề xuất; cách hoàn điểm khi hủy, phạm vi giảm (không giảm phí vận chuyển). |
| N4 | Hạn nộp | Mô tả BTL2 ghi hạn LMS năm 2025; cần xác nhận hạn hiện hành và lịch buổi thực hành thứ 5, 6. |
