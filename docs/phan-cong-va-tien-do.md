# Phân công và tiến độ BTL2

> Nguồn: *Tài liệu 2 — Phân công BTL2 theo từng thành viên*. Mỗi người tự cập nhật cột **Trạng thái** của mình khi có tiến triển.
> Ký hiệu: ✅ đã xong · 🟡 đã viết, chờ chạy thử / review · ⬜ chưa bắt đầu / chưa cập nhật.
> Cập nhật gần nhất: 23/11/2026.

## Mốc triển khai

| Mốc | Điều kiện hoàn thành | Trạng thái |
|---|---|---|
| M1 — Chốt thiết kế | T03–T08 thống nhất; không đổi khóa / công thức tùy tiện sau mốc này | ⬜ (T03 đã có; T04–T08 đã viết ở `docs/csdl-nguoi-dung-san-pham.md`, chờ Đại, Khanh rà) |
| M2 — CSDL chạy độc lập | DDL, ràng buộc, dữ liệu mẫu và routine chạy được từ DB rỗng | 🟡 đạt trên nhánh `hung/csdl-nguoi-dung-san-pham` (23/11): chạy hết từ DB rỗng, kiểm thử 50 + 18 + 64 ca đều PASS; chờ gộp PR |
| M3 — Báo cáo sơ bộ | Thiết kế, bảng, dữ liệu, phân công, tiến độ theo mẫu lớp (buổi thực hành thứ 5) | ⬜ |
| M4 — Tích hợp | UI kết nối DB thật; chạy đủ ca kiểm thử và xử lý lỗi | ⬜ |
| M5 — Nộp cuối | PDF, source, SQL, README, dữ liệu demo, kịch bản bảo vệ đồng bộ (buổi thứ 6) | ⬜ |

## A. Khưu Huỳnh Gia Hưng — CSDL, EERD, schema, ràng buộc

| Mã | Việc | Trạng thái |
|---|---|---|
| T04 | Sửa BIEN_THE_SAN_PHAM thành thực thể yếu, khóa riêng phần, quan hệ định danh | 🟡 `docs/csdl-nguoi-dung-san-pham.md` mục 2 |
| T05 | Specialization mapping NGUOI_DUNG / KHACH_HANG / NHAN_VIEN (total + overlapping) | 🟡 `docs/csdl-nguoi-dung-san-pham.md` mục 3 |
| T06 | Cập nhật EERD tổng thể | ⬜ |
| T07 | Ánh xạ schema 22 bảng, PK/FK ghép | 🟡 ánh xạ ở `docs/csdl-nguoi-dung-san-pham.md` mục 1 và DDL; hình lược đồ chưa vẽ |
| T08 | Data dictionary NULL / DEFAULT / UNIQUE / CHECK | 🟡 10 bảng của Hưng: `docs/csdl-nguoi-dung-san-pham.md` mục 4; 12 bảng đơn hàng – điểm: `docs/csdl-don-hang-diem.md` mục 7 |
| T10 | Chốt hệ quản trị, quy ước tên, cấu trúc thư mục, thứ tự chạy | 🟡 đã chốt trong `README.md` (SQL Server 2022 trong Docker, collation, cờ `-I`, file 38/39/40) |
| T11 | DDL người dùng, vai trò, địa chỉ, nhân viên, danh mục, dữ liệu nền | 🟡 `sql/11_ddl_nguoi_dung.sql`, `sql/38_du_lieu_mau_nguoi_dung.sql` |
| T12 | DDL sản phẩm, biến thể, bảng phụ | 🟡 `sql/12_ddl_san_pham.sql` |
| T14 | Đối chiếu đủ bảng, PK/FK, UNIQUE, NOT NULL, DEFAULT, CHECK | 🟡 nhóm K của `sql/90_kiem_thu_cau_truc_rang_buoc.sql` |
| T15 | Ràng buộc liên bảng: tuổi khách, total specialization, cây danh mục, địa chỉ | 🟡 `sql/15_rang_buoc_lien_bang.sql` (địa chỉ RB13, RB14 khai báo trong DDL 11, 13) |
| T25 | Trigger duy trì SAN_PHAM.TongSoLuongDaBan | 🟡 `sql/25_trigger_dan_xuat.sql` |
| T35 | Kiểm thử khóa ghép, NULL, miền giá trị, vai trò, cây danh mục, địa chỉ | 🟡 `sql/90_kiem_thu_cau_truc_rang_buoc.sql` (50 ca, PASS) |
| T37 | Kiểm thử trigger nghiệp vụ / dẫn xuất một dòng và nhiều dòng | 🟡 `sql/90_kiem_thu_dan_xuat_nghiep_vu.sql` (18 ca, PASS) |

## B. Võ Quốc Đại — nghiệp vụ điểm, đơn hàng, CRUD biến thể

