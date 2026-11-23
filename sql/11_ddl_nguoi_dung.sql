/* =====================================================================
   11_ddl_nguoi_dung.sql — T11 (Khưu Huỳnh Gia Hưng)
   DDL 6 bảng: NGUOI_DUNG, SDT_LIEN_LAC, KHACH_HANG, NHAN_VIEN, DIA_CHI, DANH_MUC.
   Thiết kế, data dictionary và lý do: docs/csdl-nguoi-dung-san-pham.md (mục 3, 4).
   Hệ quản trị: SQL Server 2019+. Chạy trên DB rỗng tạo với COLLATE SQL_Latin1_General_CP1_CI_AS.

   Quy ước:
   - Ràng buộc kiểm tra được trong CREATE TABLE thì dùng CHECK/UNIQUE/FK, không dùng trigger.
     Ràng buộc liên bảng (tuổi khách RB4, total specialization, cây danh mục RB9): 15_rang_buoc_lien_bang.sql.
   - "Ngày hiện tại" theo giờ Việt Nam: CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE)
     (file này chạy trước 20 nên chưa có dbo.fn_ThoiDiemVN()).
   - Số điện thoại: 10 chữ số, bắt đầu bằng 0 (cùng mẫu với CK_DON_HANG_Sdt của Đại).
   - Khóa chính INT không IDENTITY: dữ liệu mẫu giữ đúng mã mà 40_du_lieu_mau_don_hang_diem.sql tham chiếu.
   - Ghi vào DIA_CHI (có index lọc) cần QUOTED_IDENTIFIER ON: chạy sqlcmd với cờ -I.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
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

/* Lớp cha của specialization total + overlapping (KHACH_HANG, NHAN_VIEN) */
CREATE TABLE dbo.NGUOI_DUNG (
    MaNguoiDung   INT            NOT NULL,
    TenDangNhap   VARCHAR(50)    NOT NULL,
    MatKhauBam    VARCHAR(255)   NOT NULL,
    Ho            NVARCHAR(50)   NOT NULL,
    Ten           NVARCHAR(50)   NOT NULL,
    Email         VARCHAR(100)   NOT NULL,
    SdtXacThuc    VARCHAR(15)    NULL,
    GioiTinh      NVARCHAR(10)   NULL,
    NgaySinh      DATE           NULL,          -- khách hàng bắt buộc có và đủ 13 tuổi: trigger ở file 15 (RB4)
    AnhDaiDien    VARCHAR(255)   NULL,
    CONSTRAINT PK_NGUOI_DUNG PRIMARY KEY (MaNguoiDung),
    CONSTRAINT UQ_NGUOI_DUNG_TenDangNhap UNIQUE (TenDangNhap),
    CONSTRAINT UQ_NGUOI_DUNG_Email UNIQUE (Email),
    CONSTRAINT CK_NGUOI_DUNG_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_NGUOI_DUNG_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CONSTRAINT CK_NGUOI_DUNG_NgaySinh CHECK (NgaySinh <= CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE)),
    CONSTRAINT CK_NGUOI_DUNG_SdtXacThuc CHECK (SdtXacThuc LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);

/* Thuộc tính đa trị "Số điện thoại liên lạc" */
CREATE TABLE dbo.SDT_LIEN_LAC (
    MaNguoiDung   INT          NOT NULL,
    SoDienThoai   VARCHAR(15)  NOT NULL,
    CONSTRAINT PK_SDT_LIEN_LAC PRIMARY KEY (MaNguoiDung, SoDienThoai),
    CONSTRAINT FK_SDT_LIEN_LAC_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung) ON DELETE CASCADE,
    CONSTRAINT CK_SDT_LIEN_LAC_So CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);

/* Lớp con. KHÔNG có DiemTichLuy: điểm khả dụng là thuộc tính dẫn xuất (vw_DiemKhaDung của Đại) */
CREATE TABLE dbo.KHACH_HANG (
    MaNguoiDung   INT NOT NULL,
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaNguoiDung),
    CONSTRAINT FK_KHACH_HANG_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung) ON DELETE CASCADE
);

/* Lớp con. MaNhanVien là khóa duy nhất mà NHAT_KY_XU_LY_DON tham chiếu */
CREATE TABLE dbo.NHAN_VIEN (
    MaNguoiDung   INT            NOT NULL,
    MaNhanVien    VARCHAR(10)    NOT NULL,
    ChucVu        NVARCHAR(50)   NOT NULL,
    Luong         DECIMAL(14,2)  NOT NULL,
    NgayVaoLam    DATE           NOT NULL,
    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaNguoiDung),
    CONSTRAINT UQ_NHAN_VIEN_MaNhanVien UNIQUE (MaNhanVien),
    CONSTRAINT FK_NHAN_VIEN_NGUOI_DUNG FOREIGN KEY (MaNguoiDung) REFERENCES dbo.NGUOI_DUNG (MaNguoiDung) ON DELETE CASCADE,
    CONSTRAINT CK_NHAN_VIEN_Luong CHECK (Luong > 0),                                                          -- RB10
    CONSTRAINT CK_NHAN_VIEN_NgayVaoLam CHECK (NgayVaoLam <= CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE)) -- RB10
);

/* Chuỗi ghép "SoNha TenDuong, Phuong, TinhThanhPho" tối đa 20+1+100+2+100+2+100 = 325 ký tự,
   vừa DON_HANG.DiaChiGiaoHang NVARCHAR(400) mà sp_TaoDonHang chép sang. */
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
    CONSTRAINT UQ_DIA_CHI_MaDiaChi_MaKhachHang UNIQUE (MaDiaChi, MaKhachHang),   -- đích của FK ghép ở DON_HANG (RB14)
    CONSTRAINT FK_DIA_CHI_KHACH_HANG FOREIGN KEY (MaKhachHang) REFERENCES dbo.KHACH_HANG (MaNguoiDung),
    CONSTRAINT CK_DIA_CHI_Sdt CHECK (SdtNguoiNhan LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
GO
/* RB13: mỗi khách tối đa một địa chỉ mặc định */
CREATE UNIQUE INDEX UX_DIA_CHI_MotMacDinh ON dbo.DIA_CHI (MaKhachHang) WHERE LaMacDinh = 1;
GO

/* Liên kết đệ quy cha – con. CHECK chặn tự trỏ; vòng qua nhiều cấp chặn bằng trg_DanhMuc_KhongVongLap (file 15, RB9) */
CREATE TABLE dbo.DANH_MUC (
    MaDanhMuc      INT            NOT NULL,
    TenDanhMuc     NVARCHAR(100)  NOT NULL,
    MaDanhMucCha   INT            NULL,
    CONSTRAINT PK_DANH_MUC PRIMARY KEY (MaDanhMuc),
    CONSTRAINT FK_DANH_MUC_CHA FOREIGN KEY (MaDanhMucCha) REFERENCES dbo.DANH_MUC (MaDanhMuc),
    CONSTRAINT CK_DANH_MUC_KhongTuTroCha CHECK (MaDanhMucCha <> MaDanhMuc),
    CONSTRAINT UQ_DANH_MUC_TenTrongCha UNIQUE (MaDanhMucCha, TenDanhMuc)
);
GO
PRINT N'11: Đã tạo 6 bảng người dùng, vai trò, địa chỉ, danh mục.';
GO
