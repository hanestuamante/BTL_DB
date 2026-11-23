/* =====================================================================
   91_DongThoi_PhienA.sql — T38: kiểm thử HAI PHIÊN ĐẶT ĐỒNG THỜI (phiên A)
   Mục tiêu: hai phiên cùng tiêu điểm của KH1 không thể tiêu vượt số điểm khả dụng.

   Chuẩn bị: nạp lại DB từ 13 → 30 (KH1 có 1.073 điểm). Mở HAI cửa sổ truy vấn (SSMS/Azure Data Studio)
   cùng kết nối tới DB.
     1. Chạy file này ở cửa sổ 1: phiên A đặt đơn dùng 1.000 điểm và GIỮ giao dịch 20 giây.
     2. Trong 20 giây đó, chạy 92_DongThoi_PhienB.sql ở cửa sổ 2: phiên B cũng muốn dùng 1.000 điểm.
   Kỳ vọng:
     - Phiên B bị CHẶN tại câu khóa KHACH_HANG (UPDLOCK, HOLDLOCK) trong sp_TaoDonHang, không đọc
       được số điểm cũ 1.073.
     - Khi A COMMIT, B chạy tiếp, tính lại điểm khả dụng = 73 và bị từ chối với lỗi 50119.
     - Kết quả cuối: KH1 còn 73 điểm, không bao giờ âm.
   (Nếu bỏ khóa, cả hai phiên cùng thấy 1.073 điểm và cùng đặt được ⇒ KH1 còn −927 điểm.)
   ===================================================================== */
SET NOCOUNT ON;
DECLARE @id INT;
PRINT CONCAT(N'[A] Điểm KH1 trước khi đặt: ', dbo.fn_TinhDiemKhaDung(1));

BEGIN TRANSACTION;
    EXEC dbo.sp_TaoDonHang
         @MaKhachHang = 1, @MaDiaChi = 1, @MaPhuongThucVC = 2, @MaPhuongThucTT = 2,
         @DanhSachMuc = N'[{"MaSanPham":3,"MaBienTheNoiBo":"TRANG-20W","SoLuong":1},{"MaSanPham":5,"MaBienTheNoiBo":"DEN-2M","SoLuong":1}]',
         @DanhSachVoucher = 'GIAM50K', @DiemSuDung = 1000, @MaDonHang = @id OUTPUT;
    PRINT CONCAT(N'[A] Đã tạo đơn ', @id, N' (chưa commit). Hãy chạy phiên B ngay bây giờ...');
    WAITFOR DELAY '00:00:20';
COMMIT TRANSACTION;

PRINT CONCAT(N'[A] Đã commit. Điểm KH1 sau phiên A: ', dbo.fn_TinhDiemKhaDung(1), N' (kỳ vọng 73)');
GO
