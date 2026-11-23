/* =====================================================================
   90_kiem_thu_don_hang_diem.sql — T38 (Võ Quốc Đại)
   Kiểm thử: công thức điểm (ví dụ tính tay), điểm danh lặp, đặt đơn (điểm, voucher, tồn kho),
   chuyển trạng thái / hủy đơn (hoàn đúng 1 lần), quyền đánh giá (T24), chính sách mới,
   CRUD biến thể (T17–T19), fn_TinhDiemKhaDung = vw_DiemKhaDung.
   Kiểm thử hai phiên đặt đồng thời: 91_kiem_thu_dong_thoi_phien_a.sql + 92_kiem_thu_dong_thoi_phien_b.sql.

   CÁCH CHẠY: trên DB vừa nạp 00 (hoặc 11, 12 của Hưng) → 13 → 20 → 21 → 22 → 23 → 40, chạy file này MỘT lần
   trong cùng một phiên (dùng bảng tạm #). Mỗi ca in PASS/FAIL; cuối file có bảng tổng hợp.
   Script làm thay đổi dữ liệu (tạo đơn, đổi chính sách...) ⇒ muốn chạy lại thì nạp lại từ 13.
   Các ca dùng thời điểm hiện tại; voucher GIAM50K hết hạn 31/12/2026.
   ===================================================================== */
SET NOCOUNT ON;
GO
IF OBJECT_ID('tempdb..#KQ') IS NOT NULL DROP TABLE #KQ;
IF OBJECT_ID('tempdb..#Don') IS NOT NULL DROP TABLE #Don;
CREATE TABLE #KQ  (STT INT IDENTITY(1,1), Ma VARCHAR(10), Dat BIT, MoTa NVARCHAR(200), ChiTiet NVARCHAR(2000));
CREATE TABLE #Don (Ten VARCHAR(20) PRIMARY KEY, MaDonHang INT);
GO
IF OBJECT_ID('tempdb..#Ghi') IS NOT NULL DROP PROCEDURE #Ghi;
GO
CREATE PROCEDURE #Ghi @Ma VARCHAR(10), @MoTa NVARCHAR(200), @Dat BIT, @ChiTiet NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT #KQ (Ma, Dat, MoTa, ChiTiet) VALUES (@Ma, ISNULL(@Dat, 0), @MoTa, @ChiTiet);
    PRINT CONCAT(CASE WHEN @Dat = 1 THEN N'PASS' ELSE N'FAIL' END, N' [', @Ma, N'] ', @MoTa, N' — ', @ChiTiet);
END;
GO
IF OBJECT_ID('tempdb..#KyVongLoi') IS NOT NULL DROP PROCEDURE #KyVongLoi;
GO
/* Chạy @Sql, kỳ vọng bị từ chối với mã lỗi @MaLoi */
CREATE PROCEDURE #KyVongLoi @Ma VARCHAR(10), @MoTa NVARCHAR(200), @MaLoi INT, @Sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @So INT = 0, @Msg NVARCHAR(2048) = N'Không bị từ chối (lẽ ra phải lỗi)', @Dat BIT;
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @So = ERROR_NUMBER(), @Msg = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
    SET @Dat = CASE WHEN @So = @MaLoi THEN 1 ELSE 0 END;
    IF @Dat = 0 SET @Msg = CONCAT(N'(kỳ vọng ', @MaLoi, N') ', @Msg);
    EXEC #Ghi @Ma, @MoTa, @Dat, @Msg;
END;
GO
IF OBJECT_ID('tempdb..#KyVongOK') IS NOT NULL DROP PROCEDURE #KyVongOK;
GO
/* Chạy @Sql, kỳ vọng thành công */
CREATE PROCEDURE #KyVongOK @Ma VARCHAR(10), @MoTa NVARCHAR(200), @Sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Dat BIT = 1, @Msg NVARCHAR(2048) = N'OK';
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @Dat = 0, @Msg = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
    EXEC #Ghi @Ma, @MoTa, @Dat, @Msg;
END;
GO

