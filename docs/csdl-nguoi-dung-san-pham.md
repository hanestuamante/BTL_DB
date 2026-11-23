# CSDL người dùng – sản phẩm — thiết kế và data dictionary cho báo cáo BTL2

> Người viết: Khưu Huỳnh Gia Hưng (T04, T05, T07, T08). DDL ở `sql/11_ddl_nguoi_dung.sql`, `sql/12_ddl_san_pham.sql` (T11, T12) và ràng buộc liên bảng ở `sql/15_rang_buoc_lien_bang.sql` (T15) viết đúng theo tài liệu này.

> Khanh có thể chép các mục dưới đây vào báo cáo (T43–T45). Phần đơn hàng – điểm – biến thể của Đại ở `docs/csdl-don-hang-diem.md`.

## 1. 22 bảng theo nguồn ánh xạ

| Nguồn ánh xạ | Số bảng | Bảng |
|---|---|---|
| Kiểu thực thể (gồm lớp cha, hai lớp con và các thực thể yếu) | 17 | `NGUOI_DUNG`, `KHACH_HANG`, `NHAN_VIEN`, `DIA_CHI`, `DANH_MUC`, `THUONG_HIEU`, `SAN_PHAM`, `BIEN_THE_SAN_PHAM`, `PHUONG_THUC_VAN_CHUYEN`, `PHUONG_THUC_THANH_TOAN`, `KHUYEN_MAI`, `DON_HANG`, `CHI_TIET_DON_HANG`, `DANH_GIA`, `NHAT_KY_XU_LY_DON`, `CHINH_SACH_DIEM` (mới), `DIEM_DANH_DANG_NHAP` (mới) |
| Liên kết N:M | 2 | `GIO_HANG`, `AP_DUNG_KHUYEN_MAI` |
| Thuộc tính đa trị | 3 | `SDT_LIEN_LAC`, `HINH_ANH_SAN_PHAM`, `TEP_DANH_GIA` |

Bảng sinh từ thuộc tính đa trị chỉ tính một lần (cùng quy định ở BTL1 mục 3.5), nên số bảng được tính là 17 + 2 + 1 = **20**, vượt mức tối thiểu 4 × 3 = 12.

Hưng phụ trách 10 bảng: `NGUOI_DUNG`, `SDT_LIEN_LAC`, `KHACH_HANG`, `NHAN_VIEN`, `DIA_CHI`, `DANH_MUC` (file 11) và `THUONG_HIEU`, `SAN_PHAM`, `HINH_ANH_SAN_PHAM`, `BIEN_THE_SAN_PHAM` (file 12). 12 bảng còn lại do Đại viết ở file 13.

## 2. T04 — Biến thể sản phẩm là thực thể yếu

- **BTL1:** `BIEN_THE_SAN_PHAM` là thực thể thường, khóa đơn `MaBienThe`, nối với `SAN_PHAM` qua liên kết 1:N "Có biến thể".
- **BTL2:** biến thể là **thực thể yếu** của `SAN_PHAM`. Khóa riêng phần là `MaBienTheNoiBo` (ví dụ `DEN-M`), "Có biến thể" là liên kết định danh, khóa chính là cặp `(MaSanPham, MaBienTheNoiBo)`.
- **Lý do:**
  - Người bán đặt mã biến thể theo màu và cỡ, nên mã chỉ có nghĩa bên trong một sản phẩm. Hai sản phẩm khác nhau hoàn toàn có thể cùng dùng mã `DEN-M`.
  - Biến thể không tồn tại nếu không có sản phẩm của nó.
- **Hệ quả:**
  - Hai bảng tham chiếu biến thể (`GIO_HANG`, `CHI_TIET_DON_HANG`) dùng **khóa ngoại ghép** `(MaSanPham, MaBienTheNoiBo)`.
  - Nhờ khóa ghép, CSDL tự chặn những cặp không khớp, ví dụ sản phẩm 2 đi với mã `DEN-M` vốn thuộc sản phẩm 1.
  - `UNIQUE (MaSanPham, MauSac, KichCo)`: trong một sản phẩm, mỗi cặp màu – cỡ chỉ có một biến thể.
  - Với collation `SQL_Latin1_General_CP1_CI_AS`, so sánh không phân biệt hoa/thường nhưng phân biệt dấu. Vì vậy `đen` và `Đen` bị coi là trùng phân loại, còn `Den` và `Đen` là hai màu khác nhau.

