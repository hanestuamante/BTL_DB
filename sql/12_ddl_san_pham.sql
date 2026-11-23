/* =====================================================================
   12_ddl_san_pham.sql — T12 (Khưu Huỳnh Gia Hưng)
   DDL 4 bảng: THUONG_HIEU, SAN_PHAM, HINH_ANH_SAN_PHAM, BIEN_THE_SAN_PHAM.
   Thiết kế, data dictionary và lý do: docs/csdl-nguoi-dung-san-pham.md (mục 2, 4).
   Chạy SAU 11_ddl_nguoi_dung.sql (SAN_PHAM tham chiếu DANH_MUC).

   - BIEN_THE_SAN_PHAM là THỰC THỂ YẾU của SAN_PHAM: khóa (MaSanPham, MaBienTheNoiBo).
     Mọi nơi tham chiếu biến thể (GIO_HANG, CHI_TIET_DON_HANG ở file 13) dùng khóa ngoại ghép.
   - SAN_PHAM.TongSoLuongDaBan là thuộc tính dẫn xuất được lưu, trigger T25 (25_trigger_dan_xuat.sql) duy trì.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

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

/* Thuộc tính đa trị "Hình ảnh sản phẩm" */
CREATE TABLE dbo.HINH_ANH_SAN_PHAM (
    MaSanPham         INT           NOT NULL,
    DuongDanHinhAnh   VARCHAR(400)  NOT NULL,
    CONSTRAINT PK_HINH_ANH_SAN_PHAM PRIMARY KEY (MaSanPham, DuongDanHinhAnh),
    CONSTRAINT FK_HINH_ANH_SAN_PHAM FOREIGN KEY (MaSanPham) REFERENCES dbo.SAN_PHAM (MaSanPham) ON DELETE CASCADE
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
    CONSTRAINT UQ_BIEN_THE_PhanLoai UNIQUE (MaSanPham, MauSac, KichCo),       -- collation CI_AS: 'đen' trùng 'Đen', 'Den' khác 'Đen'
    CONSTRAINT CK_BIEN_THE_TonKho CHECK (TonKhoRieng >= 0),                    -- RB3
    CONSTRAINT CK_BIEN_THE_Gia CHECK (GiaBanRieng > 0),
    -- cùng quy tắc với lỗi 50004 của sp_ThemBienThe: chỉ A–Z, 0–9, '-'
    CONSTRAINT CK_BIEN_THE_MaDinhDang CHECK (MaBienTheNoiBo <> '' AND MaBienTheNoiBo COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9-]%')
);
GO
PRINT N'12: Đã tạo 4 bảng thương hiệu, sản phẩm, hình ảnh, biến thể.';
GO
