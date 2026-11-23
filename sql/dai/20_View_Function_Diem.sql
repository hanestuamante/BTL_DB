/* =====================================================================
   20_View_Function_Diem.sql — Võ Quốc Đại
   - fn_ThoiDiemVN, fn_ChinhSachHieuLuc : hàm tiện ích
   - fn_KiemTraVoucher                  : T23 (kiểm tra voucher)
   - vw_TienDonHang, vw_DiemKhaDung     : T26 (view tính điểm khả dụng)
   - fn_TinhDiemKhaDung                 : T27 (hàm có cursor, IF, LOOP, validate tham số)
   Công thức: docs/T03_DacTa_CongThucDiem.md
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Thời điểm hiện tại theo giờ Việt Nam (UTC+7, không có giờ mùa hè) */
CREATE OR ALTER FUNCTION dbo.fn_ThoiDiemVN()
RETURNS DATETIME2(0)
AS
BEGIN
    RETURN CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATETIME2(0));
END;
GO

/* Phiên bản chính sách điểm đang hiệu lực tại @ThoiDiem; NULL nếu không có */
CREATE OR ALTER FUNCTION dbo.fn_ChinhSachHieuLuc (@ThoiDiem DATETIME2(0))
RETURNS INT
AS
BEGIN
    DECLARE @Ma INT;
    IF @ThoiDiem IS NULL RETURN NULL;
    SELECT TOP (1) @Ma = MaChinhSach
    FROM dbo.CHINH_SACH_DIEM
    WHERE HieuLucTu <= @ThoiDiem
      AND (HieuLucDen IS NULL OR @ThoiDiem < HieuLucDen)
    ORDER BY HieuLucTu DESC;
    RETURN @Ma;
END;
GO