## 3. T05 — Specialization NGƯỜI DÙNG → KHÁCH HÀNG, NHÂN VIÊN

**Ràng buộc trên EERD:** total (mỗi người dùng phải là khách hàng hoặc nhân viên) và overlapping (một người có thể là cả hai, ví dụ người dùng 4 là khách hàng và là nhân viên `NV01`).

**Ánh xạ:** mỗi lớp một bảng, giữ lý do ở BTL1 mục 3.1 bước 2. Hai lớp con giao nhau và mỗi lớp có thuộc tính, mối liên kết riêng, nên không gộp thành một bảng có cột phân loại. `KHACH_HANG` và `NHAN_VIEN` có khóa chính `MaNguoiDung`, đồng thời là khóa ngoại tới `NGUOI_DUNG` với `ON DELETE CASCADE`.

**Overlapping** không cần thêm gì: cùng một `MaNguoiDung` được phép có mặt ở cả hai bảng.

**Total.** SQL Server không có ràng buộc hoãn tới cuối giao dịch, nên không thể bắt "phải có dòng ở bảng con" ngay lúc chèn `NGUOI_DUNG`. Nhóm bảo đảm điều này bằng bốn cơ chế:

1. **Chỉ tạo người dùng qua `sp_TaoNguoiDung`.** Thủ tục chèn `NGUOI_DUNG` và ít nhất một vai trò trong cùng một giao dịch.
   - Không chọn vai trò nào: lỗi 50222.
   - Có `MaNhanVien` nhưng thiếu chức vụ, lương hoặc ngày vào làm: lỗi 50225.
2. **Chặn tạo người dùng không qua thủ tục.** Trigger `trg_NguoiDung_KiemTra` báo lỗi 50223. Thủ tục tự đánh dấu mình bằng `SESSION_CONTEXT(N'BTL2_TaoNguoiDung')`, nên trigger phân biệt được.
3. **Không xóa được vai trò cuối cùng.** Trigger `trg_KhachHang_KiemTraVaiTro` và `trg_NhanVien_KiemTraVaiTro` chặn việc xóa hoặc chuyển vai trò cuối cùng của một người dùng vẫn còn tồn tại (lỗi 50224).
4. **Xóa hẳn một người dùng thì xóa dòng `NGUOI_DUNG`.** Khóa ngoại `CASCADE` xóa luôn vai trò và số điện thoại liên lạc. Nếu người dùng đã có địa chỉ, đơn hàng hoặc nhật ký xử lý đơn, khóa ngoại của các bảng đó chặn việc xóa, nhờ vậy lịch sử được giữ.

## 4. T08 — Data dictionary của 10 bảng

Ký hiệu: PK khóa chính, FK khóa ngoại, NN = NOT NULL, N = cho phép NULL. "10 chữ số" nghĩa là CHECK theo mẫu `'0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'`, giống `CK_DON_HANG_Sdt` của Đại. "Ngày hiện tại" tính theo giờ Việt Nam: `CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE)`.

Cả 10 bảng có đúng **6 cột cho phép NULL**: `NGUOI_DUNG.SdtXacThuc`, `GioiTinh`, `NgaySinh`, `AnhDaiDien`; `SAN_PHAM.MoTaChiTiet`; `DANH_MUC.MaDanhMucCha`. Tổng cộng có 45 ràng buộc có tên và một index lọc `UX_DIA_CHI_MotMacDinh`.

