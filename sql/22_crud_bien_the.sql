/* =====================================================================
   22_crud_bien_the.sql — T17, T18, T19 (Võ Quốc Đại)
   Yêu cầu BTL2 mục 2.1: thủ tục thêm / sửa / xóa cho MỘT bảng: BIEN_THE_SAN_PHAM.
   Biến thể là thực thể yếu: luôn định danh bằng cặp (MaSanPham, MaBienTheNoiBo).

   Bảng mã lỗi (ứng dụng của Bằng hiển thị nguyên văn ERROR_MESSAGE()):
     50001 Mã sản phẩm trống                 50002 Sản phẩm không tồn tại
     50003 Mã biến thể trống                 50004 Mã biến thể sai định dạng / quá 20 ký tự
     50005 Màu sắc trống                     50006 Màu sắc quá 50 ký tự
     50007 Kích cỡ trống                     50008 Kích cỡ quá 20 ký tự
     50009 Tồn kho trống / âm / quá lớn      50010 Giá bán trống / không dương
     50011 Giá bán lệch quá xa giá niêm yết (ngoài 50%–200%)
     50012 Trùng khóa (MaSanPham, MaBienTheNoiBo)
     50013 Trùng phân loại (MauSac, KichCo) trong cùng sản phẩm
     50020 Thiếu khóa biến thể khi sửa       50021 Biến thể cần sửa không tồn tại
     50022 Đổi phân loại của biến thể đã có trong đơn hàng
     50030 Biến thể cần xóa không tồn tại    50031 Biến thể đã có trong đơn hàng
     50032 Biến thể đang nằm trong giỏ hàng  50033 Biến thể cuối cùng của sản phẩm
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   Thủ tục dùng chung: kiểm tra các thuộc tính không khóa của biến thể.
   (Được gọi bởi sp_ThemBienThe và sp_SuaBienThe; THROW lan ra thủ tục gọi.)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_BienThe_KiemTraDuLieu
    @MaSanPham    INT,
    @MauSac       NVARCHAR(60),
    @KichCo       NVARCHAR(30),
    @TonKhoRieng  INT,
    @GiaBanRieng  DECIMAL(14,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400), @GiaNiemYet DECIMAL(14,2);

    IF @MaSanPham IS NULL
        THROW 50001, N'Mã sản phẩm không được để trống.', 1;

    SELECT @GiaNiemYet = GiaNiemYet FROM dbo.SAN_PHAM WHERE MaSanPham = @MaSanPham;
    IF @GiaNiemYet IS NULL
    BEGIN
        SET @Loi = CONCAT(N'Sản phẩm có mã ', @MaSanPham, N' không tồn tại.');
        THROW 50002, @Loi, 1;
    END;

    IF @MauSac IS NULL OR LTRIM(RTRIM(@MauSac)) = ''
        THROW 50005, N'Màu sắc của biến thể không được để trống.', 1;
    IF LEN(@MauSac) > 50
        THROW 50006, N'Màu sắc tối đa 50 ký tự.', 1;

    IF @KichCo IS NULL OR LTRIM(RTRIM(@KichCo)) = ''
        THROW 50007, N'Kích cỡ của biến thể không được để trống (dùng "Freesize" nếu sản phẩm không chia cỡ).', 1;
    IF LEN(@KichCo) > 20
        THROW 50008, N'Kích cỡ tối đa 20 ký tự.', 1;

    IF @TonKhoRieng IS NULL
        THROW 50009, N'Tồn kho không được để trống.', 1;
    IF @TonKhoRieng < 0
    BEGIN
        SET @Loi = CONCAT(N'Tồn kho phải là số nguyên không âm (giá trị nhập: ', @TonKhoRieng, N').');
        THROW 50009, @Loi, 1;
    END;
    IF @TonKhoRieng > 1000000
        THROW 50009, N'Tồn kho vượt quá 1.000.000 đơn vị, vui lòng kiểm tra lại số liệu nhập.', 1;

    IF @GiaBanRieng IS NULL
        THROW 50010, N'Giá bán của biến thể không được để trống.', 1;
    IF @GiaBanRieng <= 0
    BEGIN
        SET @Loi = CONCAT(N'Giá bán phải lớn hơn 0 (giá trị nhập: ', FORMAT(@GiaBanRieng, 'N0'), N'đ).');
        THROW 50010, @Loi, 1;
    END;

    -- Quy tắc nghiệp vụ: giá biến thể dao động trong 50%–200% giá niêm yết của sản phẩm
    IF @GiaBanRieng < @GiaNiemYet * 0.5 OR @GiaBanRieng > @GiaNiemYet * 2
    BEGIN
        SET @Loi = CONCAT(N'Giá bán biến thể ', FORMAT(@GiaBanRieng, 'N0'), N'đ phải nằm trong khoảng ',
                          FORMAT(@GiaNiemYet * 0.5, 'N0'), N'đ – ', FORMAT(@GiaNiemYet * 2, 'N0'),
                          N'đ (50%–200% giá niêm yết ', FORMAT(@GiaNiemYet, 'N0'), N'đ của sản phẩm ', @MaSanPham, N').');
        THROW 50011, @Loi, 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   T17 — sp_ThemBienThe
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ThemBienThe
    @MaSanPham       INT,
    @MaBienTheNoiBo  VARCHAR(30),
    @MauSac          NVARCHAR(60),
    @KichCo          NVARCHAR(30),
    @TonKhoRieng     INT,
    @GiaBanRieng     DECIMAL(14,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400);

    SET @MaBienTheNoiBo = UPPER(LTRIM(RTRIM(@MaBienTheNoiBo)));
    SET @MauSac = LTRIM(RTRIM(@MauSac));
    SET @KichCo = LTRIM(RTRIM(@KichCo));

    IF @MaSanPham IS NULL
        THROW 50001, N'Mã sản phẩm không được để trống.', 1;

    IF @MaBienTheNoiBo IS NULL OR @MaBienTheNoiBo = ''
        THROW 50003, N'Mã biến thể nội bộ không được để trống.', 1;
    IF LEN(@MaBienTheNoiBo) > 20
       OR @MaBienTheNoiBo COLLATE Latin1_General_BIN LIKE '%[^A-Z0-9-]%'
    BEGIN
        SET @Loi = CONCAT(N'Mã biến thể "', @MaBienTheNoiBo,
                          N'" không hợp lệ: chỉ gồm chữ in hoa không dấu, chữ số và dấu "-", tối đa 20 ký tự (ví dụ: DEN-M).');
        THROW 50004, @Loi, 1;
    END;

    EXEC dbo.sp_BienThe_KiemTraDuLieu @MaSanPham, @MauSac, @KichCo, @TonKhoRieng, @GiaBanRieng;

    IF EXISTS (SELECT 1 FROM dbo.BIEN_THE_SAN_PHAM
               WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo)
    BEGIN
        SET @Loi = CONCAT(N'Sản phẩm ', @MaSanPham, N' đã có biến thể mã "', @MaBienTheNoiBo, N'".');
        THROW 50012, @Loi, 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.BIEN_THE_SAN_PHAM
               WHERE MaSanPham = @MaSanPham AND MauSac = @MauSac AND KichCo = @KichCo)
    BEGIN
        SELECT @Loi = CONCAT(N'Sản phẩm ', @MaSanPham, N' đã có biến thể màu "', @MauSac, N'", cỡ "', @KichCo,
                             N'" (mã ', MaBienTheNoiBo, N').')
        FROM dbo.BIEN_THE_SAN_PHAM
        WHERE MaSanPham = @MaSanPham AND MauSac = @MauSac AND KichCo = @KichCo;
        THROW 50013, @Loi, 1;
    END;

    INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng)
    VALUES (@MaSanPham, @MaBienTheNoiBo, @MauSac, @KichCo, @TonKhoRieng, @GiaBanRieng);

    SELECT N'Thêm biến thể thành công.' AS ThongBao, b.*
    FROM dbo.BIEN_THE_SAN_PHAM b
    WHERE b.MaSanPham = @MaSanPham AND b.MaBienTheNoiBo = @MaBienTheNoiBo;
END;
GO

/* ---------------------------------------------------------------------
   T18 — sp_SuaBienThe
   - Khóa (MaSanPham, MaBienTheNoiBo) KHÔNG đổi được (đang được tham chiếu bởi đơn/giỏ).
   - Bảo toàn lịch sử: đơn cũ đã chốt DonGiaLucDat, MauSacChot, KichCoChot nên đổi giá/tồn
     không ảnh hưởng đơn cũ; tuy nhiên KHÔNG cho đổi màu/cỡ của biến thể đã có trong đơn,
     vì khi đó cùng một mã sẽ chỉ hai mặt hàng khác nhau trong lịch sử và đánh giá.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_SuaBienThe
    @MaSanPham       INT,
    @MaBienTheNoiBo  VARCHAR(30),
    @MauSac          NVARCHAR(60),
    @KichCo          NVARCHAR(30),
    @TonKhoRieng     INT,
    @GiaBanRieng     DECIMAL(14,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400), @MauCu NVARCHAR(50), @CoCu NVARCHAR(20), @SoDon INT;

    SET @MaBienTheNoiBo = UPPER(LTRIM(RTRIM(@MaBienTheNoiBo)));
    SET @MauSac = LTRIM(RTRIM(@MauSac));
    SET @KichCo = LTRIM(RTRIM(@KichCo));

    IF @MaSanPham IS NULL OR @MaBienTheNoiBo IS NULL OR @MaBienTheNoiBo = ''
        THROW 50020, N'Phải cung cấp đủ khóa biến thể (MaSanPham, MaBienTheNoiBo) để sửa.', 1;

    SELECT @MauCu = MauSac, @CoCu = KichCo
    FROM dbo.BIEN_THE_SAN_PHAM
    WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;
    IF @MauCu IS NULL
    BEGIN
        SET @Loi = CONCAT(N'Không tìm thấy biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N') để sửa.');
        THROW 50021, @Loi, 1;
    END;

    EXEC dbo.sp_BienThe_KiemTraDuLieu @MaSanPham, @MauSac, @KichCo, @TonKhoRieng, @GiaBanRieng;

    IF EXISTS (SELECT 1 FROM dbo.BIEN_THE_SAN_PHAM
               WHERE MaSanPham = @MaSanPham AND MauSac = @MauSac AND KichCo = @KichCo
                 AND MaBienTheNoiBo <> @MaBienTheNoiBo)
    BEGIN
        SELECT @Loi = CONCAT(N'Không thể đổi sang màu "', @MauSac, N'", cỡ "', @KichCo,
                             N'": phân loại này đã thuộc biến thể ', MaBienTheNoiBo, N' của sản phẩm ', @MaSanPham, N'.')
        FROM dbo.BIEN_THE_SAN_PHAM
        WHERE MaSanPham = @MaSanPham AND MauSac = @MauSac AND KichCo = @KichCo AND MaBienTheNoiBo <> @MaBienTheNoiBo;
        THROW 50013, @Loi, 1;
    END;

    IF @MauSac <> @MauCu OR @KichCo <> @CoCu
    BEGIN
        SELECT @SoDon = COUNT(DISTINCT MaDonHang)
        FROM dbo.CHI_TIET_DON_HANG
        WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;
        IF @SoDon > 0
        BEGIN
            SET @Loi = CONCAT(N'Biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N') đã xuất hiện trong ', @SoDon,
                              N' đơn hàng nên không được đổi màu/kích cỡ (để bảo toàn lịch sử). Hãy tạo biến thể mới.');
            THROW 50022, @Loi, 1;
        END;
    END;

    UPDATE dbo.BIEN_THE_SAN_PHAM
    SET MauSac = @MauSac, KichCo = @KichCo, TonKhoRieng = @TonKhoRieng, GiaBanRieng = @GiaBanRieng
    WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;

    SELECT N'Cập nhật biến thể thành công.' AS ThongBao, b.*
    FROM dbo.BIEN_THE_SAN_PHAM b
    WHERE b.MaSanPham = @MaSanPham AND b.MaBienTheNoiBo = @MaBienTheNoiBo;
END;
GO

/* ---------------------------------------------------------------------
   T19 — sp_XoaBienThe
   Mục đích: xóa biến thể tạo NHẦM, chưa phát sinh giao dịch.
   ĐƯỢC xóa khi: biến thể chưa từng có trong đơn hàng, không nằm trong giỏ hàng nào,
                 và sản phẩm vẫn còn ít nhất một biến thể khác.
   KHÔNG được xóa khi:
     - đã có trong CHI_TIET_DON_HANG (mất lịch sử đơn, đánh giá) → muốn ngừng bán: đặt tồn kho = 0;
     - đang nằm trong giỏ của khách (khách đang dự định mua);
     - là biến thể cuối cùng (mỗi sản phẩm phải có ít nhất một biến thể).
   Khóa UPDLOCK/HOLDLOCK để không có đơn/giỏ mới chen vào giữa lúc kiểm tra và xóa.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_XoaBienThe
    @MaSanPham       INT,
    @MaBienTheNoiBo  VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Loi NVARCHAR(400), @TonTai INT, @SoDon INT, @SoGio INT, @SoBienThe INT;

    SET @MaBienTheNoiBo = UPPER(LTRIM(RTRIM(@MaBienTheNoiBo)));
    IF @MaSanPham IS NULL OR @MaBienTheNoiBo IS NULL OR @MaBienTheNoiBo = ''
        THROW 50030, N'Phải cung cấp đủ khóa biến thể (MaSanPham, MaBienTheNoiBo) để xóa.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @TonTai = 1
        FROM dbo.BIEN_THE_SAN_PHAM WITH (UPDLOCK, HOLDLOCK)
        WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;
        IF @TonTai IS NULL
        BEGIN
            SET @Loi = CONCAT(N'Không tìm thấy biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N') để xóa.');
            THROW 50030, @Loi, 1;
        END;

        SELECT @SoDon = COUNT(DISTINCT MaDonHang)
        FROM dbo.CHI_TIET_DON_HANG WITH (HOLDLOCK)
        WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;
        IF @SoDon > 0
        BEGIN
            SET @Loi = CONCAT(N'Không thể xóa biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N'): đã xuất hiện trong ',
                              @SoDon, N' đơn hàng, cần giữ để bảo toàn lịch sử đơn và đánh giá. Muốn ngừng bán, hãy sửa tồn kho về 0.');
            THROW 50031, @Loi, 1;
        END;

        SELECT @SoGio = COUNT(*)
        FROM dbo.GIO_HANG WITH (HOLDLOCK)
        WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;
        IF @SoGio > 0
        BEGIN
            SET @Loi = CONCAT(N'Không thể xóa biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N'): đang nằm trong giỏ hàng của ',
                              @SoGio, N' khách hàng.');
            THROW 50032, @Loi, 1;
        END;

        SELECT @SoBienThe = COUNT(*)
        FROM dbo.BIEN_THE_SAN_PHAM WITH (UPDLOCK, HOLDLOCK)
        WHERE MaSanPham = @MaSanPham;
        IF @SoBienThe <= 1
        BEGIN
            SET @Loi = CONCAT(N'Không thể xóa biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo,
                              N'): đây là biến thể cuối cùng, mỗi sản phẩm phải có ít nhất một biến thể.');
            THROW 50033, @Loi, 1;
        END;

        DELETE dbo.BIEN_THE_SAN_PHAM
        WHERE MaSanPham = @MaSanPham AND MaBienTheNoiBo = @MaBienTheNoiBo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT CONCAT(N'Đã xóa biến thể (', @MaSanPham, N', ', @MaBienTheNoiBo, N').') AS ThongBao;
END;
GO
PRINT N'22: Đã tạo sp_ThemBienThe, sp_SuaBienThe, sp_XoaBienThe.';
GO