/* ---------------------------------------------------------------------
   T23 — fn_KiemTraVoucher
   Trả về NULL nếu voucher dùng được cho đơn có tổng tiền hàng @TongTienHang
   đặt tại @ThoiDiem; ngược lại trả về thông báo lỗi CỤ THỂ.
   Hiện thực RB5 (giá trị đơn tối thiểu) và RB8 (còn hiệu lực khi áp dụng).
   Dùng chung bởi sp_TaoDonHang và trigger trg_ApDungKhuyenMai_KiemTra.
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_KiemTraVoucher
(
    @MaVoucher     VARCHAR(400),
    @TongTienHang  DECIMAL(18,2),
    @ThoiDiem      DATETIME2(0)
)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @BatDau DATETIME2(0), @KetThuc DATETIME2(0), @ToiThieu DECIMAL(14,2);

    IF @MaVoucher IS NULL OR LTRIM(RTRIM(@MaVoucher)) = ''
        RETURN N'Mã voucher không được để trống.';
    IF @TongTienHang IS NULL OR @TongTienHang < 0
        RETURN N'Tổng tiền hàng dùng để kiểm tra voucher phải là số không âm.';
    IF @ThoiDiem IS NULL
        SET @ThoiDiem = dbo.fn_ThoiDiemVN();

    SELECT @BatDau = NgayBatDau, @KetThuc = NgayKetThuc, @ToiThieu = GiaTriDonToiThieu
    FROM dbo.KHUYEN_MAI
    WHERE MaVoucher = LTRIM(RTRIM(@MaVoucher));

    IF @BatDau IS NULL
        RETURN CONCAT(N'Voucher "', LTRIM(RTRIM(@MaVoucher)), N'" không tồn tại.');
    IF @ThoiDiem < @BatDau
        RETURN CONCAT(N'Voucher "', @MaVoucher, N'" chưa đến thời gian áp dụng (bắt đầu từ ',
                      CONVERT(VARCHAR(16), @BatDau, 120), N').');
    IF @ThoiDiem > @KetThuc
        RETURN CONCAT(N'Voucher "', @MaVoucher, N'" đã hết hạn (kết thúc lúc ',
                      CONVERT(VARCHAR(16), @KetThuc, 120), N').');
    IF @TongTienHang < @ToiThieu
        RETURN CONCAT(N'Đơn hàng chưa đạt giá trị tối thiểu ', FORMAT(@ToiThieu, 'N0'),
                      N'đ để dùng voucher "', @MaVoucher, N'" (tổng tiền hàng hiện tại: ',
                      FORMAT(@TongTienHang, 'N0'), N'đ).');
    RETURN NULL;
END;
GO

/* ---------------------------------------------------------------------
   T26 — vw_TienDonHang: các đại lượng tiền / điểm của từng đơn
     H = Σ SoLuongMua × DonGiaLucDat      V = Σ TienGiamChot
     U = DiemSuDung, G = U × v            F = PhiVanChuyenChot
     A = H − V − G (tiền hàng thực trả)   T = A + F (tổng thanh toán)
     E = FLOOR(A × r / v)  (chỉ được ghi nhận khi đơn DA_GIAO)
   r, v lấy từ phiên bản chính sách CHỐT trên đơn (MaChinhSachDiemChot).
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_TienDonHang
AS
WITH TienHang AS (
    SELECT MaDonHang, SUM(SoLuongMua * DonGiaLucDat) AS TongTienHang
    FROM dbo.CHI_TIET_DON_HANG
    GROUP BY MaDonHang
),
GiamVoucher AS (
    SELECT MaDonHang, SUM(TienGiamChot) AS TongGiamVoucher
    FROM dbo.AP_DUNG_KHUYEN_MAI
    GROUP BY MaDonHang
)
SELECT
    d.MaDonHang,
    d.MaKhachHang,
    d.TrangThaiDon,
    d.NgayDatHang,
    d.MaChinhSachDiemChot,
    x.H                                   AS TongTienHang,
    x.V                                   AS GiamVoucher,
    d.DiemSuDung,
    x.G                                   AS GiamBangDiem,
    d.PhiVanChuyenChot                    AS PhiVanChuyen,
    y.A                                   AS TienHangThucTra,
    y.A + d.PhiVanChuyenChot              AS TongThanhToan,
    CASE WHEN x.H - x.V > 0
         THEN CAST(ROUND(x.G * 100 / (x.H - x.V), 2) AS DECIMAL(6,2))
         ELSE 0 END                       AS TyLeGiamBangDiemPhanTram,
    CASE WHEN y.A > 0
         THEN CAST(FLOOR(y.A * cs.TyLeTichDiem / cs.GiaTriMotDiem) AS INT)
         ELSE 0 END                       AS DiemMuaHangDuKien,
    CASE WHEN d.TrangThaiDon = 'DA_GIAO' AND y.A > 0
         THEN CAST(FLOOR(y.A * cs.TyLeTichDiem / cs.GiaTriMotDiem) AS INT)
         ELSE 0 END                       AS DiemMuaHangDaNhan
FROM dbo.DON_HANG d
JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = d.MaChinhSachDiemChot
LEFT JOIN TienHang h       ON h.MaDonHang = d.MaDonHang
LEFT JOIN GiamVoucher v    ON v.MaDonHang = d.MaDonHang
CROSS APPLY (SELECT ISNULL(h.TongTienHang, 0)    AS H,
                    ISNULL(v.TongGiamVoucher, 0) AS V,
                    d.DiemSuDung * cs.GiaTriMotDiem AS G) x
CROSS APPLY (SELECT x.H - x.V - x.G AS A) y;
GO

/* ---------------------------------------------------------------------
   T26 — vw_DiemKhaDung
   DiemKhaDung = Σ điểm mua hàng (đơn DA_GIAO)
               + Σ điểm thưởng đăng nhập (theo chính sách chốt của từng lần điểm danh)
               − Σ điểm đã dùng ở các đơn CHƯA bị hủy
   (Hủy đơn hợp lệ ⇒ điểm của đơn tự động không còn bị trừ; không có thao tác "hoàn" thứ hai.)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DiemKhaDung
AS
SELECT
    kh.MaNguoiDung                                       AS MaKhachHang,
    ISNULL(mh.Diem, 0)                                   AS DiemMuaHang,
    ISNULL(dn.Diem, 0)                                   AS DiemDangNhap,
    ISNULL(sd.Diem, 0)                                   AS DiemDaSuDung,
    ISNULL(mh.Diem, 0) + ISNULL(dn.Diem, 0) - ISNULL(sd.Diem, 0) AS DiemKhaDung
FROM dbo.KHACH_HANG kh
LEFT JOIN (SELECT MaKhachHang, SUM(DiemMuaHangDaNhan) AS Diem
           FROM dbo.vw_TienDonHang
           WHERE TrangThaiDon = 'DA_GIAO'
           GROUP BY MaKhachHang) mh ON mh.MaKhachHang = kh.MaNguoiDung
LEFT JOIN (SELECT dd.MaKhachHang, SUM(cs.DiemThuongDangNhap) AS Diem
           FROM dbo.DIEM_DANH_DANG_NHAP dd
           JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = dd.MaChinhSachDiemChot
           GROUP BY dd.MaKhachHang) dn ON dn.MaKhachHang = kh.MaNguoiDung
LEFT JOIN (SELECT MaKhachHang, SUM(DiemSuDung) AS Diem
           FROM dbo.DON_HANG
           WHERE TrangThaiDon <> 'DA_HUY'
           GROUP BY MaKhachHang) sd ON sd.MaKhachHang = kh.MaNguoiDung;
GO

/* ---------------------------------------------------------------------
   T27 — fn_TinhDiemKhaDung(@MaKhachHang)
   Yêu cầu BTL2 2.4: có tham số + kiểm tra tham số, có CURSOR, IF và LOOP,
   truy vấn dữ liệu để tính toán.
   Giá trị trả về:
     >= 0 : số điểm khả dụng
       -1 : tham số NULL hoặc không dương
       -2 : mã không phải là khách hàng
   (Hàm trong SQL Server không được THROW nên dùng mã âm để báo tham số sai.)
   Kết quả phải BẰNG cột DiemKhaDung của vw_DiemKhaDung (kiểm thử ở 90_KiemThu_Dai.sql).
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_TinhDiemKhaDung (@MaKhachHang INT)
RETURNS INT
AS
BEGIN
    IF @MaKhachHang IS NULL OR @MaKhachHang <= 0
        RETURN -1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaNguoiDung = @MaKhachHang)
        RETURN -2;

    DECLARE @Tong        INT = 0,
            @MaDon       INT,
            @TrangThai   VARCHAR(20),
            @U           INT,
            @r           DECIMAL(5,4),
            @GiaTriDiem  DECIMAL(14,2),
            @H           DECIMAL(18,2),
            @TongGiam    DECIMAL(18,2),
            @A           DECIMAL(18,2),
            @DiemDangNhap INT;

    DECLARE cur_DonHang CURSOR LOCAL FAST_FORWARD FOR
        SELECT d.MaDonHang, d.TrangThaiDon, d.DiemSuDung, cs.TyLeTichDiem, cs.GiaTriMotDiem
        FROM dbo.DON_HANG d
        JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = d.MaChinhSachDiemChot
        WHERE d.MaKhachHang = @MaKhachHang
        ORDER BY d.MaDonHang;

    OPEN cur_DonHang;
    FETCH NEXT FROM cur_DonHang INTO @MaDon, @TrangThai, @U, @r, @GiaTriDiem;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Đơn đã giao: cộng điểm mua hàng E = FLOOR(A × r / v)
        IF @TrangThai = 'DA_GIAO'
        BEGIN
            SELECT @H = ISNULL(SUM(SoLuongMua * DonGiaLucDat), 0)
            FROM dbo.CHI_TIET_DON_HANG WHERE MaDonHang = @MaDon;

            SELECT @TongGiam = ISNULL(SUM(TienGiamChot), 0)
            FROM dbo.AP_DUNG_KHUYEN_MAI WHERE MaDonHang = @MaDon;

            SET @A = @H - @TongGiam - @U * @GiaTriDiem;
            IF @A > 0
                SET @Tong = @Tong + CAST(FLOOR(@A * @r / @GiaTriDiem) AS INT);
        END;

        -- Đơn chưa bị hủy: điểm đã dùng vẫn bị trừ
        IF @TrangThai <> 'DA_HUY'
            SET @Tong = @Tong - @U;

        FETCH NEXT FROM cur_DonHang INTO @MaDon, @TrangThai, @U, @r, @GiaTriDiem;
    END;

    CLOSE cur_DonHang;
    DEALLOCATE cur_DonHang;

    -- Điểm thưởng đăng nhập theo chính sách chốt của từng lần điểm danh
    SELECT @DiemDangNhap = ISNULL(SUM(cs.DiemThuongDangNhap), 0)
    FROM dbo.DIEM_DANH_DANG_NHAP dd
    JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = dd.MaChinhSachDiemChot
    WHERE dd.MaKhachHang = @MaKhachHang;

    RETURN @Tong + @DiemDangNhap;
END;
GO
PRINT N'20: Đã tạo fn_ThoiDiemVN, fn_ChinhSachHieuLuc, fn_KiemTraVoucher, vw_TienDonHang, vw_DiemKhaDung, fn_TinhDiemKhaDung.';
GO