### NGUOI_DUNG
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaNguoiDung | INT | NN | `PK_NGUOI_DUNG` | định danh; không dùng IDENTITY để dữ liệu mẫu giữ đúng mã mà file 40 tham chiếu |
| TenDangNhap | VARCHAR(50) | NN | `UQ_NGUOI_DUNG_TenDangNhap` | tên đăng nhập không trùng |
| MatKhauBam | VARCHAR(255) | NN | | chỉ lưu chuỗi băm, không lưu mật khẩu gốc |
| Ho | NVARCHAR(50) | NN | | thuộc tính tổ hợp Họ tên |
| Ten | NVARCHAR(50) | NN | | |
| Email | VARCHAR(100) | NN | `UQ_NGUOI_DUNG_Email`; `CK_NGUOI_DUNG_Email`: `LIKE '%_@_%._%'` | mỗi email một tài khoản |
| SdtXacThuc | VARCHAR(15) | N | `CK_NGUOI_DUNG_SdtXacThuc`: 10 chữ số | không bắt buộc khi đăng ký bằng email |
| GioiTinh | NVARCHAR(10) | N | `CK_NGUOI_DUNG_GioiTinh`: `N'Nam'`, `N'Nữ'`, `N'Khác'` | không bắt buộc |
| NgaySinh | DATE | N | `CK_NGUOI_DUNG_NgaySinh`: ≤ ngày hiện tại | nhân viên có thể không khai; khách hàng bắt buộc có và đủ 13 tuổi (RB4, kiểm bằng trigger) |
| AnhDaiDien | VARCHAR(255) | N | | không bắt buộc |

### SDT_LIEN_LAC
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaNguoiDung | INT | NN | `PK_SDT_LIEN_LAC`; `FK_SDT_LIEN_LAC_NGUOI_DUNG` → `NGUOI_DUNG`, ON DELETE CASCADE | thuộc tính đa trị của người dùng |
| SoDienThoai | VARCHAR(15) | NN | thuộc PK; `CK_SDT_LIEN_LAC_So`: 10 chữ số | |

### KHACH_HANG
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaNguoiDung | INT | NN | `PK_KHACH_HANG`; `FK_KHACH_HANG_NGUOI_DUNG` → `NGUOI_DUNG`, ON DELETE CASCADE | lớp con. Không còn cột `DiemTichLuy`: điểm khả dụng là thuộc tính dẫn xuất (`vw_DiemKhaDung`, `fn_TinhDiemKhaDung` của Đại) |

### NHAN_VIEN
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaNguoiDung | INT | NN | `PK_NHAN_VIEN`; `FK_NHAN_VIEN_NGUOI_DUNG` → `NGUOI_DUNG`, ON DELETE CASCADE | lớp con |
| MaNhanVien | VARCHAR(10) | NN | `UQ_NHAN_VIEN_MaNhanVien` | mã nội bộ; `NHAT_KY_XU_LY_DON` tham chiếu cột này |
| ChucVu | NVARCHAR(50) | NN | | |
| Luong | DECIMAL(14,2) | NN | `CK_NHAN_VIEN_Luong`: > 0 | RB10 |
| NgayVaoLam | DATE | NN | `CK_NHAN_VIEN_NgayVaoLam`: ≤ ngày hiện tại | RB10 |

### DIA_CHI
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDiaChi | INT | NN | `PK_DIA_CHI` | |
| MaKhachHang | INT | NN | `FK_DIA_CHI_KHACH_HANG` → `KHACH_HANG` (không CASCADE); cùng `MaDiaChi` tạo `UQ_DIA_CHI_MaDiaChi_MaKhachHang` | liên kết Lưu địa chỉ (1:N). Cặp UNIQUE là đích của khóa ngoại ghép từ `DON_HANG` (RB14) |
| TenNguoiNhan | NVARCHAR(100) | NN | | |
| SdtNguoiNhan | VARCHAR(15) | NN | `CK_DIA_CHI_Sdt`: 10 chữ số | được chép sang `DON_HANG`, nơi có cùng CHECK |
| SoNha | NVARCHAR(20) | NN | | thuộc tính tổ hợp Địa chỉ |
| TenDuong | NVARCHAR(100) | NN | | |
| Phuong | NVARCHAR(100) | NN | | |
| TinhThanhPho | NVARCHAR(100) | NN | | chuỗi ghép `SoNha TenDuong, Phuong, TinhThanhPho` dài tối đa 325 ký tự, vừa `DON_HANG.DiaChiGiaoHang NVARCHAR(400)` |
| LaMacDinh | BIT | NN | `DF_DIA_CHI_LaMacDinh` = 0; index lọc `UX_DIA_CHI_MotMacDinh` trên `(MaKhachHang) WHERE LaMacDinh = 1` | RB13: mỗi khách tối đa một địa chỉ mặc định. Ghi vào bảng có index lọc cần `QUOTED_IDENTIFIER ON` (cờ `-I` của sqlcmd) |
| LaDiaChiLayHang | BIT | NN | `DF_DIA_CHI_LayHang` = 0 | |
| LaDiaChiTraHang | BIT | NN | `DF_DIA_CHI_TraHang` = 0 | |