/* =====================================================================
   A. DỮ LIỆU MẪU & CÔNG THỨC (T03, T26, T27)
   ===================================================================== */
DECLARE @d BIT = 0, @ct NVARCHAR(2000) = N'Không tìm thấy đơn 4';
SELECT @d = CASE WHEN TongTienHang = 500000 AND GiamVoucher = 50000 AND GiamBangDiem = 100000
                  AND PhiVanChuyen = 20000 AND TienHangThucTra = 350000 AND TongThanhToan = 370000
                  AND DiemMuaHangDaNhan = 35 AND TyLeGiamBangDiemPhanTram = 22.22 THEN 1 ELSE 0 END,
       @ct = CONCAT('H=', TongTienHang, ' V=', GiamVoucher, ' G=', GiamBangDiem, ' F=', PhiVanChuyen,
                    ' A=', TienHangThucTra, ' T=', TongThanhToan, ' E=', DiemMuaHangDaNhan, ' %=', TyLeGiamBangDiemPhanTram)
FROM dbo.vw_TienDonHang WHERE MaDonHang = 4;
EXEC #Ghi 'A1', N'Ví dụ tính tay trên đơn mẫu 4 (T=370.000, E=35, 22,22%)', @d, @ct;
GO
DECLARE @d BIT, @ct NVARCHAR(2000);
SELECT @d = CASE WHEN COUNT(*) = 5
                  AND SUM(CASE WHEN v.DiemKhaDung = k.KyVong AND dbo.fn_TinhDiemKhaDung(v.MaKhachHang) = k.KyVong THEN 1 ELSE 0 END) = 5
                 THEN 1 ELSE 0 END,
       @ct = STRING_AGG(CONCAT('KH', v.MaKhachHang, ': view=', v.DiemKhaDung, ' fn=', dbo.fn_TinhDiemKhaDung(v.MaKhachHang),
                               ' kỳ vọng=', k.KyVong), '; ')
FROM dbo.vw_DiemKhaDung v
JOIN (VALUES (1, 1073), (2, 49), (3, 134), (4, 30), (6, 0)) k (Ma, KyVong) ON k.Ma = v.MaKhachHang;
EXEC #Ghi 'A2', N'Điểm khả dụng sau dữ liệu mẫu: view = function = kỳ vọng', @d, @ct;
GO
DECLARE @d BIT = CASE WHEN dbo.fn_TinhDiemKhaDung(NULL) = -1 AND dbo.fn_TinhDiemKhaDung(-3) = -1
                       AND dbo.fn_TinhDiemKhaDung(5) = -2 AND dbo.fn_TinhDiemKhaDung(999) = -2 THEN 1 ELSE 0 END;
DECLARE @ct NVARCHAR(200) = CONCAT('NULL→', dbo.fn_TinhDiemKhaDung(NULL), ', 5 (nhân viên)→', dbo.fn_TinhDiemKhaDung(5),
                                   ', 999→', dbo.fn_TinhDiemKhaDung(999));
EXEC #Ghi 'A3', N'fn_TinhDiemKhaDung kiểm tra tham số (-1: sai tham số, -2: không phải khách)', @d, @ct;
GO

/* =====================================================================
   B. ĐIỂM DANH ĐĂNG NHẬP (T20)
   ===================================================================== */
DECLARE @Diem INT, @TB NVARCHAR(300), @d BIT, @ct NVARCHAR(500);
EXEC dbo.sp_DiemDanhDangNhap @MaKhachHang = 6, @DiemThuong = @Diem OUTPUT, @ThongBao = @TB OUTPUT;
SET @d = CASE WHEN @Diem = 5 AND dbo.fn_TinhDiemKhaDung(6) = 5 THEN 1 ELSE 0 END;
SET @ct = CONCAT(N'Điểm thưởng=', @Diem, N'; ', @TB);
EXEC #Ghi 'B1', N'Đăng nhập lần đầu trong ngày được +5 điểm (chính sách 5)', @d, @ct;

