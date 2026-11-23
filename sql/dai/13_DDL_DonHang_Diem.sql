/* =====================================================================
   13_DDL_DonHang_Diem.sql — T13 (Võ Quốc Đại)
   DDL 12 bảng nghiệp vụ: vận chuyển, thanh toán, chính sách điểm, điểm danh,
   khuyến mãi, giỏ hàng, đơn hàng, chi tiết, áp dụng khuyến mãi, đánh giá,
   tệp đánh giá, nhật ký xử lý đơn.
   Hệ quản trị: SQL Server 2019+ (compatibility level >= 130).
   Chạy SAU DDL của Hưng (T11, T12) hoặc file 00_TAM_... khi chưa có.

   Quy ước chung:
   - Mọi thời điểm lưu theo giờ Việt Nam (UTC+7), kiểu DATETIME2(0).
   - Tiền: DECIMAL(14,2) (đồng). Điểm: INT.
   - Mã trạng thái đơn (ASCII, tránh lỗi mã hóa khi tích hợp ứng dụng):
       CHO_THANH_TOAN  Chờ thanh toán      CHO_XAC_NHAN  Chờ xác nhận
       CHO_LAY_HANG    Chờ lấy hàng        DANG_GIAO     Đang giao
       DA_GIAO         Đã giao             DA_HUY        Đã hủy
   - Ràng buộc kiểm tra được trong CREATE TABLE thì dùng CHECK/UNIQUE/FK,
     KHÔNG dùng trigger (đúng yêu cầu BTL2). Ràng buộc liên bảng: xem 21_Trigger_Dai.sql
     và các procedure ở 23_QuyTrinh_DonHang.sql.
   ===================================================================== */
SET NOCOUNT ON;
GO

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
GO

/* ---------- 1. PHƯƠNG THỨC VẬN CHUYỂN ---------- */
CREATE TABLE dbo.PHUONG_THUC_VAN_CHUYEN (
    MaPhuongThucVC         INT            NOT NULL,
    TenPhuongThucVC        NVARCHAR(100)  NOT NULL,
    PhiVanChuyenThamChieu  DECIMAL(14,2)  NOT NULL,
    ThoiLuongGiaoDuKien    INT            NOT NULL,     -- số ngày
    CONSTRAINT PK_PHUONG_THUC_VAN_CHUYEN PRIMARY KEY (MaPhuongThucVC),
    CONSTRAINT UQ_PTVC_Ten UNIQUE (TenPhuongThucVC),
    CONSTRAINT CK_PTVC_Phi CHECK (PhiVanChuyenThamChieu >= 0),
    CONSTRAINT CK_PTVC_ThoiLuong CHECK (ThoiLuongGiaoDuKien > 0)
);

/* ---------- 2. PHƯƠNG THỨC THANH TOÁN ---------- */
CREATE TABLE dbo.PHUONG_THUC_THANH_TOAN (
    MaPhuongThucTT      INT            NOT NULL,
    TenPhuongThucTT     NVARCHAR(100)  NOT NULL,
    LaThanhToanKhiNhan  BIT            NOT NULL CONSTRAINT DF_PTTT_COD DEFAULT (0),
        -- 1 = COD: đơn bắt đầu ở CHO_XAC_NHAN; 0 = trả trước: đơn bắt đầu ở CHO_THANH_TOAN (RB15)
    CONSTRAINT PK_PHUONG_THUC_THANH_TOAN PRIMARY KEY (MaPhuongThucTT),
    CONSTRAINT UQ_PTTT_Ten UNIQUE (TenPhuongThucTT)
);

/* ---------- 3. CHÍNH SÁCH ĐIỂM (phiên bản) ----------
   Khoảng hiệu lực nửa mở [HieuLucTu, HieuLucDen); HieuLucDen NULL = chưa kết thúc.
   Không chồng lấn giữa các phiên bản: trigger trg_ChinhSachDiem_KiemTra. */
