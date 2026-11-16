--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Christoph Bauer and
--  modified by Danny Angelo Carminati Grein.

with Ada.Command_Line;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Text_IO;

procedure Nbody is
   use Ada.Numerics.Long_Elementary_Functions;

   Pi            : constant := 3.141592653589793;
   Solar_Mass    : constant := 4.0 * Pi * Pi;
   Days_Per_Year : constant := 365.24;

   type Planet is record
      X, Y, Z    : Long_Float;
      Vx, Vy, Vz : Long_Float;
      Mass       : Long_Float;
   end record;

   Nbodies : constant := 5;
   type Planets is array (0 .. Nbodies - 1) of Planet;

   Bodies : Planets :=
     ((0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Solar_Mass),
      (4.84143144246472090e+00,
       -1.16032004402742839e+00,
       -1.03622044471123109e-01,
       1.66007664274403694e-03 * Days_Per_Year,
       7.69901118419740425e-03 * Days_Per_Year,
       -6.90460016972063023e-05 * Days_Per_Year,
       9.54791938424326609e-04 * Solar_Mass),
      (8.34336671824457987e+00,
       4.12479856412430479e+00,
       -4.03523417114321381e-01,
       -2.76742510726862411e-03 * Days_Per_Year,
       4.99852801234917238e-03 * Days_Per_Year,
       2.30417297573763929e-05 * Days_Per_Year,
       2.85885980666130812e-04 * Solar_Mass),
      (1.28943695621391310e+01,
       -1.51111514016986312e+01,
       -2.23307578892655734e-01,
       2.96460137564761618e-03 * Days_Per_Year,
       2.37847173959480950e-03 * Days_Per_Year,
       -2.96589568540237556e-05 * Days_Per_Year,
       4.36624404335156298e-05 * Solar_Mass),
      (1.53796971148509165e+01,
       -2.59193146099879641e+01,
       1.79258772950371181e-01,
       2.68067772490389322e-03 * Days_Per_Year,
       1.62824170038242295e-03 * Days_Per_Year,
       -9.51592254519715870e-05 * Days_Per_Year,
       5.15138902046611451e-05 * Solar_Mass));

   procedure Advance (Dt : Long_Float) is
   begin
      for I in Bodies'Range loop
         for J in I + 1 .. Bodies'Last loop
            declare
               B         : Planet renames Bodies (I);
               B2        : Planet renames Bodies (J);
               Dx        : constant Long_Float := B.X - B2.X;
               Dy        : constant Long_Float := B.Y - B2.Y;
               Dz        : constant Long_Float := B.Z - B2.Z;
               Distanced : constant Long_Float := Dx * Dx + Dy * Dy + Dz * Dz;
               Distance  : constant Long_Float := Sqrt (Distanced);
               Mag       : constant Long_Float := Dt / (Distanced * Distance);
            begin
               B.Vx := B.Vx - Dx * B2.Mass * Mag;
               B.Vy := B.Vy - Dy * B2.Mass * Mag;
               B.Vz := B.Vz - Dz * B2.Mass * Mag;
               B2.Vx := B2.Vx + Dx * B.Mass * Mag;
               B2.Vy := B2.Vy + Dy * B.Mass * Mag;
               B2.Vz := B2.Vz + Dz * B.Mass * Mag;
            end;
         end loop;
      end loop;
      for I in Bodies'Range loop
         declare
            B : Planet renames Bodies (I);
         begin
            B.X := B.X + Dt * B.Vx;
            B.Y := B.Y + Dt * B.Vy;
            B.Z := B.Z + Dt * B.Vz;
         end;
      end loop;
   end Advance;

   function Energy return Long_Float is
      E : Long_Float := 0.0;
   begin
      for I in Bodies'Range loop
         declare
            B : Planet renames Bodies (I);
         begin
            E := E + 0.5 * B.Mass * (B.Vx * B.Vx + B.Vy * B.Vy + B.Vz * B.Vz);
            for J in I + 1 .. Bodies'Last loop
               declare
                  B2       : Planet renames Bodies (J);
                  Dx       : constant Long_Float := B.X - B2.X;
                  Dy       : constant Long_Float := B.Y - B2.Y;
                  Dz       : constant Long_Float := B.Z - B2.Z;
                  Distance : constant Long_Float := Sqrt (Dx * Dx + Dy * Dy + Dz * Dz);
               begin
                  E := E - (B.Mass * B2.Mass) / Distance;
               end;
            end loop;
         end;
      end loop;
      return E;
   end Energy;

   procedure Offset_Momentum is
      Px, Py, Pz : Long_Float := 0.0;
   begin
      for I in Bodies'Range loop
         Px := Px + Bodies (I).Vx * Bodies (I).Mass;
         Py := Py + Bodies (I).Vy * Bodies (I).Mass;
         Pz := Pz + Bodies (I).Vz * Bodies (I).Mass;
      end loop;
      Bodies (0).Vx := -Px / Solar_Mass;
      Bodies (0).Vy := -Py / Solar_Mass;
      Bodies (0).Vz := -Pz / Solar_Mass;
   end Offset_Momentum;

   package Long_IO is new Ada.Text_IO.Float_IO (Long_Float);

   N : constant Natural := Natural'Value (Ada.Command_Line.Argument (1));
begin
   Offset_Momentum;
   Long_IO.Put (Energy, Fore => 1, Aft => 9, Exp => 0);
   Ada.Text_IO.New_Line;
   for I in 1 .. N loop
      Advance (0.01);
   end loop;
   Long_IO.Put (Energy, Fore => 1, Aft => 9, Exp => 0);
   Ada.Text_IO.New_Line;
end Nbody;
