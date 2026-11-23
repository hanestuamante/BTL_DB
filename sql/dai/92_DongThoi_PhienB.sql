/* =====================================================================
   92_DongThoi_PhienB.sql — T38: kiểm thử HAI PHIÊN ĐẶT ĐỒNG THỜI (phiên B)
   Chạy trong lúc 91_DongThoi_PhienA.sql đang WAITFOR (xem hướng dẫn ở file 91).
   Kỳ vọng: câu EXEC bị chờ đến khi A commit, sau đó báo lỗi 50119
   "Khách hàng chỉ có 73 điểm khả dụng, không đủ để dùng 1000 điểm."
   ===================================================================== */
SET NOCOUNT ON;
DECLARE @id INT, @BatDau DATETIME2(3) = SYSDATETIME();
BEGIN TRY
    EXEC dbo.sp_TaoDonHang
         @MaKhachHang = 1, @MaDiaChi = 1, @MaPhuongThucVC = 2, @MaPhuongThucTT = 1,
         @DanhSachMuc = N'[{"MaSanPham":2,"MaBienTheNoiBo":"XAM-40","SoLuong":1}]',
         @DiemSuDung = 1000, @MaDonHang = @id OUTPUT;
    PRINT CONCAT(N'FAIL [B] Phiên B vẫn đặt được đơn ', @id, N' — điểm KH1 = ', dbo.fn_TinhDiemKhaDung(1));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(CASE WHEN ERROR_NUMBER() = 50119 THEN N'PASS' ELSE N'FAIL' END,
                 N' [B] Bị chờ ', DATEDIFF(SECOND, @BatDau, SYSDATETIME()), N' giây rồi bị từ chối: ',
                 ERROR_NUMBER(), N' — ', ERROR_MESSAGE());
END CATCH;
PRINT CONCAT(N'[B] Điểm KH1 cuối cùng: ', dbo.fn_TinhDiemKhaDung(1), N' (kỳ vọng 73, không âm)');
GO
