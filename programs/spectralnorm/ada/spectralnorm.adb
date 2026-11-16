--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Sebastien Loisel.

with Ada.Command_Line;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Text_IO;

procedure Spectralnorm is
   use Ada.Numerics.Long_Elementary_Functions;

   type Vector is array (Natural range <>) of Long_Float;

   function Eval_A (I, J : Integer) return Long_Float is
   begin
      return 1.0 / Long_Float ((I + J) * (I + J + 1) / 2 + I + 1);
   end Eval_A;

   procedure Eval_A_Times_U (U : Vector; Au : out Vector) is
   begin
      for I in Au'Range loop
         Au (I) := 0.0;
         for J in U'Range loop
            Au (I) := Au (I) + Eval_A (I, J) * U (J);
         end loop;
      end loop;
   end Eval_A_Times_U;

   procedure Eval_At_Times_U (U : Vector; Au : out Vector) is
   begin
      for I in Au'Range loop
         Au (I) := 0.0;
         for J in U'Range loop
            Au (I) := Au (I) + Eval_A (J, I) * U (J);
         end loop;
      end loop;
   end Eval_At_Times_U;

   procedure Eval_AtA_Times_U (U : Vector; AtAu : out Vector) is
      V : Vector (U'Range);
   begin
      Eval_A_Times_U (U, V);
      Eval_At_Times_U (V, AtAu);
   end Eval_AtA_Times_U;

   package Long_IO is new Ada.Text_IO.Float_IO (Long_Float);

   N : constant Natural :=
     (if Ada.Command_Line.Argument_Count = 1
      then Natural'Value (Ada.Command_Line.Argument (1)) else 100);
   U, V     : Vector (0 .. N - 1);
   VBv, Vv  : Long_Float := 0.0;
begin
   U := (others => 1.0);
   for I in 1 .. 10 loop
      Eval_AtA_Times_U (U, V);
      Eval_AtA_Times_U (V, U);
   end loop;
   for I in 0 .. N - 1 loop
      VBv := VBv + U (I) * V (I);
      Vv := Vv + V (I) * V (I);
   end loop;
   Long_IO.Put (Sqrt (VBv / Vv), Fore => 1, Aft => 9, Exp => 0);
   Ada.Text_IO.New_Line;
end Spectralnorm;
