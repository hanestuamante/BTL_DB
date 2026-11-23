/* =====================================================================
   00_tam_bang_nguoi_dung_san_pham.sql
   !!! FILE TẠM — KHÔNG NỘP — XÓA KHI CÓ 11_ddl_nguoi_dung.sql VÀ 12_ddl_san_pham.sql !!!

   10 bảng dưới đây thuộc phần việc của Khưu Huỳnh Gia Hưng (T11, T12).
   Bản tối giản (Đại viết) để các script 13 → 92 chạy được trước khi có DDL thật.
   Khi có DDL thật của Hưng: BỎ file này, chạy DDL của Hưng thay thế.

   Những điểm DDL thật cần giữ để khớp các bảng 13 (xem docs/phan-cong-va-tien-do.md):
     1. KHACH_HANG không còn cột DiemTichLuy (điểm là thuộc tính dẫn xuất).
     2. DIA_CHI có UNIQUE (MaDiaChi, MaKhachHang) để DON_HANG dùng FK ghép
        → hiện thực RB14 "địa chỉ giao hàng phải thuộc khách đặt đơn" bằng khai báo.
     3. BIEN_THE_SAN_PHAM: PK (MaSanPham, MaBienTheNoiBo), MaBienTheNoiBo VARCHAR(20),
        UNIQUE (MaSanPham, MauSac, KichCo), MauSac/KichCo NOT NULL.
     4. NHAN_VIEN.MaNhanVien VARCHAR(10) UNIQUE (NHAT_KY_XU_LY_DON tham chiếu cột này).
     5. SAN_PHAM có cột TongSoLuongDaBan (T25 của Hưng duy trì bằng trigger).
   Kiểu khóa giả định: MaNguoiDung, MaDiaChi, MaSanPham, MaDanhMuc, MaThuongHieu là INT.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Xóa theo thứ tự ngược phụ thuộc (gồm cả 12 bảng của Đại nếu đã tồn tại) */
DROP TABLE IF EXISTS dbo.TEP_DANH_GIA;
DROP TABLE IF EXISTS dbo.DANH_GIA;
DROP TABLE IF EXISTS dbo.NHAT_KY_XU_LY_DON;
DROP TABLE IF EXISTS dbo.AP_DUNG_KHUYEN_MAI;
DROP TABLE IF EXISTS dbo.CHI_TIET_DON_HANG;
DROP TABLE IF EXISTS dbo.DON_HANG;
DROP TABLE IF EXISTS dbo.GIO_HANG;
DROP TABLE IF EXISTS dbo.KHUYEN_MAI;
DROP TABLE IF EXISTS dbo.DIEM_DANH_DANG_NHAP;
DROP TABLE IF EXISTS dbo.CHINH_SACH_DIEM;
DROP TABLE IF EXISTS dbo.PHUONG_THUC_THANH_TOAN;
DROP TABLE IF EXISTS dbo.PHUONG_THUC_VAN_CHUYEN;

DROP TABLE IF EXISTS dbo.BIEN_THE_SAN_PHAM;
DROP TABLE IF EXISTS dbo.HINH_ANH_SAN_PHAM;
DROP TABLE IF EXISTS dbo.SAN_PHAM;
DROP TABLE IF EXISTS dbo.THUONG_HIEU;
DROP TABLE IF EXISTS dbo.DANH_MUC;
DROP TABLE IF EXISTS dbo.DIA_CHI;
DROP TABLE IF EXISTS dbo.NHAN_VIEN;
DROP TABLE IF EXISTS dbo.KHACH_HANG;
DROP TABLE IF EXISTS dbo.SDT_LIEN_LAC;
DROP TABLE IF EXISTS dbo.NGUOI_DUNG;
GO

CREATE TABLE dbo.NGUOI_DUNG (
    MaNguoiDung   INT            NOT NULL,
    TenDangNhap   VARCHAR(50)    NOT NULL,
    MatKhauBam    VARCHAR(255)   NOT NULL,
    Ho            NVARCHAR(50)   NOT NULL,
    Ten           NVARCHAR(50)   NOT NULL,
    Email         VARCHAR(100)   NOT NULL,
    SdtXacThuc    VARCHAR(15)    NULL,
    GioiTinh      NVARCHAR(10)   NULL,
    NgaySinh      DATE           NULL,
    AnhDaiDien    VARCHAR(255)   NULL,
    CONSTRAINT PK_NGUOI_DUNG PRIMARY KEY (MaNguoiDung),
    CONSTRAINT UQ_NGUOI_DUNG_TenDangNhap UNIQUE (TenDangNhap),
    CONSTRAINT UQ_NGUOI_DUNG_Email UNIQUE (Email)
);

