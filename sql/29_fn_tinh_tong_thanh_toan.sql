/* =====================================================================
   29_fn_tinh_tong_thanh_toan.sql — T29 (Lê Viễn Bằng)
   Tổng thanh toán T = H − V − U×v + F, theo chính sách điểm chốt của đơn.
   Mã lỗi: -1 mã đơn không hợp lệ, -2 đơn không tồn tại, -3 đơn chưa có chi tiết.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER FUNCTION dbo.fn_TinhTongThanhToan (@MaDonHang INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF @MaDonHang IS NULL OR @MaDonHang <= 0
        RETURN -1;

    DECLARE @H DECIMAL(28,2) = 0, @V DECIMAL(28,2) = 0,
            @DiemSuDung INT, @GiaTriMotDiem DECIMAL(14,2), @PhiVanChuyen DECIMAL(14,2),
            @SoLuong INT, @DonGia DECIMAL(14,2), @TienGiam DECIMAL(14,2),
            @CoChiTiet BIT = 0;

    SELECT @DiemSuDung = d.DiemSuDung,
           @GiaTriMotDiem = cs.GiaTriMotDiem,
           @PhiVanChuyen = d.PhiVanChuyenChot
    FROM dbo.DON_HANG AS d
    JOIN dbo.CHINH_SACH_DIEM AS cs ON cs.MaChinhSach = d.MaChinhSachDiemChot
    WHERE d.MaDonHang = @MaDonHang;

    IF @DiemSuDung IS NULL
        RETURN -2;

    DECLARE cur_ChiTiet CURSOR LOCAL FAST_FORWARD FOR
        SELECT SoLuongMua, DonGiaLucDat
        FROM dbo.CHI_TIET_DON_HANG
        WHERE MaDonHang = @MaDonHang;

    OPEN cur_ChiTiet;
    FETCH NEXT FROM cur_ChiTiet INTO @SoLuong, @DonGia;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CoChiTiet = 1;
        SET @H = @H + @SoLuong * @DonGia;
        FETCH NEXT FROM cur_ChiTiet INTO @SoLuong, @DonGia;
    END;
    CLOSE cur_ChiTiet;
    DEALLOCATE cur_ChiTiet;

    IF @CoChiTiet = 0
        RETURN -3;

    DECLARE cur_Voucher CURSOR LOCAL FAST_FORWARD FOR
        SELECT TienGiamChot
        FROM dbo.AP_DUNG_KHUYEN_MAI
        WHERE MaDonHang = @MaDonHang;

    OPEN cur_Voucher;
    FETCH NEXT FROM cur_Voucher INTO @TienGiam;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @V = @V + @TienGiam;
        FETCH NEXT FROM cur_Voucher INTO @TienGiam;
    END;
    CLOSE cur_Voucher;
    DEALLOCATE cur_Voucher;

    IF @V > @H
        SET @V = @H;

    RETURN @H - @V - @DiemSuDung * @GiaTriMotDiem + @PhiVanChuyen;
END;
GO