| Mã | Việc | Trạng thái | File |
|---|---|---|---|
| T03 | Công thức tích điểm, đổi điểm, đăng nhập, hủy đơn, làm tròn, ví dụ tính tay | 🟡 chờ Khanh rà, giảng viên xác nhận số liệu | `docs/dac-ta-nghiep-vu-diem.md` |
| T13 | DDL đơn hàng, chi tiết, giỏ, voucher, đánh giá, nhật ký, chính sách, điểm danh | 🟡 | `sql/13_ddl_don_hang_diem.sql` |
| T17 | `sp_ThemBienThe` | 🟡 | `sql/22_crud_bien_the.sql` |
| T18 | `sp_SuaBienThe` | 🟡 | `sql/22_crud_bien_the.sql` |
| T19 | `sp_XoaBienThe` | 🟡 | `sql/22_crud_bien_the.sql` |
| T20 | Điểm danh đăng nhập | 🟡 | `sql/23_quy_trinh_don_hang.sql` |
| T21 | Giao dịch tạo đơn | 🟡 chờ Hưng review | `sql/23_quy_trinh_don_hang.sql` |
| T22 | Chuyển trạng thái / hủy đơn | 🟡 | `sql/23_quy_trinh_don_hang.sql` |
| T23 | Kiểm tra voucher, ngưỡng, hiệu lực, tổng giảm | 🟡 | `sql/20_…`, `sql/21_…` |
| T24 | Trigger quyền đánh giá | 🟡 | `sql/21_trigger_don_hang.sql` |
| T26 | View điểm khả dụng | 🟡 | `sql/20_function_view_diem.sql` |
| T27 | `fn_TinhDiemKhaDung` | 🟡 | `sql/20_function_view_diem.sql` |
| T38 | Kiểm thử điểm, đăng nhập lặp, chính sách mới, hủy đơn, hai phiên đồng thời | 🟡 đã viết 64 ca, chưa chạy | `sql/90_…`, `sql/91_…`, `sql/92_…` |

🟡 ở đây nghĩa là script đã viết xong nhưng **chưa chạy trên SQL Server**.

## C. Lê Viễn Bằng — backend, giao diện, tích hợp

| Mã | Việc | Trạng thái |
|---|---|---|
| T16 | Hợp nhất dữ liệu mẫu, ≥ 5 dòng có nghĩa mỗi bảng | ⬜ (miền đơn hàng – điểm đã có: `sql/40_du_lieu_mau_don_hang_diem.sql`) |
| T29 | `fn_TinhTongThanhToan` | ⬜ |
| T30 | `sp_ThongKeBanTheoSanPham` | ⬜ |
| T31 | Kết nối backend với CSDL thật | ⬜ |
| T32 | Form thêm / sửa / xóa biến thể gọi 3 procedure CRUD | ⬜ |
| T33 | Danh sách biến thể gọi Q1, search / filter / sort | ⬜ |
| T34 | Giao diện thống kê gọi Q2 | ⬜ |
| T40 | Kiểm thử UI → backend → DB | ⬜ |
| T41 | Chạy lại toàn bộ từ DB rỗng theo README | ⬜ |

## D. Hoàng Đình Vĩnh Khanh — báo cáo, đọc lại, kiểm thử tổng hợp

| Mã | Việc | Trạng thái |
|---|---|---|
| T01 | Checklist yêu cầu BTL2, feedback, phần BTL1 cần thay | ⬜ |
| T02 | Ma trận 17 ràng buộc gốc + quy tắc bổ sung | ⬜ (phần đơn hàng – điểm: `docs/csdl-don-hang-diem.md` mục 6) |
| T09 | Viết lại đoạn BTL1 liên quan | ⬜ (đoạn thay RB11, RB17: `docs/dac-ta-nghiep-vu-diem.md` mục 8) |
| T28 | `sp_TimBienThe` | ⬜ |
| T36 | Kiểm thử độc lập 3 CRUD procedure và Q1 | ⬜ |
| T39 | Chuẩn bị demo Q1, Q2, F1, F2 | ⬜ |
| T42 | Báo cáo sơ bộ (buổi thực hành thứ 5) | ⬜ |
| T43 | Báo cáo BTL2 | ⬜ |
| T44 | Chèn EERD, schema, ảnh UI, kết quả SQL | ⬜ |
| T45 | Ma trận yêu cầu → mã nguồn → minh chứng → người thực hiện | ⬜ |
| T46 | Đọc lại toàn bộ, sửa mâu thuẫn | ⬜ |
| T47 | Điều phối demo và hỏi đáp chéo | ⬜ |
| T48 | Xuất PDF, đóng gói SQL, app, README, dữ liệu demo | ⬜ |

## Bàn giao giữa các thành viên

Những điểm các phần phải khớp nhau. Ai thay đổi điều gì trong bảng này thì báo người liên quan.

