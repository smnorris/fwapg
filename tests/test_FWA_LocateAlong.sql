-- https://github.com/smnorris/fwapg/issues/81
select st_astext(postgisftw.fwa_locatealong(356493192, 340.150635772625)) = 'POINT ZM (1595887.803 515210.805 442.005999999994 340.150635772625)'