EXEC dbo.sp_DiemDanhDangNhap @MaKhachHang = 6, @DiemThuong = @Diem OUTPUT, @ThongBao = @TB OUTPUT;
SET @d = CASE WHEN @Diem = 0 AND dbo.fn_TinhDiemKhaDung(6) = 5 THEN 1 ELSE 0 END;
SET @ct = CONCAT(N'Điểm thưởng=', @Diem, N'; ', @TB);
EXEC #Ghi 'B2', N'Đăng nhập lần 2 cùng ngày không được cộng thêm', @d, @ct;
GO
EXEC #KyVongLoi 'B3', N'Nhân viên thuần (không phải khách) không được điểm danh', 50181,
     N'EXEC dbo.sp_DiemDanhDangNhap @MaKhachHang = 5;';
EXEC #KyVongLoi 'B4', N'Thời điểm đăng nhập ở tương lai bị từ chối', 50182,
     N'DECLARE @t DATETIME2(0) = DATEADD(DAY, 1, dbo.fn_ThoiDiemVN()); EXEC dbo.sp_DiemDanhDangNhap @MaKhachHang = 2, @ThoiDiem = @t;';
GO

/* =====================================================================
   C. TẠO ĐƠN (T21, T23)
   ===================================================================== */
EXEC #KyVongLoi 'C1', N'Dùng điểm vượt trần c=30% (H=120.000 ⇒ tối đa 360 điểm)', 50120,
     N'EXEC dbo.sp_TaoDonHang 1, 1, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', NULL, 500;';
EXEC #KyVongLoi 'C2', N'Dùng nhiều điểm hơn điểm khả dụng (KH6 có 5 điểm)', 50119,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', NULL, 10;';
EXEC #KyVongLoi 'C3', N'Voucher chưa đạt giá trị đơn tối thiểu (GIAM50K cần 300.000)', 50117,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', ''GIAM50K'';';
EXEC #KyVongLoi 'C4', N'Voucher đã hết hạn (HETHAN01)', 50117,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', ''HETHAN01'';';
EXEC #KyVongLoi 'C5', N'Voucher không tồn tại', 50117,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', ''KHONGCO'';';
EXEC #KyVongLoi 'C6', N'Một voucher nhập hai lần', 50109,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'', ''GIAM15K,GIAM15K'';';
EXEC #KyVongLoi 'C7', N'Tồn kho không đủ', 50116,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":2,"MaBienTheNoiBo":"XAM-41","SoLuong":1000}]'';';
EXEC #KyVongLoi 'C8', N'Địa chỉ không thuộc khách đặt đơn (RB14)', 50111,
     N'EXEC dbo.sp_TaoDonHang 1, 2, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":1}]'';';
EXEC #KyVongLoi 'C9', N'Biến thể không tồn tại (khóa ghép sai)', 50115,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":1,"MaBienTheNoiBo":"TIM-XXL","SoLuong":1}]'';';
EXEC #KyVongLoi 'C10', N'Danh sách mặt hàng không phải JSON', 50105,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''DEN-1M x1'';';
EXEC #KyVongLoi 'C11', N'Số lượng mua không dương', 50108,
     N'EXEC dbo.sp_TaoDonHang 6, 5, 2, 1, N''[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":0}]'';';
GO
/* C12 — Lặp lại ví dụ tính tay QUA THỦ TỤC: KH1 (1073 điểm) mua 1 củ sạc 350.000 + 1 cáp 150.000,
   voucher GIAM50K, dùng 1.000 điểm, vận chuyển Nhanh 20.000, thanh toán ví ⇒ T = 370.000, còn 73 điểm. */
DECLARE @id INT, @d BIT = 1, @ct NVARCHAR(2000), @TonTruoc INT, @TonSau INT;
SELECT @TonTruoc = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 3 AND MaBienTheNoiBo = 'TRANG-20W';
BEGIN TRY
    EXEC dbo.sp_TaoDonHang @MaKhachHang = 1, @MaDiaChi = 1, @MaPhuongThucVC = 2, @MaPhuongThucTT = 2,
         @DanhSachMuc = N'[{"MaSanPham":3,"MaBienTheNoiBo":"TRANG-20W","SoLuong":1},{"MaSanPham":5,"MaBienTheNoiBo":"DEN-2M","SoLuong":1}]',
         @DanhSachVoucher = 'GIAM50K', @DiemSuDung = 1000, @MaDonHang = @id OUTPUT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @d = 0, @ct = ERROR_MESSAGE();