CREATE TABLE dbo.SDT_LIEN_LAC (
    MaNguoiDung   INT          NOT NULL,
    SoDienThoai   VARCHAR(15)  NOT NULL,
    CONSTRAINT PK_SDT_LIEN_LAC PRIMARY KEY (MaNguoiDung, SoDienThoai),
    CONSTRAINT FK_SDT_LIEN_LAC_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung)
);

CREATE TABLE dbo.KHACH_HANG (
    MaNguoiDung   INT NOT NULL,          -- KHÔNG còn DiemTichLuy (điểm là thuộc tính dẫn xuất)
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaNguoiDung),
    CONSTRAINT FK_KHACH_HANG_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung)
);

CREATE TABLE dbo.NHAN_VIEN (
    MaNguoiDung   INT            NOT NULL,
    MaNhanVien    VARCHAR(10)    NOT NULL,
    ChucVu        NVARCHAR(50)   NOT NULL,
    Luong         DECIMAL(14,2)  NOT NULL,
    NgayVaoLam    DATE           NOT NULL,
    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaNguoiDung),
    CONSTRAINT UQ_NHAN_VIEN_MaNhanVien UNIQUE (MaNhanVien),
    CONSTRAINT FK_NHAN_VIEN_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung),
    CONSTRAINT CK_NHAN_VIEN_Luong CHECK (Luong > 0)
);

CREATE TABLE dbo.DIA_CHI (
    MaDiaChi          INT            NOT NULL,
    MaKhachHang       INT            NOT NULL,
    TenNguoiNhan      NVARCHAR(100)  NOT NULL,
    SdtNguoiNhan      VARCHAR(15)    NOT NULL,
    SoNha             NVARCHAR(20)   NOT NULL,
    TenDuong          NVARCHAR(100)  NOT NULL,
    Phuong            NVARCHAR(100)  NOT NULL,
    TinhThanhPho      NVARCHAR(100)  NOT NULL,
    LaMacDinh         BIT            NOT NULL CONSTRAINT DF_DIA_CHI_LaMacDinh DEFAULT (0),
    LaDiaChiLayHang   BIT            NOT NULL CONSTRAINT DF_DIA_CHI_LayHang DEFAULT (0),
    LaDiaChiTraHang   BIT            NOT NULL CONSTRAINT DF_DIA_CHI_TraHang DEFAULT (0),
    CONSTRAINT PK_DIA_CHI PRIMARY KEY (MaDiaChi),
    CONSTRAINT UQ_DIA_CHI_MaDiaChi_MaKhachHang UNIQUE (MaDiaChi, MaKhachHang),   -- cần cho FK ghép ở DON_HANG
    CONSTRAINT FK_DIA_CHI_KHACH_HANG FOREIGN KEY (MaKhachHang) REFERENCES dbo.KHACH_HANG (MaNguoiDung)
);

CREATE TABLE dbo.DANH_MUC (
    MaDanhMuc      INT            NOT NULL,
    TenDanhMuc     NVARCHAR(100)  NOT NULL,
    MaDanhMucCha   INT            NULL,
    CONSTRAINT PK_DANH_MUC PRIMARY KEY (MaDanhMuc),
    CONSTRAINT FK_DANH_MUC_CHA FOREIGN KEY (MaDanhMucCha) REFERENCES dbo.DANH_MUC (MaDanhMuc)
);

CREATE TABLE dbo.THUONG_HIEU (
    MaThuongHieu   INT            NOT NULL,
    TenThuongHieu  NVARCHAR(100)  NOT NULL,
    CONSTRAINT PK_THUONG_HIEU PRIMARY KEY (MaThuongHieu),
    CONSTRAINT UQ_THUONG_HIEU_Ten UNIQUE (TenThuongHieu)
);