### Phần DDL người dùng / sản phẩm (Hưng) ↔ phần đơn hàng (Đại)
- File tạm `00` đã bỏ (23/11). DDL thật ở `11_…`, `12_…`; dữ liệu người dùng ở `38_…`, dữ liệu sản phẩm ở `39_…`, giữ nguyên mọi mã của file 00 cũ.
- DDL thật cần giữ: `KHACH_HANG` **không** có cột `DiemTichLuy` (điểm là thuộc tính dẫn xuất); `DIA_CHI` có `UNIQUE (MaDiaChi, MaKhachHang)`; `BIEN_THE_SAN_PHAM` có PK `(MaSanPham, MaBienTheNoiBo)` và `UNIQUE (MaSanPham, MauSac, KichCo)`; `NHAN_VIEN.MaNhanVien VARCHAR(10) UNIQUE`; `SAN_PHAM.TongSoLuongDaBan`.
- Kiểu khóa (đã chốt trong DDL thật): `MaNguoiDung`, `MaDiaChi`, `MaSanPham` là `INT`; `MaBienTheNoiBo VARCHAR(20)`; tiền `DECIMAL(14,2)`.
- Người dùng mới chỉ tạo được qua `sp_TaoNguoiDung` (dữ liệu của Bằng ở T16, hoặc màn hình nếu có); INSERT thẳng vào `NGUOI_DUNG` bị chặn (50223).
- Dữ liệu sản phẩm nằm ở file `39`, Bằng mở rộng ở T16.
- `sqlcmd` phải có cờ `-I` (thiếu cờ này thì INSERT vào `DIA_CHI` lỗi 1934).
- DB tạo với `COLLATE SQL_Latin1_General_CP1_CI_AS` (lệnh trong README).
- EERD / lược đồ (T06, T07) cần thể hiện các thay đổi ở bảng đơn hàng: thêm `CHINH_SACH_DIEM`, `DIEM_DANH_DANG_NHAP`; `DON_HANG.MaChinhSachDiemChot` thay `TyLeQuyDoiDiemChot`; `PHUONG_THUC_THANH_TOAN.LaThanhToanKhiNhan`; `NHAT_KY_XU_LY_DON.NguonThaoTac` và `MaNhanVien` cho phép NULL (nhật ký ghi cả thao tác của khách và hệ thống); FK ghép biến thể ở `GIO_HANG`, `CHI_TIET_DON_HANG`. Tổng 22 bảng.
- Trigger T25 dùng mã trạng thái `DA_GIAO`. Trạng thái đơn chỉ đổi qua `sp_CapNhatTrangThaiDon`; dữ liệu mẫu chèn thẳng đơn `DA_GIAO` rồi mới chèn chi tiết, nên T25 cần bắt cả INSERT `CHI_TIET_DON_HANG`. `DA_GIAO`, `DA_HUY` là trạng thái cuối.
- RB16 (nhân viên không xử lý đơn của chính mình) đã có trong `21_trigger_don_hang.sql`, T15 không cần làm lại.

### Phần CSDL ↔ ứng dụng (Bằng)
- Form biến thể gọi đúng 3 procedure, luôn truyền đủ `(MaSanPham, MaBienTheNoiBo)`, khóa không cho sửa ô khóa; hiển thị nguyên văn `ERROR_MESSAGE()` (bảng mã lỗi ở đầu `sql/22_crud_bien_the.sql`).
- `fn_TinhTongThanhToan` (T29) phải khớp `T = H − V − U×v + F` với v của chính sách **chốt** trên đơn; đối chiếu cột `TongThanhToan` của `vw_TienDonHang` (đơn mẫu 4 = 370.000đ).
- Hợp nhất dữ liệu mẫu: nếu đổi ID khách / địa chỉ / biến thể / nhân viên thì sửa `40_du_lieu_mau_don_hang_diem.sql` cho khớp, giữ nguyên số liệu đơn 4 (ví dụ tính tay). `GIO_HANG` thuộc miền dữ liệu của Bằng.

### Phần CSDL ↔ báo cáo (Khanh)
- Nội dung cho báo cáo về đơn hàng – điểm – biến thể: `docs/csdl-don-hang-diem.md`.
- T09: thay RB11, RB17 và bước 9 mục 3.1 của BTL1 theo `docs/dac-ta-nghiep-vu-diem.md` mục 8; sửa số bảng (22), số thành viên (4), số ràng buộc ở phần kết luận.
- Dữ liệu đánh giá / tệp đánh giá (miền chung Khanh + Đại) nằm trong `40_du_lieu_mau_don_hang_diem.sql`.

## Việc chung còn mở

| Việc | Ghi chú |
|---|---|
| Chạy toàn bộ script trên một DB thống nhất | Đã chạy 23/11 trên SQL Server 2022 (Docker, máy Hưng) theo lệnh README: từ DB rỗng chạy hết, 64 + 50 + 18 ca PASS. Máy Mac chưa chạy thử. |
| Kiểm thử hai phiên đặt đồng thời (`91_…` + `92_…`) | Đã chạy 23/11: phiên B bị chặn 17 giây rồi bị từ chối 50119, KH1 còn 73 điểm (đúng kỳ vọng). |
| Xác nhận chính sách điểm với giảng viên | r = 1%, v = 100đ/điểm, c = 30%, L = 5 điểm/ngày là đề xuất; cách hoàn điểm khi hủy; điểm không giảm phí vận chuyển. |
| Xác nhận hạn nộp | Mô tả BTL2 ghi hạn LMS năm 2025; cần xác nhận hạn hiện hành và lịch buổi thực hành thứ 5, 6. |