CREATE TABLE dbo.CHINH_SACH_DIEM (
    MaChinhSach         INT            NOT NULL,
    TenChinhSach        NVARCHAR(100)  NOT NULL,
    HieuLucTu           DATETIME2(0)   NOT NULL,
    HieuLucDen          DATETIME2(0)   NULL,
    TyLeTichDiem        DECIMAL(5,4)   NOT NULL,   -- r: 0.0100 = 1% tiền hàng thực trả
    GiaTriMotDiem       DECIMAL(14,2)  NOT NULL,   -- v: đồng / 1 điểm
    TyLeGiamToiDa       DECIMAL(5,4)   NOT NULL,   -- c: 0.3000 = tối đa 30% tiền hàng sau voucher
    DiemThuongDangNhap  INT            NOT NULL,   -- L: điểm / lần đăng nhập hợp lệ đầu tiên trong ngày
    CONSTRAINT PK_CHINH_SACH_DIEM PRIMARY KEY (MaChinhSach),
    CONSTRAINT CK_CSD_HieuLuc CHECK (HieuLucDen IS NULL OR HieuLucDen > HieuLucTu),
    CONSTRAINT CK_CSD_TyLeTichDiem CHECK (TyLeTichDiem >= 0 AND TyLeTichDiem <= 1),
    CONSTRAINT CK_CSD_GiaTriMotDiem CHECK (GiaTriMotDiem > 0),
    CONSTRAINT CK_CSD_TyLeGiamToiDa CHECK (TyLeGiamToiDa >= 0 AND TyLeGiamToiDa <= 1),
    CONSTRAINT CK_CSD_DiemDangNhap CHECK (DiemThuongDangNhap >= 0)
);

/* ---------- 4. ĐIỂM DANH ĐĂNG NHẬP ----------
   Mỗi khách tối đa 1 lần thưởng / ngày (giờ VN) → khóa chính (MaKhachHang, NgayTinhThuongVN). */
CREATE TABLE dbo.DIEM_DANH_DANG_NHAP (
    MaKhachHang          INT           NOT NULL,
    NgayTinhThuongVN     DATE          NOT NULL,
    ThoiDiemDangNhap     DATETIME2(0)  NOT NULL,
    MaChinhSachDiemChot  INT           NOT NULL,
    CONSTRAINT PK_DIEM_DANH_DANG_NHAP PRIMARY KEY (MaKhachHang, NgayTinhThuongVN),
    CONSTRAINT FK_DIEM_DANH_KHACH_HANG FOREIGN KEY (MaKhachHang) REFERENCES dbo.KHACH_HANG (MaNguoiDung),
    CONSTRAINT FK_DIEM_DANH_CHINH_SACH FOREIGN KEY (MaChinhSachDiemChot) REFERENCES dbo.CHINH_SACH_DIEM (MaChinhSach),
    CONSTRAINT CK_DIEM_DANH_Ngay CHECK (NgayTinhThuongVN = CAST(ThoiDiemDangNhap AS DATE))
);

/* ---------- 5. KHUYẾN MÃI (voucher) ---------- */
CREATE TABLE dbo.KHUYEN_MAI (
    MaVoucher          VARCHAR(20)    NOT NULL,
    TenChuongTrinh     NVARCHAR(200)  NOT NULL,
    GiaTriGiamGia      DECIMAL(14,2)  NOT NULL,
    GiaTriDonToiThieu  DECIMAL(14,2)  NOT NULL CONSTRAINT DF_KM_DonToiThieu DEFAULT (0),
    NgayBatDau         DATETIME2(0)   NOT NULL,
    NgayKetThuc        DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_KHUYEN_MAI PRIMARY KEY (MaVoucher),
    CONSTRAINT CK_KM_GiaTriGiam CHECK (GiaTriGiamGia > 0),
    CONSTRAINT CK_KM_DonToiThieu CHECK (GiaTriDonToiThieu >= 0),
    CONSTRAINT CK_KM_ThoiGian CHECK (NgayKetThuc > NgayBatDau)                 -- RB7
);

/* ---------- 6. GIỎ HÀNG (liên kết N:M khách hàng – biến thể) ---------- */
CREATE TABLE dbo.GIO_HANG (
    MaKhachHang     INT          NOT NULL,
    MaSanPham       INT          NOT NULL,
    MaBienTheNoiBo  VARCHAR(20)  NOT NULL,
    SoLuongDuMua    INT          NOT NULL,
    CONSTRAINT PK_GIO_HANG PRIMARY KEY (MaKhachHang, MaSanPham, MaBienTheNoiBo),
    CONSTRAINT FK_GIO_HANG_KHACH_HANG FOREIGN KEY (MaKhachHang) REFERENCES dbo.KHACH_HANG (MaNguoiDung),
    CONSTRAINT FK_GIO_HANG_BIEN_THE FOREIGN KEY (MaSanPham, MaBienTheNoiBo)
        REFERENCES dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo),
    CONSTRAINT CK_GIO_HANG_SoLuong CHECK (SoLuongDuMua > 0)
);

