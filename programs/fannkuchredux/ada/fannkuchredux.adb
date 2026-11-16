--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Ledrug Katz.

with Ada.Command_Line;
with Ada.Text_IO;

procedure Fannkuchredux is
   subtype Elem is Integer;
   type Elems is array (0 .. 15) of Elem;

   S, T : Elems := (others => 0);

   Maxflips : Integer := 0;
   Max_N    : Integer;
   Odd      : Boolean := False;
   Checksum : Integer := 0;

   function Img (V : Integer) return String is
      Text : constant String := Integer'Image (V);
   begin
      return (if Text (Text'First) = ' ' then Text (Text'First + 1 .. Text'Last) else Text);
   end Img;

   function Flip return Integer is
      I, C : Integer;
      X, Y : Integer;
   begin
      for K in 0 .. Max_N - 1 loop
         T (K) := S (K);
      end loop;
      I := 1;
      loop
         X := 0;
         Y := T (0);
         while X < Y loop
            C := T (X);
            T (X) := T (Y);
            T (Y) := C;
            X := X + 1;
            Y := Y - 1;
         end loop;
         I := I + 1;
         exit when T (T (0)) = 0;
      end loop;
      return I;
   end Flip;

   procedure Rotate (N : Integer) is
      C : constant Elem := S (0);
   begin
      for I in 1 .. N loop
         S (I - 1) := S (I);
      end loop;
      S (N) := C;
   end Rotate;

   --  Tompkin-Paige iterative permutation generation.
   procedure Tk (N : Integer) is
      I : Integer := 0;
      F : Integer;
      C : Elems := (others => 0);
   begin
      while I < N loop
         Rotate (I);
         if C (I) >= I then
            C (I) := 0;
            I := I + 1;
         else
            C (I) := C (I) + 1;
            I := 1;
            Odd := not Odd;
            if S (0) /= 0 then
               F := (if S (S (0)) /= 0 then Flip else 1);
               if F > Maxflips then
                  Maxflips := F;
               end if;
               Checksum := Checksum + (if Odd then -F else F);
            end if;
         end if;
      end loop;
   end Tk;

begin
   Max_N := Integer'Value (Ada.Command_Line.Argument (1));
   for I in 0 .. Max_N - 1 loop
      S (I) := I;
   end loop;
   Tk (Max_N);
   Ada.Text_IO.Put_Line (Img (Checksum));
   Ada.Text_IO.Put_Line ("Pfannkuchen(" & Img (Max_N) & ") = " & Img (Maxflips));
end Fannkuchredux;
