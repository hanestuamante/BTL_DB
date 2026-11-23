/* =====================================================================
   23_QuyTrinh_DonHang.sql — T20, T21, T22 (Võ Quốc Đại)
     sp_DiemDanhDangNhap      T20 — thưởng đăng nhập tối đa 1 lần/ngày (giờ VN)
     sp_TaoDonHang            T21 — giao dịch tạo đơn: điểm, voucher, tồn kho, chốt dữ liệu
     sp_CapNhatTrangThaiDon   T22 — chuyển trạng thái / hủy đơn, hoàn tồn đúng 1 lần, ghi nhật ký
   Mã lỗi: 50100–50129 tạo đơn, 50130–50149 trạng thái, 50180–50189 điểm danh.
   Công thức: docs/T03_DacTa_CongThucDiem.md
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   T20 — sp_DiemDanhDangNhap
   Gọi sau mỗi lần đăng nhập thành công. Lần đầu trong ngày (giờ VN) được cộng
   L điểm theo chính sách hiệu lực tại thời điểm đăng nhập; các lần sau trả 0 điểm.
   @ThoiDiem: để NULL (= bây giờ). Chỉ truyền khi kiểm thử / nhập bù dữ liệu.
   Không bật XACT_ABORT để lỗi trùng khóa (hai phiên đăng nhập cùng lúc) được bắt và
   xử lý như "đã nhận thưởng" mà không làm hỏng giao dịch bên ngoài.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_DiemDanhDangNhap
    @MaKhachHang  INT,
    @ThoiDiem     DATETIME2(0)   = NULL,
    @DiemThuong   INT            = NULL OUTPUT,
    @ThongBao     NVARCHAR(300)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400), @Ngay DATE, @MaCS INT, @L INT;
    SET @DiemThuong = 0;

    IF @MaKhachHang IS NULL
        THROW 50180, N'Mã khách hàng không được để trống.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaNguoiDung = @MaKhachHang)
    BEGIN
        SET @Loi = CONCAT(N'Người dùng ', @MaKhachHang, N' không phải là khách hàng nên không được tích điểm đăng nhập.');
        THROW 50181, @Loi, 1;
    END;

    SET @ThoiDiem = ISNULL(@ThoiDiem, dbo.fn_ThoiDiemVN());
    IF @ThoiDiem > DATEADD(MINUTE, 5, dbo.fn_ThoiDiemVN())
        THROW 50182, N'Thời điểm đăng nhập không được ở tương lai.', 1;

    SET @Ngay = CAST(@ThoiDiem AS DATE);
    SET @MaCS = dbo.fn_ChinhSachHieuLuc(@ThoiDiem);

    IF @MaCS IS NULL
    BEGIN
        SET @ThongBao = N'Đăng nhập thành công nhưng không có chính sách điểm hiệu lực nên không cộng điểm.';
        SELECT @DiemThuong AS DiemThuong, @ThongBao AS ThongBao;
        RETURN 0;
    END;

    IF EXISTS (SELECT 1 FROM dbo.DIEM_DANH_DANG_NHAP
               WHERE MaKhachHang = @MaKhachHang AND NgayTinhThuongVN = @Ngay)
    BEGIN
        SET @ThongBao = CONCAT(N'Khách hàng đã nhận thưởng đăng nhập ngày ', CONVERT(VARCHAR(10), @Ngay, 103),
                               N', không cộng thêm.');
        SELECT @DiemThuong AS DiemThuong, @ThongBao AS ThongBao;
        RETURN 0;
    END;

    BEGIN TRY
        INSERT dbo.DIEM_DANH_DANG_NHAP (MaKhachHang, NgayTinhThuongVN, ThoiDiemDangNhap, MaChinhSachDiemChot)
        VALUES (@MaKhachHang, @Ngay, @ThoiDiem, @MaCS);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2627, 2601)     -- phiên khác vừa ghi điểm danh cùng ngày
        BEGIN
            SET @ThongBao = CONCAT(N'Khách hàng đã nhận thưởng đăng nhập ngày ', CONVERT(VARCHAR(10), @Ngay, 103),
                                   N', không cộng thêm.');
            SELECT @DiemThuong AS DiemThuong, @ThongBao AS ThongBao;
            RETURN 0;
        END;
        THROW;
    END CATCH;

    SELECT @L = DiemThuongDangNhap FROM dbo.CHINH_SACH_DIEM WHERE MaChinhSach = @MaCS;
    SET @DiemThuong = @L;
    SET @ThongBao = CONCAT(N'Cộng ', @L, N' điểm thưởng đăng nhập ngày ', CONVERT(VARCHAR(10), @Ngay, 103),
                           N' (chính sách ', @MaCS, N').');
    SELECT @DiemThuong AS DiemThuong, @ThongBao AS ThongBao,
           dbo.fn_TinhDiemKhaDung(@MaKhachHang) AS DiemKhaDungMoi;
    RETURN 0;
END;
GO

/* ---------------------------------------------------------------------
   T21 — sp_TaoDonHang
   @DanhSachMuc     : JSON mảng mặt hàng, ví dụ
                      N'[{"MaSanPham":3,"MaBienTheNoiBo":"TRANG-20W","SoLuong":1},
                         {"MaSanPham":5,"MaBienTheNoiBo":"DEN-2M","SoLuong":1}]'
                      (dòng trùng biến thể được gộp số lượng)
   @DanhSachVoucher : chuỗi mã voucher cách nhau bởi dấu phẩy, ví dụ 'GIAM50K,GIAM15K'
   @DiemSuDung      : U — số điểm muốn dùng (số nguyên ≥ 0)
   @ThoiDiemDat     : để NULL (= bây giờ); chỉ truyền khi kiểm thử
   Các bước (toàn bộ trong MỘT giao dịch, lỗi bất kỳ ⇒ ROLLBACK):
     1. Khóa dòng KHACH_HANG (UPDLOCK, HOLDLOCK) ⇒ các giao dịch tiêu điểm của cùng một khách
        chạy tuần tự, hai phiên không thể cùng tiêu vượt số điểm.
     2. Kiểm tra địa chỉ (thuộc khách — RB14), phương thức vận chuyển, thanh toán, chính sách hiệu lực.
     3. Khóa các biến thể (UPDLOCK), kiểm tra tồn kho (RB3), chốt đơn giá + phân loại.
     4. Voucher: hiệu lực (RB8), ngưỡng (RB5); tiền giảm = MIN(giá trị voucher, phần tiền hàng còn lại),
        áp voucher giá trị lớn trước; tổng giảm ≤ tiền hàng (RB6).
     5. Điểm: U ≤ điểm khả dụng và U ≤ FLOOR(c × (H − V) / v); tổng thanh toán ≥ 0 (RB17).
     6. Ghi DON_HANG, CHI_TIET_DON_HANG, AP_DUNG_KHUYEN_MAI; trừ tồn; xóa khỏi giỏ; ghi nhật ký.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TaoDonHang
    @MaKhachHang      INT,
    @MaDiaChi         INT,
    @MaPhuongThucVC   INT,
    @MaPhuongThucTT   INT,
    @DanhSachMuc      NVARCHAR(MAX),
    @DanhSachVoucher  VARCHAR(400)   = NULL,
    @DiemSuDung       INT            = 0,
    @LoiNhanNguoiBan  NVARCHAR(500)  = NULL,
    @ThoiDiemDat      DATETIME2(0)   = NULL,
    @MaDonHang        INT            = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Loi NVARCHAR(400);

    /* ---------- 0. Kiểm tra tham số (chưa mở giao dịch) ---------- */
    IF @MaKhachHang IS NULL
        THROW 50100, N'Mã khách hàng không được để trống.', 1;
    IF @MaDiaChi IS NULL
        THROW 50101, N'Phải chọn địa chỉ giao hàng.', 1;
    IF @MaPhuongThucVC IS NULL
        THROW 50102, N'Phải chọn phương thức vận chuyển.', 1;
    IF @MaPhuongThucTT IS NULL
        THROW 50103, N'Phải chọn phương thức thanh toán.', 1;
    SET @DiemSuDung = ISNULL(@DiemSuDung, 0);
    IF @DiemSuDung < 0
        THROW 50104, N'Số điểm sử dụng phải là số nguyên không âm.', 1;
    IF @DanhSachMuc IS NULL OR ISJSON(@DanhSachMuc) = 0
        THROW 50105, N'Danh sách mặt hàng phải là chuỗi JSON hợp lệ, ví dụ [{"MaSanPham":1,"MaBienTheNoiBo":"DEN-M","SoLuong":2}].', 1;
    SET @ThoiDiemDat = ISNULL(@ThoiDiemDat, dbo.fn_ThoiDiemVN());

    DECLARE @Raw TABLE (MaSanPham INT NULL, MaBienTheNoiBo VARCHAR(20) NULL, SoLuong INT NULL);
    INSERT @Raw (MaSanPham, MaBienTheNoiBo, SoLuong)
    SELECT MaSanPham, UPPER(LTRIM(RTRIM(MaBienTheNoiBo))), SoLuong
    FROM OPENJSON(@DanhSachMuc)
         WITH (MaSanPham INT '$.MaSanPham', MaBienTheNoiBo VARCHAR(20) '$.MaBienTheNoiBo', SoLuong INT '$.SoLuong');

    IF NOT EXISTS (SELECT 1 FROM @Raw)
        THROW 50106, N'Đơn hàng phải có ít nhất một mặt hàng.', 1;
    IF EXISTS (SELECT 1 FROM @Raw WHERE MaSanPham IS NULL OR MaBienTheNoiBo IS NULL OR MaBienTheNoiBo = '')
        THROW 50107, N'Mỗi mặt hàng phải có đủ khóa biến thể (MaSanPham, MaBienTheNoiBo).', 1;
    SELECT TOP (1) @Loi = CONCAT(N'Số lượng mua của biến thể (', MaSanPham, N', ', MaBienTheNoiBo,
                                 N') phải là số nguyên dương.')
    FROM @Raw WHERE SoLuong IS NULL OR SoLuong <= 0;
    IF @Loi IS NOT NULL THROW 50108, @Loi, 1;

    DECLARE @VoucherNhap TABLE (MaVoucher VARCHAR(400) NOT NULL);
    IF @DanhSachVoucher IS NOT NULL
        INSERT @VoucherNhap (MaVoucher)
        SELECT UPPER(LTRIM(RTRIM(value)))
        FROM STRING_SPLIT(@DanhSachVoucher, ',')
        WHERE LTRIM(RTRIM(value)) <> '';
    IF (SELECT COUNT(*) FROM @VoucherNhap) <> (SELECT COUNT(DISTINCT MaVoucher) FROM @VoucherNhap)
        THROW 50109, N'Mỗi voucher chỉ được áp dụng một lần trong cùng một đơn hàng.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---------- 1. Khóa khách hàng (chống hai phiên cùng tiêu điểm) ---------- */
        DECLARE @KhoaKH INT;
        SELECT @KhoaKH = MaNguoiDung
        FROM dbo.KHACH_HANG WITH (UPDLOCK, HOLDLOCK)
        WHERE MaNguoiDung = @MaKhachHang;
        IF @KhoaKH IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Người dùng ', @MaKhachHang, N' không phải là khách hàng nên không thể đặt hàng.');
            THROW 50110, @Loi, 1;
        END;

        /* ---------- 2. Địa chỉ, vận chuyển, thanh toán, chính sách ---------- */
        DECLARE @TenNguoiNhan NVARCHAR(100), @SdtNguoiNhan VARCHAR(15), @DiaChiText NVARCHAR(400);
        SELECT @TenNguoiNhan = TenNguoiNhan, @SdtNguoiNhan = SdtNguoiNhan,
               @DiaChiText = CONCAT(SoNha, N' ', TenDuong, N', ', Phuong, N', ', TinhThanhPho)
        FROM dbo.DIA_CHI
        WHERE MaDiaChi = @MaDiaChi AND MaKhachHang = @MaKhachHang;
        IF @TenNguoiNhan IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Địa chỉ ', @MaDiaChi, N' không tồn tại hoặc không thuộc khách hàng ', @MaKhachHang, N'.');
            THROW 50111, @Loi, 1;
        END;

        DECLARE @PhiVC DECIMAL(14,2), @SoNgayGiao INT, @LaCOD BIT;
        SELECT @PhiVC = PhiVanChuyenThamChieu, @SoNgayGiao = ThoiLuongGiaoDuKien
        FROM dbo.PHUONG_THUC_VAN_CHUYEN WHERE MaPhuongThucVC = @MaPhuongThucVC;
        IF @PhiVC IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Phương thức vận chuyển ', @MaPhuongThucVC, N' không tồn tại.');
            THROW 50112, @Loi, 1;
        END;

        SELECT @LaCOD = LaThanhToanKhiNhan
        FROM dbo.PHUONG_THUC_THANH_TOAN WHERE MaPhuongThucTT = @MaPhuongThucTT;
        IF @LaCOD IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Phương thức thanh toán ', @MaPhuongThucTT, N' không tồn tại.');
            THROW 50113, @Loi, 1;
        END;

        DECLARE @MaCS INT = dbo.fn_ChinhSachHieuLuc(@ThoiDiemDat);
        IF @MaCS IS NULL
            THROW 50114, N'Không có chính sách điểm hiệu lực tại thời điểm đặt hàng, không thể chốt đơn.', 1;
        DECLARE @TyLeTich DECIMAL(5,4), @GiaTriDiem DECIMAL(14,2), @TyLeGiamMax DECIMAL(5,4);
        SELECT @TyLeTich = TyLeTichDiem, @GiaTriDiem = GiaTriMotDiem, @TyLeGiamMax = TyLeGiamToiDa
        FROM dbo.CHINH_SACH_DIEM WHERE MaChinhSach = @MaCS;

        /* ---------- 3. Biến thể: tồn tại, khóa, tồn kho, chốt giá & phân loại ---------- */
        DECLARE @ChiTiet TABLE (
            STT INT IDENTITY(1,1) NOT NULL,
            MaSanPham INT NOT NULL, MaBienTheNoiBo VARCHAR(20) NOT NULL, SoLuong INT NOT NULL,
            DonGia DECIMAL(14,2) NULL, MauSac NVARCHAR(50) NULL, KichCo NVARCHAR(20) NULL, TonKho INT NULL);

        INSERT @ChiTiet (MaSanPham, MaBienTheNoiBo, SoLuong, DonGia, MauSac, KichCo, TonKho)
        SELECT m.MaSanPham, m.MaBienTheNoiBo, m.SoLuong, b.GiaBanRieng, b.MauSac, b.KichCo, b.TonKhoRieng
        FROM (SELECT MaSanPham, MaBienTheNoiBo, SUM(SoLuong) AS SoLuong
              FROM @Raw GROUP BY MaSanPham, MaBienTheNoiBo) m
        LEFT JOIN dbo.BIEN_THE_SAN_PHAM b WITH (UPDLOCK, ROWLOCK)
               ON b.MaSanPham = m.MaSanPham AND b.MaBienTheNoiBo = m.MaBienTheNoiBo
        ORDER BY m.MaSanPham, m.MaBienTheNoiBo;

        SELECT TOP (1) @Loi = CONCAT(N'Biến thể (', MaSanPham, N', ', MaBienTheNoiBo, N') không tồn tại.')
        FROM @ChiTiet WHERE DonGia IS NULL;
        IF @Loi IS NOT NULL THROW 50115, @Loi, 1;

        SELECT TOP (1) @Loi = CONCAT(N'Biến thể (', MaSanPham, N', ', MaBienTheNoiBo, N') chỉ còn ', TonKho,
                                     N' sản phẩm, không đủ số lượng đặt ', SoLuong, N'.')
        FROM @ChiTiet WHERE SoLuong > TonKho;
        IF @Loi IS NOT NULL THROW 50116, @Loi, 1;

        DECLARE @H DECIMAL(18,2) = (SELECT SUM(SoLuong * DonGia) FROM @ChiTiet);

        /* ---------- 4. Voucher ---------- */
        SELECT TOP (1) @Loi = k.Loi
        FROM @VoucherNhap vn
        CROSS APPLY (SELECT dbo.fn_KiemTraVoucher(vn.MaVoucher, @H, @ThoiDiemDat) AS Loi) k
        WHERE k.Loi IS NOT NULL;
        IF @Loi IS NOT NULL THROW 50117, @Loi, 1;

        DECLARE @ApDung TABLE (MaVoucher VARCHAR(20) NOT NULL PRIMARY KEY, TienGiam DECIMAL(14,2) NOT NULL);
        INSERT @ApDung (MaVoucher, TienGiam)
        SELECT x.MaVoucher,
               CASE WHEN x.DaGiamTruoc >= @H THEN 0
                    WHEN x.DaGiamTruoc + x.GiaTri > @H THEN @H - x.DaGiamTruoc
                    ELSE x.GiaTri END
        FROM (SELECT km.MaVoucher, km.GiaTriGiamGia AS GiaTri,
                     ISNULL(SUM(km.GiaTriGiamGia) OVER (ORDER BY km.GiaTriGiamGia DESC, km.MaVoucher
                                                       ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS DaGiamTruoc
              FROM @VoucherNhap vn
              JOIN dbo.KHUYEN_MAI km ON km.MaVoucher = vn.MaVoucher) x;

        SELECT TOP (1) @Loi = CONCAT(N'Voucher "', MaVoucher,
                                     N'" không còn tác dụng vì các voucher khác đã giảm hết tiền hàng; hãy bỏ voucher này.')
        FROM @ApDung WHERE TienGiam <= 0;
        IF @Loi IS NOT NULL THROW 50118, @Loi, 1;

        DECLARE @V DECIMAL(18,2) = ISNULL((SELECT SUM(TienGiam) FROM @ApDung), 0);

        /* ---------- 5. Điểm sử dụng ---------- */
        DECLARE @DiemKhaDung INT = dbo.fn_TinhDiemKhaDung(@MaKhachHang);
        DECLARE @TranDiem INT = CAST(FLOOR(@TyLeGiamMax * (@H - @V) / @GiaTriDiem) AS INT);

        IF @DiemSuDung > @DiemKhaDung
        BEGIN
            SET @Loi = CONCAT(N'Khách hàng chỉ có ', @DiemKhaDung, N' điểm khả dụng, không đủ để dùng ', @DiemSuDung, N' điểm.');
            THROW 50119, @Loi, 1;
        END;
        IF @DiemSuDung > @TranDiem
        BEGIN
            SET @Loi = CONCAT(N'Đơn này chỉ được dùng tối đa ', @TranDiem, N' điểm (',
                              CAST(@TyLeGiamMax * 100 AS DECIMAL(5,2)), N'% của ', FORMAT(@H - @V, 'N0'),
                              N'đ tiền hàng sau voucher, ', FORMAT(@GiaTriDiem, 'N0'), N'đ/điểm); đã nhập ', @DiemSuDung, N' điểm.');
            THROW 50120, @Loi, 1;
        END;

        DECLARE @G DECIMAL(18,2) = @DiemSuDung * @GiaTriDiem;
        DECLARE @T DECIMAL(18,2) = @H - @V - @G + @PhiVC;
        IF @T < 0
            THROW 50121, N'Tổng thanh toán của đơn bị âm, kiểm tra lại voucher và điểm sử dụng.', 1;

        /* ---------- 6. Ghi dữ liệu ---------- */
        DECLARE @TrangThaiDau VARCHAR(20) = CASE WHEN @LaCOD = 1 THEN 'CHO_XAC_NHAN' ELSE 'CHO_THANH_TOAN' END;

        INSERT dbo.DON_HANG (NgayDatHang, TrangThaiDon, NgayGiaoDuKien, DiemSuDung, PhiVanChuyenChot,
                             LoiNhanNguoiBan, TenNguoiNhan, DiaChiGiaoHang, SdtNguoiNhan,
                             MaKhachHang, MaDiaChi, MaPhuongThucVC, MaPhuongThucTT, MaChinhSachDiemChot)
        VALUES (@ThoiDiemDat, @TrangThaiDau, DATEADD(DAY, @SoNgayGiao, CAST(@ThoiDiemDat AS DATE)), @DiemSuDung, @PhiVC,
                @LoiNhanNguoiBan, @TenNguoiNhan, @DiaChiText, @SdtNguoiNhan,
                @MaKhachHang, @MaDiaChi, @MaPhuongThucVC, @MaPhuongThucTT, @MaCS);
        SET @MaDonHang = SCOPE_IDENTITY();

        INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot,
                                      MaSanPham, MaBienTheNoiBo)
        SELECT @MaDonHang, STT, SoLuong, DonGia, MauSac, KichCo, MaSanPham, MaBienTheNoiBo
        FROM @ChiTiet;

        INSERT dbo.AP_DUNG_KHUYEN_MAI (MaDonHang, MaVoucher, TienGiamChot)
        SELECT @MaDonHang, MaVoucher, TienGiam FROM @ApDung;

        UPDATE b
        SET TonKhoRieng = b.TonKhoRieng - c.SoLuong
        FROM dbo.BIEN_THE_SAN_PHAM b
        JOIN @ChiTiet c ON c.MaSanPham = b.MaSanPham AND c.MaBienTheNoiBo = b.MaBienTheNoiBo;

        DELETE g
        FROM dbo.GIO_HANG g
        JOIN @ChiTiet c ON c.MaSanPham = g.MaSanPham AND c.MaBienTheNoiBo = g.MaBienTheNoiBo
        WHERE g.MaKhachHang = @MaKhachHang;

        INSERT dbo.NHAT_KY_XU_LY_DON (ThoiDiem, ThaoTac, TrangThaiTruoc, TrangThaiSau, GhiChu, MaDonHang, NguonThaoTac, MaNhanVien)
        VALUES (@ThoiDiemDat, N'Tạo đơn hàng', NULL, @TrangThaiDau,
                CONCAT(N'H=', FORMAT(@H, 'N0'), N'; V=', FORMAT(@V, 'N0'), N'; U=', @DiemSuDung,
                       N'; F=', FORMAT(@PhiVC, 'N0'), N'; T=', FORMAT(@T, 'N0')),
                @MaDonHang, 'HeThong', NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @MaDonHang AS MaDonHang, TrangThaiDon, TongTienHang AS H, GiamVoucher AS V, DiemSuDung AS U,
           GiamBangDiem AS G, PhiVanChuyen AS F, TongThanhToan AS T,
           DiemMuaHangDuKien AS E_KhiGiaoThanhCong, TyLeGiamBangDiemPhanTram
    FROM dbo.vw_TienDonHang
    WHERE MaDonHang = @MaDonHang;
END;
GO

/* ---------------------------------------------------------------------
   T22 — sp_CapNhatTrangThaiDon
   Máy trạng thái (RB15):
     CHO_THANH_TOAN → CHO_XAC_NHAN   : chỉ HeThong (thanh toán thành công)
     CHO_XAC_NHAN   → CHO_LAY_HANG   : NhanVien
     CHO_LAY_HANG   → DANG_GIAO      : NhanVien
     DANG_GIAO      → DA_GIAO        : NhanVien
     (CHO_THANH_TOAN | CHO_XAC_NHAN | CHO_LAY_HANG) → DA_HUY : KhachHang, NhanVien hoặc HeThong
     DA_GIAO, DA_HUY: trạng thái cuối.
   RB16: nhân viên không xử lý đơn do chính mình đặt.
   Hủy đơn: hoàn tồn kho ĐÚNG MỘT LẦN — đơn bị khóa UPDLOCK, và DA_HUY là trạng thái cuối nên
   không thể hủy lần hai. Điểm đã dùng tự được loại khỏi tổng trừ (điểm là dẫn xuất) ⇒ không hoàn 2 lần.
   Khi đơn sang DA_GIAO, điểm mua hàng E tự xuất hiện trong vw_DiemKhaDung / fn_TinhDiemKhaDung;
   trigger T25 của Hưng cập nhật SAN_PHAM.TongSoLuongDaBan.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_CapNhatTrangThaiDon
    @MaDonHang     INT,
    @TrangThaiMoi  VARCHAR(20),
    @NguonThaoTac  VARCHAR(10),            -- 'NhanVien' | 'KhachHang' | 'HeThong'
    @MaNhanVien    VARCHAR(10)    = NULL,  -- bắt buộc khi nguồn là NhanVien
    @GhiChu        NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Loi NVARCHAR(400), @TrangThaiCu VARCHAR(20), @MaKH INT, @BuocTiep VARCHAR(20),
            @Now DATETIME2(0) = dbo.fn_ThoiDiemVN();

    SET @TrangThaiMoi = UPPER(LTRIM(RTRIM(@TrangThaiMoi)));
    SET @MaNhanVien = NULLIF(UPPER(LTRIM(RTRIM(@MaNhanVien))), '');

    IF @MaDonHang IS NULL
        THROW 50130, N'Mã đơn hàng không được để trống.', 1;
    IF @TrangThaiMoi IS NULL OR @TrangThaiMoi NOT IN ('CHO_THANH_TOAN','CHO_XAC_NHAN','CHO_LAY_HANG','DANG_GIAO','DA_GIAO','DA_HUY')
    BEGIN
        SET @Loi = CONCAT(N'Trạng thái mới "', @TrangThaiMoi,
                          N'" không hợp lệ. Giá trị cho phép: CHO_XAC_NHAN, CHO_LAY_HANG, DANG_GIAO, DA_GIAO, DA_HUY.');
        THROW 50131, @Loi, 1;
    END;
    IF @NguonThaoTac IS NULL OR @NguonThaoTac NOT IN ('NhanVien','KhachHang','HeThong')
        THROW 50132, N'Nguồn thao tác phải là NhanVien, KhachHang hoặc HeThong.', 1;
    IF @NguonThaoTac = 'NhanVien' AND @MaNhanVien IS NULL
        THROW 50132, N'Thao tác của nhân viên phải có mã nhân viên.', 1;
    IF @NguonThaoTac <> 'NhanVien' AND @MaNhanVien IS NOT NULL
        THROW 50132, N'Chỉ truyền mã nhân viên khi nguồn thao tác là NhanVien.', 1;
    IF @NguonThaoTac = 'NhanVien' AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNhanVien = @MaNhanVien)
    BEGIN
        SET @Loi = CONCAT(N'Mã nhân viên ', @MaNhanVien, N' không tồn tại.');
        THROW 50132, @Loi, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @TrangThaiCu = TrangThaiDon, @MaKH = MaKhachHang
        FROM dbo.DON_HANG WITH (UPDLOCK, HOLDLOCK)
        WHERE MaDonHang = @MaDonHang;

        IF @TrangThaiCu IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Đơn hàng ', @MaDonHang, N' không tồn tại.');
            THROW 50133, @Loi, 1;
        END;
        IF @TrangThaiCu IN ('DA_GIAO','DA_HUY')
        BEGIN
            SET @Loi = CONCAT(N'Đơn hàng ', @MaDonHang, N' đã ở trạng thái kết thúc ', @TrangThaiCu,
                              N', không thể chuyển tiếp hoặc hủy lại.');
            THROW 50134, @Loi, 1;
        END;
        IF @TrangThaiMoi = @TrangThaiCu
        BEGIN
            SET @Loi = CONCAT(N'Đơn hàng ', @MaDonHang, N' đang ở trạng thái ', @TrangThaiCu, N' rồi.');
            THROW 50135, @Loi, 1;
        END;

        SET @BuocTiep = CASE @TrangThaiCu
                            WHEN 'CHO_THANH_TOAN' THEN 'CHO_XAC_NHAN'
                            WHEN 'CHO_XAC_NHAN'   THEN 'CHO_LAY_HANG'
                            WHEN 'CHO_LAY_HANG'   THEN 'DANG_GIAO'
                            WHEN 'DANG_GIAO'      THEN 'DA_GIAO'
                        END;

        IF @TrangThaiMoi = 'DA_HUY'
        BEGIN
            IF @TrangThaiCu = 'DANG_GIAO'
            BEGIN
                SET @Loi = CONCAT(N'Đơn hàng ', @MaDonHang, N' đang giao, chỉ được hủy khi đơn ở trạng thái trước DANG_GIAO.');
                THROW 50136, @Loi, 1;
            END;
        END
        ELSE
        BEGIN
            IF @TrangThaiMoi <> @BuocTiep
            BEGIN
                SET @Loi = CONCAT(N'Không thể chuyển đơn ', @MaDonHang, N' từ ', @TrangThaiCu, N' sang ', @TrangThaiMoi,
                                  N'; bước hợp lệ tiếp theo là ', @BuocTiep,
                                  CASE WHEN @TrangThaiCu = 'DANG_GIAO' THEN N'' ELSE N' hoặc DA_HUY' END, N'.');
                THROW 50137, @Loi, 1;
            END;
            IF @NguonThaoTac = 'KhachHang'
                THROW 50138, N'Khách hàng chỉ được phép hủy đơn, không được tự chuyển trạng thái xử lý.', 1;
            IF @TrangThaiCu = 'CHO_THANH_TOAN' AND @NguonThaoTac <> 'HeThong'
                THROW 50139, N'Bước CHO_THANH_TOAN → CHO_XAC_NHAN do hệ thống thực hiện khi thanh toán thành công.', 1;
            IF @TrangThaiCu <> 'CHO_THANH_TOAN' AND @NguonThaoTac <> 'NhanVien'
            BEGIN
                SET @Loi = CONCAT(N'Bước ', @TrangThaiCu, N' → ', @TrangThaiMoi, N' phải do nhân viên thực hiện.');
                THROW 50140, @Loi, 1;
            END;
        END;

        -- RB16
        IF @NguonThaoTac = 'NhanVien'
           AND EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNhanVien = @MaNhanVien AND MaNguoiDung = @MaKH)
        BEGIN
            SET @Loi = CONCAT(N'Nhân viên ', @MaNhanVien, N' không được xử lý đơn ', @MaDonHang,
                              N' vì đơn này do chính nhân viên đó đặt với tư cách khách hàng.');
            THROW 50141, @Loi, 1;
        END;

        UPDATE dbo.DON_HANG SET TrangThaiDon = @TrangThaiMoi WHERE MaDonHang = @MaDonHang;

        IF @TrangThaiMoi = 'DA_HUY'
            UPDATE b
            SET TonKhoRieng = b.TonKhoRieng + c.SoLuongMua
            FROM dbo.BIEN_THE_SAN_PHAM b
            JOIN dbo.CHI_TIET_DON_HANG c
              ON c.MaSanPham = b.MaSanPham AND c.MaBienTheNoiBo = b.MaBienTheNoiBo
            WHERE c.MaDonHang = @MaDonHang;

        INSERT dbo.NHAT_KY_XU_LY_DON (ThoiDiem, ThaoTac, TrangThaiTruoc, TrangThaiSau, GhiChu, MaDonHang, NguonThaoTac, MaNhanVien)
        VALUES (@Now,
                CASE @TrangThaiMoi
                    WHEN 'CHO_XAC_NHAN' THEN N'Xác nhận thanh toán'
                    WHEN 'CHO_LAY_HANG' THEN N'Xác nhận đơn, chuẩn bị hàng'
                    WHEN 'DANG_GIAO'    THEN N'Bàn giao đơn vị vận chuyển'
                    WHEN 'DA_GIAO'      THEN N'Giao hàng thành công'
                    WHEN 'DA_HUY'       THEN N'Hủy đơn hàng, hoàn tồn kho'
                END,
                @TrangThaiCu, @TrangThaiMoi, @GhiChu, @MaDonHang, @NguonThaoTac, @MaNhanVien);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT d.MaDonHang, d.TrangThaiDon, d.MaKhachHang,
           dbo.fn_TinhDiemKhaDung(d.MaKhachHang) AS DiemKhaDungCuaKhach,
           CONCAT(N'Đã chuyển đơn từ ', @TrangThaiCu, N' sang ', @TrangThaiMoi, N'.') AS ThongBao
    FROM dbo.DON_HANG d
    WHERE d.MaDonHang = @MaDonHang;
END;
GO
PRINT N'23: Đã tạo sp_DiemDanhDangNhap, sp_TaoDonHang, sp_CapNhatTrangThaiDon.';
GO