/* ---------- 7. ĐƠN HÀNG ----------
   Thay đổi so với BTL1: bỏ TyLeQuyDoiDiemChot (mơ hồ), thêm MaChinhSachDiemChot (FK phiên bản chính sách).
   Tổng tiền thanh toán là thuộc tính dẫn xuất → không lưu, tính ở vw_TienDonHang. */
CREATE TABLE dbo.DON_HANG (
    MaDonHang            INT             IDENTITY(1,1) NOT NULL,
    NgayDatHang          DATETIME2(0)    NOT NULL CONSTRAINT DF_DON_HANG_NgayDat DEFAULT (CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATETIME2(0))),
    TrangThaiDon         VARCHAR(20)     NOT NULL,
    NgayGiaoDuKien       DATE            NOT NULL,
    DiemSuDung           INT             NOT NULL CONSTRAINT DF_DON_HANG_DiemSuDung DEFAULT (0),
    PhiVanChuyenChot     DECIMAL(14,2)   NOT NULL,
    LoiNhanNguoiBan      NVARCHAR(500)   NULL,
    TenNguoiNhan         NVARCHAR(100)   NOT NULL,
    DiaChiGiaoHang       NVARCHAR(400)   NOT NULL,
    SdtNguoiNhan         VARCHAR(15)     NOT NULL,
    MaKhachHang          INT             NOT NULL,
    MaDiaChi             INT             NOT NULL,
    MaPhuongThucVC       INT             NOT NULL,
    MaPhuongThucTT       INT             NOT NULL,
    MaChinhSachDiemChot  INT             NOT NULL,
    CONSTRAINT PK_DON_HANG PRIMARY KEY (MaDonHang),
    CONSTRAINT FK_DON_HANG_KHACH_HANG FOREIGN KEY (MaKhachHang) REFERENCES dbo.KHACH_HANG (MaNguoiDung),
    -- RB14: địa chỉ giao phải thuộc chính khách đặt đơn → FK ghép tới UNIQUE (MaDiaChi, MaKhachHang)
    CONSTRAINT FK_DON_HANG_DIA_CHI FOREIGN KEY (MaDiaChi, MaKhachHang) REFERENCES dbo.DIA_CHI (MaDiaChi, MaKhachHang),
    CONSTRAINT FK_DON_HANG_PTVC FOREIGN KEY (MaPhuongThucVC) REFERENCES dbo.PHUONG_THUC_VAN_CHUYEN (MaPhuongThucVC),
    CONSTRAINT FK_DON_HANG_PTTT FOREIGN KEY (MaPhuongThucTT) REFERENCES dbo.PHUONG_THUC_THANH_TOAN (MaPhuongThucTT),
    CONSTRAINT FK_DON_HANG_CHINH_SACH FOREIGN KEY (MaChinhSachDiemChot) REFERENCES dbo.CHINH_SACH_DIEM (MaChinhSach),
    CONSTRAINT CK_DON_HANG_TrangThai CHECK (TrangThaiDon IN
        ('CHO_THANH_TOAN','CHO_XAC_NHAN','CHO_LAY_HANG','DANG_GIAO','DA_GIAO','DA_HUY')),
    CONSTRAINT CK_DON_HANG_NgayGiao CHECK (NgayGiaoDuKien >= CAST(NgayDatHang AS DATE)),   -- RB2
    CONSTRAINT CK_DON_HANG_DiemSuDung CHECK (DiemSuDung >= 0),
    CONSTRAINT CK_DON_HANG_PhiVC CHECK (PhiVanChuyenChot >= 0),
    CONSTRAINT CK_DON_HANG_Sdt CHECK (SdtNguoiNhan LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
CREATE INDEX IX_DON_HANG_KhachHang ON dbo.DON_HANG (MaKhachHang, TrangThaiDon);

/* ---------- 8. CHI TIẾT ĐƠN HÀNG (thực thể yếu của DON_HANG) ----------
   FK ghép tới biến thể (MaSanPham, MaBienTheNoiBo) — biến thể là thực thể yếu của SAN_PHAM. */
CREATE TABLE dbo.CHI_TIET_DON_HANG (
    MaDonHang       INT            NOT NULL,
    SoThuTuDong     INT            NOT NULL,
    SoLuongMua      INT            NOT NULL,
    DonGiaLucDat    DECIMAL(14,2)  NOT NULL,
    MauSacChot      NVARCHAR(50)   NOT NULL,
    KichCoChot      NVARCHAR(20)   NOT NULL,
    MaSanPham       INT            NOT NULL,
    MaBienTheNoiBo  VARCHAR(20)    NOT NULL,
    CONSTRAINT PK_CHI_TIET_DON_HANG PRIMARY KEY (MaDonHang, SoThuTuDong),
    CONSTRAINT FK_CTDH_DON_HANG FOREIGN KEY (MaDonHang) REFERENCES dbo.DON_HANG (MaDonHang),
    CONSTRAINT FK_CTDH_BIEN_THE FOREIGN KEY (MaSanPham, MaBienTheNoiBo)
        REFERENCES dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo),
    CONSTRAINT UQ_CTDH_BienThe UNIQUE (MaDonHang, MaSanPham, MaBienTheNoiBo),   -- mỗi biến thể 1 dòng / đơn
    CONSTRAINT CK_CTDH_STT CHECK (SoThuTuDong > 0),
    CONSTRAINT CK_CTDH_SoLuong CHECK (SoLuongMua > 0),
    CONSTRAINT CK_CTDH_DonGia CHECK (DonGiaLucDat >= 0)
);
CREATE INDEX IX_CTDH_BienThe ON dbo.CHI_TIET_DON_HANG (MaSanPham, MaBienTheNoiBo);