END CATCH;
IF @d = 1
BEGIN
    INSERT #Don (Ten, MaDonHang) VALUES ('VD', @id);
    SELECT @TonSau = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 3 AND MaBienTheNoiBo = 'TRANG-20W';
    SELECT @d = CASE WHEN TongThanhToan = 370000 AND GiamBangDiem = 100000 AND DiemMuaHangDuKien = 35
                      AND TrangThaiDon = 'CHO_THANH_TOAN' AND @TonSau = @TonTruoc - 1
                      AND dbo.fn_TinhDiemKhaDung(1) = 73 THEN 1 ELSE 0 END,
           @ct = CONCAT(N'Đơn ', @id, N': T=', TongThanhToan, N' G=', GiamBangDiem, N' E dự kiến=', DiemMuaHangDuKien,
                        N' trạng thái=', TrangThaiDon, N' tồn ', @TonTruoc, N'→', @TonSau,
                        N' điểm KH1=', dbo.fn_TinhDiemKhaDung(1))
    FROM dbo.vw_TienDonHang WHERE MaDonHang = @id;
END;
EXEC #Ghi 'C12', N'Đặt đơn qua thủ tục khớp ví dụ tính tay, trừ tồn, giữ điểm', @d, @ct;
GO

/* =====================================================================
   D. CHUYỂN TRẠNG THÁI (T22) & QUYỀN ĐÁNH GIÁ (T24)
   ===================================================================== */
