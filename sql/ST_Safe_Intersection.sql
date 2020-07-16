-- BSD 3-Clause License
--
-- Copyright (c) 2016, Juno Inc.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice, this
--   list of conditions and the following disclaimer.
--
-- * Redistributions in binary form must reproduce the above copyright notice,
--   this list of conditions and the following disclaimer in the documentation
--   and/or other materials provided with the distribution.
--
-- * Neither the name of the copyright holder nor the names of its
--   contributors may be used to endorse or promote products derived from
--   this software without specific prior written permission.
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


create or replace function ST_Safe_Intersection(
    geom_a           geometry,
    geom_b           geometry default null,
    message          text default '[unspecified]',
    grid_granularity double precision default 1
)
    returns geometry as
$$
begin
    if geom_b is null
    then
        raise notice 'ST_Safe_Intersection: second geometry is NULL (%%)', message;
        return geom_b;
    end if;
    return
    ST_Safe_Repair(
        ST_Intersection(
            geom_a,
            geom_b
        )
    );
    exception
    when others
        then
            begin
                raise notice 'ST_Safe_Intersection: making everything valid (%%)', message;
                return
                ST_Translate(
                    ST_Safe_Repair(
                        ST_Intersection(
                            ST_Safe_Repair(ST_Translate(geom_a, -ST_XMin(geom_a), -ST_YMin(geom_a))),
                            ST_Safe_Repair(ST_Translate(geom_b, -ST_XMin(geom_a), -ST_YMin(geom_a)))
                        )
                    ),
                    ST_XMin(geom_a),
                    ST_YMin(geom_a)
                );
                exception
                when others
                    then
                        begin
                            raise notice 'ST_Safe_Intersection: buffering everything (%%)', message;
                            return
                            ST_Safe_Repair(
                                ST_Intersection(
                                    ST_Buffer(
                                        geom_a,
                                        0.4 * grid_granularity
                                    ),
                                    ST_Buffer(
                                        geom_b,
                                        -0.4 * grid_granularity
                                    )
                                )
                            );
                            exception
                            when others
                                then
                                    raise exception 'ST_Safe_Intersection: everything failed (%%)', message;
                        end;
            end;
end
$$
language 'plpgsql' immutable parallel safe;