### DANH_MUC
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaDanhMuc | INT | NN | `PK_DANH_MUC` | |
| TenDanhMuc | NVARCHAR(100) | NN | `UQ_DANH_MUC_TenTrongCha`: `UNIQUE (MaDanhMucCha, TenDanhMuc)` | không có hai danh mục cùng tên dưới cùng một cha, kể cả hai danh mục gốc |
| MaDanhMucCha | INT | N | `FK_DANH_MUC_CHA` → `DANH_MUC`; `CK_DANH_MUC_KhongTuTroCha`: `MaDanhMucCha <> MaDanhMuc` | liên kết đệ quy, NULL là danh mục gốc. CHECK chặn tự trỏ; vòng dài hơn do trigger chặn (RB9) |

### THUONG_HIEU
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaThuongHieu | INT | NN | `PK_THUONG_HIEU` | |
| TenThuongHieu | NVARCHAR(100) | NN | `UQ_THUONG_HIEU_Ten` | |

### SAN_PHAM
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaSanPham | INT | NN | `PK_SAN_PHAM` | |
| TenSanPham | NVARCHAR(200) | NN | | |
| GiaNiemYet | DECIMAL(14,2) | NN | `CK_SAN_PHAM_GiaNiemYet`: > 0 | mốc 50–200% cho giá biến thể (`sp_ThemBienThe`) |
| MoTaChiTiet | NVARCHAR(MAX) | N | | không bắt buộc |
| TongSoLuongDaBan | INT | NN | `DF_SAN_PHAM_DaBan` = 0; `CK_SAN_PHAM_DaBan`: ≥ 0 | thuộc tính dẫn xuất **được lưu**, trigger T25 duy trì |
| MaThuongHieu | INT | NN | `FK_SAN_PHAM_THUONG_HIEU` → `THUONG_HIEU` | liên kết Cung cấp (1:N) |
| MaDanhMuc | INT | NN | `FK_SAN_PHAM_DANH_MUC` → `DANH_MUC` | liên kết Thuộc danh mục (1:N) |

### HINH_ANH_SAN_PHAM
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaSanPham | INT | NN | `PK_HINH_ANH_SAN_PHAM`; `FK_HINH_ANH_SAN_PHAM` → `SAN_PHAM`, ON DELETE CASCADE | thuộc tính đa trị của sản phẩm |
| DuongDanHinhAnh | VARCHAR(400) | NN | thuộc PK | |

### BIEN_THE_SAN_PHAM
| Cột | Kiểu | NULL | Ràng buộc / mặc định | Lý do |
|---|---|---|---|---|
| MaSanPham | INT | NN | `PK_BIEN_THE_SAN_PHAM`; `FK_BIEN_THE_SAN_PHAM` → `SAN_PHAM` (không CASCADE) | thực thể yếu, phần khóa của thực thể chủ |
| MaBienTheNoiBo | VARCHAR(20) | NN | thuộc PK; `CK_BIEN_THE_MaDinhDang`: khác rỗng, chỉ gồm `A–Z`, `0–9`, `-` | khóa riêng phần; cùng quy tắc với lỗi 50004 của `sp_ThemBienThe` |
| MauSac | NVARCHAR(50) | NN | `UQ_BIEN_THE_PhanLoai`: `UNIQUE (MaSanPham, MauSac, KichCo)` | mỗi phân loại một biến thể |
| KichCo | NVARCHAR(20) | NN | | dùng "Freesize" nếu sản phẩm không chia cỡ |
| TonKhoRieng | INT | NN | `DF_BIEN_THE_TonKho` = 0; `CK_BIEN_THE_TonKho`: ≥ 0 | RB3 |
| GiaBanRieng | DECIMAL(14,2) | NN | `CK_BIEN_THE_Gia`: > 0 | |

## 5. Ràng buộc BTL1 thuộc phần Hưng → cách hiện thực