/* ---------- 9. ÁP DỤNG KHUYẾN MÃI (N:M đơn hàng – voucher) ----------
   RB5, RB6, RB8 (liên bảng) kiểm tra bằng trigger trg_ApDungKhuyenMai_KiemTra. */
CREATE TABLE dbo.AP_DUNG_KHUYEN_MAI (
    MaDonHang     INT            NOT NULL,
    MaVoucher     VARCHAR(20)    NOT NULL,
    TienGiamChot  DECIMAL(14,2)  NOT NULL,
    CONSTRAINT PK_AP_DUNG_KHUYEN_MAI PRIMARY KEY (MaDonHang, MaVoucher),
    CONSTRAINT FK_ADKM_DON_HANG FOREIGN KEY (MaDonHang) REFERENCES dbo.DON_HANG (MaDonHang),
    CONSTRAINT FK_ADKM_KHUYEN_MAI FOREIGN KEY (MaVoucher) REFERENCES dbo.KHUYEN_MAI (MaVoucher),
    CONSTRAINT CK_ADKM_TienGiam CHECK (TienGiamChot > 0)
);

/* ---------- 10. ĐÁNH GIÁ (1:1 với dòng chi tiết đơn) ----------
   RB1 (chỉ đánh giá dòng của đơn đã giao, sau mốc giao) → trigger trg_DanhGia_KiemTraQuyen (T24). */
CREATE TABLE dbo.DANH_GIA (
    MaDanhGia         INT             IDENTITY(1,1) NOT NULL,
    SoSao             TINYINT         NOT NULL,
    ThoiGianDanhGia   DATETIME2(0)    NOT NULL CONSTRAINT DF_DANH_GIA_ThoiGian DEFAULT (CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATETIME2(0))),
    NoiDungBinhLuan   NVARCHAR(2000)  NULL,
    DanhGiaDungMoTa   NVARCHAR(100)   NULL,
    SoLuotBamHuuIch   INT             NOT NULL CONSTRAINT DF_DANH_GIA_HuuIch DEFAULT (0),
    MaDonHang         INT             NOT NULL,
    SoThuTuDong       INT             NOT NULL,
    CONSTRAINT PK_DANH_GIA PRIMARY KEY (MaDanhGia),
    CONSTRAINT UQ_DANH_GIA_DongChiTiet UNIQUE (MaDonHang, SoThuTuDong),        -- tối đa 1 đánh giá / dòng
    CONSTRAINT FK_DANH_GIA_CTDH FOREIGN KEY (MaDonHang, SoThuTuDong)
        REFERENCES dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong),
    CONSTRAINT CK_DANH_GIA_SoSao CHECK (SoSao BETWEEN 1 AND 5),                -- RB12
    CONSTRAINT CK_DANH_GIA_HuuIch CHECK (SoLuotBamHuuIch >= 0)
);