CREATE TABLE dbo.SAN_PHAM (
    MaSanPham         INT             NOT NULL,
    TenSanPham        NVARCHAR(200)   NOT NULL,
    GiaNiemYet        DECIMAL(14,2)   NOT NULL,
    MoTaChiTiet       NVARCHAR(MAX)   NULL,
    TongSoLuongDaBan  INT             NOT NULL CONSTRAINT DF_SAN_PHAM_DaBan DEFAULT (0),
    MaThuongHieu      INT             NOT NULL,
    MaDanhMuc         INT             NOT NULL,
    CONSTRAINT PK_SAN_PHAM PRIMARY KEY (MaSanPham),
    CONSTRAINT FK_SAN_PHAM_THUONG_HIEU FOREIGN KEY (MaThuongHieu) REFERENCES dbo.THUONG_HIEU (MaThuongHieu),
    CONSTRAINT FK_SAN_PHAM_DANH_MUC FOREIGN KEY (MaDanhMuc) REFERENCES dbo.DANH_MUC (MaDanhMuc),
    CONSTRAINT CK_SAN_PHAM_GiaNiemYet CHECK (GiaNiemYet > 0),
    CONSTRAINT CK_SAN_PHAM_DaBan CHECK (TongSoLuongDaBan >= 0)
);

CREATE TABLE dbo.HINH_ANH_SAN_PHAM (
    MaSanPham         INT           NOT NULL,
    DuongDanHinhAnh   VARCHAR(400)  NOT NULL,
    CONSTRAINT PK_HINH_ANH_SAN_PHAM PRIMARY KEY (MaSanPham, DuongDanHinhAnh),
    CONSTRAINT FK_HINH_ANH_SAN_PHAM FOREIGN KEY (MaSanPham) REFERENCES dbo.SAN_PHAM (MaSanPham)
);

/* Thực thể yếu: định danh bởi (MaSanPham, MaBienTheNoiBo) */
CREATE TABLE dbo.BIEN_THE_SAN_PHAM (
    MaSanPham        INT            NOT NULL,
    MaBienTheNoiBo   VARCHAR(20)    NOT NULL,
    MauSac           NVARCHAR(50)   NOT NULL,
    KichCo           NVARCHAR(20)   NOT NULL,
    TonKhoRieng      INT            NOT NULL CONSTRAINT DF_BIEN_THE_TonKho DEFAULT (0),
    GiaBanRieng      DECIMAL(14,2)  NOT NULL,
    CONSTRAINT PK_BIEN_THE_SAN_PHAM PRIMARY KEY (MaSanPham, MaBienTheNoiBo),
    CONSTRAINT FK_BIEN_THE_SAN_PHAM FOREIGN KEY (MaSanPham) REFERENCES dbo.SAN_PHAM (MaSanPham),
    CONSTRAINT UQ_BIEN_THE_PhanLoai UNIQUE (MaSanPham, MauSac, KichCo),
    CONSTRAINT CK_BIEN_THE_TonKho CHECK (TonKhoRieng >= 0),
    CONSTRAINT CK_BIEN_THE_Gia CHECK (GiaBanRieng > 0)
);
GO

/* ---------- Dữ liệu tối giản (Hưng/Bằng sẽ thay bằng dữ liệu thật) ---------- */
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email, SdtXacThuc, GioiTinh, NgaySinh) VALUES
 (1, 'an.nguyen',   'sha256$a1', N'Nguyễn Văn', N'An',    'an.nguyen@mail.vn',   '0901000001', N'Nam', '2002-03-15'),
 (2, 'binh.tran',   'sha256$a2', N'Trần Thị',   N'Bình',  'binh.tran@mail.vn',   '0901000002', N'Nữ',  '1999-07-20'),
 (3, 'chi.le',      'sha256$a3', N'Lê Minh',    N'Chi',   'chi.le@mail.vn',      '0901000003', N'Nữ',  '2004-11-02'),
 (4, 'dung.pham',   'sha256$a4', N'Phạm Quốc',  N'Dũng',  'dung.pham@mail.vn',   '0901000004', N'Nam', '1995-01-30'),
 (5, 'em.hoang',    'sha256$a5', N'Hoàng Thu',  N'Em',    'em.hoang@mail.vn',    '0901000005', N'Nữ',  '1998-05-12'),
 (6, 'giang.vo',    'sha256$a6', N'Võ Trường',  N'Giang', 'giang.vo@mail.vn',    '0901000006', N'Nam', '2001-09-09'),
 (7, 'hai.dang',    'sha256$a7', N'Đặng Thanh', N'Hải',   'hai.dang@mail.vn',    '0901000007', N'Nam', '1993-12-25');

INSERT dbo.SDT_LIEN_LAC (MaNguoiDung, SoDienThoai) VALUES
 (1,'0911000001'),(2,'0911000002'),(3,'0911000003'),(4,'0911000004'),(6,'0911000006');

