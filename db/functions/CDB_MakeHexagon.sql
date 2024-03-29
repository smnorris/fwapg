-- Copyright (c) 2014, Vizzuality
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
-- list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
-- this list of conditions and the following disclaimer in the documentation
-- and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its contributors
-- may be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-- ensure the functions are created in the public schema
set search_path to public;

-- Return an Hexagon with given center and side (or maximal radius)
CREATE OR REPLACE FUNCTION CDB_MakeHexagon(center GEOMETRY, radius FLOAT8)
RETURNS GEOMETRY
AS $$
  SELECT ST_MakePolygon(ST_MakeLine(geom))
    FROM
    (
      SELECT (ST_DumpPoints(ST_ExteriorRing(ST_Buffer($1, $2, 3)))).*
    ) as points
    WHERE path[1] % 2 != 0
$$ LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;


-- In older versions of the extension, CDB_HexagonGrid had a different signature
--DROP FUNCTION IF EXISTS cartodb.CDB_HexagonGrid(GEOMETRY, FLOAT8, GEOMETRY);

--
-- Fill given extent with an hexagonal coverage
--
-- @param ext Extent to fill. Only hexagons with center point falling
--            inside the extent (or at the lower or leftmost edge) will
--            be emitted. The returned hexagons will have the same SRID
--            as this extent.
--
-- @param side Side measure for the hexagon.
--             Maximum diameter will be 2 * side.
--
-- @param origin Optional origin to allow for exact tiling.
--               If omitted the origin will be 0,0.
--               The parameter is checked for having the same SRID
--               as the extent.
--
-- @param maxcells Optional maximum number of grid cells to generate;
--                 if the grid requires more cells to cover the extent
--                 and exception will occur.
----
-- DROP FUNCTION IF EXISTS CDB_HexagonGrid(ext GEOMETRY, side FLOAT8);
CREATE OR REPLACE FUNCTION CDB_HexagonGrid(ext GEOMETRY, side FLOAT8, origin GEOMETRY DEFAULT NULL, maxcells INTEGER DEFAULT 512*512)
RETURNS SETOF GEOMETRY
AS $$
DECLARE
  h GEOMETRY; -- hexagon
  c GEOMETRY; -- center point
  rec RECORD;
  hstep FLOAT8; -- horizontal step
  vstep FLOAT8; -- vertical step
  vstart FLOAT8;
  vstartary FLOAT8[];
  vstartidx INTEGER;
  hskip BIGINT;
  hstart FLOAT8;
  hend FLOAT8;
  vend FLOAT8;
  xoff FLOAT8;
  yoff FLOAT8;
  xgrd FLOAT8;
  ygrd FLOAT8;
  srid INTEGER;
BEGIN

  --            |     |
  --            |hstep|
  --  ______   ___    |
  --  vstep  /     \ ___ /
  --  ______ \ ___ /     \
  --         /     \ ___ /
  --
  --
  RAISE DEBUG 'Side: %', side;

  vstep := side * sqrt(3); -- x 2 ?
  hstep := side * 1.5;

  RAISE DEBUG 'vstep: %', vstep;
  RAISE DEBUG 'hstep: %', hstep;

  srid := ST_SRID(ext);

  xoff := 0;
  yoff := 0;

  IF origin IS NOT NULL THEN
    IF ST_SRID(origin) != srid THEN
      RAISE EXCEPTION 'SRID mismatch between extent (%) and origin (%)', srid, ST_SRID(origin);
    END IF;
    xoff := ST_X(origin);
    yoff := ST_Y(origin);
  END IF;

  RAISE DEBUG 'X offset: %', xoff;
  RAISE DEBUG 'Y offset: %', yoff;

  xgrd := side * 0.5;
  ygrd := ( side * sqrt(3) ) / 2.0;
  RAISE DEBUG 'X grid size: %', xgrd;
  RAISE DEBUG 'Y grid size: %', ygrd;

  -- Tweak horizontal start on hstep*2 grid from origin
  hskip := ceil((ST_XMin(ext)-xoff)/hstep);
  RAISE DEBUG 'hskip: %', hskip;
  hstart := xoff + hskip*hstep;
  RAISE DEBUG 'hstart: %', hstart;

  -- Tweak vertical start on hstep grid from origin
  vstart := yoff + ceil((ST_Ymin(ext)-yoff)/vstep)*vstep;
  RAISE DEBUG 'vstart: %', vstart;

  hend := ST_XMax(ext);
  vend := ST_YMax(ext);

  IF vstart - (vstep/2.0) < ST_YMin(ext) THEN
    vstartary := ARRAY[ vstart + (vstep/2.0), vstart ];
  ELSE
    vstartary := ARRAY[ vstart - (vstep/2.0), vstart ];
  END IF;

  If maxcells IS NOT NULL AND maxcells > 0 THEN
    IF CEIL((CEIL((vend-vstart)/(vstep/2.0)) * CEIL((hend-hstart)/(hstep*2.0/3.0)))/3.0)::integer > maxcells THEN
      RAISE EXCEPTION 'The requested grid is too big to be rendered';
    END IF;
  END IF;

  vstartidx := abs(hskip)%2;

  RAISE DEBUG 'vstartary: % : %', vstartary[1], vstartary[2];
  RAISE DEBUG 'vstartidx: %', vstartidx;

  c := ST_SetSRID(ST_MakePoint(hstart, vstartary[vstartidx+1]), srid);
  h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
  vstartidx := (vstartidx + 1) % 2;
  WHILE ST_X(c) < hend LOOP -- over X
    --RAISE DEBUG 'X loop starts, center point: %', ST_AsText(c);
    WHILE ST_Y(c) < vend LOOP -- over Y
      --RAISE DEBUG 'Center: %', ST_AsText(c);
      --h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
      RETURN NEXT h;
      h := ST_SnapToGrid(ST_Translate(h, 0, vstep), xoff, yoff, xgrd, ygrd);
      c := ST_Translate(c, 0, vstep);  -- TODO: drop ?
    END LOOP;
    -- TODO: translate h direcly ...
    c := ST_SetSRID(ST_MakePoint(ST_X(c)+hstep, vstartary[vstartidx+1]), srid);
    h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
    vstartidx := (vstartidx + 1) % 2;
  END LOOP;

  RETURN;
END
$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;