/* ---------- 11. TỆP ĐÁNH GIÁ (thuộc tính đa trị) ---------- */
CREATE TABLE dbo.TEP_DANH_GIA (
    MaDanhGia  INT           NOT NULL,
    UriTep     VARCHAR(400)  NOT NULL,
    LoaiTep    VARCHAR(10)   NOT NULL,
    CONSTRAINT PK_TEP_DANH_GIA PRIMARY KEY (MaDanhGia, UriTep),
    CONSTRAINT FK_TEP_DANH_GIA FOREIGN KEY (MaDanhGia) REFERENCES dbo.DANH_GIA (MaDanhGia) ON DELETE CASCADE,
    CONSTRAINT CK_TEP_DANH_GIA_Loai CHECK (LoaiTep IN ('HinhAnh','Video'))
);

/* ---------- 12. NHẬT KÝ XỬ LÝ ĐƠN ----------
   Đề xuất mở rộng so với BTL1: thêm NguonThaoTac để ghi cả thao tác của khách (hủy) và hệ thống
   (tạo đơn, xác nhận thanh toán, hủy quá hạn). MaNhanVien bắt buộc khi và chỉ khi nguồn là nhân viên. */
CREATE TABLE dbo.NHAT_KY_XU_LY_DON (
    MaNhatKy        INT            IDENTITY(1,1) NOT NULL,
    ThoiDiem        DATETIME2(0)   NOT NULL CONSTRAINT DF_NHAT_KY_ThoiDiem DEFAULT (CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATETIME2(0))),
    ThaoTac         NVARCHAR(100)  NOT NULL,
    TrangThaiTruoc  VARCHAR(20)    NULL,           -- NULL ở dòng "Tạo đơn hàng"
    TrangThaiSau    VARCHAR(20)    NOT NULL,
    GhiChu          NVARCHAR(500)  NULL,
    MaDonHang       INT            NOT NULL,
    NguonThaoTac    VARCHAR(10)    NOT NULL,
    MaNhanVien      VARCHAR(10)    NULL,
    CONSTRAINT PK_NHAT_KY_XU_LY_DON PRIMARY KEY (MaNhatKy),
    CONSTRAINT FK_NHAT_KY_DON_HANG FOREIGN KEY (MaDonHang) REFERENCES dbo.DON_HANG (MaDonHang),
    CONSTRAINT FK_NHAT_KY_NHAN_VIEN FOREIGN KEY (MaNhanVien) REFERENCES dbo.NHAN_VIEN (MaNhanVien),
    CONSTRAINT CK_NHAT_KY_TrangThaiTruoc CHECK (TrangThaiTruoc IS NULL OR TrangThaiTruoc IN
        ('CHO_THANH_TOAN','CHO_XAC_NHAN','CHO_LAY_HANG','DANG_GIAO','DA_GIAO','DA_HUY')),
    CONSTRAINT CK_NHAT_KY_TrangThaiSau CHECK (TrangThaiSau IN
        ('CHO_THANH_TOAN','CHO_XAC_NHAN','CHO_LAY_HANG','DANG_GIAO','DA_GIAO','DA_HUY')),
    CONSTRAINT CK_NHAT_KY_DoiTrangThai CHECK (TrangThaiTruoc IS NULL OR TrangThaiTruoc <> TrangThaiSau),
    CONSTRAINT CK_NHAT_KY_Nguon CHECK (NguonThaoTac IN ('NhanVien','KhachHang','HeThong')),
    CONSTRAINT CK_NHAT_KY_NhanVien CHECK (
        (NguonThaoTac = 'NhanVien' AND MaNhanVien IS NOT NULL) OR
        (NguonThaoTac <> 'NhanVien' AND MaNhanVien IS NULL))
);
CREATE INDEX IX_NHAT_KY_DonHang ON dbo.NHAT_KY_XU_LY_DON (MaDonHang, TrangThaiSau, ThoiDiem);
GO
PRINT N'13: Đã tạo 12 bảng nghiệp vụ đơn hàng / điểm của Đại.';
GO