-- Khách hàng: 1, 2, 3, 4, 6.  Nhân viên: 4 (NV01 — vừa là khách vừa là nhân viên), 5 (NV02), 7 (NV03)
INSERT dbo.KHACH_HANG (MaNguoiDung) VALUES (1),(2),(3),(4),(6);
INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam) VALUES
 (4, 'NV01', N'Nhân viên xử lý đơn', 12000000, '2024-03-01'),
 (5, 'NV02', N'Nhân viên kho',        10000000, '2024-06-15'),
 (7, 'NV03', N'Trưởng nhóm vận hành', 18000000, '2023-09-01');

INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho, LaMacDinh) VALUES
 (1, 1, N'Nguyễn Văn An',     '0901000001', N'268',  N'Lý Thường Kiệt',  N'Phường Diên Hồng', N'TP. Hồ Chí Minh', 1),
 (2, 2, N'Trần Thị Bình',     '0901000002', N'12A',  N'Nguyễn Trãi',     N'Phường Bến Thành', N'TP. Hồ Chí Minh', 1),
 (3, 3, N'Lê Minh Chi',       '0901000003', N'45',   N'Trần Phú',        N'Phường Hải Châu',  N'TP. Đà Nẵng',     1),
 (4, 4, N'Phạm Quốc Dũng',    '0901000004', N'7',    N'Hai Bà Trưng',    N'Phường Hoàn Kiếm', N'TP. Hà Nội',      1),
 (5, 6, N'Võ Trường Giang',   '0901000006', N'101',  N'Võ Văn Ngân',     N'Phường Thủ Đức',   N'TP. Hồ Chí Minh', 1),
 (6, 1, N'Nguyễn Văn An (KTX)','0901000001', N'KTX B', N'Tô Vĩnh Diện',   N'Phường Linh Xuân', N'TP. Hồ Chí Minh', 0);

INSERT dbo.DANH_MUC (MaDanhMuc, TenDanhMuc, MaDanhMucCha) VALUES
 (1, N'Thời trang', NULL), (2, N'Áo', 1), (3, N'Giày dép', 1), (4, N'Điện tử', NULL), (5, N'Phụ kiện điện thoại', 4);

INSERT dbo.THUONG_HIEU (MaThuongHieu, TenThuongHieu) VALUES
 (1, N'Coolmate'), (2, N'Biti''s'), (3, N'Anker'), (4, N'Uniqlo'), (5, N'Baseus');

INSERT dbo.SAN_PHAM (MaSanPham, TenSanPham, GiaNiemYet, MoTaChiTiet, MaThuongHieu, MaDanhMuc) VALUES
 (1, N'Áo thun cotton nam',          199000, N'Cotton 100%, form regular', 1, 2),
 (2, N'Giày thể thao Hunter',        899000, N'Đế cao su, thoáng khí',     2, 3),
 (3, N'Củ sạc nhanh 20W',            350000, N'Chuẩn PD 20W',              3, 5),
 (4, N'Áo khoác gió chống nước',     590000, N'Vải dù 2 lớp',              4, 2),
 (5, N'Cáp sạc USB-C',               120000, N'Bện dù, sạc nhanh 60W',     5, 5),
 (6, N'Ốp lưng điện thoại trong suốt', 80000, N'TPU chống ố vàng',         5, 5);

INSERT dbo.HINH_ANH_SAN_PHAM (MaSanPham, DuongDanHinhAnh) VALUES
 (1,'/img/sp1-1.jpg'),(2,'/img/sp2-1.jpg'),(3,'/img/sp3-1.jpg'),(4,'/img/sp4-1.jpg'),(5,'/img/sp5-1.jpg'),(6,'/img/sp6-1.jpg');

INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES
 (1, 'DEN-M',     N'Đen',       N'M',    50, 199000),
 (1, 'DEN-L',     N'Đen',       N'L',    40, 199000),
 (1, 'TRANG-M',   N'Trắng',     N'M',    30, 189000),
 (2, 'XAM-40',    N'Xám',       N'40',   20, 899000),
 (2, 'XAM-41',    N'Xám',       N'41',   15, 899000),
 (3, 'TRANG-20W', N'Trắng',     N'20W', 100, 350000),
 (4, 'XANH-L',    N'Xanh navy', N'L',    25, 590000),
 (5, 'DEN-1M',    N'Đen',       N'1m',   80, 120000),
 (5, 'DEN-2M',    N'Đen',       N'2m',   60, 150000),
 (6, 'TRONG-IP15',N'Trong suốt',N'iPhone 15', 70, 80000);
GO
PRINT N'00: Đã tạo 10 bảng TẠM của phần Hưng + dữ liệu tối giản.';
GO