DECLARE @id INT = (SELECT MaDonHang FROM #Don WHERE Ten = 'VD'), @s NVARCHAR(MAX);
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_XAC_NHAN'', ''KhachHang'';');
EXEC #KyVongLoi 'D1', N'Khách hàng không được tự xác nhận đơn', 50138, @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_XAC_NHAN'', ''NhanVien'', ''NV02'';');
EXEC #KyVongLoi 'D2', N'Xác nhận thanh toán phải do hệ thống', 50139, @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_XAC_NHAN'', ''HeThong'';');
EXEC #KyVongOK 'D3', N'Hệ thống xác nhận thanh toán: CHO_THANH_TOAN → CHO_XAC_NHAN', @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''DANG_GIAO'', ''NhanVien'', ''NV02'';');
EXEC #KyVongLoi 'D4', N'Không được nhảy cóc CHO_XAC_NHAN → DANG_GIAO', 50137, @s;
SET @s = CONCAT(N'INSERT dbo.DANH_GIA (SoSao, NoiDungBinhLuan, MaDonHang, SoThuTuDong) VALUES (5, N''Chưa nhận đã khen'', ', @id, N', 1);');
EXEC #KyVongLoi 'D5', N'Đánh giá khi đơn chưa giao bị trigger chặn (T24)', 50160, @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_LAY_HANG'', ''NhanVien'', ''NV01'';');
EXEC #KyVongOK 'D6', N'NV01 (là KH4) được xử lý đơn của KH1', @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''DANG_GIAO'', ''NhanVien'', ''NV02'';');
EXEC #KyVongOK 'D7', N'CHO_LAY_HANG → DANG_GIAO', @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''DA_HUY'', ''KhachHang'';');
EXEC #KyVongLoi 'D8', N'Không được hủy đơn đang giao', 50136, @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''DA_GIAO'', ''NhanVien'', ''NV03'';');
EXEC #KyVongOK 'D9', N'DANG_GIAO → DA_GIAO', @s;
GO
DECLARE @id INT = (SELECT MaDonHang FROM #Don WHERE Ten = 'VD');
DECLARE @d BIT = CASE WHEN dbo.fn_TinhDiemKhaDung(1) = 108
                       AND (SELECT DiemKhaDung FROM dbo.vw_DiemKhaDung WHERE MaKhachHang = 1) = 108 THEN 1 ELSE 0 END;
DECLARE @ct NVARCHAR(200) = CONCAT(N'Điểm KH1 = ', dbo.fn_TinhDiemKhaDung(1), N' (kỳ vọng 73 + 35 = 108)');
EXEC #Ghi 'D10', N'Đơn giao thành công ⇒ cộng điểm mua hàng E = 35', @d, @ct;
GO
DECLARE @id INT = (SELECT MaDonHang FROM #Don WHERE Ten = 'VD'), @s NVARCHAR(MAX);
SET @s = CONCAT(N'INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, MaDonHang, SoThuTuDong) VALUES (4, ''2026-01-01'', ', @id, N', 1);');
EXEC #KyVongLoi 'D11', N'Thời gian đánh giá trước mốc giao hàng bị chặn (T24)', 50161, @s;
SET @s = CONCAT(N'INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, MaDonHang, SoThuTuDong) VALUES (4, DATEADD(HOUR, 2, dbo.fn_ThoiDiemVN()), ', @id, N', 1);');
EXEC #KyVongLoi 'D12', N'Thời gian đánh giá ở tương lai bị chặn (T24)', 50162, @s;
SET @s = CONCAT(N'INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, NoiDungBinhLuan, MaDonHang, SoThuTuDong) ',
                N'VALUES (5, DATEADD(SECOND, 2, dbo.fn_ThoiDiemVN()), N''Sạc tốt'', ', @id, N', 1), ',
                N'(4, DATEADD(SECOND, 2, dbo.fn_ThoiDiemVN()), N''Cáp ổn'', ', @id, N', 2);');
EXEC #KyVongOK 'D13', N'Đánh giá 2 dòng cùng lúc sau khi giao (trigger xử lý nhiều dòng)', @s;
SET @s = CONCAT(N'UPDATE dbo.DON_HANG SET TrangThaiDon = ''DANG_GIAO'' WHERE MaDonHang = ', @id, N';');
EXEC #KyVongLoi 'D14', N'Không được đổi đơn đã giao về trạng thái khác', 50191, @s;
SET @s = CONCAT(N'DELETE dbo.NHAT_KY_XU_LY_DON WHERE MaDonHang = ', @id, N';');
EXEC #KyVongLoi 'D15', N'Không được xóa nhật ký (mốc giao hàng)', 50192, @s;
GO
/* D16 — RB16: NV01 (người dùng 4) không được xử lý đơn do chính mình (KH4) đặt */
DECLARE @id INT, @s NVARCHAR(MAX);
EXEC dbo.sp_TaoDonHang 4, 4, 1, 1, N'[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-2M","SoLuong":1}]', @MaDonHang = @id OUTPUT;
INSERT #Don (Ten, MaDonHang) VALUES ('KH4', @id);
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_LAY_HANG'', ''NhanVien'', ''NV01'';');
EXEC #KyVongLoi 'D16', N'Nhân viên không xử lý đơn của chính mình (RB16)', 50141, @s;
SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''CHO_LAY_HANG'', ''NhanVien'', ''NV02'';');
EXEC #KyVongOK 'D17', N'Nhân viên khác (NV02) xử lý được đơn của KH4', @s;
SET @s = CONCAT(N'INSERT dbo.NHAT_KY_XU_LY_DON (ThaoTac, TrangThaiTruoc, TrangThaiSau, MaDonHang, NguonThaoTac, MaNhanVien) ',
                N'VALUES (N''Ghi tay'', ''CHO_LAY_HANG'', ''DANG_GIAO'', ', @id, N', ''NhanVien'', ''NV01'');');
EXEC #KyVongLoi 'D18', N'Ghi nhật ký trực tiếp vẫn bị trigger RB16 chặn', 50193, @s;
GO

/* =====================================================================
   E. HỦY ĐƠN: hoàn tồn & giải phóng điểm ĐÚNG MỘT LẦN (T22)
   ===================================================================== */
DECLARE @id INT, @d BIT, @ct NVARCHAR(2000), @Ton0 INT, @Ton1 INT, @Ton2 INT, @Ton3 INT,
        @Diem0 INT, @Diem1 INT, @Diem2 INT, @s NVARCHAR(MAX);
SELECT @Ton0 = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 5 AND MaBienTheNoiBo = 'DEN-1M';
SET @Diem0 = dbo.fn_TinhDiemKhaDung(2);                                     -- 49
EXEC dbo.sp_TaoDonHang 2, 2, 2, 1, N'[{"MaSanPham":5,"MaBienTheNoiBo":"DEN-1M","SoLuong":2}]',
     NULL, 40, N'Kiểm thử hủy đơn', @MaDonHang = @id OUTPUT;
INSERT #Don (Ten, MaDonHang) VALUES ('HUY', @id);
SELECT @Ton1 = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 5 AND MaBienTheNoiBo = 'DEN-1M';
SET @Diem1 = dbo.fn_TinhDiemKhaDung(2);                                     -- 9
SET @d = CASE WHEN @Ton1 = @Ton0 - 2 AND @Diem1 = @Diem0 - 40 THEN 1 ELSE 0 END;
SET @ct = CONCAT(N'Tồn ', @Ton0, N'→', @Ton1, N'; điểm KH2 ', @Diem0, N'→', @Diem1);
EXEC #Ghi 'E1', N'Đặt đơn: trừ tồn 2, giữ 40 điểm', @d, @ct;

EXEC dbo.sp_CapNhatTrangThaiDon @id, 'DA_HUY', 'KhachHang', NULL, N'Kiểm thử hủy';
SELECT @Ton2 = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 5 AND MaBienTheNoiBo = 'DEN-1M';
SET @Diem2 = dbo.fn_TinhDiemKhaDung(2);
SET @d = CASE WHEN @Ton2 = @Ton0 AND @Diem2 = @Diem0 THEN 1 ELSE 0 END;
SET @ct = CONCAT(N'Tồn ', @Ton1, N'→', @Ton2, N'; điểm KH2 ', @Diem1, N'→', @Diem2);
EXEC #Ghi 'E2', N'Hủy đơn: hoàn tồn và giải phóng điểm', @d, @ct;

SET @s = CONCAT(N'EXEC dbo.sp_CapNhatTrangThaiDon ', @id, N', ''DA_HUY'', ''NhanVien'', ''NV02'';');
EXEC #KyVongLoi 'E3', N'Hủy lần hai bị từ chối', 50134, @s;
SELECT @Ton3 = TonKhoRieng FROM dbo.BIEN_THE_SAN_PHAM WHERE MaSanPham = 5 AND MaBienTheNoiBo = 'DEN-1M';
SET @d = CASE WHEN @Ton3 = @Ton0 AND dbo.fn_TinhDiemKhaDung(2) = @Diem0 THEN 1 ELSE 0 END;
SET @ct = CONCAT(N'Tồn sau lần hủy thứ hai = ', @Ton3, N' (kỳ vọng ', @Ton0, N'); điểm KH2 = ', dbo.fn_TinhDiemKhaDung(2));
EXEC #Ghi 'E4', N'Không hoàn tồn / hoàn điểm lần hai', @d, @ct;
GO

/* =====================================================================
   F. CHÍNH SÁCH MỚI KHÔNG ẢNH HƯỞNG ĐƠN CŨ
   ===================================================================== */
EXEC #KyVongLoi 'F1', N'Không sửa tỷ lệ của chính sách đã chốt', 50171,
     N'UPDATE dbo.CHINH_SACH_DIEM SET TyLeTichDiem = 0.02 WHERE MaChinhSach = 5;';
EXEC #KyVongLoi 'F2', N'Không thêm chính sách chồng khoảng hiệu lực', 50170,
     N'INSERT dbo.CHINH_SACH_DIEM VALUES (6, N''Chồng lấn'', ''2026-08-01'', NULL, 0.02, 100, 0.3, 8);';
GO
DECLARE @Moc DATETIME2(0) = DATEADD(SECOND, 1, dbo.fn_ThoiDiemVN()), @d BIT = 1, @ct NVARCHAR(2000),
        @Diem INT, @TB NVARCHAR(300), @E4 INT, @EVD INT;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.CHINH_SACH_DIEM SET HieuLucDen = @Moc WHERE MaChinhSach = 5;
    INSERT dbo.CHINH_SACH_DIEM (MaChinhSach, TenChinhSach, HieuLucTu, HieuLucDen, TyLeTichDiem, GiaTriMotDiem, TyLeGiamToiDa, DiemThuongDangNhap)
    VALUES (6, N'Kiểm thử: tích điểm 2%, thưởng đăng nhập 8', @Moc, NULL, 0.0200, 100, 0.3000, 8);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @d = 0, @ct = ERROR_MESSAGE();
END CATCH;
IF @d = 1
BEGIN
    EXEC dbo.sp_DiemDanhDangNhap @MaKhachHang = 3, @ThoiDiem = @Moc, @DiemThuong = @Diem OUTPUT, @ThongBao = @TB OUTPUT;
    SELECT @E4 = DiemMuaHangDaNhan FROM dbo.vw_TienDonHang WHERE MaDonHang = 4;
    SELECT @EVD = v.DiemMuaHangDaNhan FROM dbo.vw_TienDonHang v JOIN #Don t ON t.MaDonHang = v.MaDonHang WHERE t.Ten = 'VD';
    SET @d = CASE WHEN @Diem = 8 AND @E4 = 35 AND @EVD = 35 THEN 1 ELSE 0 END;
    SET @ct = CONCAT(N'Điểm danh theo chính sách 6 = ', @Diem, N'; E đơn 4 = ', @E4, N'; E đơn VD = ', @EVD, N' (vẫn theo chính sách 5)');
END;
EXEC #Ghi 'F3', N'Chính sách mới áp dụng cho nghiệp vụ mới, đơn cũ giữ chính sách đã chốt', @d, @ct;
GO

/* =====================================================================
   G. CRUD BIẾN THỂ (T17, T18, T19)
   ===================================================================== */
EXEC #KyVongOK   'G1',  N'Thêm biến thể hợp lệ (1, XANH-XL)', N'EXEC dbo.sp_ThemBienThe 1, ''xanh-xl'', N''Xanh'', N''XL'', 10, 209000;';
EXEC #KyVongLoi  'G2',  N'Trùng khóa ghép (1, XANH-XL)', 50012, N'EXEC dbo.sp_ThemBienThe 1, ''XANH-XL'', N''Xanh lá'', N''XL'', 10, 209000;';
EXEC #KyVongLoi  'G3',  N'Trùng phân loại Đen/M trong sản phẩm 1', 50013, N'EXEC dbo.sp_ThemBienThe 1, ''DEN-M2'', N''Đen'', N''M'', 5, 199000;';
EXEC #KyVongLoi  'G4',  N'Mã biến thể sai định dạng', 50004, N'EXEC dbo.sp_ThemBienThe 1, ''den m@'', N''Nâu'', N''M'', 5, 199000;';
EXEC #KyVongLoi  'G5',  N'Giá bán bằng 0', 50010, N'EXEC dbo.sp_ThemBienThe 1, ''NAU-M'', N''Nâu'', N''M'', 5, 0;';
EXEC #KyVongLoi  'G6',  N'Giá bán vượt 200% giá niêm yết', 50011, N'EXEC dbo.sp_ThemBienThe 1, ''NAU-M'', N''Nâu'', N''M'', 5, 1000000;';
EXEC #KyVongLoi  'G7',  N'Sản phẩm không tồn tại', 50002, N'EXEC dbo.sp_ThemBienThe 999, ''NAU-M'', N''Nâu'', N''M'', 5, 199000;';
EXEC #KyVongLoi  'G8',  N'Tồn kho âm', 50009, N'EXEC dbo.sp_ThemBienThe 1, ''NAU-M'', N''Nâu'', N''M'', -1, 199000;';
EXEC #KyVongLoi  'G9',  N'Kích cỡ để trống', 50007, N'EXEC dbo.sp_ThemBienThe 1, ''NAU-M'', N''Nâu'', N''  '', 5, 199000;';
EXEC #KyVongOK   'G10', N'Sửa giá và tồn của biến thể đã có đơn (DEN-M)', N'EXEC dbo.sp_SuaBienThe 1, ''DEN-M'', N''Đen'', N''M'', 45, 209000;';
EXEC #KyVongLoi  'G11', N'Không đổi màu/cỡ của biến thể đã có trong đơn', 50022, N'EXEC dbo.sp_SuaBienThe 1, ''DEN-M'', N''Đen nhám'', N''M'', 45, 209000;';
EXEC #KyVongOK   'G12', N'Đổi màu biến thể chưa có đơn (XANH-XL)', N'EXEC dbo.sp_SuaBienThe 1, ''XANH-XL'', N''Xanh rêu'', N''XL'', 12, 209000;';
EXEC #KyVongLoi  'G13', N'Đổi sang phân loại đã thuộc biến thể khác', 50013, N'EXEC dbo.sp_SuaBienThe 1, ''XANH-XL'', N''Đen'', N''L'', 12, 209000;';
EXEC #KyVongLoi  'G14', N'Sửa biến thể không tồn tại', 50021, N'EXEC dbo.sp_SuaBienThe 1, ''KHONG-CO'', N''Đỏ'', N''S'', 1, 199000;';
EXEC #KyVongLoi  'G15', N'Xóa biến thể đã có trong đơn hàng', 50031, N'EXEC dbo.sp_XoaBienThe 1, ''DEN-M'';';
INSERT dbo.GIO_HANG (MaKhachHang, MaSanPham, MaBienTheNoiBo, SoLuongDuMua) VALUES (6, 1, 'XANH-XL', 1);
EXEC #KyVongLoi  'G16', N'Xóa biến thể đang nằm trong giỏ hàng', 50032, N'EXEC dbo.sp_XoaBienThe 1, ''XANH-XL'';';
DELETE dbo.GIO_HANG WHERE MaKhachHang = 6 AND MaSanPham = 1 AND MaBienTheNoiBo = 'XANH-XL';
EXEC #KyVongOK   'G17', N'Xóa biến thể tạo nhầm, chưa giao dịch (XANH-XL)', N'EXEC dbo.sp_XoaBienThe 1, ''XANH-XL'';';
EXEC #KyVongLoi  'G18', N'Không xóa biến thể cuối cùng của sản phẩm 6', 50033, N'EXEC dbo.sp_XoaBienThe 6, ''TRONG-IP15'';';
EXEC #KyVongLoi  'G19', N'Xóa biến thể không tồn tại', 50030, N'EXEC dbo.sp_XoaBienThe 1, ''XANH-XL'';';
GO

/* =====================================================================
   H. ĐỐI CHIẾU CUỐI: function (cursor) = view cho mọi khách sau toàn bộ thao tác
   ===================================================================== */
DECLARE @d BIT, @ct NVARCHAR(2000);
SELECT @d = CASE WHEN SUM(CASE WHEN dbo.fn_TinhDiemKhaDung(MaKhachHang) = DiemKhaDung THEN 0 ELSE 1 END) = 0 THEN 1 ELSE 0 END,
       @ct = STRING_AGG(CONCAT('KH', MaKhachHang, ': view=', DiemKhaDung, ' fn=', dbo.fn_TinhDiemKhaDung(MaKhachHang)), '; ')
FROM dbo.vw_DiemKhaDung;
EXEC #Ghi 'H1', N'fn_TinhDiemKhaDung = vw_DiemKhaDung cho mọi khách', @d, @ct;
GO

/* ---------- TỔNG HỢP ---------- */
SELECT COUNT(*) AS TongSoCa, SUM(CAST(Dat AS INT)) AS SoPass, COUNT(*) - SUM(CAST(Dat AS INT)) AS SoFail FROM #KQ;
SELECT Ma, MoTa, ChiTiet FROM #KQ WHERE Dat = 0 ORDER BY STT;
GO