| RB | Nội dung | Hiện thực | Mã lỗi |
|---|---|---|---|
| 4 | Khách hàng đủ 13 tuổi | `sp_TaoNguoiDung`; `trg_KhachHang_KiemTraVaiTro` khi tạo hoặc thêm vai trò khách; `trg_NguoiDung_KiemTra` khi sửa ngày sinh. Không dùng CHECK được vì điều kiện phụ thuộc bảng `KHACH_HANG` | 50220, 50221 |
| 9 | Cây danh mục không có vòng | `CK_DANH_MUC_KhongTuTroCha` (tự trỏ) + `trg_DanhMuc_KhongVongLap` (vòng qua nhiều cấp, kể cả khi một câu lệnh sửa nhiều dòng) | 547, 50240 |
| 10 | Lương dương, ngày vào làm không sau hôm nay | `CK_NHAN_VIEN_Luong`, `CK_NHAN_VIEN_NgayVaoLam` | 547 |
| 13 | Tối đa một địa chỉ mặc định mỗi khách | index lọc `UX_DIA_CHI_MotMacDinh` | 2601 |
| 14 | Địa chỉ giao thuộc khách đặt đơn | `UQ_DIA_CHI_MaDiaChi_MaKhachHang` + khóa ngoại ghép ở `DON_HANG` (file 13 của Đại) | 547 |
| — | Total specialization | mục 3 | 50222 – 50225 |

Tài liệu phân công ghi "17 ràng buộc gốc" vì bản BTL1 đã chỉnh có thêm RB17 về điểm. RB17 thuộc phần của Đại, câu thay thế ở `docs/dac-ta-nghiep-vu-diem.md` mục 8. Bản PDF BTL1 trên máy Hưng có 16 ràng buộc ở mục 1.4.

## 6. Thay đổi so với BTL1 (để Khanh sửa ở T09)

| Chỗ trong BTL1 | BTL1 | BTL2 | Lý do |
|---|---|---|---|
| Mục 3.3, 3.5: số bảng | 20 bảng, tính 18 | 22 bảng, tính 20 | thêm `CHINH_SACH_DIEM`, `DIEM_DANH_DANG_NHAP` (phần Đại) |
| `KHACH_HANG` | có `DiemTichLuy` | bỏ cột này | điểm khả dụng tính từ lịch sử đơn và điểm danh (`docs/dac-ta-nghiep-vu-diem.md`) |
| `BIEN_THE_SAN_PHAM` | thực thể thường, khóa `MaBienThe` | thực thể yếu, khóa `(MaSanPham, MaBienTheNoiBo)` | mục 2 |
| `GIO_HANG`, `CHI_TIET_DON_HANG` | khóa ngoại `MaBienThe` | khóa ngoại ghép `(MaSanPham, MaBienTheNoiBo)` | theo thay đổi ở dòng trên |
| Mục 3.1 bước 3 (thực thể yếu) | chỉ `CHI_TIET_DON_HANG` | thêm `BIEN_THE_SAN_PHAM`, `DIEM_DANH_DANG_NHAP` | |
| Mục 3.1 bước 9 (thuộc tính dẫn xuất) | tổng số lượng đã bán "không lưu thành cột" | `SAN_PHAM.TongSoLuongDaBan` **được lưu**, trigger T25 tính lại khi một dòng chi tiết của đơn đã giao thay đổi, hoặc khi đơn vào / ra trạng thái đã giao | BTL2 mục 2.2.2 yêu cầu trigger duy trì thuộc tính dẫn xuất; trigger tính lại theo tập sản phẩm bị ảnh hưởng nên giá trị không lệch, và bỏ qua dòng của đơn chưa giao nên không làm các phiên đặt đơn chờ nhau |
| `NHAT_KY_XU_LY_DON.MaNhanVien` | bắt buộc | cho phép NULL | nhật ký ghi cả thao tác của khách và hệ thống (phần Đại) |
| `DANH_MUC` | không có | thêm `UQ_DANH_MUC_TenTrongCha` | tránh hai danh mục cùng tên dưới một cha |
| Mục 1.4, 3.5: số ràng buộc | 16 (bản trên máy Hưng) | theo ma trận ràng buộc của Khanh (T02) | |
